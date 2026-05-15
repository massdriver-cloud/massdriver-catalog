# Register an existing Azure Database for MySQL instance

Use this form to bring an Azure Database for MySQL Flexible Server (or Single Server) into Massdriver so other bundles can connect to it.

You will need the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli):

```bash
az login
az account set --subscription "<your-subscription-id>"
```

---

### **ID**

```bash
az mysql flexible-server list --query '[].{name:name, resourceGroup:resourceGroup, version:version}' -o table
```

Use the server `name` (for example `orders-prod`) as your **ID**, or the full ARM ID if you need disambiguation:

```bash
az mysql flexible-server show \
  --resource-group <rg> --name <name> --query id -o tsv
```

Paste it into the **ID** field.

---

### **Version**

```bash
az mysql flexible-server show \
  --resource-group <rg> --name <name> --query version -o tsv
```

Paste the version (for example `8.0`) into **Version**.

---

### **Authentication → Host**

```bash
az mysql flexible-server show \
  --resource-group <rg> --name <name> --query fullyQualifiedDomainName -o tsv
```

Paste the FQDN (for example `orders-prod.mysql.database.azure.com`) into **Host**.

### **Authentication → Port**

`3306` for Flexible Server. Paste it into **Port**.

### **Authentication → Database**

List databases on the server:

```bash
az mysql flexible-server db list \
  --resource-group <rg> --server-name <name> -o table
```

Paste the database name you want consumers to default to into **Database**.

### **Authentication → Username**

```bash
az mysql flexible-server show \
  --resource-group <rg> --name <name> --query administratorLogin -o tsv
```

Paste the admin login into **Username**. For production prefer creating a least-privilege user and using that instead.

### **Authentication → Password**

Azure does **not** expose the password via the API after creation. Pull it from your secret store (Azure Key Vault, password manager) and paste it into **Password**:

```bash
az keyvault secret show \
  --vault-name <kv> --name <secret> --query value -o tsv
```

The field is masked in the UI and audit-logged on download.

---

### **Character Set** *(optional)*

```bash
mysql -h <fqdn> -u <user> -p<password> --ssl-mode=REQUIRED \
  -e "SHOW VARIABLES LIKE 'character_set_server';"
```

Paste the value into **Character Set** (typically `utf8mb4`).

---

### **High Availability** *(optional)*

```bash
az mysql flexible-server show \
  --resource-group <rg> --name <name> --query 'highAvailability.mode' -o tsv
```

Set **High Availability** to `true` when the mode is `ZoneRedundant` or `SameZone`.

---

### **Policies**

Edit the policy list to match the GRANTs your IaC actually issues. A common starter set:

- `read-only` / "Read"
- `read-write` / "Write"
- `admin` / "Admin"
