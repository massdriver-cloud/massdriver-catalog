---
templating: mustache
---

# DynamoDB Table Runbook

{{#resources.table}}

## Application gets AccessDenied on reads or writes

Symptom: the application logs `AccessDeniedException` on DynamoDB calls that used to work.

First confirm which policy the caller was granted, then confirm the role actually has it
attached:

```bash
aws iam list-attached-role-policies --role-name <caller-execution-role>
```

The three policies published by this table end in `-read-`, `-write-`, and `-admin-`. A caller
that only has `read` will fail on `PutItem` and `UpdateItem` — that is the most common cause.
Change the policy selection in the consuming bundle's form and redeploy it.

If the right policy is attached and calls still fail, the KMS key is the next suspect. Every
item here is encrypted, so a caller needs KMS permission as well as DynamoDB permission. All
three published policies include it, but a hand-written policy usually does not. The message
names the key when this is the cause:

```bash
aws dynamodb describe-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --query 'Table.SSEDescription'
```

Compare the `KMSMasterKeyArn` with the resources in the caller's policy.

## Reads fail with ValidationException about the key

Symptom: `ValidationException: The provided key element does not match the schema`.

The call is passing the wrong key attributes. Print what the table actually expects:

```bash
aws dynamodb describe-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --query 'Table.KeySchema'
```

This table's partition key is `{{resources.table.partition_key}}`{{#resources.table.sort_key}} and its sort key is `{{resources.table.sort_key}}`{{/resources.table.sort_key}}. Every `GetItem`, `PutItem`, `UpdateItem`, and
`DeleteItem` must supply {{#resources.table.sort_key}}both{{/resources.table.sort_key}}{{^resources.table.sort_key}}it{{/resources.table.sort_key}}, and the value must be a string — a number or
boolean written into a key attribute fails the same way.

Neither key can be changed on an existing table. If the application genuinely needs different
keys, deploy a second table and migrate.

## Requests are throttled

Symptom: `ProvisionedThroughputExceededException` or `ThrottlingException`, usually with
retries in the SDK masking it until latency spikes.

This table is billed on demand, so throttling is not a capacity setting you can raise. It means
traffic is concentrated on one partition key value. Find out which one — turn on Contributor
Insights, wait for traffic, then read the top keys:

```bash
aws dynamodb update-contributor-insights --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --contributor-insights-action ENABLE
```

Then in CloudWatch Contributor Insights, look at the `MostAccessedKeys` rule for this table.

Fix it in the application, not in the infrastructure: spread the hot value across several keys
by appending a bucket number, or cache the record that everything is reading.

A sudden burst of new traffic against a table that has been quiet can also throttle while AWS
grows the table's capacity behind the scenes. That resolves itself within minutes; a hot key
does not.

## Bill jumped without more traffic

Symptom: read costs climbed but request counts did not.

Scans are the usual cause — one scan reads and charges for the entire table. Check consumed
capacity against request count:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value={{resources.table.name}} \
  --region {{resources.table.region}} \
  --start-time "$(date -u -v-7d '+%Y-%m-%dT%H:%M:%SZ')" \
  --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --period 86400 --statistics Sum
```

A high consumed-capacity number against a low request count means a small number of very
expensive calls. Find the scans in the application and replace them with key lookups.

Growing item size does this too. Check whether the table is storing more per record than it
used to:

```bash
aws dynamodb describe-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --query 'Table.{Items:ItemCount,Bytes:TableSizeBytes}'
```

`ItemCount` and `TableSizeBytes` update about every six hours, so use them for trends only.

## Records are not expiring

Symptom: TTL is configured but old records are still there.

Confirm TTL is on and pointed at the right attribute:

```bash
aws dynamodb describe-time-to-live --table-name {{resources.table.name}} \
  --region {{resources.table.region}}
```

If the status is `DISABLED`, set **Expire Records Using** in the form and redeploy.

If it is `ENABLED` and records persist, the attribute values are wrong. DynamoDB only deletes a
record when the attribute is a **number** holding Unix epoch **seconds**. A string, a
millisecond timestamp, or an ISO date is ignored silently. Look at a record that should have
gone:

```bash
aws dynamodb get-item --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --key '{"{{resources.table.partition_key}}": {"S": "<value>"}}'
```

The attribute should print as `{"N": "1700000000"}`. Deletion also lags the timestamp by up to
a couple of days, so give a correct-looking record time before digging further.

## Restoring the table after bad writes

With continuous backups on, restore to a point in time. The restore creates a **new** table —
it never overwrites this one:

```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name {{resources.table.name}} \
  --target-table-name {{resources.table.name}}-restore \
  --region {{resources.table.region}} \
  --restore-date-time "$(date -u -v-1H '+%Y-%m-%dT%H:%M:%SZ')"
```

Check the window is wide enough first — it is 35 days, and the earliest restorable second is
reported here:

```bash
aws dynamodb describe-continuous-backups --table-name {{resources.table.name}} \
  --region {{resources.table.region}}
```

If this returns `PointInTimeRecoveryStatus: DISABLED`, there is nothing to restore from. Turn
on **Continuous Backups** before you need it.

The restored table is a separate table with its own name and its own permissions, so nothing
reads from it automatically. Copy the records you need back into this table, then delete the
restore.

## Decommission fails saying the table cannot be deleted

Symptom: the delete fails with `ResourceInUseException` mentioning deletion protection.

**Block Accidental Deletion** is on. That is the setting doing its job. If the table really
should go, turn the setting off in the form, redeploy so the change lands, then decommission:

```bash
aws dynamodb describe-table --table-name {{resources.table.name}} \
  --region {{resources.table.region}} \
  --query 'Table.DeletionProtectionEnabled'
```

This must read `false` before the decommission will succeed.

{{/resources.table}}

{{^resources.table}}

This table has not been deployed yet. Deploy it, then return here for operational procedures.

{{/resources.table}}
