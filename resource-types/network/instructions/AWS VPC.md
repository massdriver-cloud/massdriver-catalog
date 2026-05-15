# Register an existing AWS VPC as a Network resource

Use this form to bring an already-provisioned AWS VPC into Massdriver so other bundles in the environment can connect to it without re-provisioning.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured for the account hosting the VPC.

---

### **ID**

Find your VPC's ID:

```bash
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`]|[0].Value,CidrBlock]' --output table
```

Paste the `vpc-xxxxxxxx` string into the **ID** field.

---

### **CIDR**

The IPv4 CIDR block is shown in the same command above (third column). You can also fetch just the CIDR for a specific VPC:

```bash
aws ec2 describe-vpcs --vpc-ids vpc-xxxxxxxx --query 'Vpcs[0].CidrBlock' --output text
```

Paste it (for example `10.0.0.0/16`) into the **CIDR** field.

---

### **Region** *(optional)*

Use the region the VPC was created in — the same `AWS_REGION` you pointed the CLI at:

```bash
aws configure get region
```

Paste it (for example `us-east-1`) into the **Region** field.

---

### **Subnets**

List all subnets in the VPC and capture each one's ID, CIDR, and AZ:

```bash
aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=vpc-xxxxxxxx \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table
```

For each row, click **Add Subnet** and fill in:

- **ID** → `SubnetId` (e.g. `subnet-0a1b2c3d4e5f6g7h`)
- **CIDR** → `CidrBlock` (e.g. `10.0.1.0/24`)
- **Availability Zone** → `AvailabilityZone` (e.g. `us-east-1a`)
- **Type** → `public` if `MapPublicIpOnLaunch` is `True`, otherwise `private`

> A subnet is "public" if it has a route to an Internet Gateway. `MapPublicIpOnLaunch=True` is a strong hint; for the authoritative answer check the subnet's route table for a `0.0.0.0/0 → igw-...` rule.
