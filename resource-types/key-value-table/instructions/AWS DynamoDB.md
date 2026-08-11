# Register an existing AWS DynamoDB table

Use this form to bring a DynamoDB table you already have into Massdriver, so other bundles can read and write to it.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured for the account that owns the table.

If you do not know the table's name, list what is in the account first:

```bash
aws dynamodb list-tables --output table
```

---

### **Table Name**

The name of the table, exactly as DynamoDB has it:

```bash
aws dynamodb describe-table --table-name <table-name> --query 'Table.TableName' --output text
```

Paste the name (for example `orders`) into **Table Name**.

---

### **Table ARN**

The ARN is the unique identifier for the table across all of AWS:

```bash
aws dynamodb describe-table --table-name <table-name> --query 'Table.TableArn' --output text
```

Paste the value (it looks like `arn:aws:dynamodb:us-east-1:123456789012:table/orders`) into **Table ARN**.

---

### **Region** *(optional)*

The region is the fourth field of the ARN above, but you can also read it from your CLI configuration:

```bash
aws configure get region
```

Paste it (for example `us-east-1`) into **Region**.

---

### **Partition Key**

Every item in the table is stored and looked up by this attribute. DynamoDB calls it the `HASH` key:

```bash
aws dynamodb describe-table --table-name <table-name> \
  --query 'Table.KeySchema[?KeyType==`HASH`].AttributeName' --output text
```

Paste the attribute name (for example `pk` or `customer_id`) into **Partition Key**.

---

### **Sort Key** *(optional)*

Some tables have a second key that orders the items sharing one partition key. DynamoDB calls it the `RANGE` key:

```bash
aws dynamodb describe-table --table-name <table-name> \
  --query 'Table.KeySchema[?KeyType==`RANGE`].AttributeName' --output text
```

If the command prints nothing, the table has no sort key — leave **Sort Key** empty. Otherwise paste the attribute name (for example `sk` or `created_at`).

---

### **Policies**

List the IAM policies your platform team binds for consumers of this table. A common starter set:

- `read` — `dynamodb:GetItem`, `BatchGetItem`, `Query`, `Scan`, `DescribeTable`
- `write` — adds `PutItem`, `UpdateItem`, `DeleteItem`, `BatchWriteItem`
- `admin` — full `dynamodb:*` on the table and its indexes

If those policies already exist in the account, get their ARNs:

```bash
aws iam list-policies --scope Local --query 'Policies[].[PolicyName,Arn]' --output table
```

The **ID** is what your IaC's role bindings key off — usually the policy ARN. **Name** is what shows up in the dropdown of a bundle that connects to this table. If your platform grants access by assuming a role instead of attaching a policy, put the role ARN in **ID** and document the convention in your platform onboarding so consuming bundles know which role to assume per policy name.

One thing to check before you finish: if the table is encrypted with a customer-managed KMS key, each of those policies also needs `kms:Decrypt` (and `kms:Encrypt` plus `kms:GenerateDataKey` for writers) on that key, or callers will get `AccessDenied` even with the right DynamoDB permissions:

```bash
aws dynamodb describe-table --table-name <table-name> \
  --query 'Table.SSEDescription.KMSMasterKeyArn' --output text
```
