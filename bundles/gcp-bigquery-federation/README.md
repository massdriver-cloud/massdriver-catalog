# Query the app database from BigQuery

Analysts get a place in BigQuery where they can run SQL against the apps' real tables. Nothing is
copied, exported, or synced on a schedule — a query reaches into the shared PostgreSQL database
and reads the rows that are there at that moment.

## What gets created

- A **BigQuery dataset**, which is where analysts write queries and where they can save results if
  they are allowed to.
- A **connection to the shared PostgreSQL database**, holding the login that queries read as.
- The **permission the connection needs** to open the database. Google creates a service account
  for every connection, and it can reach nothing until it is given that permission.
- **Permissions for the people you list.** Being able to run a federated query takes three
  separate grants in Google Cloud, and this bundle makes all three from one list of names.

## The first query

Open the BigQuery console, pick this dataset, and paste this in. The long dotted string is the
connection — it is on this component's page in Massdriver, and every query needs it:

```sql
SELECT *
FROM EXTERNAL_QUERY(
  "acme-platform.us-central1.analytics_scp_dev_warehouse_postgres",
  "SELECT city, venue, show_date FROM tour_dates.shows ORDER BY show_date;"
);
```

Everything inside the quotes is PostgreSQL and runs on the app database. Everything outside is
BigQuery's own SQL. That split is the one thing worth learning here, because it decides how much
work lands on the database the apps are using.

**Push the filtering and counting inside the quotes** so the app database sends back a small
answer instead of every row:

```sql
SELECT *
FROM EXTERNAL_QUERY(
  "acme-platform.us-central1.analytics_scp_dev_warehouse_postgres",
  """
  SELECT source, count(*) AS signups
  FROM fan_signups.signups
  GROUP BY source
  ORDER BY 2 DESC;
  """
);
```

Triple quotes are how BigQuery takes a query written over several lines. A plain `"..."` has to
stay on one line.

**Two apps in one query.** The tour schedule and the merch stock belong to different teams, and
neither team has to be involved: no export, no CSV, and nobody handing an analyst a database
login:

```sql
WITH shows AS (
  SELECT *
  FROM EXTERNAL_QUERY(
    "acme-platform.us-central1.analytics_scp_dev_warehouse_postgres",
    "SELECT city, venue, show_date FROM tour_dates.shows WHERE show_date >= current_date;"
  )
),
stock AS (
  SELECT *
  FROM EXTERNAL_QUERY(
    "acme-platform.us-central1.analytics_scp_dev_warehouse_postgres",
    "SELECT sku, item, location, qty FROM merch_inventory.items;"
  )
)
SELECT s.show_date, s.city, s.venue, k.item, k.qty
FROM shows s
JOIN stock k ON k.location = s.city
ORDER BY s.show_date;
```

**Keeping an answer.** If analysts were given "read and save", a result can be stored in the
dataset so a dashboard reads it instantly instead of hitting the app database every refresh:

```sql
CREATE OR REPLACE TABLE `acme-platform.analytics_scp_dev_warehouse.merch_by_show` AS
SELECT s.show_date, s.city, k.item, k.qty
FROM EXTERNAL_QUERY(
  "acme-platform.us-central1.analytics_scp_dev_warehouse_postgres",
  "SELECT city, venue, show_date FROM tour_dates.shows;"
) s
JOIN EXTERNAL_QUERY(
  "acme-platform.us-central1.analytics_scp_dev_warehouse_postgres",
  "SELECT sku, item, location, qty FROM merch_inventory.items;"
) k
ON k.location = s.city;
```

## Which login the queries read as

Every query through this connection runs as one PostgreSQL login, whoever pressed run. That login
is deliberately **not** the shared database's admin user.

Instead, this bundle takes a `pg-schema` — the same component every app uses to get its own
schema and login — and uses the login from that. So the analytics login is created the same way
as any app's login, its access is a list of `shared_tables` entries on a component on the canvas,
and adding a table to what analysts can see is a reviewed change with a name and a date on it.

That matters more here than anywhere else, because a BigQuery connection **stores** the username
and password. It is not a credential passed at deploy time and forgotten; it sits in Google Cloud
being used by everyone who queries. Three things follow from that:

- **A scoped login stays scoped.** If analytics reads as the admin user, then every person you
  ever add to the analyst list can read every table in every app's schema, and there is nothing
  in between them and it. With the table set, the answer to "what can analytics see?" is a list
  you can read off the canvas.
- **A rotation is visible.** `pg-schema` generates a new password whenever it redeploys. That
  breaks this connection until this component is redeployed too — which is annoying, and far
  better than an admin password sitting inside a connection that nobody remembers exists.
- **Nothing here can write.** The table set grants `SELECT` on other apps' tables. Analysts with
  "read and save" can save tables in BigQuery; nobody can write back into an app's database
  through this connection.

The cost of the decision is one more component on the canvas, and the fact that a table nobody
added to `shared_tables` is invisible to analysts even though the connection reaches the
database. That failure is a `permission denied` at query time, and it is covered in the runbook.

## Why there is no region setting

BigQuery will only run a federated query when the dataset, the connection, and the Cloud SQL
instance are all in the same place. So the region is read off the database this connects to
rather than offered as a dropdown — the only value it could ever be set to is the one that is
already correct.

Moving the analytics dataset to another region is not a setting either. It means pointing this at
a database in that region, which BigQuery can only do by building a new dataset.

## What the shared database needs first

BigQuery reaches Cloud SQL from outside the platform network, so the instance needs a public
endpoint. The `gcp-cloud-sql-postgres` bundle turns one on as soon as `iac_authorized_networks`
has an entry in it — which it already does anywhere `pg-schema` is deployed, since that bundle
needs the same thing.

BigQuery does not need an entry of its own on that list. It authenticates as a service account
through Google's own path into Cloud SQL rather than arriving from a fixed address. If the
instance has no public endpoint at all, this bundle refuses to deploy and says so.

## Settings

**Dataset Name** — What analysts see this called in BigQuery, and what they type in every query.
Cannot be changed afterwards; a rename is a new dataset.

**Who is allowed to run these queries?** — People, groups, or services, written the way Google
writes them (`group:analytics@example.com`). Nobody outside this list can query the app data.
A group is easier to keep correct than a list of individuals.

**What should analysts be able to do here?** — Whether they can only read query results, or also
save tables in this dataset for dashboards and scheduled reports. Neither option lets anyone
write to the app database.

**Delete saved tables after (days)** — Housekeeping for tables analysts save here, so scratch work
stops being billed forever. 0 keeps everything.

**Your own encryption key** — Leave empty unless somebody has told you your organisation requires
it. BigQuery encrypts what it stores either way; this decides who holds the key. Supplying a Cloud
KMS key also gives BigQuery permission to use it, which is the step people miss.

**Allow this dataset to be deleted while it still has tables in it?** — Off means tearing this
down stops rather than deleting somebody's saved work.

## What this does not do

It does not make a copy, so there is no sync to fall behind and no schedule to run — and equally,
a heavy query is real load on the database the apps are using. Read the "Push the filtering and
counting inside the quotes" example again before pointing a dashboard at this.

It also does not replace the apps' own access to their data. Apps keep talking to PostgreSQL
directly through their own login; this is the analytics path, and only that.

## Connecting a dashboard or a report to it

Wire the component that needs it to this one on the canvas. It receives the project, the dataset,
the location, and the connection string, plus the three IAM roles it has to bind to its own
service account to run a query: one to start the job, one to read the dataset, one to use the
connection.
