"""Reads and writes the connected table.

Replace this with your own image once your repository builds one — the table,
the permissions and the route stay exactly as they are.
"""

import decimal
import json
import os
import time
import uuid

import boto3

TABLE_NAME = os.environ["TABLE_NAME"]
PARTITION_KEY = os.environ.get("PARTITION_KEY", "id")
ALLOWED_DOMAINS = [d for d in os.environ.get("ALLOWED_DOMAINS", "").split(",") if d]

table = boto3.resource("dynamodb").Table(TABLE_NAME)


def _plain(value):
    """Numbers come back from the table as Decimal, which JSON cannot carry."""
    if isinstance(value, decimal.Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"{type(value).__name__} is not JSON serializable")


def _reply(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, default=_plain),
    }


def _caller(event):
    """The gateway has already proven the token is genuine before we run.

    What is left to decide is whether this particular person counts, which is a
    question about the organization rather than about the token.
    """
    claims = (
        event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
    )
    return claims.get("email"), claims.get("hd")


def handler(event, context):
    if ALLOWED_DOMAINS:
        email, domain = _caller(event)
        if domain not in ALLOWED_DOMAINS:
            return _reply(403, {"error": "Your account is not from an allowed domain."})
    else:
        email = None

    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")

    if method == "GET":
        items = table.scan(Limit=25).get("Items", [])
        return _reply(200, {"items": items, "count": len(items)})

    if method == "POST":
        body = json.loads(event.get("body") or "{}")
        item = {
            PARTITION_KEY: str(uuid.uuid4()),
            "text": body.get("text", "untitled"),
            "created_at": int(time.time()),
        }
        if email:
            item["created_by"] = email
        table.put_item(Item=item)
        return _reply(201, {"created": item})

    return _reply(405, {"error": f"{method} is not something this endpoint does."})
