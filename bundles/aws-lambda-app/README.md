# AWS Lambda App

Runs your application code on AWS Lambda.

You do not manage servers, and you pay only while a request is actually running. This suits web
APIs, scheduled jobs, and code that reacts to events. It suits long-running processes and
anything needing a persistent connection much less well.

## How code gets here

Your code lives in the bundle, in the `src/app` folder. To ship a change:

1. Edit the files in `src/app`
2. `mass bundle publish --development`
3. Deploy the component

That is the whole loop. You do not need cloud credentials, the AWS CLI, or access to any
bucket — the platform holds the credentials and does the upload for you.

Behind the scenes the folder is zipped and stored under a name containing a hash of its
contents, so each change lands as a separate version and older ones stay available to roll back
to.

### Adding libraries

Install them into the same folder so they travel with your code:

```bash
pip install requests -t src/app
```

For Node, run `npm install --omit=dev` inside `src/app`.

### If your team has a build pipeline

Set **Where Your Code Comes From** to "Uploaded to the code bucket" and set **Code Object Key**
to the zip your pipeline pushes. Most people should leave this alone.

## Connecting a network

Leave the network unlinked unless you need it. Functions outside a network start faster and
need no extra setup.

Link a network when the function must reach something private, such as a database with no
public endpoint. When you link one, the function is placed in the private subnets and gets
outbound access — but note that reaching the public internet from there also requires the
network to have a NAT gateway enabled.

## Connecting a gateway

Link an API gateway and this function becomes reachable on the internet. The function claims a
route on that gateway and grants it permission to invoke.

**Route** decides which requests reach this function:

- `$default` — everything the gateway has no other match for. Use this when one function is the
  whole application and does its own routing.
- `GET /orders`, `POST /users` — a specific method and path. Use these when several functions
  share one gateway and each owns part of the API.

Two functions on the same gateway must not claim the same route. The second one to deploy will
fail with a conflict.

Leave the gateway unlinked for a function that runs on a schedule or reacts to events. It still
deploys; it just has no public URL. When a gateway is linked, the function also receives
`API_BASE_URL` as an environment variable.

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
