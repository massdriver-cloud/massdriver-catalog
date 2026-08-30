# BigQuery federation runbook

## A query fails with `Not found: Connection ...`

The name is right but the location is not. A BigQuery query runs in one location, and it can only
see connections and datasets that live there.

{{#resources.dataset}}
Everything here is in `{{resources.dataset.location}}`, and the connection is exactly:

```
{{resources.dataset.connection_id}}
```

Confirm it exists where the query is looking:

```bash
bq show --format=prettyjson --connection {{resources.dataset.connection_id}}
```
{{/resources.dataset}}

Two ways people land here: the query was written against a dataset in another region (the BigQuery
console remembers a location per query tab), or somebody retyped the connection string and dropped
the middle part. It is three fields joined by dots — project, location, connection.

## A query fails with `bigquery.connections.use` or `bigquery.jobs.create` denied

The person is not on the analyst list. Running a federated query needs three grants and this bundle
issues all three together, so a partial failure means the list itself is wrong, not that one grant
is missing.

Add them to "Who is allowed to run these queries?" and redeploy:

```bash
mass instance deploy {{slug}} -m "add <name> to the analyst list" -f
```

If they are already on the list, check the form of the entry. `sam@example.com` on its own does
nothing — Google needs the kind first, as in `user:sam@example.com` or `group:analytics@example.com`.

If the entry is a group and the person joined it recently, wait a few minutes and try again. The
grant is on the group and Google takes its time noticing a new member.

## A query fails with `password authentication failed for user`

The full message looks like:

```
Invalid table-valued function EXTERNAL_QUERY Failed to connect to PostgreSQL database.
Error: FATAL: password authentication failed for user "{{resources.dataset.source_database.username}}"
```

The connection stores its own copy of that password, and `pg-table-set` generates a fresh one every
time it deploys. So a redeploy of the analytics login breaks every federated query until this
component is deployed again and re-stores it.

```bash
mass instance deploy {{slug}} -m "re-store the analytics login password" -f
```

Nothing is lost while it is broken, and no query returns wrong data — they all fail the same way.
If it keeps happening, look for whatever keeps redeploying the table set.

## A query fails to connect, but says nothing about a password

```
Invalid table-valued function EXTERNAL_QUERY Failed to connect to PostgreSQL database.
```

with a timeout or a "could not connect to server" underneath, rather than an authentication error.
The login is fine and the socket never opened. Two causes:

**The instance lost its public endpoint.** BigQuery reaches Cloud SQL from outside the platform
network. Emptying `iac_authorized_networks` on `gcp-cloud-sql-postgres` takes the public endpoint
away, and this connection goes dark with it — while the apps keep working, because they use the
private address. Put an entry back and redeploy that component.

**The connection's service account lost its permission.** Every connection has its own
Google-managed service account, and it needs `roles/cloudsql.client`. This bundle grants it, so it
comes back on a redeploy — but a project-wide IAM cleanup can strip it in between.

{{#resources.dataset}}
Find the account, then check whether it still holds the role:

```bash
bq show --format=prettyjson --connection {{resources.dataset.connection_id}} | grep serviceAccountId

gcloud projects get-iam-policy {{resources.dataset.project_id}} \
  --flatten="bindings[].members" \
  --filter="bindings.role=roles/cloudsql.client" \
  --format="value(bindings.members)"
```
{{/resources.dataset}}

## A query fails with `permission denied for table` or `relation ... does not exist`

The connection reached the database and the database refused the read. This is the access model
working, not a fault.

{{#resources.dataset}}
Queries read as `{{resources.dataset.source_database.username}}`, which can only see tables that
are listed in `shared_tables` on the `pg-table-set` component wired into `analytics_login`.
{{/resources.dataset}}
Add the schema and table there, deploy that component, then deploy this one so the connection picks
up the login again.

`relation ... does not exist` with a schema name in it usually means something else: the app that
owns that schema has not been deployed into this environment, or has not created its tables yet.
Check the owning app before touching grants.

## Deploy fails: `BigQuery Connection API has not been used in project ... before or it is disabled`

This bundle enables that API itself, so seeing this means the enable and the create landed in the
same apply and Google had not finished switching it on. Deploy again; it is a wait, not a fix.

If it survives a second deploy, the credential this deploys with cannot enable APIs. It needs
`roles/serviceusage.serviceUsageAdmin` on the project, or somebody enables
`bigqueryconnection.googleapis.com` by hand once.

## Deploy fails on the encryption key

An error naming `cloudkms.cryptoKeyEncrypterDecrypter` means the grant this bundle makes has not
taken effect yet — Cloud KMS permissions can lag by a minute. Deploy again.

An error naming the key and two different locations is not a wait. A key can only encrypt a dataset
in its own region, or be global, and the dataset's region is fixed by the database it reads
{{#resources.dataset}}(`{{resources.dataset.location}}`){{/resources.dataset}}. Point the setting at
a key in that region.

Do not delete or disable the key afterwards. BigQuery cannot read the dataset without it, and there
is no recovery on this side.

## Deploy fails: the shared database has no address BigQuery can reach

The deploy stops before it changes anything, with a message naming `iac_authorized_networks`. The
instance is private-only, and no amount of IAM or credentials will get a query through to it.

Add an entry to `iac_authorized_networks` on the `gcp-cloud-sql-postgres` component and redeploy
that first — that is what gives the instance a public endpoint. BigQuery does not need an entry for
itself; it authenticates as a service account rather than arriving from a fixed address, so the
list stays as narrow as it already was.

Anywhere `pg-table-set` is deployed this is already true, because that bundle needs the same thing.

## Deploy fails: the analytics login and the database are on different instances

Two components on the canvas are pointing at different databases. The `analytics_login` table set
was created against one instance and `postgres_cluster` is another one, so the login in the
connection does not exist in the database it opens.

Rewire `analytics_login` to a `pg-table-set` that sits on the same database. The message names both
addresses, and the one to change is almost always the table set, not the cluster.

## The plan wants to destroy and recreate the dataset

A dataset cannot move. Its location is fixed when it is created, so pointing this at a Cloud SQL
instance in a different region means BigQuery has to build a new dataset in the new region, and
everything saved in the old one goes with it.

{{^params.allow_delete_with_contents}}
"Allow this dataset to be deleted while it still has tables in it?" is off, so the destroy will
stop rather than delete anyone's saved tables — see the next entry.
{{/params.allow_delete_with_contents}}
{{#params.allow_delete_with_contents}}
"Allow this dataset to be deleted while it still has tables in it?" is on, so the destroy will
take everything saved in the dataset with it, without asking. Copy anything worth keeping first.
{{/params.allow_delete_with_contents}}

Anyone querying it also has to change the connection string in their saved queries, because the
location is part of it.

## Deploy fails: `Dataset ... is still in use` / `resourceInUse`

Somebody saved tables in the dataset and the deploy is trying to delete it — either a teardown, or
the recreate above.

Decide which you want. To keep the tables, stop and copy them somewhere else first:

{{#resources.dataset}}
```bash
bq ls {{resources.dataset.project_id}}:{{resources.dataset.dataset_id}}
bq cp {{resources.dataset.project_id}}:{{resources.dataset.dataset_id}}.<table> {{resources.dataset.project_id}}:<other_dataset>.<table>
```
{{/resources.dataset}}

To let it go, turn on "Allow this dataset to be deleted while it still has tables in it?" and deploy
again. It stays on afterwards, so turn it back off once the teardown is done if this dataset is
sticking around.

## Trying to change the dataset name

It is immutable, because a rename in BigQuery is a new dataset and a rewrite of every saved query
pointing at the old one. If the name is genuinely wrong, stand up a second component with the right
name, move anything saved across with `bq cp`, then decommission this one.

## The apps got slow when the analysts started working

Expected, and the trade-off this bundle makes. A federated query runs on the app database — the
part inside the quotes is real load on the same instance serving the apps.

Look for a query that pulls whole tables into BigQuery and filters afterwards. Moving the `where`
and the `group by` inside the quotes turns a full table scan into a small answer. For anything a
dashboard refreshes on a schedule, save the result as a table in the dataset and let the dashboard
read that instead of the database.

{{#resources.dataset}}
Cloud SQL's own logs show which queries arrived and how long they took, under
`resource.type="cloudsql_database"`, and they arrive as
`{{resources.dataset.source_database.username}}`, so they are easy to pick out from app traffic.
{{/resources.dataset}}

## Decommission

Removes the dataset, the connection, and the grants this bundle made. The app data is untouched —
it lives in PostgreSQL and nothing here ever held a copy of it.

The analytics login survives too: it belongs to the `pg-table-set` component, not to this one. If
the point was to cut analytics access off entirely, decommission that as well, or the login is still
there for anyone who can reach the database.
