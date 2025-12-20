---
templating: mustache
---

# 🐬 MySQL Bundle Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>.specs`, `artifacts.<name>.specs`

## Package Information

**Slug:** `{{slug}}`

### Configuration

**MySQL Version:** `{{params.db_version}}`

**Database Name:** `{{params.database_name}}`

**Username:** `{{params.username}}`

### Connected Network

{{#connections.network}}
**Network CIDR:** `{{specs.network.cidr}}`
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

**Database Version:** MySQL `{{artifacts.database.specs.database.version}}`

**Database Name:** `{{params.database_name}}`

**Username:** `{{artifacts.database.specs.database.username}}`

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
# Connect to MySQL
# Username and password are stored securely and injected at runtime
mysql -h {{artifacts.database.specs.database.hostname}} \
      -u {{artifacts.database.specs.database.username}} \
      -p \
      -P {{artifacts.database.specs.database.port}} \
      {{params.database_name}}
```

### Common Operations

**Check database size:**

```bash
mysql -h {{artifacts.database.specs.database.hostname}} \
      -u {{artifacts.database.specs.database.username}} \
      -p \
      -P {{artifacts.database.specs.database.port}} \
      {{params.database_name}} \
      -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
          FROM information_schema.tables
          WHERE table_schema = '{{params.database_name}}';"
```

**Create a backup:**

```bash
mysqldump -h {{artifacts.database.specs.database.hostname}} \
          -u {{artifacts.database.specs.database.username}} \
          -p \
          -P {{artifacts.database.specs.database.port}} \
          {{params.database_name}} > backup-$(date +%Y%m%d).sql
```



---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/mysql/operator.md) 🎯
