"""Game world API.

Players, positions, inventory, and combat for a small multiplayer browser game.
The server is authoritative: the browser asks to move or attack, and this decides
what actually happened.

State lives in one DynamoDB table, one item per player, keyed by username.
Inventory is two counters rather than individual items, so picking up a rock is
an atomic increment and there is nothing to reconcile.
"""

import json
import os
import random
import time
import uuid
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Attr

TABLE_NAME = os.environ["TABLE_NAME"]
STARTING_HP = int(os.environ.get("STARTING_HP", "20"))
WORLD_W = int(os.environ.get("WORLD_WIDTH", "1000"))
WORLD_H = int(os.environ.get("WORLD_HEIGHT", "600"))

ROCK_RANGE = 400  # a thrown rock reaches this far
STICK_RANGE = 60  # a swing only lands up close
STICK_BREAK_CHANCE = 0.25
IDLE_SECONDS = 60  # players quieter than this drop out of the world view

# Rocks and sticks lie on the ground and are collected by walking over them.
PICKUP_RADIUS = 28  # how close you must pass to sweep something up
MAX_ITEMS = 40  # how much litter the world holds at once
SPAWN_INTERVAL = 2.5  # seconds between top-ups
SPAWN_BATCH = 3  # most items added in one top-up

WORLD_KEY = "world#spawn"  # bookkeeping row, never a player

table = boto3.resource("dynamodb").Table(TABLE_NAME)


# --------------------------------------------------------------------------- #
# HTTP plumbing
# --------------------------------------------------------------------------- #

CORS = {
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "content-type",
    "access-control-allow-methods": "GET,POST,OPTIONS",
}


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json", **CORS},
        "body": json.dumps(body, default=_plain),
    }


def _plain(value):
    # DynamoDB hands back Decimal; JSON has no opinion about it.
    if isinstance(value, Decimal):
        return int(value)
    raise TypeError(f"cannot serialize {type(value)}")


def read_body(event):
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        import base64

        try:
            raw = base64.b64decode(raw).decode("utf-8")
        except (ValueError, UnicodeDecodeError):
            return None, respond(400, {"error": "body could not be decoded"})
    try:
        data = json.loads(raw)
    except ValueError:
        return None, respond(400, {"error": "body must be valid JSON"})
    if not isinstance(data, dict):
        return None, respond(400, {"error": "body must be a JSON object"})
    return data, None


def clean_username(raw):
    """Usernames are the primary key, so they are validated, not trusted."""
    if not isinstance(raw, str):
        return None
    name = raw.strip()
    if not 2 <= len(name) <= 16:
        return None
    if not all(c.isalnum() or c in "-_" for c in name):
        return None
    return name


def to_int(value, default=None):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def clamp(value, low, high):
    return max(low, min(high, value))


# --------------------------------------------------------------------------- #
# Player records
# --------------------------------------------------------------------------- #


def is_player(record):
    """Players, ground items, and bookkeeping all share one table."""
    return record.get("kind", "player") == "player"


def as_player(item):
    if not item:
        return None
    return {
        "username": item["pk"],
        "x": int(item.get("x", 0)),
        "y": int(item.get("y", 0)),
        "hp": int(item.get("hp", 0)),
        "max_hp": int(item.get("max_hp", STARTING_HP)),
        "rocks": int(item.get("rocks", 0)),
        "sticks": int(item.get("sticks", 0)),
        "alive": bool(item.get("alive", False)),
        "last_seen": int(item.get("last_seen", 0)),
    }


def get_player(username):
    record = table.get_item(Key={"pk": username}).get("Item")
    if record and not is_player(record):
        return None
    return as_player(record)


def spawn(username):
    """Place a player somewhere in the world with a full loadout of nothing."""
    now = int(time.time())
    item = {
        "pk": username,
        "kind": "player",
        "x": random.randint(50, WORLD_W - 50),
        "y": random.randint(50, WORLD_H - 50),
        "hp": STARTING_HP,
        "max_hp": STARTING_HP,
        # You arrive empty-handed. The ground is where you get armed.
        "rocks": 0,
        "sticks": 0,
        "alive": True,
        "last_seen": now,
    }
    table.put_item(Item=item)
    return as_player(item)


def touch(username):
    table.update_item(
        Key={"pk": username},
        UpdateExpression="SET last_seen = :now",
        ExpressionAttributeValues={":now": int(time.time())},
    )


