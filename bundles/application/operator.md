---
templating: mustache
---

# Application Runbook

> **Templating context:** `slug`, `params`, `connections.<name>`, `artifacts.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Image | `{{params.image}}` |
| Environment | `{{params.environment}}` |
| Log level | `{{params.log_level}}` |
| Replicas | `{{params.replicas}}` |
| Port | `{{params.port}}` |
| Domain | `{{params.domain_name}}` |
| Health check | `https://{{params.domain_name}}{{params.health_check_path}}` |
| CPU / memory | `{{params.cpu_limit}}` / `{{params.memory_limit}}` |

### Connected dependencies

{{#connections.database}}
**Database:** `{{connections.database.id}}` — `{{connections.database.auth.hostname}}:{{connections.database.auth.port}}/{{connections.database.auth.database}}` (policy: `{{params.database_policy}}`)
{{/connections.database}}
{{#connections.bucket}}
**Bucket:** `{{connections.bucket.name}}` (policy: `{{params.bucket_policy}}`)
{{/connections.bucket}}
{{#connections.network}}
**Network:** `{{connections.network.id}}` ({{connections.network.cidr}})
{{/connections.network}}

---

## Active alarms — what they mean

### Pod Restart Rate (> 3 / 10min)

A pod is crash-looping. Either OOMKilled, liveness-probe failures, or a config error.

```bash
# Look at the most recent restarts
kubectl get pods -l app={{slug}} \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\t"}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'

# Pull logs from the previous (terminated) container — most useful for OOMs
kubectl logs <pod-name> --previous --tail 200
```

Common fixes: bump `memory_limit` if `lastState.terminated.reason` is `OOMKilled`; widen the `health_check_path` probe's failure threshold; check for a missing env var the app expects.

### 5xx Error Rate (> 1%)

Users are seeing server errors.

```bash
# Compare error rate to traffic rate over the last 30 minutes
kubectl exec -ti <pod-name> -- curl -s http://localhost:{{params.port}}{{params.health_check_path}}
```

```bash
# Trail logs at warn+
kubectl logs -l app={{slug}} --tail 200 -f | grep -Ei 'warn|error|panic'
```

If errors cluster around a code path, roll back to the last green deploy:

```bash
# Roll back via the Massdriver UI ("Versions" → previous), or use the CLI
mass instance deploy <instance-id> --patch='.image = "<previous-image-tag>"'
```

### p95 Latency (> 500ms)

Response times are slowing. Common causes: database becoming the bottleneck, an upstream timeout, or a noisy neighbor on the node.

```bash
# Show DB connections from this app (if you've labeled them via application_name)
PGPASSWORD={{connections.database.auth.password}} psql \
  -h {{connections.database.auth.hostname}} \
  -p {{connections.database.auth.port}} \
  -U {{connections.database.auth.username}} \
  -d {{connections.database.auth.database}} \
  -c "SELECT pid, state, query_start, wait_event_type, wait_event,
             substring(query, 1, 80) AS query
      FROM pg_stat_activity
      WHERE application_name LIKE '%{{slug}}%'
        AND state != 'idle';"
```

```bash
# Per-pod CPU / memory snapshot
kubectl top pod -l app={{slug}}
```

---

## Common operations

### Restart cleanly

```bash
kubectl rollout restart deployment/{{slug}}
kubectl rollout status deployment/{{slug}}
```

### Tail logs

```bash
kubectl logs -l app={{slug}} --tail 200 -f
```

### Scale temporarily without a redeploy

```bash
# Useful in incident response — the next Massdriver deploy will reset to params.replicas={{params.replicas}}
kubectl scale deployment/{{slug}} --replicas=<n>
```

### Open a shell in a running pod

```bash
kubectl exec -ti $(kubectl get pod -l app={{slug}} -o jsonpath='{.items[0].metadata.name}') -- /bin/sh
```

### Verify env vars are wired correctly

The bundle's `app:` block lifts these values out of the linked resources:

| Env var | Source |
|---------|--------|
| `APP_ENV` | `params.environment` = `{{params.environment}}` |
| `LOG_LEVEL` | `params.log_level` = `{{params.log_level}}` |
| `PORT` | `params.port` = `{{params.port}}` |
| `DATABASE_HOST` | `connections.database.auth.hostname` |
| `DATABASE_URL` | composed from `connections.database.auth.*` |
| `BUCKET_NAME` | `connections.bucket.name` (empty if no bucket linked) |
| `JWT_SECRET` | `app.secrets.JWT_SECRET` (set in Massdriver UI) |

```bash
kubectl exec -ti <pod-name> -- env | grep -E '^(APP_ENV|LOG_LEVEL|PORT|DATABASE_|BUCKET_)='
```

---

## Disaster recovery

The application is stateless — replicas can be killed and recreated freely. Data lives in:

- **Database** `{{connections.database.id}}` — see its own runbook for recovery.
- **Bucket** `{{connections.bucket.name}}` — see its own runbook for recovery.

If the application image itself is bad:

1. Identify the last known-good image tag from this bundle's deploy history (Versions tab).
2. Patch the deployed config: `mass instance deploy <instance-id> --patch='.image = "<good-tag>"'`.
3. Watch the rollout: `kubectl rollout status deployment/{{slug}}`.

---

**Edit this runbook:** https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/application/operator.md
