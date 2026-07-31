---
templating: mustache
---

# App Skeleton Runbook

## Common operations

### Check pod status

```bash
kubectl -n {{slug}} get pods
kubectl -n {{slug}} logs deploy/app --tail=100
```

### Verify IRSA is wired correctly

```bash
kubectl -n {{slug}} exec -it deploy/app -- aws sts get-caller-identity
# Should show the app's own scoped IAM role, not the node role.
```

### Verify every connection landed in the environment

```bash
kubectl -n {{slug}} exec -it deploy/app -- env | grep -E 'DATABASE_|STORAGE_|QUEUE_|REDIS_|SMTP_'
```

## Disaster recovery

This bundle holds no state; redeploying from scratch is always safe.

---

**Edit this runbook:** https://github.com/YOUR_ORG/YOUR_REPO/tree/main/bundles/app-skeleton/operator.md
