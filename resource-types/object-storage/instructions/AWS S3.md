# Register an existing AWS S3 bucket

Use this form to bring an existing S3 bucket into Massdriver so other bundles can read/write to it.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured for the account that owns the bucket.

---

### **ID**

Use the bucket ARN — it's globally unique and stable:

```bash
aws s3api get-bucket-location --bucket <bucket-name>   # confirms the bucket exists
echo "arn:aws:s3:::<bucket-name>"
```

Paste `arn:aws:s3:::<bucket-name>` into the **ID** field.

---

### **Name**

The S3 bucket name itself:

```bash
aws s3api list-buckets --query 'Buckets[].Name' --output table
```

Paste the bucket name (for example `acme-orders-prod`) into **Name**.

---

### **Endpoint** *(optional)*

Use the virtual-hosted-style URL for the region:

```bash
REGION=$(aws s3api get-bucket-location --bucket <bucket-name> --query LocationConstraint --output text)
# us-east-1 returns "None" — treat that as us-east-1
[ "$REGION" = "None" ] && REGION=us-east-1
echo "https://<bucket-name>.s3.${REGION}.amazonaws.com"
```

Paste the URL into **Endpoint**.

---

### **Region** *(optional)*

Use the `REGION` value from the same command above. Paste it (for example `us-east-1`) into **Region**.

---

### **Policies**

Edit the policy list to match the IAM policies your platform team binds for bucket consumers. A common starter set:

- `read-only` / "Read" — `s3:GetObject`, `s3:ListBucket`
- `read-write` / "Write" — adds `s3:PutObject`, `s3:DeleteObject`
- `admin` / "Admin" — full `s3:*` on the bucket and its objects

The **ID** is what your IaC's role-bindings key off; **Name** is what shows in dropdowns. If you bind policies via IAM role assumption rather than inline policy attachment, document the role-ARN convention in your platform onboarding so consuming bundles know which role to assume per policy name.
