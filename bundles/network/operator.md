---
templating: mustache
---

# 📚 Network Bundle Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

### Configuration

**CIDR Block:** `{{params.cidr}}`

**Subnets:**

{{#params.subnets}}

- **{{name}}**: `{{cidr}}`
  {{/params.subnets}}

---

## Welcome to Your Runbook! 👋

This is a **default runbook template** for your bundle. You can customize this file to provide operational guidance, troubleshooting steps, and best practices for managing this infrastructure.

### 📝 How to Use This File

This `operator.md` file lives in the root of your bundle directory (`./bundles/network/operator.md`). When you edit it, your custom runbook will appear in the Massdriver UI, giving your team instant access to operational documentation right where they need it.

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

## Network Operations

### Network Configuration

**Network ID:** `{{artifacts.network.infrastructure.network_id}}`

**Network CIDR:** `{{artifacts.network.infrastructure.cidr}}`

### Subnets

{{#artifacts.network.subnets}}

- **Subnet ID:** `{{subnet_id}}` | **CIDR:** `{{cidr}}` | **Type:** `{{type}}`
  {{/artifacts.network.subnets}}

### Network Information

Use the network ID and subnet details to connect other resources to this network.

---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/network/operator.md) 🎯
