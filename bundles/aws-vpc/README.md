# AWS Network

This bundle creates the network that everything else in the migration lives inside: a private, walled-off piece of AWS with some parts open to the internet and some parts closed off.

## What you get

- A network split into **public** subnets (things the internet can reach, like a load balancer) and **private** subnets (things the internet can't reach directly, like your cluster's worker nodes and your databases).
- One shared **NAT gateway** so anything in a private subnet can still reach the internet to, say, download a package or call an external API — without being reachable from the internet itself. It's shared across every private subnet to keep the bill down.
- Direct, private paths to **S3** (your object storage) and **ECR** (your container image registry) so that traffic never has to loop out through the NAT gateway. This is both cheaper and faster — pulling a container image or reading a file from a bucket doesn't pay the NAT gateway's per-GB fee or its bandwidth ceiling.
- An optional **flow logs** feature that records a summary of network traffic for security review. Turn it on for anything customer-facing.

## Who uses this

Every other bundle in this catalog — the Kubernetes cluster, the database, the cache, the queues, and the storage bucket — connects to this network. Build this one first.

## Things you can't change later

The network's address range (`cidr`) and how many availability zones it spans (`az_count`) are locked in once deployed. Changing either means standing up a new network and migrating everything that depends on it, so pick generously up front (a `/16` gives you plenty of room to grow).

## Customize it

1. Edit `massdriver.yaml` if you need a different address range or more/fewer availability zones than the 2-or-3 choice offered here.
2. `src/main.tf` is real Terraform/OpenTofu (not a placeholder) — it provisions an actual VPC, subnets, NAT gateway, route tables, and the S3/ECR endpoints.
3. Update `operator.md` with anything your team specifically watches for (this one ships with NAT exhaustion and endpoint troubleshooting already).

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
