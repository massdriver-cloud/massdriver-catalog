# gcp-vertex-workbench

Vertex AI Workbench instance for interactive data science. Each bundle instance provisions a dedicated per-instance service account and a managed JupyterLab environment running on GCE. When a BigQuery dataset is connected, the instance SA is automatically granted read-only access — no manual IAM wiring required.

## Use Cases

- **Exploratory data analysis** — interactive notebooks with access to BigQuery datasets and GCS buckets via scoped IAM.
- **ML model development** — GPU-accelerated notebook environments for training and evaluation, with the ability to consume Pub/Sub topics or write results to BigQuery via separate pipeline services.
- **Platform-managed data science environments** — org-wide Workbench standard enforcing Shielded VM, no public IP, per-instance identity, and idle shutdown — so each team gets a consistent, auditable environment without manual GCP console work.

## Resources Created

| Resource | Description |
|---|---|
| `google_service_account.instance` | Per-instance SA — this bundle's own workload identity |
| `google_workbench_instance.main` | The Vertex AI Workbench instance (Workbench Instances API v2) |
| `google_bigquery_dataset_iam_member.dataset_viewer` | Created only when BigQuery dataset is connected — grants `roles/bigquery.dataViewer` (read-only) to instance SA |

## Connections

### Required

| Connection | Artifact Type | Purpose |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | GCP credentials used by Terraform to provision resources |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id`, `network.region`, and subnet self-link for instance placement |

### Optional

| Connection | Artifact Type | IAM Role Granted |
|---|---|---|
| `bigquery_dataset` | `catalog-demo/gcp-bigquery-dataset` | `roles/bigquery.dataViewer` (read-only) on the dataset |

When the BigQuery dataset is connected, the instance SA can run SELECT queries from notebooks without manual IAM changes. Disconnect the canvas wire and redeploy to revoke access.

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-vertex-workbench`

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project that owns the instance |
| `instance_name` | string | Short instance name (used in gcloud commands) |
| `location` | string | GCP zone where the instance is deployed (e.g., `us-central1-a`) |
| `proxy_url` | string | JupyterLab HTTPS proxy URL — open this in a browser to access the notebook. May be empty while the instance is starting. |
| `instance_service_account_email` | string | Email of this instance's own SA |
| `instance_service_account_member` | string | IAM principal string (`serviceAccount:<email>`) for downstream bindings |

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `machine_type` | enum | `e2-standard-4` | GCP machine type. E2 for general-purpose, N1 required for GPUs. |
| `boot_disk_size_gb` | integer | `150` | Boot disk size in GB (150–4000). Minimum 150 GB enforced by the Workbench base image. Holds OS, packages, and local notebook files. |
| `idle_shutdown_timeout_minutes` | integer | `180` | Minutes of kernel inactivity before auto-shutdown. 0 = never (continuous billing). |
| `accelerator_type` | enum | _(none)_ | GPU type. Requires N1 machine type. Leave empty for CPU-only. |
| `accelerator_count` | integer | `1` | Number of GPU accelerators. Only used when `accelerator_type` is set. |

## Presets

| Preset | Machine Type | Disk | GPU | Idle Timeout |
|---|---|---|---|---|
| Small | `e2-standard-4` | 150 GB | none | 3 hours |
| Medium | `n1-standard-8` | 200 GB | none | 3 hours |
| GPU | `n1-standard-8` | 200 GB | NVIDIA_TESLA_T4 × 1 | 3 hours |

## Compliance

### Hardcoded Controls

| Control | Value | Rationale |
|---|---|---|
| Shielded VM — Secure Boot | `enable_secure_boot = true` | Prevents unsigned kernel modules and boot-time malware from loading. Cannot be disabled without recreating the instance. |
| Shielded VM — vTPM | `enable_vtpm = true` | Enables measured boot and key attestation. Required for integrity monitoring. |
| Shielded VM — Integrity Monitoring | `enable_integrity_monitoring = true` | Detects tampering with the boot sequence by comparing against a known-good baseline. |
| No public IP | `disable_public_ip = true` | The Workbench proxy handles browser access. No external IP is exposed. JupyterLab traffic does not traverse the public internet. |
| Per-instance service account | `google_service_account.instance` (one per bundle instance) | Each instance gets its own SA — no shared SA that grants access across all Workbench notebooks. See iam.tf for design rationale. |
| Read-only BigQuery access | `roles/bigquery.dataViewer` (not dataEditor) | Workbench is an exploration environment. Write access would allow ad-hoc schema mutations from notebook cells. Users who need to write back should use their personal GCP identity. |
| Resource labels | Massdriver default tags | Enforces cost attribution and environment tagging. |

### Skipped Checks

None. As of checkov 3.2.x, all existing Vertex AI Workbench checks (CKV_GCP_89, CKV_GCP_126, CKV_GCP_127) target the deprecated `google_notebooks_instance` resource and do not fire against `google_workbench_instance`. CMEK for disk encryption is intentionally out of scope for this bundle — Google-managed encryption is used. If CMEK is required, a separate bundle with a KMS key connection should be used.

## Assumptions

- The landing zone provides `project_id`, `network.region`, and `primary_subnet.self_link`. The Workbench instance is placed in the primary subnet of the landing zone's region, zone `-a`.
- The landing zone's subnet must have Private Google Access enabled for the instance to reach GCP APIs (BigQuery, GCS) without a public IP. The `gcp-landing-zone` bundle enables this by default.
- Idle shutdown is implemented via the `idle-timeout-seconds` GCE metadata key, which the Workbench agent reads at startup. If the instance is restarted externally (e.g., via gcloud), the idle timer resets.
- GPU availability is zone-dependent. If a GPU type is not available in `<region>-a`, change `local.zone` in `src/main.tf` to a zone with quota.
- The `proxy_url` artifact field may be empty immediately after deploy while the instance boots. It populates within 2–5 minutes after the instance reaches ACTIVE state.
