# Register an existing Cloud SQL PostgreSQL instance

Use this form to bring a Cloud SQL for PostgreSQL instance into Massdriver so other bundles can connect to it.

You will need the [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated against the project hosting the instance:

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

---

### **ID**

```bash
gcloud sql instances list
```

Paste the `NAME` (for example `orders-prod`) — or the fully-qualified `projects/<proj>/instances/<name>` if you need to disambiguate across projects — into the **ID** field.

---

### **Version**

```bash
gcloud sql instances describe <name> --format='value(databaseVersion)'
```

This returns `POSTGRES_16` style — paste just the number (`16`) into **Version**.

---

### **Authentication → Host**

By default applications connect through the Cloud SQL Auth Proxy. The connection string for the proxy is the **connection name**:

```bash
gcloud sql instances describe <name> --format='value(connectionName)'
```

Paste it (for example `my-proj:us-central1:orders-prod`) into **Host** if your consumers are using the Auth Proxy.

If you've enabled **public IP** or **private IP** and your consumers are connecting directly:

```bash
gcloud sql instances describe <name> \
  --format='value(ipAddresses[0].ipAddress)'
```

Paste the IP into **Host** instead.

### **Authentication → Port**

`5432` for direct connections, or the local port your proxy listens on (typically `5432` too). Paste **5432** unless you've customized.

### **Authentication → Database**

Cloud SQL creates a database called `postgres` by default. If you've created application databases on top, list them:

```bash
gcloud sql databases list --instance <name>
```

Paste the database name you want consumers to default to into **Database**.

### **Authentication → Username**

The built-in superuser is `postgres`. To list all users:

```bash
gcloud sql users list --instance <name>
```

Paste the username you want consumers to default to into **Username**. For production, prefer a least-privilege user over `postgres`.

### **Authentication → Password**

Cloud SQL does **not** expose the password via the API after creation. Pull it from wherever you stashed it (Secret Manager, password manager, your IaC state) and paste into **Password**:

```bash
gcloud secrets versions access latest --secret=<your-pg-password-secret>
```

The field is masked everywhere in the UI and audit-logged on download.

---

### **High Availability** *(optional)*

```bash
gcloud sql instances describe <name> --format='value(settings.availabilityType)'
```

Set **High Availability** to `true` when this prints `REGIONAL`.

---

### **Policies**

Edit the policy list to match the SQL roles you actually GRANT. A common starter set is:

- `read-only` / "Read"
- `read-write` / "Write"
- `admin` / "Admin"

The **ID** is what your IaC's role-bindings key off; **Name** is what shows in dropdowns for consumers.
