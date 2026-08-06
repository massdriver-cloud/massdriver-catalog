# gcp-network

Minimal GCP VPC network with a single regional subnet. Deploy this before `gcp-landing-zone` — the landing zone consumes the `gcp-network` artifact and passes it downstream so other bundles only need one connection.

## Use Cases

- Foundational networking for a GCP data platform stack
- Single regional subnet with Private Google Access so VMs reach GCP APIs without a NAT gateway
- Baseline deny-all ingress policy; workload bundles layer their own allow rules on top

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_compute_network.vpc` | VPC network | Custom subnet mode; GCP does not auto-create subnets in other regions |
| `google_compute_subnetwork.primary` | Regional subnet | Flow logging on (0.5 sampling), Private Google Access on |
| `google_compute_firewall.deny_all_ingress` | Firewall rule | Deny all ingress at priority 65534 |

## Connections

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |

## Artifact Produced

**Artifact type:** `gcp-network`

| Field | Description |
|---|---|
| `project_id` | GCP project the VPC belongs to |
| `network_name` | Name of the VPC network resource |
| `network_self_link` | Full self-link URI for the VPC |
| `region` | Region of the primary subnet |
| `primary_subnet.name` | Subnet resource name |
| `primary_subnet.cidr` | Primary IP range of the subnet |
| `primary_subnet.self_link` | Full self-link URI for the subnet |

This artifact is consumed by `gcp-landing-zone`, which passes it through into its own artifact so downstream bundles (Cloud Run, Vertex Workbench) only need to connect to the landing zone.

## Compliance

### Hardcoded security controls

| Control | Mechanism | Reason |
|---|---|---|
| Deny-all ingress | `google_compute_firewall.deny_all_ingress` at priority 65534 | Enforces explicit allowlisting per workload (Checkov CKV2_GCP_18) |
| Custom subnet mode | `auto_create_subnetworks = false` | Prevents GCP from auto-creating subnets in every region |
| Private Google Access | `private_ip_google_access = true` | VMs reach GCP APIs over internal IPs without egress or NAT |
| Flow logging | `log_config` block, 0.5 sampling | Network audit trail for traffic troubleshooting |

No Checkov skips — all findings are satisfied by the hardcoded controls above or blocked in production via `halt_on_failure`.

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with remaining high-severity findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- The GCP project already exists — this bundle does not create projects.
- The `gcp_authentication` credential has `compute.admin` or equivalent IAM to create VPC resources and firewall rules.

## Presets

| Preset | Region | Network Name | Subnet CIDR |
|---|---|---|---|
| Standard | `us-central1` | `data-platform-vpc` | `10.0.0.0/20` |
