# Address Range Runbook

{{#resources.allocation}}
| Field | Value |
|---|---|
| Range | `{{resources.allocation.data.cidr}}` |
| Pool | `{{resources.allocation.data.pool}}` |
| Registered | `{{resources.allocation.data.registered}}` |
{{/resources.allocation}}

## The deployment fails on the registration step

**Diagnosis.** The endpoint refused the request, or Massdriver cannot reach it.

**Fix.** Test the endpoint from outside your network.

```bash
curl -i -X POST <ENDPOINT> \
  -H 'Content-Type: application/json' \
  -d '{"cidr":"10.10.0.0/16","pool":"corp-nonprod"}'
```

The endpoint must accept traffic from the Massdriver provisioner. Ask the
network team to open it.

## The endpoint answers 409

The record exists already. The bundle treats 409 as success, because a repeat
deployment sends the same range.

## Warning: two networks with the same range

The bundle records the range that you give. It does not search for a conflict.
Reserve the range in the management system first.

## Turn registration off

Set `register_with_ipam` to false. The bundle then records the range inside
Massdriver alone, and the platform team registers it by hand.
