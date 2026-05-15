# Register an existing Azure VNet as a Network resource

Use this form to bring an already-provisioned Azure Virtual Network into Massdriver so other bundles in the environment can attach to it.

You will need the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) signed in to the subscription that owns the VNet:

```bash
az login
az account set --subscription "<your-subscription-id>"
```

---

### **ID**

Find your VNet's resource ID:

```bash
az network vnet list -o table
az network vnet show \
  --resource-group <your-rg> \
  --name <your-vnet> \
  --query id -o tsv
```

Paste the full ARM ID (starts with `/subscriptions/...`) into the **ID** field.

---

### **CIDR**

Read the address space from the same VNet:

```bash
az network vnet show \
  --resource-group <your-rg> \
  --name <your-vnet> \
  --query 'addressSpace.addressPrefixes[0]' -o tsv
```

Paste the result (for example `10.0.0.0/16`) into the **CIDR** field.

---

### **Region** *(optional)*

```bash
az network vnet show \
  --resource-group <your-rg> \
  --name <your-vnet> \
  --query location -o tsv
```

Paste the location (for example `eastus2`) into the **Region** field.

---

### **Subnets**

List every subnet in the VNet:

```bash
az network vnet subnet list \
  --resource-group <your-rg> \
  --vnet-name <your-vnet> \
  --query '[].{id:id, name:name, cidr:addressPrefix}' \
  -o table
```

For each row, click **Add Subnet** and fill in:

- **ID** → the full ARM `id` (or the short name — pick one convention and stick with it across all your environments)
- **CIDR** → `cidr`
- **Type** → `public` if the subnet has an Internet route via a public load balancer or NAT gateway; otherwise `private`. The default is `private`.
- **Availability Zone** → Azure subnets aren't bound to a single AZ; leave blank, or set it to match the AZ your downstream resources will live in if you're modeling that explicitly.

---

> Tip: if you maintain VNets via Terraform, get the same values from `terraform show -json` and pluck them out with `jq` — no Azure CLI needed.
