# Register an existing RDS MariaDB / MySQL instance

Use this form to register a MySQL-compatible database that was created outside Massdriver so applications can connect to it.

1. Open the [RDS console](https://console.aws.amazon.com/rds/) and select your region.
2. Go to **Databases** and click your instance.

## Database ID

Copy the **ARN** from **Configuration** (looks like `arn:aws:rds:us-east-1:123456789012:db:my-mariadb`).

## Server Version

The major.minor version from **Configuration → Engine version** — enter `11.4` for `11.4.3`.

## High Availability

`true` if **Configuration → Multi-AZ** says Yes.

## Authentication

- **Host**: the **Endpoint** under **Connectivity & security**.
- **Port**: the **Port** shown next to it (usually `3306`).
- **Database**: the initial database name from **Configuration → DB name**.
- **Username / Password**: an application user, not the master user. Create one:

  ```sql
  CREATE USER 'app_user'@'%' IDENTIFIED BY 'generate-a-strong-password';
  GRANT SELECT, INSERT, UPDATE, DELETE ON mydb.* TO 'app_user'@'%';
  ```

## Access Policies

List the access levels applications can request from this database. If you're unsure, start with:

| Policy ID | Policy Name |
|-----------|-------------|
| `read-only` | Read |
| `read-write` | Write |
