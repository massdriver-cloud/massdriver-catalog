---
templating: mustache
---

# {{ name }} Runbook

> Replace this with your team's actual runbook once the function does real work.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Memory | `{{params.memory_mb}} MB` |
| Timeout | `{{params.timeout_seconds}}s` |
| Log retention | `{{params.log_retention_days}}d` |

## The function is erroring

Tail the logs first — the stack trace is almost always enough:

```bash
aws logs tail /aws/lambda/YOUR_FUNCTION_NAME --since 15m --follow
```

## The function is slow or timing out

- Check duration vs. the `{{params.timeout_seconds}}s` timeout in the logs (`REPORT` lines).
- CPU scales with memory — bumping `memory_mb` is the first lever.
- If work genuinely takes minutes, move it to a queue-driven worker instead of raising the timeout.
