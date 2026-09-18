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
3. Create a **Fivetran Account** resource in Massdriver, and put the token in it.
4. Set that resource as the default of the environment.

The token lives in a resource, not in a secret of this instance. One record then
serves every environment, and the platform team rotates it in one place.

## Connections

| Connection | Required | Purpose |
|---|---|---|
| Kubernetes cluster | Yes | The cluster that runs the agent. |
| Fivetran account | Yes | The token that joins the agent to your account. |
| Database | No | A source that the agent reads. |
