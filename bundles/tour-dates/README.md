# Tour Dates

A small web page listing every confirmed show, so nobody has to ask for the latest spreadsheet.

## What it does

Open the app's web address and you get a table of shows — city, venue, and date. Anyone who can
reach the page can also upload a CSV file to add more dates.

The first time somebody opens the page, the app creates its table and fills it with six example
shows. There is no separate setup step and no migration to run by hand. If the table already has
rows, nothing is added — the examples only appear when the table is empty.

## What gets created

- A Cloud Run service that runs the app. It sleeps when nobody is using it and wakes up on the
  next visit.
- A container image, built inside Google Cloud from the code in `build/app/`. Nobody needs Docker
  or `gcloud` installed on their laptop.
- A table called `shows` inside this app's own schema in the shared database, with the columns
  `city`, `venue`, and `show_date`.
- Two separate identities in Google Cloud: one that only builds the image, and one that only runs
  the service. Neither can do the other's job.

## Why it shares a database instead of having its own

The app connects to the shared PostgreSQL database through a `pg-table-set` component. That gives
it a schema it owns completely, and a login that can reach nothing else in the database.

One shared database is cheaper than five separate ones, gets backed up once, and lets one app read
another app's data without copying it around. The schema boundary is what stops any app from
dropping another app's tables.

The show schedule is the kind of table other apps want to read — Merch Inventory cares which
cities are coming up. That is done by adding `tour_dates.shows` to `shared_tables` on the reading
app's `pg-table-set` component. It then shows up on the canvas as a link between the two apps, so
this team can see who depends on the table before changing it.

## Adding dates from a spreadsheet

The upload form on the page takes a CSV file with three columns, in this order:

```
city,venue,show_date
Lisbon,Coliseu dos Recreios,2026-09-14
Madrid,La Riviera,2026-09-17
```

`show_date` is a real date column, so it has to be written as `YYYY-MM-DD`. A header row is
skipped if its first cell reads `city`. Uploading adds rows — it never replaces what is already
there, and it does not check for duplicates. Uploading the same file twice gives you every show
twice.

## Who can see it

Nothing on the open internet can reach this app unless somebody turns on **Anyone On The Internet
Can Reach This**. It is off to begin with, so the page answers only requests from inside Google
Cloud until that is deliberately changed.

The database password is never shown on the page and never typed by anyone. It is generated when
the database component deploys and handed to the app at deploy time.

## Where the app's code lives

`build/app/main.py` and `build/app/Dockerfile`. Every deploy zips that folder, builds it inside
Google Cloud, and runs the result. Changing what the page shows means changing those two files and
deploying again.