def distance(a, b):
    return ((a["x"] - b["x"]) ** 2 + (a["y"] - b["y"]) ** 2) ** 0.5


def scan_all(**kwargs):
    while True:
        page = table.scan(**kwargs)
        for record in page.get("Items", []):
            yield record
        if "LastEvaluatedKey" not in page:
            return
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]


def world_view():
    """Everyone currently alive and recently active."""
    cutoff = int(time.time()) - IDLE_SECONDS
    return [
        as_player(r)
        for r in scan_all(FilterExpression=Attr("last_seen").gte(cutoff))
        if is_player(r) and r.get("alive")
    ]


# --------------------------------------------------------------------------- #
# Ground items
#
# Rocks and sticks appear on their own and are collected by walking over them.
# Each one is its own row so that two players racing for the same rock resolve
# through a conditional delete — exactly one of them gets it.
# --------------------------------------------------------------------------- #


def as_item(record):
    return {
        "id": record["pk"],
        "type": record.get("item_type", "rock"),
        "x": int(record.get("x", 0)),
        "y": int(record.get("y", 0)),
    }


def world_items():
    return [as_item(r) for r in scan_all(FilterExpression=Attr("kind").eq("item"))]


def maybe_spawn(existing):
    """Scatter a few more items, at most once every SPAWN_INTERVAL.

    There is no scheduler in front of this API, so topping up rides on the
    polling every client already does. The conditional update means only one
    caller in a crowd wins the right to spawn, however many are polling.
    """
    if len(existing) >= MAX_ITEMS:
        return []

    now = Decimal(str(round(time.time(), 3)))
    ready = now - Decimal(str(SPAWN_INTERVAL))
    try:
        table.update_item(
            Key={"pk": WORLD_KEY},
            UpdateExpression="SET last_spawn = :now, kind = :kind",
            ConditionExpression=Attr("last_spawn").lte(ready) | Attr("last_spawn").not_exists(),
            ExpressionAttributeValues={":now": now, ":kind": "world"},
        )
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        return []

    room = min(SPAWN_BATCH, MAX_ITEMS - len(existing))
    fresh = []
    for _ in range(random.randint(1, room)):
        record = {
            "pk": f"item#{uuid.uuid4()}",
            "kind": "item",
            "item_type": random.choice(["rock", "rock", "stick"]),  # rocks are commoner
            "x": random.randint(20, WORLD_W - 20),
            "y": random.randint(20, WORLD_H - 20),
        }
        table.put_item(Item=record)
        fresh.append(as_item(record))
    return fresh


def point_to_segment(px, py, ax, ay, bx, by):
    """Distance from a point to the line segment a→b.

    Movement is sent as a destination, not a stream of positions, so the server
    sees a jump. Measuring against the whole segment means everything under the
    path gets swept up, however coarsely the client reports movement.
    """
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / float(dx * dx + dy * dy)))
    cx, cy = ax + t * dx, ay + t * dy
    return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5


def collect_along(username, ax, ay, bx, by):
    """Pick up everything lying on the path just walked."""
    picked = {"rock": 0, "stick": 0}
    for record in scan_all(FilterExpression=Attr("kind").eq("item")):
        item = as_item(record)
        if point_to_segment(item["x"], item["y"], ax, ay, bx, by) > PICKUP_RADIUS:
            continue
        try:
            # Whoever deletes the row owns the item; the loser gets nothing.
            table.delete_item(
                Key={"pk": item["id"]},
                ConditionExpression=Attr("pk").exists(),
            )
        except table.meta.client.exceptions.ConditionalCheckFailedException:
            continue
        picked[item["type"]] = picked.get(item["type"], 0) + 1

    if not picked["rock"] and not picked["stick"]:
        return picked

    table.update_item(
        Key={"pk": username},
        UpdateExpression="SET rocks = rocks + :r, sticks = sticks + :s",
        ExpressionAttributeValues={":r": picked["rock"], ":s": picked["stick"]},
    )
    return picked


# --------------------------------------------------------------------------- #
# Game actions
# --------------------------------------------------------------------------- #


def do_login(body):
    username = clean_username(body.get("username"))
    if not username:
        return respond(400, {"error": "username must be 2-16 letters, digits, - or _"})

    player = get_player(username)
    # A dead or absent player starts fresh; a live one simply resumes.
    if player is None or not player["alive"] or player["hp"] <= 0:
        player = spawn(username)
    else:
        touch(username)
        player = get_player(username)
    return respond(200, {"player": player})


