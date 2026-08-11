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
PICKUP_COOLDOWN = 1.0  # seconds, stops a held key farming the world
IDLE_SECONDS = 60  # players quieter than this drop out of the world view

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
    return as_player(table.get_item(Key={"pk": username}).get("Item"))


def spawn(username):
    """Place a player somewhere in the world with a full loadout of nothing."""
    now = int(time.time())
    item = {
        "pk": username,
        "x": random.randint(50, WORLD_W - 50),
        "y": random.randint(50, WORLD_H - 50),
        "hp": STARTING_HP,
        "max_hp": STARTING_HP,
        "rocks": 3,
        "sticks": 1,
        "alive": True,
        "last_seen": now,
        "last_pickup": Decimal("0"),
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


def world_view():
    """Everyone currently alive and recently active."""
    cutoff = int(time.time()) - IDLE_SECONDS
    players, kwargs = [], {"FilterExpression": Attr("last_seen").gte(cutoff)}
    while True:
        page = table.scan(**kwargs)
        players.extend(as_player(i) for i in page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            return [p for p in players if p["alive"]]
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]


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
    return respond(200, {"you": you, "players": world_view()})


def do_move(body):
    username = clean_username(body.get("username"))
    if not username:
        return respond(400, {"error": "unknown username"})
    x, y = to_int(body.get("x")), to_int(body.get("y"))
    if x is None or y is None:
        return respond(400, {"error": "x and y must be numbers"})

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
    return respond(200, {"you": as_player(result["Attributes"])})


def do_pickup(body):
    username = clean_username(body.get("username"))
    item = body.get("item")
    if not username:
        return respond(400, {"error": "unknown username"})
    if item not in ("rock", "stick"):
        return respond(400, {"error": "item must be rock or stick"})

    field = "rocks" if item == "rock" else "sticks"
    now = Decimal(str(round(time.time(), 3)))
    ready = now - Decimal(str(PICKUP_COOLDOWN))

    try:
        result = table.update_item(
            Key={"pk": username},
            UpdateExpression=f"SET {field} = {field} + :one, last_pickup = :now, last_seen = :seen",
            # The cooldown is enforced here rather than in the browser, so a
            # modified client cannot farm the ground.
            ConditionExpression=Attr("alive").eq(True)
            & (Attr("last_pickup").lte(ready) | Attr("last_pickup").not_exists()),
            # Only values the update expression names belong here. The condition
            # builds its own placeholders, and DynamoDB rejects the whole call if
            # anything in this map goes unreferenced.
            ExpressionAttributeValues={
                ":one": 1,
                ":now": now,
                ":seen": int(time.time()),
            },
            ReturnValues="ALL_NEW",
        )
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        you = get_player(username)
        if you and not you["alive"]:
            return respond(409, {"error": "you are dead"})
        return respond(429, {"error": "still bending down"})
    return respond(200, {"you": as_player(result["Attributes"])})


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
    players, kwargs = [], {}
    while True:
        page = table.scan(**kwargs)
        players.extend(as_player(i) for i in page.get("Items", []))
        if "LastEvaluatedKey" not in page:
            break
        kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
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
