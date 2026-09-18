# Fivetran Hybrid Deployment Agent

This bundle runs the Fivetran agent on a Kubernetes cluster. The agent reads a
source inside your network, so the data never crosses the public internet on the
way out of the source.

## Warning: confirm the chart before the first deployment

The chart repository, the chart name, and the value keys in this bundle come
from the public Fivetran documentation. They are not verified against your
account. Confirm all three with your Fivetran account team, then correct
`massdriver.yaml` and `chart/values.jq`.

Helm ignores a wrong key without an error. The agent then starts with its
default values, and it does not report the mistake.

## Before you deploy

1. Create the agent in the Fivetran dashboard.
2. Copy the token that Fivetran shows once.
3. Put that token in the `FIVETRAN_AGENT_TOKEN` secret of this instance.

## Connections

| Connection | Required | Purpose |
|---|---|---|
| Kubernetes cluster | Yes | The cluster that runs the agent. |
| Database | No | A source that the agent reads. |
