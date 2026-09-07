---
templating: mustache
---

# {{resources.api.url}}

```
API      {{resources.api.api_id}}
Region   {{resources.api.region}}
Logs     /aws/apigateway/{{id}}
```

---

## Requests failing

The application is returning errors, not the caller. Every one of these was a real request that
did not work.

**Find out whether it is one endpoint or all of them.**

```bash
aws logs filter-log-events --log-group-name /aws/apigateway/{{id}} \
  --start-time $(($(date +%s) * 1000 - 900000)) \
  --filter-pattern '{ $.status >= 500 }' \
  --region {{resources.api.region}} \
  --query 'events[*].message' --output text | head -40
```

Each line carries a `routeKey`. If they are all the same route, the problem is that endpoint's
function and this address is an innocent bystander — go to that endpoint's own guide. If they
are spread across every route, the problem is here or in something every endpoint shares.

**If it is everything at once**, check whether a deployment is halfway through. A sign-in policy
attaching or detaching briefly changes how routes answer.

```bash
aws apigatewayv2 get-routes --api-id {{resources.api.api_id}} \
  --region {{resources.api.region}} \
  --query 'Items[*].[RouteKey,AuthorizationType,Target]' --output table
```

A route with no `Target` has lost its endpoint — the function behind it was removed or failed to
deploy, and requests to that path have nowhere to go.

---

## Callers being turned away

A steady trickle of 4xx is normal — bad paths, expired sign-ins, someone poking at the address.
A flood is not.

```bash
# What are they actually getting, and on which paths
aws logs filter-log-events --log-group-name /aws/apigateway/{{id}} \
  --start-time $(($(date +%s) * 1000 - 900000)) \
  --filter-pattern '{ $.status >= 400 && $.status < 500 }' \
  --region {{resources.api.region}} \
  --query 'events[*].message' --output text | head -40
```

**Mostly 401** means sign-in is rejecting people. Either a policy was just attached and callers
have not been told, or the identity provider changed something. Check what the routes expect:

```bash
aws apigatewayv2 get-authorizers --api-id {{resources.api.api_id}} \
  --region {{resources.api.region}} \
  --query 'Items[*].[Name,JwtConfiguration]' --output table
```

**Mostly 404** on paths that used to work means a route disappeared. Usually an endpoint was
removed, or renamed, and its callers were not.

**Mostly 429** means the rate limit is being hit. Decide whether the traffic is real before
raising it — if it is not, the limit is doing its job.

---

## Slowest requests getting slow

Measured at the 99th percentile, so this fires while the average still looks fine. The slow tail
is what times out and what people notice.

```bash
# Which routes are slow, worst first
aws logs filter-log-events --log-group-name /aws/apigateway/{{id}} \
  --start-time $(($(date +%s) * 1000 - 900000)) \
  --region {{resources.api.region}} \
  --query 'events[*].message' --output text \
  | python3 -c "import sys,json;[print(d['responseLength'],d['routeKey'],d['status']) for d in (json.loads(l) for l in sys.stdin if l.strip())]" \
  | sort -rn | head -20
```

This address adds almost nothing to a request's time — it is nearly always the endpoint behind
it. Find the slow route and go to that endpoint's guide. Common causes there: a cold start on a
function that is rarely called, a function attached to a network when it does not need to be, or
a table being scanned rather than queried.

---

## Nothing answers at all

Everything returns 404, including paths you know exist.

```bash
aws apigatewayv2 get-routes --api-id {{resources.api.api_id}} \
  --region {{resources.api.region}} --query 'Items[*].RouteKey' --output text
```

If that comes back empty, no endpoints are attached. An address with no routes returns 404 to
everything, which is correct rather than broken. Deploy an endpoint and it starts answering.

---

## Changing who may call from a browser

```bash
aws apigatewayv2 get-api --api-id {{resources.api.api_id}} \
  --region {{resources.api.region}} --query 'CorsConfiguration'
```

If that shows `*`, any page on the internet can call this API as your signed-in users. Change
`cors_origins` in the configuration and redeploy. Do not edit it by hand here — the next deploy
would put it back.
