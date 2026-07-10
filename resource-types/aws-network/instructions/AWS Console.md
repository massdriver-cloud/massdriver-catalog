# Register an existing AWS VPC

Use this form to register a VPC that was created outside Massdriver so bundles can attach to it.

1. Open the [VPC console](https://console.aws.amazon.com/vpc/) and select your region.
2. Go to **Your VPCs** and click the VPC you want to register.

## VPC ID

Copy the **VPC ID** from the details panel (looks like `vpc-0a1b2c3d4e5f67890`).

## CIDR Block

Copy the **IPv4 CIDR** from the same panel (looks like `10.0.0.0/16`).

## Region

The region code from the console's region picker, like `us-east-1`.

## Default Security Group

Go to **Security groups**, filter by your VPC ID, and copy the ID of the group named `default` (looks like `sg-0a1b2c3d4e5f67890`).

## Subnets

Go to **Subnets** and filter by your VPC ID. Add one entry per subnet:

- **Subnet ID**: the `subnet-…` identifier.
- **Name**: the subnet's `Name` tag.
- **CIDR**: the subnet's **IPv4 CIDR**.
- **Tier**: `public` if the subnet's route table has a route to an internet gateway (`igw-…`), otherwise `private`. Check under the subnet's **Route table** tab.
- **Availability Zone**: shown in the subnet list, like `us-east-1a`.
