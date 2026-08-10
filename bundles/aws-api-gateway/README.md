# AWS API Gateway

A shared HTTPS front door for your functions.

Deploy it on its own and you get a URL. Nothing answers on that URL yet — functions attach
themselves to it.

## How routing works

This bundle owns the endpoint, the rate limits, and the logs. It does not own any routes.
Each function that connects to it claims its own route, set in that function's form:

- One function with the route `$default` receives every request. Use this for a single
  application that does its own routing.
- Several functions with routes like `GET /orders` and `POST /users` split the traffic between
  them. The gateway decides which function handles each request.

Because the gateway owns no routes itself, you can add and remove functions behind it without
touching the gateway, and the URL never changes.

## Before any function attaches

A freshly deployed gateway returns `404 Not Found` on every path. That is expected — it means
the endpoint is live and waiting for a function to claim a route.

## Rate limiting

**Requests Per Second** is the sustained rate callers get. **Burst Allowance** is how much can
arrive at once above that before requests start getting rejected with a `429`.

These are not optional extras. A function with no limit in front of it will happily scale to
whatever traffic arrives — including a bad loop in a client, a scraper, or an attack — and you
pay for every invocation. Set the rate to something a few times above your expected peak, and
the burst to roughly twice the rate.

## Browser access

If a web page hosted on a different domain calls this API, browsers require the API to say so
explicitly. List those sites in **Browser Origins Allowed to Call This API**.

Leave it empty when only servers, mobile apps, or pages on the same domain call the API — none
of those are subject to this rule.

## Authentication

This bundle does not add authentication. The URL is public, and anything not rejected by rate
limiting reaches your function. If the API needs to be protected, handle it in application code
by checking a token on each request, or ask your platform team for a bundle that adds an
authorizer. Rate limiting applies to every route regardless.

## What you get back

The endpoint URL is published as a resource so functions can attach to it and other things can
find it. It looks like `https://abc123.execute-api.us-east-1.amazonaws.com`, with no stage path
on the end.

## Costs

About $1 per million requests, plus log storage. There is no hourly charge — an idle API costs
nothing.
