# Register an existing GCP Cloud Storage bucket

Use this form to bring an existing Cloud Storage bucket into Massdriver so other bundles can read/write to it.

You will need the [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated against the project that owns the bucket:

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

---

### **ID**

Use the bucket's `gs://` URI — it's project-scoped and stable:

```bash
gcloud storage buckets list
```

Paste `gs://<bucket-name>` into the **ID** field.

---

### **Name**

Cloud Storage bucket names are globally unique. List yours:

```bash
gcloud storage buckets list --format='value(name)'
```

Paste the bucket name (for example `acme-orders-prod`) into **Name**.

---

### **Endpoint** *(optional)*

Cloud Storage exposes buckets at a predictable URL:

```
https://storage.googleapis.com/<bucket-name>
```

Paste that into **Endpoint**.

---

### **Region** *(optional)*

```bash
gcloud storage buckets describe gs://<bucket-name> \
  --format='value(location)'
```

Paste the location (for example `US-CENTRAL1` or `US` for multi-region) into **Region**.

---

### **Policies**

Edit the policy list to match the IAM bindings your IaC creates. A common starter set on Cloud Storage:

- `read-only` / "Read" — `roles/storage.objectViewer`
- `read-write` / "Write" — `roles/storage.objectUser`
- `admin` / "Admin" — `roles/storage.admin`

The **ID** is what your IaC's role-bindings key off; **Name** is what shows in dropdowns for consumers.
