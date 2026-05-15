# Register an existing GCP VPC as a Network resource

Use this form to bring a Google Cloud VPC network into Massdriver so other bundles in the environment can attach to it.

You will need the [gcloud CLI](https://cloud.google.com/sdk/docs/install) authenticated against the project that owns the network:

```bash
gcloud auth login
gcloud config set project <your-project-id>
```

---

### **ID**

List your VPC networks:

```bash
gcloud compute networks list
```

GCP VPCs are project-scoped, so the "ID" Massdriver wants is the fully-qualified self-link or the project-qualified short name. Pick a self-link for unambiguous referencing:

```bash
gcloud compute networks describe <network-name> --format='value(selfLink)'
```

Paste the URL (for example `https://www.googleapis.com/compute/v1/projects/my-proj/global/networks/my-vpc`) into the **ID** field.

---

### **CIDR**

GCP VPCs in **auto-mode** assign subnets per region automatically and don't carry a single network-wide CIDR. **Custom-mode** VPCs declare subnet CIDRs explicitly.

For custom-mode networks, treat the **CIDR** field as the supernet you reserved for this VPC (the IP plan documented for this network, not anything you can read off the API). Common examples: `10.0.0.0/8`, `10.10.0.0/16`.

Paste your reserved supernet into the **CIDR** field.

---

### **Region** *(optional)*

GCP VPCs are global, not regional. Leave **Region** blank, or set it to the region most of your downstream workloads will live in if it makes the resource easier to identify in the UI.

---

### **Subnets**

List the network's subnets across all regions:

```bash
gcloud compute networks subnets list \
  --filter="network:<network-name>" \
  --format='table(name,region,ipCidrRange,privateIpGoogleAccess)'
```

For each row, click **Add Subnet** and fill in:

- **ID** → the subnet's self-link (preferred) or the `region/name` pair:

  ```bash
  gcloud compute networks subnets describe <subnet-name> \
    --region <region> --format='value(selfLink)'
  ```

- **CIDR** → `ipCidrRange`
- **Availability Zone** → the **region**. GCP subnets are regional, not zonal, so use the region here.
- **Type** → `public` if the subnet has an instance with an external IP or sits behind a Cloud NAT advertising public routes; otherwise `private`. In most projects this is `private`.
