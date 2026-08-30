# Changelog

## 0.0.0

Initial release.

- BigQuery dataset and a Cloud SQL connection, so analysts can query the apps' live PostgreSQL
  tables with `EXTERNAL_QUERY` instead of copying data into a warehouse
- Reads through the scoped login from a `pg-table-set` rather than the shared instance's admin
  credential, so what analytics can see is a reviewed list on the canvas
- Dataset and connection location taken from the Cloud SQL instance, which is the only value
  federation will accept
- One list of people, groups, or services, bound to the three IAM roles a federated query needs
- Optional customer-managed encryption key, including the grant the BigQuery service agent needs
  to use it
- Deploy-time preconditions for an instance BigQuery cannot reach, an analytics login from a
  different instance, and a database that is not Cloud SQL
- Emits an `analytics-dataset` resource carrying the connection string, the tables it can read,
  and the IAM policies a consuming workload binds to
