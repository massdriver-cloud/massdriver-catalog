# Register an Address Range From an External System

Use these steps when your IP address management system reserves the range, and
Massdriver only records it.

## Values

| Field | What to enter |
|---|---|
| `cidr` | The range that the system reserved. |
| `pool` | The name of the parent pool. |
| `allocation_id` | The record identifier in that system. |
| `region` | The region that the range serves. |
| `registered` | `true` after someone writes the range back to the system. |

## Warning

Two networks with the same range cannot route to each other. Reserve the range
in the management system first. Do not pick a range by hand.
