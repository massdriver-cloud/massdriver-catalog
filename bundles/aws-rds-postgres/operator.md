---
templating: mustache
---

# AWS RDS PostgreSQL — Operator Runbook

- **Instance:** `{{id}}`
- **Writer endpoint:** {{#artifacts.database}}`{{artifacts.database.auth.hostname}}`{{/artifacts.database}}

## Connect with psql using IAM auth

`iam_database_auth` is `{{params.iam_database_auth}}`. When enabled, generate a 15-minute token and connect over TLS.

```bash
TOKEN=$(aws rds generate-db-auth-token \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --hostname {{#artifacts.database}}{{artifacts.database.auth.hostname}}{{/artifacts.database}} \
  --port 5432 \
  --username <iam-mapped-user>)

PGPASSWORD="$TOKEN" psql \
  "host={{#artifacts.database}}{{artifacts.database.auth.hostname}}{{/artifacts.database}} port=5432 \
   dbname={{params.database_name}} user=<iam-mapped-user> \
   sslmode=verify-full sslrootcert=/etc/ssl/certs/rds-global-bundle.pem"
```

The `<iam-mapped-user>` must already exist in Postgres and be granted the `rds_iam` role:

```sql
CREATE USER app_iam;
GRANT rds_iam TO app_iam;
GRANT CONNECT ON DATABASE {{params.database_name}} TO app_iam;
```

## Connect with the master password (debugging only)

Pull the master password from Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --secret-id {{#artifacts.database}}{{artifacts.database.secret_arn}}{{/artifacts.database}} \
  --query SecretString --output text | jq -r .password
```

## Connections timing out

```bash
aws rds describe-db-instances \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --db-instance-identifier {{#artifacts.database}}{{artifacts.database.id}}{{/artifacts.database}} \
  --query 'DBInstances[0].{Status:DBInstanceStatus,AZ:AvailabilityZone,Endpoint:Endpoint.Address}'
```

If `DBInstanceStatus` is `modifying` or `rebooting`, wait. Otherwise:

1. Confirm the workload's security group is granted ingress on `{{#artifacts.database}}{{artifacts.database.security_group_id}}{{/artifacts.database}}` for TCP 5432.
2. The workload subnet must have a route to the RDS subnets in `{{#connections.vpc}}{{connections.vpc.id}}{{/connections.vpc}}`.
3. Check that `Endpoint.Address` resolves from the workload host.

## Reads slow but writes are healthy

If `read_replica_count > 0` (currently `{{params.read_replica_count}}`), point read traffic at the reader endpoint `{{#artifacts.database}}{{artifacts.database.auth.reader_endpoint}}{{/artifacts.database}}`. Otherwise scale the writer's `instance_class` or migrate to Aurora.

```bash
aws cloudwatch get-metric-statistics \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --namespace AWS/RDS \
  --metric-name ReplicaLag \
  --dimensions Name=DBInstanceIdentifier,Value={{#artifacts.database}}{{artifacts.database.id}}{{/artifacts.database}}-r1 \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time   $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 --statistics Maximum
```

## Multi-AZ failover

Multi-AZ is `{{params.multi_az}}`. When enabled, AWS performs an automatic failover on instance health failure and DNS for the writer endpoint updates within roughly 30 to 90 seconds.

Force a manual failover for testing or to recover from a degraded primary:

```bash
aws rds reboot-db-instance \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --db-instance-identifier {{#artifacts.database}}{{artifacts.database.id}}{{/artifacts.database}} \
  --force-failover
```

If the application caches DNS aggressively, force a reconnect after failover. JDBC drivers should set `socketTimeout` and connection-pool TTL to align with failover behavior.

## Point-in-time restore

Backups are retained for `{{params.backup_retention_days}}` days. PITR creates a new instance — it does not modify the source.

```bash
aws rds restore-db-instance-to-point-in-time \
  --region {{#connections.vpc}}{{connections.vpc.region}}{{/connections.vpc}} \
  --source-db-instance-identifier {{#artifacts.database}}{{artifacts.database.id}}{{/artifacts.database}} \
  --target-db-instance-identifier {{#artifacts.database}}{{artifacts.database.id}}{{/artifacts.database}}-restore \
  --restore-time <ISO-8601-timestamp>
```

The new instance is created without the source's security groups or parameter groups. Reattach them before cutting traffic over.

## Granting workloads access

The bundle publishes pre-built IAM policies (Read / Write / Admin) on the artifact's `policies` array. Bind the appropriate policy ARN to the workload's IAM role (e.g., the IRSA role on a pod's ServiceAccount).

The IAM role must also be mapped to a Postgres user that holds `rds_iam`. Massdriver workload bundles handle the IAM-to-Postgres mapping at deploy time.

## Known constraints

- IAM auth tokens expire after 15 minutes. Long-lived sessions must refresh the token before reconnecting.
- Major-version upgrades (e.g., 14 to 15) require a maintenance window and are not in-place; they replace the underlying engine.
- Storage can be increased online but cannot be decreased. Plan storage growth carefully.
- `username` and `database_name` are immutable after the first deploy.
