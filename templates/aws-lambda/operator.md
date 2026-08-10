---
templating: mustache
---
{% raw %}
# Lambda App Runbook

{{#resources.function}}

## Deploy new code

Edit the files in the bundle's `src/app` folder, then:

```bash
mass bundle publish --development
```

Deploy the component afterwards. The provisioner packages the folder and uploads it; no cloud
credentials are involved.

To confirm which build is live, compare the function's code object against what is in the
bucket:

```bash
aws s3 ls s3://{{resources.function.code_bucket}}/
```

The object currently in use is `{{resources.function.code_key}}`. Older objects are previous
builds — roll back by setting **Where Your Code Comes From** to the bucket and naming one.

## Function still returns the old code

Confirm the publish actually happened — a deploy reuses the last published bundle, so code
edits that were never published will not appear:

```bash
mass bundle publish --development
```

Then deploy again. If the code object key in the resource panel does not change between
deploys, the contents of `src/app` did not change, because the key is a hash of that folder.

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

## Deploy fails with a route conflict

Symptom: provision fails on `aws_apigatewayv2_route` with `ConflictException`.

Another function already claimed this route on the same gateway. Two functions cannot share
one route key. List what is taken:

```bash
aws apigatewayv2 get-routes --api-id <gateway-api-id> \
  --query 'Items[].RouteKey' --output table
```

Change **Route** to something unclaimed and redeploy. Note that `$default` conflicts with
nothing else by name, but only one function may hold it.

## Function has no public URL

Only relevant when a gateway is linked. Confirm this function actually claimed its route:

```bash
aws apigatewayv2 get-routes --api-id <gateway-api-id> \
  --query 'Items[].{Route:RouteKey,Target:Target}' --output table
```

The `Target` names the integration id. If this function's route is absent, the deploy did not
finish — redeploy. If the gateway is not linked at all, the function has no URL by design.

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
{% endraw %}
