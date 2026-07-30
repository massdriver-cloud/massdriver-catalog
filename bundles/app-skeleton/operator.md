---
templating: mustache
---

# App Skeleton Runbook

> **Templating context:** `slug`, `params`. This bundle has no application logic — this runbook exists mainly to show the pattern real app bundles should follow.

## At a glance

| Field | Value |
|-------|-------|
| Instance slug | `{{slug}}` |
| Image | `{{params.image}}` |
| Replicas | `{{params.replicas}}` |
| Container port | `{{params.container_port}}` |

---

## Common operations

### Check pod status

```bash
kubectl -n {{slug}} get pods
kubectl -n {{slug}} logs deploy/app --tail=100
```

### Confirm IRSA is wired correctly

```bash
kubectl -n {{slug}} exec -it deploy/app -- aws sts get-caller-identity
# Should show the app's own scoped IAM role, not the node role.
```

### Confirm every connection landed in the environment

```bash
kubectl -n {{slug}} exec -it deploy/app -- env | grep -E 'DATABASE_|STORAGE_|QUEUE_|REDIS_|SMTP_'
```

---

## Disaster recovery

There's no real state here — redeploying from scratch is always safe. This bundle exists to prove wiring, not to hold anything worth protecting.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/app-skeleton/operator.md