def do_state(body):
    username = clean_username(body.get("username"))
    if not username:
        return respond(400, {"error": "unknown username"})
    you = get_player(username)
    if you is None:
        return respond(404, {"error": "no such player, log in again"})
    if you["alive"]:
        touch(username)
        you["last_seen"] = int(time.time())

    items = world_items()
    items.extend(maybe_spawn(items))
    return respond(200, {"you": you, "players": world_view(), "items": items})


def do_move(body):
    username = clean_username(body.get("username"))
    if not username:
        return respond(400, {"error": "unknown username"})
    x, y = to_int(body.get("x")), to_int(body.get("y"))
    if x is None or y is None:
        return respond(400, {"error": "x and y must be numbers"})

    before = get_player(username)
    if before is None:
        return respond(404, {"error": "no such player, log in again"})

    try:
        result = table.update_item(
            Key={"pk": username},
            UpdateExpression="SET x = :x, y = :y, last_seen = :now",
            ConditionExpression=Attr("alive").eq(True),
            ExpressionAttributeValues={
                ":x": clamp(x, 0, WORLD_W),
                ":y": clamp(y, 0, WORLD_H),
                ":now": int(time.time()),
            },
            ReturnValues="ALL_NEW",
        )
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        return respond(409, {"error": "you are dead"})

    moved = as_player(result["Attributes"])
    picked = collect_along(username, before["x"], before["y"], moved["x"], moved["y"])
    if picked["rock"] or picked["stick"]:
        moved["rocks"] += picked["rock"]
        moved["sticks"] += picked["stick"]

    return respond(200, {"you": moved, "picked": picked})


def do_pickup(body):
    """Kept so an older cached client gets an explanation, not a 404."""
    return respond(410, {"error": "walk over rocks and sticks to pick them up"})


def do_attack(body):
    username = clean_username(body.get("username"))
    target_name = clean_username(body.get("target"))
    weapon = body.get("weapon")

    if not username:
        return respond(400, {"error": "unknown username"})
    if not target_name:
        return respond(400, {"error": "pick a target first"})
    if weapon not in ("rock", "stick"):
        return respond(400, {"error": "weapon must be rock or stick"})
    if username == target_name:
        return respond(400, {"error": "you cannot hit yourself"})

    attacker, target = get_player(username), get_player(target_name)
    if attacker is None:
        return respond(404, {"error": "no such player, log in again"})
    if not attacker["alive"]:
        return respond(409, {"error": "you are dead"})
    if target is None or not target["alive"]:
        return respond(404, {"error": f"{target_name} is not in the world"})

    reach = ROCK_RANGE if weapon == "rock" else STICK_RANGE
    if distance(attacker, target) > reach:
        return respond(400, {"error": f"{target_name} is out of range"})

    ammo_field = "rocks" if weapon == "rock" else "sticks"
    if attacker[ammo_field] < 1:
        return respond(400, {"error": f"you have no {ammo_field}"})

    # Spend the ammo first, conditional on still having it. If two swings race,
    # only one of them gets to consume the last stick.
    broke = False
    if weapon == "rock":
        spend = "SET rocks = rocks - :one"
    else:
        # A stick survives unless it breaks, so it is only spent on a break.
        broke = random.random() < STICK_BREAK_CHANCE
        spend = "SET sticks = sticks - :one" if broke else "SET last_seen = :seen"

    values = {":seen": int(time.time())}
    condition = Attr("alive").eq(True)
    if weapon == "rock" or broke:
        values[":one"] = 1
        condition = condition & Attr(ammo_field).gte(1)
        spend += ", last_seen = :seen"

    try:
        attacker_after = table.update_item(
            Key={"pk": username},
            UpdateExpression=spend,
            ConditionExpression=condition,
            ExpressionAttributeValues=values,
            ReturnValues="ALL_NEW",
        )["Attributes"]
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        return respond(409, {"error": f"you have no {ammo_field}"})

    damage = random.randint(1, 10) if weapon == "rock" else random.randint(1, 4)

    target_after = table.update_item(
        Key={"pk": target_name},
        UpdateExpression="SET hp = hp - :dmg",
        ExpressionAttributeValues={":dmg": damage},
        ReturnValues="ALL_NEW",
    )["Attributes"]

    killed = int(target_after.get("hp", 0)) <= 0
    if killed:
        target_after = table.update_item(
            Key={"pk": target_name},
            UpdateExpression="SET hp = :zero, alive = :dead",
            ExpressionAttributeValues={":zero": 0, ":dead": False},
            ReturnValues="ALL_NEW",
        )["Attributes"]

    verb = "hits" if weapon == "rock" else "clubs"
    message = f"{username} {verb} {target_name} for {damage}"
    if broke:
        message += " — the stick snaps"
    if killed:
        message += f" — {target_name} is down!"

    return respond(200, {
        "you": as_player(attacker_after),
        "target": as_player(target_after),
        "damage": damage,
        "killed": killed,
        "broke": broke,
        "message": message,
    })


