# Register an existing AWS RDS PostgreSQL instance

Use this form to bring an already-running RDS PostgreSQL instance into Massdriver so other bundles can connect to it.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured for the account that owns the database, plus the master password (Massdriver does not read it from AWS — Secrets Manager hides it from the CLI).

---

### **ID**

Use the DB instance identifier:

```bash
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,Engine,EngineVersion]' \
  --output table
```

Paste the `DBInstanceIdentifier` (for example `prod-orders-db`) into the **ID** field.

---

### **Version**

Use the `EngineVersion` major number from the table above. RDS reports it as `16.2` — pass the **major** version only:

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].EngineVersion' \
  --output text | cut -d. -f1
```

Paste the result (for example `16`) into the **Version** field.

---

### **Authentication → Host**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

Paste the endpoint (for example `prod-orders-db.cxyz.us-east-1.rds.amazonaws.com`) into **Host**.

### **Authentication → Port**

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].Endpoint.Port' \
  --output text
```

Paste it (typically `5432`) into **Port**.

### **Authentication → Database**

The default database name was set at create-time. Look it up:

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

Paste the master username (typically `postgres`) into **Username**.

### **Authentication → Password**

If the password is stored in AWS Secrets Manager (the modern RDS default), fetch it:

```bash
aws secretsmanager get-secret-value \
  --secret-id <secret-arn-from-rds-output> \
  --query 'SecretString' --output text \
  | jq -r '.password'
```

If you set the password manually at create-time, supply it from your password manager.

Paste it into **Password**. The field is masked everywhere in the UI and audit-logged on download.

---

### **High Availability** *(optional)*

```bash
aws rds describe-db-instances \
  --db-instance-identifier <id> \
  --query 'DBInstances[0].MultiAZ' \
  --output text
```

Set **High Availability** to `true` if `MultiAZ` is `True`.

---

### **Policies**

This list tells consuming bundles which application roles your team supports for this database. A sensible default if you don't have a stronger convention yet:

- `read-only` / "Read"
- `read-write` / "Write"
- `admin` / "Admin"

Each entry's **ID** is what your IaC's role-bindings will key off; **Name** is what shows in dropdowns. Edit these to match the GRANTs you actually issue.
