---
templating: mustache
---

# {{resources.table.name}}

```
Table    {{resources.table.name}}
Region   {{resources.table.region}}
Key      {{params.partition_key}}
Billing  {{params.capacity}}
```

---

## Requests being refused

Something asked the table to do more than it would. The application saw errors and so, probably,
did whoever was using it.

**First, find out which way it is being refused.**

```bash
aws dynamodb describe-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --query 'Table.[BillingModeSummary.BillingMode,ProvisionedThroughput]'
```

**If billing is `PAY_PER_REQUEST`:** the table scales itself, but not instantly. A flat spike
from idle can outrun it for a minute or two. It is also possible one partition key value is
taking all the traffic — a single tenant, a single hot record — in which case the table as a
whole looks idle while one slice of it is saturated.

```bash
# Throttles over the last hour, minute by minute. A sharp spike is a traffic
# surge; a flat line is a hot key.
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
  --metric-name ThrottledRequests \
  --dimensions Name=TableName,Value={{resources.table.name}} \
  --start-time $(date -u -v-1H +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Sum --region {{resources.table.region}}
```

**If billing is `PROVISIONED`:** you are over the reserved rate and requests above it are
refused. Raising `capacity` to on demand takes effect in minutes and is the fastest way out of
an incident. Do that first and work out the right number afterwards.

**If it is a hot key**, no amount of capacity fixes it. The partition key cannot be changed on
an existing table, so the real fix is a new table with a better key and a migration. In the
meantime, caching the hot records in front of the table buys time.

---

## Table returning errors

These are failures on the AWS side, not bad requests. One is noise. A run of them means the
table is not currently dependable.

```bash
# Is it us or is it AWS
aws dynamodb describe-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} --query 'Table.TableStatus'
```

Check the AWS status page for {{resources.table.region}}. If the region is healthy and this
persists, open a support case — there is no configuration change on your side that fixes
`SystemErrors`.

Retries with backoff are the correct application behaviour here and the AWS SDKs do it by
default. If your application is not retrying, that is worth fixing regardless of this alarm.

---

## Reads near the reserved limit

Only fires on provisioned tables. You are at 80% of what was reserved, so you have a little room
and not much.

```bash
aws dynamodb update-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --billing-mode PAY_PER_REQUEST
```

Switching to on demand removes the ceiling entirely and takes effect within minutes. It costs
more per request and nothing when idle, so for a table that spikes it is often cheaper overall.

If you would rather stay provisioned, raise `read_capacity` in the configuration and redeploy.

---

## Someone deleted data

If the rolling backup is on, the table can be restored to any second in the last 35 days — into
a **new** table. The original is left untouched, which is what you want: you can look before you
commit to anything.

```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name {{resources.table.name}} \
  --target-table-name {{resources.table.name}}-restored \
  --restore-date-time 2026-01-01T00:00:00Z \
  --region {{resources.table.region}}
```

Then compare, and move the application over deliberately rather than trying to restore in place.

```bash
# Is the backup actually on
aws dynamodb describe-continuous-backups --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription'
```

If it is off, there is no restore. Turn it on now so the next time is different.

---

## The table will not delete

Deletion protection is on. That is deliberate, and turning it off should be a decision somebody
makes on purpose:

```bash
aws dynamodb update-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} --no-deletion-protection-enabled
```
