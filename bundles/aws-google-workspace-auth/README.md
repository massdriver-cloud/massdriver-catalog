# Google Workspace Sign-in

Puts a Google sign-in door in front of an API. Connect it to an endpoint and requests without a
valid sign-in are turned away before any of that endpoint's code runs.

## How it fits together

This creates the door. It does not decide which endpoints use it — that is the endpoint's own
choice, made by connecting to this. There is a good reason for that: a path can only be secured
by whoever owns it, and endpoints own their own paths.

The practical effect is that turning sign-in on or off for an endpoint is connecting or
disconnecting a line, and the endpoint redeploys in under a minute either way.

One door can serve many endpoints. They all get the same policy, which is usually what you want
— an application where half the endpoints have different sign-in rules is an application waiting
for someone to make a mistake.

## Two separate questions

**Is this token genuine?** Answered by the gateway itself, before your code runs. It checks the
signature against Google's published keys, the issuer, the audience, and the expiry. Nothing you
write is involved and nothing reaches your endpoint if it fails.

**Should this particular person be allowed in?** A different question, and one about your
organization rather than about the token. Google reports the account's Workspace domain in the
token, but the gateway cannot be told to check arbitrary fields — so the allowed domains travel
with this resource to every connected endpoint, which checks them on a request the gateway has
already proven genuine.

That split matters when something is being refused: **401** is the door, **403** is the domain
list.

## What you need from Google first

An OAuth client in Google Cloud, whose client ID ends in `.apps.googleusercontent.com`. That ID
is what ties a sign-in to your application specifically — without it, any valid Google token from
any application on earth would be accepted.

`allowed_domains` takes Workspace domains, not email addresses. Someone signing in with a
personal Google account is turned away even though their sign-in is completely genuine, because
`gmail.com` is not your organization.

## Compliance

The scanner runs on every deployment. In production a finding stops the deployment; elsewhere it
is recorded and the deployment continues.

**Nothing is skipped.** This bundle creates one authorizer and publishes it; every check that
applies passes. `src/.checkov.yaml` is kept with an empty skip list so the answer to "what does
this bundle skip and why" is in the same place for every bundle, including the ones where the
answer is nothing.

### No alarms

There is nothing here to alarm on. An authorizer emits no metrics of its own — it is
configuration the gateway consults, not something that runs. What you actually want to watch is
the rate of rejected callers, and that belongs to the API this is attached to, where it is
already alarmed.
