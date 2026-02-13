---
templating: mustache
---

# Bundle Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

## Configuration

| Setting | Value |
|---------|-------|
| Param 1 | `{{params.example_param}}` |

## Connections

{{#connections.network}}
### Network

- **ID:** `{{connections.network.id}}`
- **CIDR:** `{{connections.network.cidr}}`
{{/connections.network}}

{{#connections.database}}
### Database

- **Host:** `{{connections.database.auth.hostname}}`
- **Database:** `{{connections.database.auth.database}}`
{{/connections.database}}

## Artifacts

{{#artifacts.my_artifact}}
### My Artifact

- **ID:** `{{artifacts.my_artifact.id}}`
{{/artifacts.my_artifact}}

---

## Common Operations

[Add your operational procedures here]

### Example: Connect to Resource

```bash
# Example command using artifact data
echo "Connecting to {{artifacts.my_artifact.id}}"
```

## Troubleshooting

### Issue: Connection Failed

1. Check network connectivity
2. Verify credentials
3. Check security group/firewall rules

### Issue: Permission Denied

1. Verify IAM policies
2. Check resource permissions

---

## Contacts

- **Team**: Platform Engineering
- **Slack**: #platform-support

---

**Ready to customize?** Edit this file at `./bundles/<name>/operator.md`
