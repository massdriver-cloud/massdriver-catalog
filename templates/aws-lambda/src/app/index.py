"""Your application code.

Everything in this directory is packaged and deployed when you run
`mass bundle publish --development`. Edit this file, publish, deploy — that is
the whole loop. You never need cloud credentials or the AWS CLI.

To add libraries, install them next to this file so they travel with the code:

    pip install requests -t .
"""

import json
import os


def handler(event, context):
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({
            "message": "Hello from your new function. Edit src/app/index.py to change this.",
            "environment": os.environ.get("APP_ENV", "unknown"),
        }),
    }
