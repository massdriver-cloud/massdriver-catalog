# 📚 Network Bundle Runbook

```
╔═══════════════════════════════════════╗
║                                       ║
║   CUSTOMIZE YOUR RUNBOOK HERE! 🚀     ║
║                                       ║
╚═══════════════════════════════════════╝
```

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

## Example: Network Operations

### Checking Network Connectivity

```bash
# Placeholder - add your actual commands
tofu state show module.network.aws_vpc.main
```

### Common Issues

**Issue**: Connection timeouts
**Solution**: Check security group rules and NACLs

---

**Ready to customize?** [Edit this file](https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/network/operator.md) to make it your own! 🎯
