# AWS Lambda App

Runs your application code on AWS Lambda.

You do not manage servers, and you pay only while a request is actually running. This suits web
APIs, scheduled jobs, and code that reacts to events. It suits long-running processes and
anything needing a persistent connection much less well.

## How code gets here

This bundle creates a private S3 bucket that belongs to your function, and the function loads
its code from that bucket. Shipping a new version is two steps:

1. Upload a zip of your code to the bucket under a new name, for example `app-v2.zip`
2. Change **Code Object Key** to `app-v2.zip` and redeploy

Uploading under a *new* name each time is deliberate. Every deploy points at an exact file, so
you can see which build is running and roll back by pointing at the previous one.

Until you upload anything, the function runs a placeholder that returns a small JSON message.
That is expected on a first deploy — it means the infrastructure works and is waiting for your
code.

The runbook has the exact upload command, with your bucket name filled in.

## Connecting a network

Leave the network unlinked unless you need it. Functions outside a network start faster and
need no extra setup.

Link a network when the function must reach something private, such as a database with no
public endpoint. When you link one, the function is placed in the private subnets and gets
outbound access — but note that reaching the public internet from there also requires the
network to have a NAT gateway enabled.

## Connecting an asset bucket

Link an asset bucket and the function receives its name and endpoint as environment variables
(`ASSET_BUCKET`, `ASSET_ENDPOINT`, `ASSET_REGION`), plus permission to use it.

**Asset Bucket Access** controls how much permission. The options come from the bucket itself.
Choose the least the code needs — a function that only serves images should have `read`.

## Settings worth understanding

**Memory** also determines CPU. A function that feels slow is often CPU-starved, and raising
memory can make it both faster *and* cheaper, because it finishes sooner. Try 1 GB before
assuming the code is the problem.

**Timeout** is a safety net, not a target. If a function regularly runs near its timeout, the
work probably belongs in a background job instead of a web request.

**Maximum Concurrent Executions** matters most when the function talks to a database. Lambda
will happily run a thousand copies at once and exhaust the database's connection limit. Set a
real number before pointing production traffic at anything stateful.

**Capture Failed Events** only affects background invocations. It does nothing for web
requests, which return an error to the caller instead.

## Costs

You pay per request and per millisecond of run time, and the free tier is generous — a modest
API often costs under a dollar a month. The parts that cost real money are a NAT gateway (if
you link a network that has one), request tracing at high volume, and log storage.
