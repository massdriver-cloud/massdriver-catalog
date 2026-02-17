---
templating: mustache
---

# 🚀 Application Bundle Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

### Application Configuration

**Container Image:** `{{params.image}}`

**Replicas:** `{{params.replicas}}`

**Port:** `{{params.port}}`

**Domain:** `{{params.domain_name}}`

---

## Welcome to Your Runbook! 👋

This is a **default runbook template** for your bundle. You can customize this file to provide operational guidance, troubleshooting steps, and best practices for managing this infrastructure.

### Connected Database

{{#connections.database}}
**Database ID:** `{{connections.database.id}}`

**Connection:** `{{connections.database.auth.hostname}}:{{connections.database.auth.port}}/{{connections.database.auth.database}}`

**Selected Access Policy:** `{{params.database_policy}}`
{{/connections.database}}
{{^connections.database}}
_No database connected_
{{/connections.database}}

### Connected Storage Bucket

{{#connections.bucket}}
**Bucket Name:** `{{connections.bucket.name}}`

**Bucket ID:** `{{connections.bucket.id}}`

**Selected Access Policy:** `{{params.bucket_policy}}`
{{/connections.bucket}}
{{^connections.bucket}}
_No storage bucket connected_
{{/connections.bucket}}

### Network Information

{{#connections.network}}
**Network ID:** `{{connections.network.id}}`

**Network CIDR:** `{{connections.network.cidr}}`
{{/connections.network}}
{{^connections.network}}
_No network connected_
{{/connections.network}}

### 💡 What to Include

Consider adding:

- **Common Operations**: How to scale, update, or modify this infrastructure
- **Troubleshooting Guide**: Known issues and their solutions
- **Monitoring & Alerts**: What to watch and when to act
- **Disaster Recovery**: Backup and restore procedures
- **Configuration Tips**: Best practices and gotchas
- **Useful Commands**: CLI commands, queries, or scripts
- **Contact Information**: Who to reach for help

### ✨ Pro Tips

- Use clear headings and sections
- Include code blocks with examples
- Add links to relevant documentation
- Keep it updated as you learn more
- Make it searchable with good keywords

---

## Application Operations

### Testing the Application

**Health check:**

```bash
curl https://{{params.domain_name}}/health
```

**Basic connectivity test:**

```bash
curl -I https://{{params.domain_name}}
```

**Debug with verbose output:**

```bash
curl -v https://{{params.domain_name}}
```

### Database Connection

{{#connections.database}}
The application is connected to database `{{connections.database.id}}`.

Connection details are available via environment variables injected at runtime.
{{/connections.database}}

### Scaling Application

Current replicas: **{{params.replicas}}**

To scale the application, update the `replicas` parameter in Massdriver and redeploy.

---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/application/operator.md) 🎯
