# Importing an existing RDS PostgreSQL instance

Use this when you already have an RDS or Aurora PostgreSQL instance and want Massdriver to know about it, instead of provisioning a new one with the `aws-rds-postgres` bundle.

## Where to find each field

1. Open the **RDS console** → **Databases** → your instance.
   - `id`: the "DB identifier" (or cluster identifier for Aurora).
   - `engine`: `rds-postgres` for a standalone RDS instance, `aurora-postgresql` for an Aurora cluster.
   - `version`: the "Engine version" field.
   - `region`: the region shown in the top-right of the console.
   - `high_availability`: true if "Multi-AZ" shows a standby, or if it's an Aurora cluster with more than one reader.
2. Under **Connectivity & security**:
   - `auth.hostname`: the "Endpoint" field (writer endpoint for Aurora).
   - `auth.port`: the "Port" field.
3. `auth.database`: the default database name you created it with (check **Configuration** tab → "DB name").
4. `auth.username` / `auth.password`: whatever credentials you provisioned the instance with — Massdriver doesn't read these from AWS, you supply them directly.

## Notes

- The password is masked everywhere in the UI except at deploy time, and cannot be copied out of a cloned environment.
