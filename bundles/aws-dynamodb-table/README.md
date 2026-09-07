# Document Table

A table for an application's records. It scales itself, costs nothing when nothing is using it,
and an application connected to it can reach this table and no other.

## When to use it

Reach for this when records are looked up by a key you already know — a user by their ID, an
order by its number, a session by its token. It is very fast and very cheap at that, and it
stays that way as the table grows.

It is the wrong choice when you need to ask open questions of your data: totals across
everything, joins between tables, "show me everyone who signed up last Tuesday and has not
logged in since". A relational database answers those; this one has to read the whole table to
try, which gets slower and more expensive every day.

## Choosing a partition key

This is the one decision you cannot change later, and the one that decides whether the table
stays fast.

Records are grouped by the partition key, and a group is stored together. Pick something with
many different values — an ID, an email address, a tenant name — and records spread evenly.
Pick something with few values — a status, a country, a type — and most records pile into one
group that gets slow and starts refusing requests while the rest of the table sits idle.

If you also want ranges back in order — the last ten orders for one customer — add a sort key.

## What it costs

**On demand** charges per request and nothing at all when the table is idle. It absorbs traffic
spikes without being told about them in advance. This is the right answer until you have a
reason it is not.

**Provisioned** reserves a fixed number of reads and writes per second. It is meaningfully
cheaper at steady, high, predictable volume, and it refuses requests above what you reserved.

Storage is billed separately and is inexpensive. A rolling backup roughly doubles the storage
cost of the table, which is still almost nothing for most tables.

## What an application gets

Connect this to an application and two things happen without anyone writing them:

- The application is granted read and write access **to this table only**, scoped to its exact
  identifier. It cannot reach any other table in the account.
- The table's name and partition key arrive as settings the application reads at startup, so
  nothing is hardcoded and moving between environments needs no code change.

## Compliance

The scanner runs on every deployment. In production a finding stops the deployment; elsewhere it
is recorded and the deployment continues.

### Passing by default

| Check | What it wants |
| --- | --- |
| `CKV_AWS_28` | A rolling backup, so the table can be restored to any point in the last 35 days. |
| `CKV_AWS_119` | Encryption at rest — satisfied by an AWS-owned key. See below. |

The rolling backup is **on by default**. You can turn it off for a table you genuinely would not
mind losing, and doing so will be flagged in production — which is the point. It should be a
decision somebody made, not something that quietly never got switched on.

### Deliberately not satisfied

**`CKV_AWS_119` — encrypt with a customer managed key.**

Records are already encrypted at rest with a key AWS owns and rotates. A customer managed key
buys exactly one thing on top of that: the ability to revoke access to the data without touching
the table. That is genuinely valuable when somebody other than the table's owner holds the key —
and when they do not, it is a key to rotate, pay for, and keep available, where losing it means
losing the table.

That trade depends on who owns the data, so it is not something every table should inherit. If
you need it, this bundle is the wrong starting point and a table with a managed key is a
different bundle.

The skip and this reasoning live in `src/.checkov.yaml`.
