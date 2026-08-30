# Changelog

## 0.0.0

Initial release.

- Creates a standalone Firestore (Native mode) database, no App Engine dependency.
- Optional point-in-time recovery (7-day rolling backup) and delete protection, both on by
  default.
- Emits a `firestore-database` resource with `Read`, `Read and Write`, and `Admin` IAM policies
  for consuming bundles to bind to.
