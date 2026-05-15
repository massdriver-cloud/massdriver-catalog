# Register an external application

Use this form to register an application that lives **outside** Massdriver — a SaaS endpoint, a workload deployed by another tool, or anything you want other bundles in the environment to be aware of (and link to).

You only need a name plus the URLs that identify and probe the service.

---

### **Name**

A short, lowercase, kebab-cased name. Shows up in dependency graphs and observability dashboards.

Pick something that maps to how the rest of your platform refers to this service. Example: `payments-api`.

Paste it into **Name**.

---

### **Service URL** *(optional)*

The base URL where consumers reach the application:

```
https://payments-api.example.com
```

Paste it into **Service URL**. Massdriver doesn't probe this URL — it's metadata for downstream bundles that need to know "where does this app live".

---

### **Health Check URL** *(optional)*

A full URL to a liveness or health endpoint. Massdriver doesn't poll it directly, but synthetic-check bundles and monitoring resource types pick it up:

```
https://payments-api.example.com/health
```

Paste it into **Health Check URL**.

---

### **Deployment ID** *(optional)*

Whatever identifier your release pipeline already uses — a commit SHA, an image digest, or a build number. Leave it blank if you're registering a service that doesn't roll out through Massdriver. Example: `sha:7a2f3e9b`.

---

### **Tags** *(optional)*

Free-form key/value labels. Common keys:

- `team` — owning team (`payments`)
- `tier` — `critical` / `important` / `experimental`
- `owner` — Slack channel or email
- `runbook` — URL to the on-call runbook
