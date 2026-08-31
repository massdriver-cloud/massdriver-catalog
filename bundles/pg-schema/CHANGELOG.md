# Changelog

## 0.0.0

Initial release.

- Login role and owned schema per app in a shared PostgreSQL database
- Declared `shared_tables` grants, read or read/write, per table
- Publishes a `postgres-schema` resource carrying the app's own scoped credential
