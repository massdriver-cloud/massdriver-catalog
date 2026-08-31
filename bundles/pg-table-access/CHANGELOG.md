# Changelog

## 0.0.0

Initial release.

- Login role scoped to a named list of existing tables, with no schema of its own
- Per-table `SELECT` or `SELECT/INSERT/UPDATE/DELETE`, never a schema-wide grant
- Publishes a `postgres-table-grants` resource carrying the login and the grants that exist
