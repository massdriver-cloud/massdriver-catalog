---
templating: mustache
---

# 🪣 Storage Bucket Runbook

> **Templating**: This runbook supports mustache templating.
> **Available context**: `slug`, `params`, `connections.<name>`, `artifacts.<name>`

## Package Information

**Slug:** `{{slug}}`

### Configuration

**Bucket Name:** `{{params.bucket_name}}`

**Versioning Enabled:** `{{params.versioning_enabled}}`

---

## Welcome to Your Runbook! 👋

This is a **default runbook template** for your bundle. You can customize this file to provide operational guidance, troubleshooting steps, and best practices for managing this infrastructure.

### 📝 How to Use This File

This `operator.md` file lives in the root of your bundle directory (`./bundles/bucket/operator.md`). When you edit it, your custom runbook will appear in the Massdriver UI, giving your team instant access to operational documentation right where they need it.

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

## Example: Bucket Operations

### Bucket Information

**Configured Name:** `{{params.bucket_name}}`

**Deployed Bucket Name:** `{{artifacts.bucket.name}}` _(includes generated suffix)_

**Bucket ID:** `{{artifacts.bucket.id}}`

**Endpoint:** `{{artifacts.bucket.endpoint}}`

**Versioning Enabled:** `{{params.versioning_enabled}}`

### Listing Bucket Contents

**AWS S3:**

```bash
# List all objects in the bucket
aws s3 ls s3://{{artifacts.bucket.name}}/

# List objects with human-readable sizes
aws s3 ls s3://{{artifacts.bucket.name}}/ --human-readable --summarize
```

**Azure Blob Storage:**

```bash
# List all blobs in the container
az storage blob list \
  --container-name {{artifacts.bucket.name}} \
  --output table

# Show blob properties
az storage blob show \
  --container-name {{artifacts.bucket.name}} \
  --name myfile.txt
```

### Uploading Files

**AWS S3:**

```bash
# Upload a single file
aws s3 cp myfile.txt s3://{{artifacts.bucket.name}}/

# Upload a directory recursively
aws s3 sync ./local-folder/ s3://{{artifacts.bucket.name}}/remote-folder/
```

**Azure Blob Storage:**

```bash
# Upload a single file
az storage blob upload \
  --container-name {{artifacts.bucket.name}} \
  --file myfile.txt \
  --name myfile.txt
```

### Common Issues

**Issue**: Access denied errors
**Solution**: Check bucket policy and access permissions for `{{artifacts.bucket.name}}`

---

**Ready to customize?** [Edit this runbook](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/bucket/operator.md) 🎯