# --------------------------------------------------------------------------- #
# Admin
# --------------------------------------------------------------------------- #

EDITABLE = {"hp": int, "rocks": int, "sticks": int, "x": int, "y": int, "alive": bool}


def do_admin_list():
    # Ground items and the spawn bookkeeping row share this table; neither is
    # a player and neither belongs in the console.
    players = [as_player(r) for r in scan_all() if is_player(r)]
    players.sort(key=lambda p: p["username"])
    return respond(200, {"players": players})


def do_admin_update(body):
    username = clean_username(body.get("username"))
    if not username:
        return respond(400, {"error": "unknown username"})
    if get_player(username) is None:
        return respond(404, {"error": "no such player"})

    sets, values = [], {}
    for field, kind in EDITABLE.items():
        if field not in body:
            continue
        if kind is bool:
            value = bool(body[field])
        else:
            value = to_int(body[field])
            if value is None:
                return respond(400, {"error": f"{field} must be a number"})
            if field == "x":
                value = clamp(value, 0, WORLD_W)
            elif field == "y":
                value = clamp(value, 0, WORLD_H)
            else:
                value = max(0, value)
        sets.append(f"{field} = :{field}")
        values[f":{field}"] = value

    if not sets:
        return respond(400, {"error": "nothing to change"})

    # Editing hp is the usual way an operator revives or finishes someone off,
    # so keep the alive flag consistent with it unless told otherwise.
    if "hp" in body and "alive" not in body:
        sets.append("alive = :alive")
        values[":alive"] = values[":hp"] > 0

    result = table.update_item(
        Key={"pk": username},
        UpdateExpression="SET " + ", ".join(sets),
        ExpressionAttributeValues=values,
        ReturnValues="ALL_NEW",
    )
    return respond(200, {"player": as_player(result["Attributes"])})


def do_admin_delete(body):
    username = clean_username(body.get("username"))
    if not username:
        return respond(400, {"error": "unknown username"})
    # clean_username already rejects the "item#..." and "world#..." key shapes,
    # but check the record too so the console can never delete world state.
    if get_player(username) is None:
        return respond(404, {"error": "no such player"})
    table.delete_item(Key={"pk": username})
    return respond(200, {"ok": True})


# --------------------------------------------------------------------------- #
# Entry point
# --------------------------------------------------------------------------- #

NEEDS_BODY = {
    "/api/login": do_login,
    "/api/state": do_state,
    "/api/move": do_move,
    "/api/pickup": do_pickup,
    "/api/attack": do_attack,
    "/api/admin/player": do_admin_update,
    "/api/admin/delete": do_admin_delete,
}


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    path = "/" + event["rawPath"].strip("/")

    if method == "OPTIONS":
        return {"statusCode": 204, "headers": CORS, "body": ""}

    if path in ("/", "/api", "/api/health"):
        return respond(200, {"ok": True, "world": {"width": WORLD_W, "height": WORLD_H}})

    if path == "/api/admin/players":
        if method != "GET":
            return respond(405, {"error": "method not allowed"})
        return do_admin_list()

    action = NEEDS_BODY.get(path)
    if action is None:
        return respond(404, {"error": "not found"})
    if method != "POST":
        return respond(405, {"error": "method not allowed"})

    body, error = read_body(event)
    if error:
        return error

    try:
        return action(body)
    except Exception as exc:  # noqa: BLE001 - never hand a raw stack trace to a browser
        print(f"error handling {path}: {exc!r}")
        return respond(500, {"error": "something went wrong"})
