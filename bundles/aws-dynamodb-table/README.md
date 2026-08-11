# AWS DynamoDB Table

A table for records your application looks up by key — user profiles, sessions, orders,
feature flags, device events.

## What you get

- A table billed only for the reads and writes you actually do, with nothing to size up front
- Encryption with its own KMS key, rotated yearly
- Continuous backups, so the table can be restored to any second in the last 35 days
- Optional automatic expiry of old records
- Three ready-made access policies your application can pick from

## How this kind of table works

You give every record a **partition key** — one attribute, like `customer_id`, that the record
is filed under. To read the record back, your application supplies that same value. This is
fast and cheap no matter how large the table gets, but it is the only cheap way in: there is no
"find all records where the email is X" unless email is part of the key.

Add a **sort key** when one partition key holds many records. With `customer_id` as the
partition key and `order_id` as the sort key, you can read one order, or every order for a
customer in order, in a single call.

Pick keys with that in mind, because neither can be changed after the table is created.
Changing them means creating a new table and copying the data across.

## Access policies, and how consumers use them

This bundle creates three real IAM policies scoped to the table:

- **read** — look up and list records
- **write** — read, plus create, update, and delete records
- **admin** — full control, including changing table settings

A bundle that connects to this table picks one by name in its own form, and attaches the
policy to its execution role. Pick the narrowest one that works: a service that only renders
profiles needs `read`, not `admin`.

Each policy also covers the encryption key. That matters if you ever hand-write a policy
instead — DynamoDB permissions alone are not enough, and the resulting failure looks like an
ordinary permissions error.

## Naming

You give a short name describing the contents, like `orders`. A random suffix is added so the
same name can be used in more than one environment without collisions. The name cannot be
changed later.

## Expiring old records

If your records go stale on a schedule — sessions, carts, one-time codes — put a Unix timestamp
on each one and name that attribute in **Expire Records Using**. AWS deletes expired records in
the background for free, which is much cheaper than deleting them yourself.

Deletion is not instant. It usually happens within a couple of days of the timestamp, and an
expired record can still be read until then, so anything that must never serve stale data
should check the timestamp itself as well.

## Keeping costs down

On-demand billing means an idle table costs almost nothing, and you never pay for capacity you
did not use.

The two things that do run up a bill are scans and hot keys. A scan reads the whole table and
charges you for it, so reach for a key lookup instead wherever you can. A hot key — a partition
key value that most records share, like a status of `active` — pushes all the traffic through
one slice of the table, which gets slow and expensive before the table as a whole looks busy.
