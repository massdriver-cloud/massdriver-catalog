# Cloud Run App

Runs your app in the cloud. You don't need Docker or `gcloud` installed on your computer —
Massdriver takes your app's source code, builds the container image inside Google Cloud, and
starts your app running, all in one deploy.

## What you get

A running copy of your app with its own web address. It can scale up automatically when more
people use it, and scale down (even to zero) when nobody is, so you're not paying for a computer
that's sitting idle.

## Settings

**Service Name** — what your app is called. Shows up in its web address and in logs. You can't
change this later, so pick something clear.

**Region** — which part of the world your app runs in. Pick whichever is closest to your users,
or wherever your database lives if you're connecting to one.

**Size** — how much computing power each running copy of your app gets. Start with Small; move up
only if your app is slow or crashes from running out of memory.

**Minimum Copies Always Running** — 0 means your app can go fully to sleep when nobody's using
it. That's the cheapest option, but the very next person to visit waits a few seconds while it
wakes back up. Set this to 1 or higher to keep it always ready, at an ongoing cost.

**Maximum Copies Under Load** — the most copies of your app that can run at the same time during
a traffic spike. This is really your spending ceiling.

**Anyone On The Internet Can Reach This** — off by default. Your app's web address won't work for
anyone until you turn this on. Leave it off for internal tools or anything handling sensitive
data; turn it on for anything public, like a marketing site or public API.

**App Settings** — plain configuration values your app can read when it starts up (feature
flags, API endpoints, that kind of thing). Don't put passwords or API keys here — connect a
database or storage bundle instead, and those get wired in automatically and kept out of plain
sight.

## Connecting a database, file storage, or Firestore

Draw a connection from this app to a database, storage bucket, or Firestore bundle on the canvas,
and your app can immediately read where to find them from its own environment: things like
`DATABASE_HOST`, `DATABASE_PASSWORD`, `BUCKET_NAME`, or `FIRESTORE_PROJECT_ID`. Nothing else to
configure — no connection strings to copy and paste, no secrets to store yourself.

## Making a new app from this template

Each app gets its own copy of this whole setup, with its own source code:

```bash
mass bundle new -n my-app -t gcp-cloud-run -o bundles
```

Then replace the placeholder code in `build/app/` with your real application, and publish.

## Where your app's code lives

Your application's source code and `Dockerfile` live in `build/app/`. Every deploy zips that
folder up, builds it into a container image inside Google Cloud, and runs it — that folder is the
only thing you should need to touch to change what your app does.
