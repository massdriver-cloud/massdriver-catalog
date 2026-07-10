---
templating: mustache
---

# WordPress Runbook

> **Templating context:** `slug`, `params`, `artifacts.<name>`, `connections.<name>`.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Workload | `{{artifacts.app.id}}` |
| Health check | `{{artifacts.app.health_path}}` |
| Database host | `{{connections.database.auth.hostname}}` |
| Exposure | `{{params.service_type}}` |
| Replicas | `{{params.replicas}}` |

The workload ID is `namespace/release`, and both halves are the same string. Set these once and paste the commands below:

```bash
ID="{{artifacts.app.id}}"
NS="${ID%%/*}"
REL="${ID##*/}"
```

---

## "The site is down"

Work outside-in:

```bash
# 1. Are the pods running?
kubectl get pods -n "$NS"

# 2. If pods are Pending / CrashLoopBackOff, why?
kubectl describe pod -n "$NS" -l app.kubernetes.io/name=wordpress | tail -30

# 3. What is the app saying?
kubectl logs -n "$NS" -l app.kubernetes.io/name=wordpress --tail=100

# 4. Does the service have an address? (LoadBalancer only)
kubectl get svc -n "$NS" "$REL"
```

- **Pods `Pending`** — the cluster is out of room or has no storage class for the 10Gi volume. `kubectl describe` says which. Escalate to the platform team; this is a cluster problem, not a WordPress problem.
- **Pods `CrashLoopBackOff`** — read the logs (step 3). Nine times out of ten it's the database (see the last section).
- **Pods `Running` but the URL times out** — the load balancer isn't ready or was deleted. `kubectl get svc` shows `<pending>` under EXTERNAL-IP; give a new one ~3 minutes. If `params.service_type` is `ClusterIP`, there is no public URL by design.

## "White screen of death"

WordPress is up but serving a blank page — usually a broken plugin or theme, not infrastructure.

```bash
# PHP fatal errors show up in the pod logs
kubectl logs -n "$NS" -l app.kubernetes.io/name=wordpress --tail=200 | grep -i "fatal\|error"

# Disable the most recently changed plugin without touching the browser
kubectl exec -n "$NS" deploy/"$REL" -- wp plugin list
kubectl exec -n "$NS" deploy/"$REL" -- wp plugin deactivate <plugin-name>
```

If the logs point at the theme instead, switch to a stock one the same way: `wp theme activate twentytwentyfour`.

## "I can't log in"

The admin username is `{{params.admin_username}}`. If the password is lost (or you set the `WORDPRESS_ADMIN_PASSWORD` app secret and want WordPress to match it), reset it in place:

```bash
kubectl exec -n "$NS" deploy/"$REL" -- wp user update {{params.admin_username}} --user_pass='NEW_PASSWORD_HERE'
```

If login *pages* load but logins bounce back with no error, clear stale login sessions:

```bash
kubectl exec -n "$NS" deploy/"$REL" -- wp user session destroy {{params.admin_username}} --all
```

## "Error establishing a database connection"

WordPress can't reach `{{connections.database.auth.hostname}}`. Check reachability from where the pods actually run:

```bash
# Can the pod resolve and reach the database?
kubectl exec -n "$NS" deploy/"$REL" -- bash -c \
  'timeout 5 bash -c "</dev/tcp/{{connections.database.auth.hostname}}/{{connections.database.auth.port}}" && echo REACHABLE || echo BLOCKED'
```

- **BLOCKED** — a security group or network policy is in the way, or the database is down. Check the database instance's own runbook in Massdriver; escalate to whoever owns it.
- **REACHABLE but still erroring** — credentials. The database password rotates with the database bundle; redeploy this instance so the Helm release picks up the new connection values.
