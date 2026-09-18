# Fivetran Agent Runbook

## The agent does not appear in the Fivetran dashboard

**Diagnosis.** The token is wrong, or the pod cannot reach Fivetran.

**Fix.** Read the logs of the pod.

```bash
kubectl logs -n <NAMESPACE> -l app.kubernetes.io/name=hybrid-deployment-agent --tail=100
```

Check that the cluster reaches the internet through its outbound address.

## The pod starts, and nothing happens

**Diagnosis.** Helm ignored the value keys, because the names do not match the
chart.

**Fix.** Read the values that the release holds now.

```bash
helm get values -n <NAMESPACE> <RELEASE>
```

Compare each key with the chart documentation, then correct
`chart/values.jq`.

## The agent cannot reach the database

**Diagnosis.** A network policy blocks the traffic, or the database answers in
another network.

**Fix.** Check that the cluster and the database sit in the same network.

## Rotate the token

Set a new value in the `FIVETRAN_AGENT_TOKEN` secret, then deploy again. Fivetran
keeps the old token until you delete the agent in its dashboard.
