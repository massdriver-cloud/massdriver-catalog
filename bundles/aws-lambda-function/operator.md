---
templating: mustache
---

# {{params.route}}

```
Function  {{id}}
Address   {{dependencies.api.url}}
Table     {{dependencies.table.name}}
Region    {{dependencies.api.region}}
Logs      /aws/lambda/{{id}}
```

---

## Endpoint throwing errors

```bash
aws logs filter-log-events --log-group-name /aws/lambda/{{id}} \
  --start-time $(($(date +%s) * 1000 - 900000)) \
  --filter-pattern 'ERROR' \
  --region {{dependencies.api.region}} \
  --query 'events[*].message' --output text | head -40
```

**`AccessDeniedException` on the table** — the endpoint is reaching for something it was not
granted. It has access to `{{dependencies.table.name}}` and nothing else, so this usually means
the code is using a table name it built itself instead of the one it was handed. The name
arrives as `TABLE_NAME`; use it rather than constructing one.

**`ValidationException`** — the record does not match the table's shape. Most often a write with
no `{{dependencies.table.partition_key}}`, or one where it is empty. Every record needs that
attribute, and it cannot be blank.

**`ResourceNotFoundException`** — the table is gone or this is pointed at the wrong region. Both
should be visible on the canvas.

**A timeout with no error** — see below.

---

## Requests refused at the limit

The ceiling on simultaneous requests was reached, and requests above it were refused rather than
queued. Callers saw failures.

```bash
aws lambda get-function-concurrency --function-name {{id}} \
  --region {{dependencies.api.region}}
```

Decide whether the traffic is real before raising it. A genuine increase means raise
`max_concurrent_executions` and redeploy. A loop somewhere means the ceiling just did exactly
what it is for — find the caller.

```bash
# How hard, and for how long
aws cloudwatch get-metric-statistics --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --dimensions Name=FunctionName,Value={{id}} \
  --start-time $(date -u -v-1H +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Maximum --region {{dependencies.api.region}}
```

Worth knowing: this ceiling protects the rest of the account. Raising it a long way takes
capacity other applications share.

---

## Requests approaching the timeout

Firing at 80% of the limit, so requests are not being cut off yet. They will be.

```bash
# Slowest recent invocations
aws logs filter-log-events --log-group-name /aws/lambda/{{id}} \
  --start-time $(($(date +%s) * 1000 - 3600000)) \
  --filter-pattern 'REPORT' \
  --region {{dependencies.api.region}} \
  --query 'events[*].message' --output text \
  | grep -o 'Duration: [0-9.]*' | sort -k2 -rn | head -10
```

Three usual causes, in the order worth checking:

**Scanning instead of querying.** Reading the whole table gets slower every day as records
accumulate — a graph that creeps upward over weeks. If the code reads everything and filters in
memory, it needs to look records up by `{{dependencies.table.partition_key}}` instead.

**Too little memory.** Processing power scales with memory, so a function on 256 MB may simply
be starved. Raising `memory_mb` often makes it cheaper as well as faster, since billing is per
millisecond.

**Cold starts.** If the slow requests are scattered rather than constant, they are first
invocations. Attaching to a network makes this considerably worse — check whether this endpoint
needs `attach_to_network` at all, since the table does not require it.

---

## Everything returns 401

Working as configured. A sign-in policy is attached and requests are being turned away before
this code runs.

```bash
aws apigatewayv2 get-routes --api-id {{dependencies.api.api_id}} \
  --region {{dependencies.api.region}} \
  --query "Items[?RouteKey=='{{params.route}}'].[RouteKey,AuthorizationType,AuthorizerId]" \
  --output table
```

`AuthorizationType` of `JWT` means sign-in is required. To open it again, disconnect the sign-in
policy on the canvas and redeploy — do not edit the route by hand, the next deploy would put it
back.

If callers are signing in correctly and still getting 401, the token is being rejected rather
than missing: usually the wrong client ID, or a token issued for a different application.

---

## Everything returns 403 with a domain message

Sign-in worked; the account is not from a domain that is allowed. That check happens in the
application, using the list passed down by the sign-in policy.

Change `allowed_domains` on the sign-in policy and redeploy. It reaches every endpoint connected
to that policy, not just this one.

---

## Switching from the example to your own image

Set `code_source` to `registry` and give it an image tag. The table, its permissions, the route
and the address are unchanged — only what runs changes.

If the endpoint stops working immediately afterwards, the image is almost certainly the problem
rather than the wiring:

```bash
aws lambda get-function --function-name {{id}} \
  --region {{dependencies.api.region}} --query 'Code.ImageUri'
```

Your image must read `TABLE_NAME` from its environment and expose a handler the runtime can
find. The example in `src/files/starter.py` is the shortest correct reference.
