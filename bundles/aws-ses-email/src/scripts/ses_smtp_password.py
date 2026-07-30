#!/usr/bin/env python3
"""
Derives an SES SMTP password from an IAM secret access key, per AWS's
published algorithm (SigV4-style HMAC chain, fixed date/service/terminal,
version byte 0x04). Invoked by Terraform's `external` data source —
reads {"secret_access_key": ..., "region": ...} on stdin, writes
{"password": "..."} on stdout.
"""
import base64
import hashlib
import hmac
import json
import sys

DATE = "11111111"
SERVICE = "ses"
MESSAGE = "SendRawEmail"
TERMINAL = "aws4_request"
VERSION = bytes([0x04])


def sign(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()


def smtp_password(secret_access_key: str, region: str) -> str:
    sig = sign(("AWS4" + secret_access_key).encode("utf-8"), DATE)
    sig = sign(sig, region)
    sig = sign(sig, SERVICE)
    sig = sign(sig, TERMINAL)
    sig = sign(sig, MESSAGE)
    return base64.b64encode(VERSION + sig).decode("utf-8")


def main() -> None:
    query = json.loads(sys.stdin.read())
    password = smtp_password(query["secret_access_key"], query["region"])
    print(json.dumps({"password": password}))


if __name__ == "__main__":
    main()
