# Merch Inventory

A small web page showing what merchandise is in stock and where it is sitting right now.

## What it does

Open the app's web address and you get a table of stock — SKU, item, location, and quantity.
Anyone who can reach the page can also upload a CSV file to add more items.

The first time somebody opens the page, the app creates its table and fills it with six example
items. There is no separate setup step and no migration to run by hand. If the table already has
rows, nothing is added — the examples only appear when the table is empty.

## What gets created

- A Cloud Run service that runs the app. It sleeps when nobody is using it and wakes up on the
  next visit.
- A container image, built inside Google Cloud from the code in `build/app/`. Nobody needs Docker
  or `gcloud` installed on their laptop.
- A table called `items` inside this app's own schema in the shared database, with the columns
  `sku`, `item`, `location`, and `qty`.
- Two separate identities in Google Cloud: one that only builds the image, and one that only runs
  the service. Neither can do the other's job.

## Why it shares a database instead of having its own

The app connects to the shared PostgreSQL database through a `pg-schema` component. That gives
it a schema it owns completely, and a login that can reach nothing else in the database.

One shared database is cheaper than five separate ones, gets backed up once, and lets one app read
another app's data without copying it around. The schema boundary is what stops any app from
dropping another app's tables.

Stock planning depends on where the tour is going, so this app is a natural reader of Tour Dates'
schedule. Reading it means adding `tour_dates.shows` to `shared_tables` on this app's
`pg-schema` component. It then shows up on the canvas as a link between the two apps, so the
team that owns the schedule can see who depends on it before they change it.

## Adding stock from a spreadsheet

The upload form on the page takes a CSV file with four columns, in this order:

```
sku,item,location,qty
TS-BLK-M,"Tour tee, black, M",Lisbon,120
HD-NVY-L,"Hoodie, navy, L",Warehouse,48
```

`qty` is a whole number column, so a value like `48 units` is rejected — write just the number.
Item names containing a comma have to be wrapped in quotes, which every spreadsheet program does
on its own when exporting CSV. A header row is skipped if its first cell reads `sku`.

Uploading adds rows — it never replaces what is already there, and it does not check for
duplicates. Uploading the same file twice gives you every item twice, and gives you two separate
rows for a SKU rather than one row with a bigger quantity.

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
