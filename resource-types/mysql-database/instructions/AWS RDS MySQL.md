# Register an existing AWS RDS MySQL instance

Use this form to bring an already-running RDS for MySQL instance into Massdriver so other bundles can connect to it.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured for the account that owns the database.

---

### **ID**

```bash
aws rds describe-db-instances \
  --query 'DBInstances[?Engine==`mysql`].[DBInstanceIdentifier,EngineVersion]' \
  --output table
```

Paste the `DBInstanceIdentifier` into the **ID** field.

---

### **Version**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].EngineVersion' \
  --output text | awk -F. '{print $1"."$2}'
```

Paste the major.minor (for example `8.0`) into **Version**.

---

### **Authentication → Host**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

Paste the endpoint into **Host**.

### **Authentication → Port**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text
```

Paste it (typically `3306`) into **Port**.

### **Authentication → Database**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].DBName' \
  --output text
```

Paste it into **Database**.

### **Authentication → Username**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].MasterUsername' \
  --output text
```

Paste the master username (typically `admin`) into **Username**.

### **Authentication → Password**

If managed by Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id <secret-arn-from-rds-output> \
  --query 'SecretString' --output text \
  | jq -r '.password'
```

Otherwise pull it from your password manager. Paste into **Password** — the field is masked in the UI and audit-logged on download.

---

### **Character Set** *(optional)*

```bash
mysql -h <host> -u <user> -p<password> \
  -e "SHOW VARIABLES LIKE 'character_set_server';"
```

Paste the value (almost always `utf8mb4`) into **Character Set**.

---

### **High Availability** *(optional)*

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].MultiAZ' \
  --output text
```

Set **High Availability** to `true` if this prints `True`.

---

### **Policies**

Edit the policy list to match the GRANTs your IaC actually issues. A common starter set:

- `read-only` / "Read"
- `read-write` / "Write"
- `admin` / "Admin"
