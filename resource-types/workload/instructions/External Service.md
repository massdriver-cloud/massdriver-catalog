# Register a Workload That Massdriver Does Not Deploy

Use these steps to put an existing service on the canvas. Other bundles then
read its address.

## Values

| Field | What to enter |
|---|---|
| `name` | A short name, in lowercase letters and hyphens. |
| `service_url` | The address that a client calls. |
| `health_check_url` | The address that a monitor calls. |
| `deployment_id` | The release that runs now. Leave it empty when you do not track releases. |
| `tags` | Labels such as `team` and `tier`. |

## Warning

Massdriver does not deploy this workload, and it does not watch it. The record
goes stale when the service moves. Update the record after each move.
