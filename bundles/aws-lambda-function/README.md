# Serverless Endpoint

A serverless endpoint backed by a table — the most common shape an application takes here.
Attach it to an API, give it a path, and it answers there. Add another for the next endpoint;
the application's address never changes.

## What you connect, and what that does

**An API** decides where this answers. Required — an endpoint with no address cannot be reached.

**A table** is where records go. Connecting one grants this endpoint read and write access to
**that table only**, scoped to its exact identifier, and passes the table's name in as a setting.
Nobody writes a policy and nothing is hardcoded.

**A sign-in policy**, optionally. Connect one and unauthenticated requests are turned away
before any of this code runs. Disconnect it and the endpoint is open again. That is the whole
mechanism — the line is the control.

**A landing zone**, optionally. Only needed to reach things with private addresses. Without one
the endpoint still runs, still reaches its table, and starts faster.

## Starting without writing anything

`code_source` defaults to a working example that reads and writes the connected table, so the
endpoint is provably reachable before anyone has built an image. Point it at your team's
registry when your repository has produced one — the table, the permissions, the route and the
address all stay exactly as they are.

## Memory, and why it is really a speed setting

Processing power is handed out in proportion to memory. A function that looks slow is often a
function that was given 256 MB, and raising it frequently makes the function *cheaper* rather
than dearer, because billing is per millisecond and it finishes sooner.

## Attaching to a network makes cold starts slower

Leave it off unless this endpoint talks to something with a private address. Joining a network
means creating a network interface before the first request can be served, and that is time the
caller waits for. The connected table does not need it.

## Compliance

The scanner runs on every deployment. In production a finding stops the deployment; elsewhere it
is recorded and the deployment continues.

### Passing by default

| Check | What it wants |
| --- | --- |
| `CKV_AWS_115` | A ceiling on simultaneous requests. |
| `CKV_AWS_338` | Logs kept for at least a year. |
| `CKV_AWS_50` | Tracing on, so a slow request can be followed through. |

The ceiling on simultaneous requests is worth understanding rather than just accepting. An
account has a fixed pool of capacity shared by every function in it. Without a ceiling, one
endpoint in a runaway loop consumes the entire pool and takes down every other application in
the account with it. The default is deliberately modest — raise it when you expect real traffic,
but raise it on purpose.

Log retention defaults to **a year**. Shortening it is flagged in production, deliberately.

### Deliberately not satisfied

**`CKV_AWS_117` — run the function inside a VPC.**

This is the closest call of the four, and worth stating plainly: `attach_to_network` does exactly
what the check asks, so connecting a landing zone with it switched on makes this pass on its own.
It is skipped because the default shape of this bundle gains nothing from it. The function is
invoked by the gateway rather than by network traffic, and its one dependency — the table — is
reached over the AWS network whether or not a VPC is involved. Attaching anyway costs a network
interface before the first request can be served, and forces a landing zone onto applications
that otherwise need no network at all.

Left as a finding it would halt every simple endpoint in production over a setting that protects
nothing here, and that is how compliance gates end up switched off entirely. If your organization
requires all compute inside a VPC, connect a landing zone and turn `attach_to_network` on — the
check then passes honestly rather than being skipped.

**`CKV_AWS_272` — verify the code was signed before running it.**

Signing needs a signing profile and a key somebody owns, rotates, and keeps available; miss any
of that and the function stops running at all. What signing protects against is a registry being
tampered with, and here the image digest and the registry's own vulnerability scan already cover
that — the registry accepts pushes from exactly one team's credentials.

**`CKV_AWS_116` — send failed invocations to a dead letter queue.**

A dead letter queue catches failures nobody is waiting on. Everything here is invoked by an API
with a caller on the other end, so a failure already returns to that caller as an error. Adding
a queue would collect messages nobody reads, while the person who actually saw the error has
already gone.

**`CKV_AWS_173` — encrypt environment variables with a customer managed key.**

These hold the table's name, its key attribute, and the allowed sign-in domains. All settings,
all discoverable from the graph anyway. Anything genuinely secret belongs in a secret store the
function reads at runtime, not in its configuration — and the schema says as much on the field.

**`CKV_AWS_158` — encrypt the log group with a customer managed key.**

What an application writes to its logs is the team's call, and a key per endpoint is a key per
endpoint to rotate and pay for. If a team is logging something that needs protecting, the fix is
to stop logging it.

The skips and this reasoning live in `src/.checkov.yaml`.
