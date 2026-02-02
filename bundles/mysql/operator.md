---
templating: mustache
---

# 🐬 MySQL Bundle Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

### Configuration

**MySQL Version:** `{{params.db_version}}`

**Database Name:** `{{params.database_name}}`

**Username:** `{{params.username}}`

### Connected Network

{{#connections.network}}
**Network ID:** `{{connections.network.id}}`

**Network CIDR:** `{{connections.network.cidr}}`
{{/connections.network}}

---

## Welcome to Your Runbook! 👋

This is a **default runbook template** for your bundle. You can customize this file to provide operational guidance, troubleshooting steps, and best practices for managing this infrastructure.

### 📝 How to Use This File

This `operator.md` file lives in the root of your bundle directory (`./bundles/mysql/operator.md`). When you edit it, your custom runbook will appear in the Massdriver UI, giving your team instant access to operational documentation right where they need it.

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

## MySQL Operations

### Database Configuration

**Database ID:** `{{artifacts.database.id}}`

**MySQL Version:** `{{params.db_version}}`

### Connection Details

**Hostname:** `{{artifacts.database.auth.hostname}}`

**Port:** `{{artifacts.database.auth.port}}`

**Database Name:** `{{artifacts.database.auth.database}}`

**Username:** `{{artifacts.database.auth.username}}`

### Connecting to the Database

```bash
# Connect to MySQL interactively
mysql -h {{artifacts.database.auth.hostname}} \
      -u {{artifacts.database.auth.username}} \
      -p{{artifacts.database.auth.password}} \
      -P {{artifacts.database.auth.port}} \
      {{artifacts.database.auth.database}}
```

### Common Operations

**Show all databases:**

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -u {{artifacts.database.auth.username}} \
      -p{{artifacts.database.auth.password}} \
      -P {{artifacts.database.auth.port}} \
      -e "SHOW DATABASES;"
```

**Show tables in current database:**

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -u {{artifacts.database.auth.username}} \
      -p{{artifacts.database.auth.password}} \
      -P {{artifacts.database.auth.port}} \
      {{artifacts.database.auth.database}} \
      -e "SHOW TABLES;"
```

**Check database size:**

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -u {{artifacts.database.auth.username}} \
      -p{{artifacts.database.auth.password}} \
      -P {{artifacts.database.auth.port}} \
      {{artifacts.database.auth.database}} \
      -e "SELECT
            table_schema AS 'Database',
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
          FROM information_schema.tables
          WHERE table_schema = '{{artifacts.database.auth.database}}'
          GROUP BY table_schema;"
```

**Check connection status:**

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -u {{artifacts.database.auth.username}} \
      -p{{artifacts.database.auth.password}} \
      -P {{artifacts.database.auth.port}} \
      -e "SELECT USER(), DATABASE(), VERSION();"
```

**Create a backup:**

```bash
mysqldump -h {{artifacts.database.auth.hostname}} \
          -u {{artifacts.database.auth.username}} \
          -p{{artifacts.database.auth.password}} \
          -P {{artifacts.database.auth.port}} \
          --single-transaction \
          --routines \
          --triggers \
          {{artifacts.database.auth.database}} > backup-{{artifacts.database.auth.database}}-$(date +%Y%m%d-%H%M%S).sql
```

**Restore from backup:**

```bash
mysql -h {{artifacts.database.auth.hostname}} \
      -u {{artifacts.database.auth.username}} \
      -p{{artifacts.database.auth.password}} \
      -P {{artifacts.database.auth.port}} \
      {{artifacts.database.auth.database}} < backup-{{artifacts.database.auth.database}}-20260123-120000.sql
```

---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/mysql/operator.md) 🎯
