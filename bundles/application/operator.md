---
templating: mustache
---

# Application runbook

## The "Pod Restart Rate" alarm fired, or pods are crash-looping

Get the restart counts and the reason the last container died:

```bash
kubectl get pods -l app={{slug}} \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\t"}{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}{end}'
```

The logs from the container that died, not the one that just started — this is where the actual
error is:

```bash
kubectl logs -l app={{slug}} --previous --tail 200
```

What the `reason` column means:

- **`OOMKilled`** — the container asked for more memory than `memory_limit`, currently
  `{{params.memory_limit}}`. Raise it and redeploy:

```bash
mass instance deploy {{slug}} -P '.memory_limit = "1Gi"' -m "OOMKilled at {{params.memory_limit}}" -f
```

- **`Error`, with the app never logging a startup line** — it is dying on configuration before it
  can serve. Check the environment (below).
- **`Completed` or an empty reason, with the app logging normally** — the app is healthy and the
  liveness probe is killing it anyway. `health_check_path` is `{{params.health_check_path}}`;
  either the app does not serve that path, or it does not answer within the probe timeout during
  startup.

## The "5xx Error Rate" alarm fired, or users are seeing server errors

Is the app answering its own health check?

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://{{params.domain_name}}{{params.health_check_path}}
```

Watch the errors as they happen:

```bash
kubectl logs -l app={{slug}} --tail 200 -f | grep -Ei 'warn|error|panic'
```

Log level is `{{params.log_level}}`. At `warn` or `error` the line that explains the failure may
never be written — raise it for the duration of the incident and put it back afterwards:

```bash
mass instance deploy {{slug}} -P '.log_level = "debug"' -m "incident triage" -f
```

If the errors started with a deploy and cluster around one code path, roll back rather than debug
in production.

## The "p95 Latency" alarm fired, or requests got slow

Check the app before you blame the database — a pod pinned at its CPU limit
(`{{params.cpu_limit}}`) looks exactly like a slow backend from the outside:

```bash
kubectl top pod -l app={{slug}}
```

{{#connections.database}}
Then look at what this app is doing to its database. `-W` prompts for the password; the value is
in `DATABASE_PASSWORD` inside the container, or on the database instance's resource in
Massdriver:

```bash
psql -h {{connections.database.auth.hostname}} -p {{connections.database.auth.port}} \
     -U {{connections.database.auth.username}} -d {{connections.database.auth.database}} -W \
     -c "SELECT pid, state, query_start, wait_event_type, wait_event,
                substring(query, 1, 80) AS query
         FROM pg_stat_activity
         WHERE application_name LIKE '%{{slug}}%'
           AND state != 'idle';"
```

Rows with a `wait_event_type` of `Lock` mean the queries are waiting on each other, not on the
database being too small. Anything else, and the database instance's own runbook takes it from
here.
{{/connections.database}}

## The app starts but cannot reach its database or bucket

Look at what the container actually received:

```bash
kubectl exec -ti $(kubectl get pod -l app={{slug}} -o jsonpath='{.items[0].metadata.name}') \
  -- env | sort | grep -E '^(APP_ENV|LOG_LEVEL|PORT|DATABASE_|BUCKET_)'
```

- **`DATABASE_*` empty or absent** — the database is not linked to this app on the canvas. These
  values come from the connection, so no link means no values, and the app's own configuration
  cannot fill the gap.
- **`BUCKET_NAME` and `BUCKET_ENDPOINT` empty** — expected when no bucket is linked. The bundle
  falls back to an empty string rather than failing the deploy, so an empty value here means "no
  bucket", not "broken bucket".
- **Everything populated and the app still cannot connect** — the values are right and the
  network path is wrong. Continue in the database or bucket instance's runbook, not this one.

Secrets do not appear in that list. `JWT_SECRET` is required, and Massdriver blocks the deploy
until it is set, so a running pod always has one.

## The app is wedged and I need to restart it

```bash
kubectl rollout restart deployment/{{slug}}
kubectl rollout status deployment/{{slug}}
```

This replaces pods one at a time and keeps serving throughout. It changes nothing about the
deployed configuration, so whatever wedged the app can wedge it again.

## Traffic spiked and I need more replicas before the next deploy

```bash
kubectl scale deployment/{{slug}} --replicas=6
```

The next Massdriver deploy resets this to `replicas`, which is `{{params.replicas}}`. If the
traffic is not going away, make it stick:

```bash
mass instance deploy {{slug}} -P '.replicas = 6' -m "scale up for sustained traffic" -f
```

## The image I just shipped is bad and I need to roll back

Find the last image that was serving in the Versions tab on this instance, then redeploy it:

```bash
mass instance deploy {{slug}} -P '.image = "ghcr.io/acme/api:1.41.0"' -m "roll back from {{params.image}}" -f
```

```bash
kubectl rollout status deployment/{{slug}}
```

The pods hold no data, so rolling them back costs nothing. The database does hold data, and
rolling the image back does not roll back a schema migration the bad version already ran. If the
release included a migration, work through the database instance's runbook before you assume the
rollback is complete.
