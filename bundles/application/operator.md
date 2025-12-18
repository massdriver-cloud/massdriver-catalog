# 🚀 Application Bundle Runbook

```
╭──────────────────────────────╮
│                              │
│  ✨ CUSTOMIZE THIS RUNBOOK!  │
│                              │
│  Your ops docs live here     │
│  in operator.md              │
│                              │
╰──────────────────────────────╯
```

## Welcome to Your Runbook! 👋

This is a **default runbook template** for your bundle. You can customize this file to provide operational guidance, troubleshooting steps, and best practices for managing this infrastructure.

### 📝 How to Use This File

This `operator.md` file lives in the root of your bundle directory (`./bundles/application/operator.md`). When you edit it, your custom runbook will appear in the Massdriver UI, giving your team instant access to operational documentation right where they need it.

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

## Example: Application Operations

### Viewing Application Logs

```bash
# Placeholder - add your actual commands
kubectl logs -f deployment/<app-name>
```

### Common Issues

**Issue**: Application not starting  
**Solution**: Check container logs and environment variables

---

**Ready to customize?** Edit this file to make it your own! 🎯
