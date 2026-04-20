# gcp-network

Minimal GCP VPC network with a single regional subnet. This is the foundational networking bundle for the GCP data platform stack. Other bundles — including `gcp-landing-zone`, Cloud Run, and Vertex Workbench — consume the `gcp-network` artifact it produces.

## Purpose

Creates a production-ready VPC with sensible defaults:

- VPC created in custom (non-auto) mode so subnets are explicitly managed
- Flow logging enabled on the subnet for visibility into traffic
- Private Google Access enabled on the subnet so workloads reach Google APIs without a NAT gateway
- A deny-all ingress firewall rule at priority 65534 enforces explicit allowlisting — workload bundles add targeted allow rules on top

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_compute_network.vpc` | VPC network | Custom subnet mode, global |
| `google_compute_subnetwork.primary` | Regional subnet | Flow logging on, Private Google Access on |
| `google_compute_firewall.deny_all_ingress` | Firewall rule | Deny all ingress at priority 65534 |

## Artifacts Consumed (Connections)

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key used for the Google provider |

## Artifacts Produced

The bundle publishes a `gcp-network` artifact with the following fields:

| Field | Description |
|---|---|
| `project_id` | GCP project the VPC belongs to |
| `network_name` | Name of the VPC network resource |
| `network_self_link` | Full self-link URI for the VPC (used by resource references) |
| `region` | Region of the primary subnet |
| `primary_subnet.name` | Subnet resource name |
| `primary_subnet.cidr` | Primary IP range of the subnet |
| `primary_subnet.self_link` | Full self-link URI for the subnet |

Downstream bundles (e.g., `gcp-landing-zone`) pass this artifact through their own artifact, so further-downstream bundles only need one connection.

## Compliance

### Hardcoded security controls

| Control | Mechanism | Reason |
|---|---|---|
| Deny-all ingress | `google_compute_firewall.deny_all_ingress` at priority 65534 | Satisfies CKV2_GCP_18; forces explicit allowlisting per workload |
| Custom subnet mode | `auto_create_subnetworks = false` | Prevents GCP from auto-creating subnets in every region |
| Private Google Access | `private_ip_google_access = true` | Lets VMs reach Google APIs over internal IPs without egress |
| Flow logging | `log_config` block with 0.5 sampling | Network audit trail; enables traffic troubleshooting |

### Checkov posture

There is no `.checkov.yml` skip list for this bundle — all findings are either satisfied by the hardcoded controls above or blocked in production via `halt_on_failure`.

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with remaining high-severity findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- The GCP project already exists — this bundle does not create projects.
- The `gcp_authentication` credential has `compute.admin` or equivalent IAM to create VPC resources and firewall rules.

## Presets

| Preset | Region | Network Name | Subnet CIDR |
|---|---|---|---|
| Standard | `us-central1` | `data-platform-vpc` | `10.0.0.0/20` |
