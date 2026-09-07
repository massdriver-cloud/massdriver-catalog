# HTTP API

One public address for an application. Endpoints attach to it and each one takes a path, so an
application can grow from a single endpoint to many without its address ever changing.

## Why the address is its own thing

The alternative is one address per endpoint, and then every time an application adds a feature
its callers have to learn a new hostname. Here the address is created once and outlives every
endpoint behind it. Adding an endpoint publishes it immediately; removing one takes it away.
Nobody redeploys the address to do either.

It also means the sign-in policy, the request logs, and the rate limit are decided once for the
whole application rather than repeated per endpoint and drifting apart.

## Who can call it from a browser

The default allows any website to call this API from a visitor's browser. That is fine while you
are building and wrong as soon as real people use it, because it means any page on the internet
can make requests as your signed-in users.

Before anyone real depends on this, replace it with your own site's address.

## Rate limit

The limit is per second, and requests above it are refused rather than queued. It is the
difference between a bad afternoon and a surprising bill, and it is the only thing standing
between a mistaken loop somewhere and every endpoint behind this address going down together.

## Compliance

The scanner runs on every deployment. In production a finding stops the deployment; elsewhere it
is recorded and the deployment continues.

### Passing by default

| Check | What it wants |
| --- | --- |
| `CKV_AWS_338` | Request logs kept for at least a year. |
| `CKV_AWS_225` | A rate limit, so the address cannot be driven without bound. |
| `CKV_AWS_76` | Access logging switched on at all. |

Log retention defaults to **a year**, which is what most audits ask for and costs very little
since the logs are text. You can shorten it, and in production a shorter window is flagged —
deliberately. Somewhere with no real users and a seven day window is sensible; production with a
seven day window is usually an oversight rather than a decision.

### Deliberately not satisfied

**`CKV_AWS_158` — encrypt the log group with a customer managed key.**

These logs record who called which path and what status came back. They contain no request
bodies and no credentials. A key of our own would protect nothing that is not already inferable
from outside, while adding a key that has to be rotated, paid for, and kept available — and if
it ever became unavailable, logging would stop entirely, which is a worse outcome than the one
being guarded against.

The skip and this reasoning live in `src/.checkov.yaml`.

### Worth knowing

An address with no endpoints attached returns 404 to everything. That is correct, not broken —
there is genuinely nothing there yet. It starts answering the moment an endpoint attaches.
