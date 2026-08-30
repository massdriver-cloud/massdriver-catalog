# Changelog

## 0.0.0

Initial release.

- Cloud SQL PostgreSQL instance, private IP only (no public address)
- Plain-English sizing (`size`) mapped to real GCP custom machine tiers
- Configurable regional high availability, backups with point-in-time recovery, and deletion
  protection
- Hardened, non-negotiable logging posture (connections, disconnections, checkpoints, lock waits,
  error verbosity)
- Generated database user and password, published as the `database` resource for consuming
  bundles
- Deploy-time precondition requiring the connected network to have Private Service Access enabled
