# AWS API Gateway

Puts your function on the public internet at an HTTPS URL.

Link a function, deploy, and you get back a URL anyone can call. Every request that arrives is
handed to the function, which decides what to do with it.

## How routing works

This bundle creates a single catch-all route. `GET /`, `POST /orders/42`, anything at all — it
all goes to the same function, and your application code does the routing. This is how most web
frameworks expect to work, and it means adding an endpoint to your app does not require an
infrastructure change.

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
authorizer.

## What you get back

Once deployed, the endpoint URL is published as a resource so other things can find it. It
looks like `https://abc123.execute-api.us-east-1.amazonaws.com`, with no stage path on the end.

## Costs

About $1 per million requests, plus log storage. There is no hourly charge — an idle API costs
nothing.
