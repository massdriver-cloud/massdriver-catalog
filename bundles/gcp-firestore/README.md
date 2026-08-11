# GCP Firestore

Creates a Firestore database in Google Cloud — a flexible, document-based database for
application data like user profiles, app state, or anything else that doesn't fit neatly into
rows and columns.

## What you get

One standalone Firestore database (Native mode), ready for your app's client library to connect
to. It is not layered on an App Engine app and doesn't need one.

## Settings

**Location** — where your data lives. The multi-region options (`nam5` for the United States,
`eur3` for Europe) spread your data across several regions for the best availability, and are the
right choice unless you have a specific reason to keep data in one region — for example, a legal
requirement to keep it in a particular country. You cannot change this later.

**Keep A Rolling 7-Day Backup** — lets you recover data from any moment in the last 7 days,
handy if something gets deleted or overwritten by mistake, whether by a bug or a person. Roughly
doubles the storage cost for the data it covers.

**Prevent Accidental Deletion** — blocks this database from being deleted, including by removing
this component from your project. Recommended for anything that matters. Turn it off first, then
redeploy, before you actually intend to delete the database.

## Connecting other things to it

This bundle produces a **Firestore Database** resource. Any bundle that needs to read or write
documents can connect to it and pick a policy: **Read** for read-only access, **Read and Write**
for normal application use, or **Admin** for something that also needs to manage indexes and other
database-level settings.

A note on how this works under the hood: Firestore permissions apply to your whole GCP project,
not to one specific database. That's not a problem as long as each project has just one Firestore
database, which is what this bundle is built for — if your project ever needs a second one, the
IAM policies above would apply to both.

## Using it from your app

The database name and project ID are on the resource in Massdriver after deploying. Any of
Google's client libraries (`google-cloud-firestore` in Python, Node, Go, etc.) will pick up
credentials automatically from the environment your app runs in — you just need the project ID
and database name to connect.
