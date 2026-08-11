# Tooth Fairy Rate Index

A fun, anonymous campaign web app. Visitors type in what the tooth fairy pays at their house
and their zip code, and see:

- The national average payout
- A state-by-state breakdown
- A chart of how the rate has changed over time

Results update on their own every few seconds as new answers come in — no need to refresh the
page.

## Privacy, by design

This app never asks for a name or email, and never stores the zip code you type in. On submit,
the zip is converted to a state right away and thrown out — only the state, the amount, and the
time are saved. A zip code can narrow someone down to a small area; a state can't, so this gets
the "which part of the country" answer the map needs without keeping anything that could
identify a person.

Amounts are checked against a sane range (a few cents up to $100) so one troll typing in
`$999999` can't wreck the national average for everyone else.

The page also carries a small note at the bottom: this is a demo app, please don't enter real
personal information.

## What you get

A running copy of the app with its own public web address, built inside Google Cloud from the
source in `build/app/` — no Docker or `gcloud` needed on your machine. See the base
`gcp-cloud-run` template's docs for how the build+deploy pipeline works.

## Settings

Same settings as the base Cloud Run template (service name, region, size, min/max copies). Two
worth calling out for this app specifically:

**Anyone On The Internet Can Reach This** — on by default. This is a public campaign site
meant to be shared with a link, and it never collects anything personal, so there's no reason
to keep it private.

**Firestore** — required. This is where state + amount + timestamp gets stored. Connect this
app to a Firestore database bundle on the canvas before deploying.

## How the live updates work

The browser polls a small `/api/stats` endpoint on this app every 5 seconds and redraws the
average, the state breakdown, and the chart with whatever's newest. This was chosen over
Firestore's realtime listeners (which would mean handing the browser its own Firestore
credentials and read rules — more moving parts than a small campaign app needs) and over
Server-Sent Events or WebSockets (which need a long-lived, sticky connection per visitor —
awkward on Cloud Run, which is built around short request/response cycles and can scale to
zero between them). A short poll interval keeps everything server-side, works naturally with
Cloud Run's request-driven model, and still feels live for this kind of app.

## Where your app's code lives

The Flask app, its Firestore access code, and the page template all live in `build/app/`.
Every deploy zips that folder up, builds it into a container image inside Google Cloud, and
runs it.
