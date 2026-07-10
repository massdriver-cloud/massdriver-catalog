# Register an existing RDS PostgreSQL instance

Use this form to register a PostgreSQL database that was created outside Massdriver so applications can connect to it.

1. Open the [RDS console](https://console.aws.amazon.com/rds/) and select your region.
2. Go to **Databases** and click your instance.

## Database ID

Copy the **ARN** from **Configuration** (looks like `arn:aws:rds:us-east-1:123456789012:db:my-postgres`).

## PostgreSQL Version

The major version from **Configuration → Engine version** — enter `16` for `16.4`.

## High Availability

`true` if **Configuration → Multi-AZ** says Yes.

## Authentication

- **Host**: the **Endpoint** under **Connectivity & security**.
- **Port**: the **Port** shown next to it (usually `5432`).
- **Database**: the initial database name from **Configuration → DB name**.
- **Username / Password**: an application user, not the master user. Create one:

  ```sql
  CREATE ROLE app_user LOGIN PASSWORD 'generate-a-strong-password';
  GRANT CONNECT ON DATABASE mydb TO app_user;
  ```

## Access Policies

List the access levels applications can request from this database. If you're unsure, start with:

| Policy ID | Policy Name |
|-----------|-------------|
| `read-only` | Read |
| `read-write` | Write |
