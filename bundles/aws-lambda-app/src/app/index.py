"""Your application code.

Everything in this directory is packaged and deployed when you run
`mass bundle publish --development`. Edit this file, publish, deploy — that is
the whole loop. You never need cloud credentials or the AWS CLI.

To add libraries, install them next to this file so they travel with the code:

    pip install requests -t .

The example below is a small REST API over the linked asset bucket. Replace it
with whatever you are building.
"""

import json
import os
import uuid

import boto3  # included in the Python runtime; no install needed

BUCKET = os.environ.get("ASSET_BUCKET")
s3 = boto3.client("s3")


def respond(status, body):
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    method = event["requestContext"]["http"]["method"]
    parts = [p for p in event["rawPath"].split("/") if p]

    if not parts:
        return respond(200, {
            "message": "Your API is running.",
            "try": ["GET /items", "POST /items", "GET /items/{id}", "DELETE /items/{id}"],
        })

    if parts[0] != "items":
        return respond(404, {"error": "not found"})

    if not BUCKET:
        return respond(503, {"error": "no asset bucket is linked to this function"})

    item_id = parts[1] if len(parts) > 1 else None

    if method == "GET" and item_id is None:
        listing = s3.list_objects_v2(Bucket=BUCKET, Prefix="items/")
        ids = [o["Key"][len("items/"):-len(".json")] for o in listing.get("Contents", [])]
        return respond(200, {"items": ids})

    if method == "POST" and item_id is None:
        body = json.loads(event.get("body") or "{}")
        new_id = str(uuid.uuid4())
        s3.put_object(
            Bucket=BUCKET,
            Key=f"items/{new_id}.json",
            Body=json.dumps(body),
            ContentType="application/json",
        )
        return respond(201, {"id": new_id, **body})

    if item_id is None:
        return respond(405, {"error": "method not allowed"})

    if method == "GET":
        try:
            obj = s3.get_object(Bucket=BUCKET, Key=f"items/{item_id}.json")
        except s3.exceptions.NoSuchKey:
            return respond(404, {"error": "not found"})
        return respond(200, {"id": item_id, **json.loads(obj["Body"].read())})

    if method == "DELETE":
        s3.delete_object(Bucket=BUCKET, Key=f"items/{item_id}.json")
        return respond(204, {})

    return respond(405, {"error": "method not allowed"})
