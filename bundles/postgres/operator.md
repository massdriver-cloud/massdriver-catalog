---
templating: mustache
---

# 🐘 PostgreSQL Bundle Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

### Configuration

**PostgreSQL Version:** `{{params.db_version}}`

**Database Name:** `{{params.database_name}}`

**Username:** `{{params.username}}`

### Connected Network

{{#connections.network}}
**Network ID:** `{{connections.network.infrastructure.network_id}}`

**Network CIDR:** `{{connections.network.infrastructure.cidr}}`
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

**Database ID:** `{{artifacts.database.infrastructure.database_id}}`

**PostgreSQL Version:** `{{params.db_version}}`

### Connection Details

**Hostname:** `{{artifacts.database.connection.hostname}}`

**Port:** `{{artifacts.database.connection.port}}`

**Database Name:** `{{artifacts.database.connection.database}}`

**Username:** `{{artifacts.database.connection.username}}`

### Connecting to the Database

```bash
# Connect to PostgreSQL interactively
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}}

# Connect with connection string format
psql "postgresql://{{artifacts.database.connection.username}}:{{artifacts.database.connection.password}}@{{artifacts.database.connection.hostname}}:{{artifacts.database.connection.port}}/{{artifacts.database.connection.database}}"
```

### Common Operations

**List all databases:**

```bash
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -c "\l"
```

**List all tables:**

```bash
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -c "\dt"
```

**Check database size:**

```bash
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -c "SELECT
           pg_database.datname AS database_name,
           pg_size_pretty(pg_database_size(pg_database.datname)) AS size
         FROM pg_database
         WHERE datname = '{{artifacts.database.connection.database}}';"
```

**Check connection and version:**

```bash
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -c "SELECT version(), current_user, current_database();"
```

**Show active connections:**

```bash
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -c "SELECT pid, usename, application_name, client_addr, state, query_start
         FROM pg_stat_activity
         WHERE datname = '{{artifacts.database.connection.database}}';"
```

**Check table sizes:**

```bash
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -c "SELECT
           schemaname,
           tablename,
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
         FROM pg_tables
         WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
         ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
         LIMIT 10;"
```

**Create a backup:**

```bash
# Custom format (recommended, supports parallel restore)
PGPASSWORD={{artifacts.database.connection.password}} pg_dump -h {{artifacts.database.connection.hostname}} \
        -U {{artifacts.database.connection.username}} \
        -d {{artifacts.database.connection.database}} \
        -p {{artifacts.database.connection.port}} \
        -F c \
        -f backup-{{artifacts.database.connection.database}}-$(date +%Y%m%d-%H%M%S).dump

# Plain SQL format
PGPASSWORD={{artifacts.database.connection.password}} pg_dump -h {{artifacts.database.connection.hostname}} \
        -U {{artifacts.database.connection.username}} \
        -d {{artifacts.database.connection.database}} \
        -p {{artifacts.database.connection.port}} \
        -F p \
        -f backup-{{artifacts.database.connection.database}}-$(date +%Y%m%d-%H%M%S).sql
```

**Restore from backup:**

```bash
# Restore from custom format
PGPASSWORD={{artifacts.database.connection.password}} pg_restore -h {{artifacts.database.connection.hostname}} \
           -U {{artifacts.database.connection.username}} \
           -d {{artifacts.database.connection.database}} \
           -p {{artifacts.database.connection.port}} \
           -c \
           backup-{{artifacts.database.connection.database}}-20260123-120000.dump

# Restore from SQL format
PGPASSWORD={{artifacts.database.connection.password}} psql -h {{artifacts.database.connection.hostname}} \
     -U {{artifacts.database.connection.username}} \
     -d {{artifacts.database.connection.database}} \
     -p {{artifacts.database.connection.port}} \
     -f backup-{{artifacts.database.connection.database}}-20260123-120000.sql
```

---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/postgres/operator.md) 🎯
