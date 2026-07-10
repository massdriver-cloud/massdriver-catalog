---
templating: mustache
---

# Lambda API Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Function ARN | `{{artifacts.app.id}}` |
| API URL | `{{artifacts.app.url}}` |
| Region | `{{params.region}}` |
| Memory | `{{params.memory_mb}} MB` |
| Timeout | `{{params.timeout_seconds}}s` |

Quick health check:

```bash
curl -s "{{artifacts.app.url}}todos"
```

---

## Active alarms — what they mean

### Errors

Invocations are failing — unhandled exceptions, timeouts, or the function can't reach DynamoDB. Read the actual error first:

```bash
FN="{{artifacts.app.id}}"
aws logs tail "/aws/lambda/${FN##*:}" --since 10m --follow
```

- **Stack traces** → a code bug. Fix the handler in `src/function/`, publish, redeploy.
- **`Task timed out after {{params.timeout_seconds}} seconds`** → raise `timeout_seconds`, or the function is stuck waiting on something. Remember function URL callers give up around 30s regardless.
- **`AccessDeniedException` on DynamoDB** → the role only allows Get/Put/Delete/Scan on this instance's table. If the handler now needs more, add it to the policy in `src/main.tf`.

### Throttles

Lambda is rejecting invocations because the account's regional concurrency pool is exhausted. This function has no reserved concurrency, so a noisy neighbor in the same account can starve it.

```bash
# Who is eating the concurrency?
aws lambda get-account-settings --region {{params.region}}
aws lambda list-functions --region {{params.region}} \
  --query 'Functions[].{name:FunctionName,mem:MemorySize}' --output table
```

**Fix now:** find and stop the runaway function, or set reserved concurrency on this one to guarantee it a slice.
**Fix later:** ask AWS for a concurrency limit increase.

## "The API is returning 500s"

Same drill as the Errors alarm — the logs have the truth:

```bash
FN="{{artifacts.app.id}}"
aws logs tail "/aws/lambda/${FN##*:}" --since 10m
```

If the logs are empty but callers see errors, the request never reached the function — check they're using the exact URL above (function URLs change if the function is recreated).

## "All the todos vanished"

Expected if the instance was decommissioned and redeployed: the DynamoDB table is created and destroyed **with this bundle**. That's deliberate — it keeps the demo self-contained with nothing to clean up. If someone is treating this data as durable, that's the real incident: move them to a database bundle with its own lifecycle and backups.
