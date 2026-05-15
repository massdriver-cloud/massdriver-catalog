# Register an existing Azure Blob Storage container

Use this form to bring an existing Azure Storage **container** into Massdriver so other bundles can read/write to it.

You will need the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli):

```bash
az login
az account set --subscription "<your-subscription-id>"
```

In Azure, what S3 calls a "bucket" is a **container** inside a **storage account**. You'll need both names below.

---

### **ID**

Use the container's full ARM resource ID:

```bash
az storage account show \
  --resource-group <rg> --name <storage-account> \
  --query id -o tsv
# then append /blobServices/default/containers/<container-name>
```

Paste the full ID into **ID**:

```
/subscriptions/.../resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>/blobServices/default/containers/<container-name>
```

---

### **Name**

The container name within the storage account:

```bash
az storage container list \
  --account-name <storage-account> \
  --query '[].name' -o tsv
```

Paste your chosen container name (3–63 lowercase chars / digits / hyphens) into **Name**.

---

### **Endpoint** *(optional)*

The blob endpoint URL for this container:

```bash
PRIMARY=$(az storage account show \
  --resource-group <rg> --name <storage-account> \
  --query primaryEndpoints.blob -o tsv)
echo "${PRIMARY}<container-name>"
```

Paste the result (for example `https://acmestorage.blob.core.windows.net/orders-prod`) into **Endpoint**.

---

### **Region** *(optional)*

```bash
az storage account show \
  --resource-group <rg> --name <storage-account> \
  --query location -o tsv
```

Paste the location (for example `eastus2`) into **Region**.

---

### **Policies**

Edit the policy list to match the role assignments your IaC creates. A common starter set:

- `read-only` / "Read" — `Storage Blob Data Reader`
- `read-write` / "Write" — `Storage Blob Data Contributor`
- `admin` / "Admin" — `Storage Blob Data Owner`

The **ID** is what your IaC's role-bindings key off; **Name** is what shows in dropdowns for consumers.
