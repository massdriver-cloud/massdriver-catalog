# pg-table-access

Issues a login for the shared database that can reach a named list of tables, and nothing else.

## When to use this instead of `pg-schema`

They answer two different questions.

- **`pg-schema`** — "this app needs somewhere to put its own data." It creates a schema the
  app owns, and the app creates its own tables inside it.
- **`pg-table-access`** — "this app needs to read data that already exists." It creates a login
  and grants it access to tables somebody else already owns. It creates no tables and no schema.

If the database is already loaded — an existing warehouse, a system of record, data migrated in
from somewhere else — this is the one you want. Nothing has to be moved or restructured first.

## What gets created

- A login role named after the app, with a generated password. No `CREATEDB`, no `CREATEROLE`,
  not a superuser, and no schema of its own.
- `USAGE` on each schema that appears in the table list. Without it the table grants are
  unusable, and the failure looks like "table does not exist" rather than a permission error.
- One grant per named table: `SELECT`, or `SELECT, INSERT, UPDATE, DELETE`.

## Why one grant per table and never per schema

Granting on a whole schema is one line shorter and quietly wrong. A table added to that schema
next month is reachable by every login that was granted the schema, and nobody revisits the
decision, because nothing prompts them to.

Naming each table means a new table is unreachable until somebody puts it on a list on purpose.
That is the entire control. The list is the audit trail, it lives in the deployment history, and
it says who added what and when.

## Who decides

The team that owns the data. This bundle is placed and configured by whoever administers the
database — an entry here is an assertion that the owning team agreed, and the deployment history
is where that shows up later.

The app never sees the cluster's administrative credential. It receives only its own login, and
that login reaches exactly the tables on the list.

## The tables must already exist

Grants are issued against real tables. If a table on the list is not there yet, the deploy fails
with `relation "<schema>.<table>" does not exist` and nothing is created.

This is deliberate rather than a limitation to work around. A grant on a table that does not exist
would silently do nothing, and "I have access" would stop meaning anything.

## Worked example

Give a reporting job read access to two teams' tables and write access to a third:

```
login_name: reporting

read:
  - tour_dates.shows
  - fan_signups.signups

read_write:
  - merch_inventory.items
```

Check what it can actually reach, connected as the administrative user:

```sql
SELECT table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'reporting'
ORDER BY table_schema, table_name, privilege_type;
```

That query is the answer to "what can this app see?", and it should match the lists above line
for line. If it returns more, something granted on a whole schema.

## Where this sits among the three ways to share a database

| How the data is split | Bundle | Cross-app sharing |
| --- | --- | --- |
| One database per app | `gcp-cloud-sql-postgres` | Not possible — PostgreSQL cannot grant across databases |
| One schema per app, one shared database | `pg-schema` | Yes, table by table |
| Data already loaded, however it got there | `pg-table-access` | The whole purpose |

The last two combine, and that combination is usually what people actually want: an app owns a
schema and writes whatever it likes there, and separately holds a second login granting it read
access to a few named tables belonging to other teams.

## A note on creating tables from infrastructure code

This bundle grants on tables; it does not create them. That is partly a design choice and partly a
constraint worth knowing about: the PostgreSQL Terraform provider has **no table resource**. It can
create roles, schemas, and grants, and it cannot run `CREATE TABLE`.

So there is no way to declare a table's shape in a bundle and have the provider build it. Creating
tables from infrastructure code needs something that executes SQL — a migration job run from
inside the network, or the application's own migrations at startup. Both are fine; neither is
this bundle.

The practical consequence: the platform can decide **who reaches which table**, which is the
security question, but the tables themselves come from the application or from a migration the
data owner runs.
