# Register a self-hosted PostgreSQL instance

Use this form to register a PostgreSQL server you run yourself — on a VM, in Kubernetes, or via an operator like Crunchy or CloudNativePG — so other Massdriver bundles can connect to it.

You will need shell access to the database host (or a `psql` client that can reach it).

---

### **ID**

Pick a stable identifier — usually the hostname or operator-resource name:

```bash
# VM-hosted server
hostname -f

# Kubernetes operator (CNPG example)
kubectl get cluster orders-prod -n databases -o jsonpath='{.metadata.uid}'
```

Paste your chosen identifier into the **ID** field. The string never has to leave your platform — it's only used to key the resource inside Massdriver.

---

### **Version**

```bash
psql -h <host> -U <user> -d postgres -c 'SHOW server_version;'
```

Paste the **major** version number (for example `16`) into **Version**.

---

### **Authentication → Host**

The DNS name or IP address your applications use to reach the database. For a Kubernetes-hosted DB this is usually the service's cluster-internal DNS:

```bash
kubectl get svc orders-prod -n databases \
  -o jsonpath='{.metadata.name}.{.metadata.namespace}.svc.cluster.local'
```

Paste it into **Host**.

### **Authentication → Port**

PostgreSQL listens on `5432` by default. Confirm against your config if you've changed it:

```bash
psql -h <host> -U <user> -d postgres -c 'SHOW port;'
```

Paste it into **Port**.

### **Authentication → Database**

The database you want consumers to default to. List all of them:

```bash
psql -h <host> -U <user> -d postgres -c '\l'
```

Paste your chosen database name into **Database**.

### **Authentication → Username**

The role applications will authenticate as. For production prefer a dedicated app role over `postgres`:

```bash
psql -h <host> -U postgres -d postgres -c '\du'
```

Paste the username into **Username**.

### **Authentication → Password**

Take the password from your secret store. If you don't have one yet, generate and set one now:

```bash
NEW_PW=$(openssl rand -base64 32)
psql -h <host> -U postgres -d postgres -c "ALTER USER <username> WITH PASSWORD '$NEW_PW';"
echo "$NEW_PW"   # paste this into Massdriver, then clear your scrollback
```

Paste the password into **Password**. The field is masked everywhere in the UI and audit-logged on download.

---

### **High Availability** *(optional)*

Set **High Availability** to `true` if you're running Patroni, repmgr, Citus, CloudNativePG with replicas, or any other replicated topology. Leave it false for a single-instance server.

---

### **Policies**

Pick the database roles consumers can request. The IDs should match real PostgreSQL roles your IaC creates / GRANTs against. A common starter set:

```sql
CREATE ROLE app_read   ;  -- map ID: read-only , Name: "Read"
CREATE ROLE app_write  ;  -- map ID: read-write, Name: "Write"
CREATE ROLE app_admin  ;  -- map ID: admin     , Name: "Admin"
```

Then list them under **Access Policies** with matching `id` and `name` values.
