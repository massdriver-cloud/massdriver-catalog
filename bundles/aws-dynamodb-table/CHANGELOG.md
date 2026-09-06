# Changelog

## 0.0.0

First release.

- A table keyed by a partition key, with an optional sort key for ordered ranges.
- On demand or provisioned billing.
- A rolling backup, on by default, restoring to any point in the last 35 days.
- Optional deletion protection and record expiry.
- Alarms for refused requests, service errors, and reserved reads running out.

Applications that connect are granted access to this table alone, scoped to its identifier, and
receive its name and partition key as settings.
