---
templating: mustache
---

# 🐘 PostgreSQL Bundle Runbook

## Package Information

**Slug:** `{{slug}}`

### Configuration

**PostgreSQL Version:** `{{params.db_version}}`
**Database Name:** `{{params.database_name}}`

### Connected Network

{{#connections.network}}
**Network CIDR:** `{{specs.network.cidr}}`
{{/connections.network}}

---

## Welcome to Your Runbook! 👋

This is a **default runbook template** for your bundle. You can customize this file to provide operational guidance, troubleshooting steps, and best practices for managing this infrastructure.

### 📝 How to Use This File

This `operator.md` file lives in the root of your bundle directory (`./bundles/postgres/operator.md`). When you edit it, your custom runbook will appear in the Massdriver UI, giving your team instant access to operational documentation right where they need it.

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

## PostgreSQL Operations

### Database Configuration

**Database Version:** PostgreSQL `{{artifacts.database.specs.database.version}}`
**Database Name:** `{{params.database_name}}`
**Hostname:** `{{artifacts.database.specs.database.hostname}}`
**Port:** `{{artifacts.database.specs.database.port}}`

### Network Information

**Subnet ID:** `{{artifacts.database.specs.network.subnet_id}}`
**Private IP:** `{{artifacts.database.specs.network.private_ip}}`

{{#connections.network}}
**Network CIDR:** `{{specs.network.cidr}}`
{{/connections.network}}

### Connecting to the Database

```bash
# Connect to PostgreSQL
# Username and password are stored securely and injected at runtime
psql -h {{artifacts.database.specs.database.hostname}} \
     -U <username> \
     -d {{params.database_name}} \
     -p {{artifacts.database.specs.database.port}}
```

### Common Operations

**Check database size:**

```bash
psql -h {{artifacts.database.specs.database.hostname}} \
     -U <username> \
     -d {{params.database_name}} \
     -p {{artifacts.database.specs.database.port}} \
     -c "SELECT pg_size_pretty(pg_database_size('{{params.database_name}}'));"
```

**Create a backup:**

```bash
pg_dump -h {{artifacts.database.specs.database.hostname}} \
        -U <username> \
        -d {{params.database_name}} \
        -p {{artifacts.database.specs.database.port}} \
        -F c -f backup-$(date +%Y%m%d).dump
```

---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/postgres/operator.md) 🎯
