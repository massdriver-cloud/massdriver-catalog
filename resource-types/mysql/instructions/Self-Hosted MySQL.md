# Register a self-hosted MySQL instance

Use this form to register a MySQL server you run yourself — on a VM, in Kubernetes, or via a Galera/Percona cluster — so other Massdriver bundles can connect to it.

You will need shell access to the database host (or a `mysql` client that can reach it).

---

### **ID**

Pick a stable identifier — usually the hostname or operator-resource name:

```bash
# VM-hosted server
hostname -f

# Kubernetes (Percona operator example)
kubectl get pxc orders-prod -n databases -o jsonpath='{.metadata.uid}'
```

Paste your chosen identifier into the **ID** field.

---

### **Version**

```bash
mysql -h <host> -u <user> -p<password> -e 'SELECT VERSION();'
```

Paste the **major.minor** version (for example `8.0`) into **Version**.

---

### **Authentication → Host**

The DNS name or IP applications use to reach the database. For a Kubernetes-hosted DB this is typically the service's cluster-internal DNS:

```bash
kubectl get svc orders-prod -n databases \
  -o jsonpath='{.metadata.name}.{.metadata.namespace}.svc.cluster.local'
```

Paste it into **Host**.

### **Authentication → Port**

MySQL listens on `3306` by default. Confirm with:

```bash
mysql -h <host> -u <user> -p<password> -e "SHOW VARIABLES LIKE 'port';"
```

Paste it into **Port**.

### **Authentication → Database**

List databases on the server:

```bash
mysql -h <host> -u <user> -p<password> -e 'SHOW DATABASES;'
```

Paste your chosen database name into **Database**.

### **Authentication → Username**

The user applications will authenticate as. For production prefer a dedicated app user over `root`:

```bash
mysql -h <host> -u root -p<password> \
  -e "SELECT User, Host FROM mysql.user WHERE User != 'mysql.sys';"
```

Paste the username into **Username**.

### **Authentication → Password**

Take the password from your secret store. If you need to set or rotate one now:

```bash
NEW_PW=$(openssl rand -base64 32)
mysql -h <host> -u root -p<old> \
  -e "ALTER USER '<username>'@'%' IDENTIFIED BY '$NEW_PW'; FLUSH PRIVILEGES;"
echo "$NEW_PW"   # paste this into Massdriver, then clear your scrollback
```

Paste the password into **Password**. The field is masked in the UI and audit-logged on download.

---

### **Character Set** *(optional)*

```bash
mysql -h <host> -u <user> -p<password> \
  -e "SHOW VARIABLES LIKE 'character_set_server';"
```

Paste the value (almost always `utf8mb4`) into **Character Set**.

---

### **High Availability** *(optional)*

Set **High Availability** to `true` if you're running Galera, Percona XtraDB Cluster, MySQL Group Replication, or any active-active/active-passive replicated topology. Leave it false for a single-instance server.

---

### **Policies**

Match these to the GRANTs your IaC actually issues. A common starter set:

```sql
CREATE USER 'app_read'@'%' IDENTIFIED BY '...';
GRANT SELECT ON <db>.* TO 'app_read'@'%';                    -- ID: read-only,  Name: "Read"

CREATE USER 'app_write'@'%' IDENTIFIED BY '...';
GRANT SELECT,INSERT,UPDATE,DELETE ON <db>.* TO 'app_write'@'%';  -- ID: read-write, Name: "Write"

CREATE USER 'app_admin'@'%' IDENTIFIED BY '...';
GRANT ALL ON <db>.* TO 'app_admin'@'%';                          -- ID: admin,      Name: "Admin"
```
