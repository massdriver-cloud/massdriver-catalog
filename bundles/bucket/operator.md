# 🪣 Storage Bucket Runbook

```
  _____________________
 /                     \
|   RUNBOOK TEMPLATE    |
|                       |
|   Edit operator.md    |
|   to customize! 🎨    |
 \_____________________/
```

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

### Listing Bucket Contents

```bash
# Placeholder - add your actual commands
aws s3 ls s3://<bucket-name>/
```

### Common Issues

**Issue**: Access denied errors
**Solution**: Check bucket policy and IAM permissions

---

**Ready to customize?** Edit this file to make it your own! 🎯
