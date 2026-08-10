---
templating: mustache
---

# Lambda App Runbook

{{#resources.function}}

## Deploy new code

Upload the zip under a new key, then set **Code Object Key** to that name and redeploy:

```bash
aws s3 cp ./app.zip s3://{{resources.function.code_bucket}}/app-$(git rev-parse --short HEAD).zip
```

Rolling back is the same move pointed at the previous key:

```bash
aws s3api list-object-versions --bucket {{resources.function.code_bucket}} \
  --query 'Versions[].{Key:Key,Modified:LastModified}' --output table
```

## Function still returns the placeholder message

The function is running `bootstrap.zip`, the placeholder shipped with the bundle. Check what
**Code Object Key** points at, and confirm that object exists:

```bash
aws s3 ls s3://{{resources.function.code_bucket}}/
```

If your zip is there but the function still serves the placeholder, the key in the form does
not match the uploaded filename. They must match exactly, including any prefix.

## Deploy fails with an S3 or code error

Symptom: provision fails on `aws_lambda_function` with `InvalidParameterValueException` about
the S3 key or zip contents.

The object named in **Code Object Key** does not exist, or is not a valid zip. Confirm:

```bash
aws s3api head-object --bucket {{resources.function.code_bucket}} --key {{resources.function.code_key}}
```

A `404` means the key is wrong or the upload never landed. Fix the key or upload the file, then
redeploy.

## Every request fails immediately

Symptom: all invocations error in milliseconds; logs show `Unable to import module` or
`Runtime.HandlerNotFound`.

The handler does not match what is in the zip. **Handler** is `file.function` relative to the
*root* of the zip — if your code is zipped inside a folder, the path is wrong. Verify the zip's
layout:

```bash
aws s3 cp s3://{{resources.function.code_bucket}}/{{resources.function.code_key}} - | unzip -l /dev/stdin
```

For `index.handler`, the zip must contain `index.py` (or `index.js`) at the top level.

## Requests time out

Check the duration and memory the function actually uses:

```bash
aws logs filter-log-events \
  --log-group-name "/aws/lambda/{{resources.function.function_name}}" \
  --filter-pattern "REPORT" --max-items 20 \
  --query 'events[].message' --output text
```

Each `REPORT` line shows `Duration`, `Memory Size`, and `Max Memory Used`. If used memory is
near the limit, raise **Memory** — this also raises CPU and usually cuts duration. If duration
is near the timeout but memory is fine, the function is waiting on something external.

When the function is attached to a network, a timeout that only affects outbound calls usually
means the network has no NAT gateway. See the network's runbook.

## Throttling under load

Symptom: `429` responses, or `Rate Exceeded` in logs.

```bash
aws lambda get-function-concurrency --function-name {{resources.function.function_name}}
```

If this returns a reserved value, **Maximum Concurrent Executions** is capping the function.
Raise it, or leave it capped deliberately if it is protecting a database.

## Reading the logs

```bash
aws logs tail "/aws/lambda/{{resources.function.function_name}}" --follow
```

Set **Log Level** to `debug` for a noisy trace while diagnosing, and put it back afterwards —
debug logging at volume is a real line on the bill.

## Failed background events

Only relevant when **Capture Failed Events** is on. Events that exhausted their retries sit in
the dead-letter queue:

```bash
aws sqs get-queue-url --queue-name {{resources.function.function_name}}-dlq
aws sqs receive-message --queue-url <url-from-above> --max-number-of-messages 10
```

Messages are kept for fourteen days.

{{/resources.function}}

{{^resources.function}}

This function has not been deployed yet. Deploy it, then return here for operational
procedures.

{{/resources.function}}
