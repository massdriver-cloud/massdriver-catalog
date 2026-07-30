# Importing an existing AWS VPC

Use this when you already have a VPC in the AWS console and want Massdriver to know about it, instead of provisioning a new one with the `aws-vpc` bundle.

## Where to find each field

1. Open the **VPC console** → **Your VPCs**, click your VPC.
   - `vpc_id`: the "VPC ID" field (`vpc-...`).
   - `cidr`: the "IPv4 CIDR" field.
   - `region`: the region shown in the top-right of the console.
2. Click **Subnets** in the left nav, filter by this VPC.
   - For each subnet, copy the "Subnet ID" (`subnet-...`), "IPv4 CIDR", and "Availability Zone".
   - A subnet is `public` if its route table has a route to an Internet Gateway (`igw-...`); otherwise it's `private`.
3. Click **NAT Gateways** in the left nav.
   - `nat_gateway_id`: the "NAT gateway ID" (`nat-...`) of your shared gateway.
4. Click **Endpoints** in the left nav.
   - `s3_vpc_endpoint_id`: the endpoint whose service name ends in `.s3`.
   - `ecr_vpc_endpoint_ids`: the two endpoints whose service names end in `.ecr.api` and `.ecr.dkr`.

## Notes

- Everything downstream (the cluster, data services) expects one shared NAT gateway per network — don't import a VPC with per-AZ NAT gateways without adjusting consuming bundles' cost expectations.
