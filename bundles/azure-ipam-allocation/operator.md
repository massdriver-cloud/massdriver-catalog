---
templating: mustache
---

# Address Range Runbook

## Health check

{{#resources.allocation}}
The range `{{resources.allocation.cidr}}` belongs to the pool
`{{resources.allocation.pool}}`. Confirm that the management system agrees.

```bash
curl -sS <ENDPOINT>?cidr={{resources.allocation.cidr}} | jq .
```
{{/resources.allocation}}

## The deployment fails on the registration step

The endpoint refused the request, or Massdriver cannot reach it.

{{#resources.allocation}}
1. Test the endpoint from outside your network.
   ```bash
   curl -i -X POST <ENDPOINT> \
     -H 'Content-Type: application/json' \
     -d '{"cidr":"{{resources.allocation.cidr}}","pool":"{{resources.allocation.pool}}"}'
   ```
2. The bundle accepts 200, 201, and 409. Any other answer fails the deployment.
3. When the endpoint refuses traffic from Massdriver, ask the network team to
   open it, or turn registration off and register the range by hand.
{{/resources.allocation}}

## The endpoint answers 409

The record exists already, and the bundle treats that as success. A repeat
deployment sends the same range, so this answer is normal.

## Two networks hold the same range

The bundle records the range that you give, and it does not search for a
conflict. Two networks with the same range cannot route to each other.

1. Reserve the range in the management system first.
2. Deploy the network that owns the range, and decommission the other one.

## Move a network to a new range

The range is immutable here, and the network destroys itself when its range
changes. Create a second allocation and a second network, move each workload,
then decommission the first pair.

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
