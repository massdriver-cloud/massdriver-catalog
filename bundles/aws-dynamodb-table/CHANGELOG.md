# Changelog

## 0.1.0

Initial release.

- On-demand DynamoDB table encrypted with a dedicated KMS key
- Configurable partition key and optional sort key
- Point-in-time recovery for a 35-day restore window
- Optional TTL attribute for automatic record expiry
- Optional deletion protection
- Publishes a `key-value-table` resource with read / write / admin IAM policies
