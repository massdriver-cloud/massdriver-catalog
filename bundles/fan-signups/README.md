# Fan Signups

A small web page holding the mailing list signups collected at the merch table.

## What it does

Open the app's web address and you get a table of signups — email, name, and where the person
signed up. Anyone who can reach the page can also upload a CSV file to add more.

The first time somebody opens the page, the app creates its table and fills it with six example
signups. There is no separate setup step and no migration to run by hand. If the table already has
rows, nothing is added — the examples only appear when the table is empty.

## What gets created

- A Cloud Run service that runs the app. It sleeps when nobody is using it and wakes up on the
  next visit.
- A container image, built inside Google Cloud from the code in `build/app/`. Nobody needs Docker
  or `gcloud` installed on their laptop.
- A table called `signups` inside this app's own schema in the shared database, with the columns
  `email`, `name`, and `source`.
- Two separate identities in Google Cloud: one that only builds the image, and one that only runs
  the service. Neither can do the other's job.

## Why it shares a database instead of having its own

The app connects to the shared PostgreSQL database through a `pg-schema` component. That gives
it a schema it owns completely, and a login that can reach nothing else in the database.

One shared database is cheaper than five separate ones, gets backed up once, and lets one app read
another app's data without copying it around. The schema boundary is what stops any app from
dropping another app's tables.

This matters more here than for the other apps. Signups are personal data, so no other app can
read this table by accident — reading it would take an explicit `shared_tables` entry naming
`fan_signups.signups`, which appears on the canvas as a visible link and in the deployment history
as a reviewed change. There is no way for another app to quietly start reading the mailing list.

## Adding signups from a spreadsheet

The upload form on the page takes a CSV file with three columns, in this order:

```
email,name,source
j.moreau@example.com,Juliette Moreau,Lisbon show
dpark@example.com,Daniel Park,Madrid show
```

A header row is skipped if its first cell reads `email`. Uploading adds rows — it never replaces
what is already there, and it does not check for duplicates. Uploading the same file twice gives
you every person twice, and the same address can appear on many rows, so treat the table as a log
of signups rather than a clean mailing list.

Nothing in this app validates that an email address is real or correctly formed.

## Who can see it

Nothing on the open internet can reach this app unless somebody turns on **Anyone On The Internet
Can Reach This**. It is off to begin with, so the page answers only requests from inside Google
Cloud until that is deliberately changed. Given what this table holds, leaving it off is the right
default and turning it on is a decision worth making deliberately.

The database password is never shown on the page and never typed by anyone. It is generated when
the database component deploys and handed to the app at deploy time.

## Where the app's code lives

`build/app/main.py` and `build/app/Dockerfile`. Every deploy zips that folder, builds it inside
Google Cloud, and runs the result. Changing what the page shows means changing those two files and
deploying again.
