---
templating: mustache
---

# API Gateway Runbook

{{#resources.api}}

## Check the endpoint is answering

```bash
curl -i {{resources.api.endpoint}}/
```

A `200` means the whole path works: gateway, permission, and function.

## Every request returns 500 with no function logs

Symptom: `curl` returns `{"message":"Internal Server Error"}`, and the function's log group has
no entries for the request.

The gateway could not invoke the function, so the request never reached it. Confirm the invoke
permission exists:

```bash
aws lambda get-policy --function-name {{dependencies.function.function_name}} \
  --query Policy --output text | python3 -m json.tool
```

Look for a statement with `Principal: apigateway.amazonaws.com` whose `SourceArn` starts with
`{{resources.api.execution_arn}}`. If it is missing, redeploy this bundle — it owns that
permission.

The gateway's own access log records the reason:

```bash
aws logs tail "/aws/apigateway/{{id}}" --follow --format short
```

The `integrationError` field in each entry says what failed.

## Requests return 404

A `404` from the gateway itself means no route matched, which should not happen — this bundle
creates a catch-all. Confirm the route survived:

```bash
aws apigatewayv2 get-routes --api-id {{resources.api.id}} \
  --query 'Items[].RouteKey' --output table
```

You should see `$default`. If you see it and still get a `404`, the `404` is coming *from your
application*, not from the gateway — check the function's logs for the path it received.

## Requests return 429

Callers are exceeding the throttle. Confirm the configured limits:

```bash
aws apigatewayv2 get-stage --api-id {{resources.api.id}} --stage-name '$default' \
  --query 'DefaultRouteSettings' --output json
```

Decide whether this is legitimate growth or abuse before raising the numbers. The access log
shows who is hitting you:

```bash
aws logs filter-log-events --log-group-name "/aws/apigateway/{{id}}" \
  --filter-pattern '{ $.status = 429 }' --max-items 50 \
  --query 'events[].message' --output text
```

If a single `ip` dominates that output, raising the limit just raises the bill.

## Browser calls fail but curl works

The browser is enforcing cross-origin rules that `curl` ignores. Check what origins are allowed:

```bash
aws apigatewayv2 get-api --api-id {{resources.api.id}} \
  --query 'CorsConfiguration' --output json
```

If this is `null`, the origin list is empty — add the site to **Browser Origins Allowed to Call
This API** and redeploy. If it is set, match it against the page's origin exactly; scheme and
port count, so `https://example.com` does not cover `http://example.com` or a subdomain.

## Finding slow requests

The access log records latency per request:

```bash
aws logs filter-log-events --log-group-name "/aws/apigateway/{{id}}" \
  --filter-pattern '{ $.responseLatency > 1000 }' --max-items 20 \
  --query 'events[].message' --output text
```

High latency here with low duration in the function's own logs points at cold starts. Raising
the function's memory usually shortens them.

{{/resources.api}}

{{^resources.api}}

This API has not been deployed yet. Deploy it, then return here for operational procedures.

{{/resources.api}}
