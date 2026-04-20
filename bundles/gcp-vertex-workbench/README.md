# gcp-vertex-workbench

Vertex AI Workbench instance for interactive data science. Each bundle instance provisions a dedicated per-instance service account and a managed JupyterLab environment running on GCE. When a BigQuery dataset is connected, the instance SA is automatically granted read-only access — no manual IAM wiring required.

## Use Cases

- Exploratory data analysis with scoped, auditable IAM access to BigQuery datasets
- ML model development in GPU-accelerated notebook environments
- Platform-managed data science environments enforcing Shielded VM, no public IP, and per-instance identity

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_service_account.instance` | Per-instance SA | This instance's workload identity — one per bundle instance |
| `google_workbench_instance.main` | Vertex AI Workbench instance | Workbench Instances API v2 (`google_workbench_instance`) |
| `google_bigquery_dataset_iam_member.dataset_viewer` | BigQuery read-only IAM | Created only when BigQuery dataset is connected — grants `roles/bigquery.dataViewer` to instance SA |

## Connections

### Required

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | GCP credentials used by Terraform to provision resources |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id`, `network.region`, and subnet self-link for instance placement |

### Optional

| Connection | Artifact Type | IAM Role Granted |
|---|---|---|
| `bigquery_dataset` | `catalog-demo/gcp-bigquery-dataset` | `roles/bigquery.dataViewer` (read-only) on the dataset |

Connecting or disconnecting the BigQuery dataset on the canvas does not take effect until a Terraform apply runs.

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-vertex-workbench`

| Field | Type | Description |
|---|---|---|
| `project_id` | string | GCP project that owns the instance |
| `instance_name` | string | Short instance name (used in gcloud commands) |
| `location` | string | GCP zone where the instance is deployed (e.g., `us-central1-a`) |
| `proxy_url` | string | JupyterLab HTTPS proxy URL — open in a browser to access the notebook. Empty while the instance is starting. |
| `instance_service_account_email` | string | Email of this instance's own SA |
| `instance_service_account_member` | string | IAM principal string (`serviceAccount:<email>`) for downstream bindings |

## Compliance

### Hardcoded controls

| Control | Value | Reason |
|---|---|---|
| Shielded VM — Secure Boot | `enable_secure_boot = true` | Prevents unsigned kernel modules and boot-time malware from loading |
| Shielded VM — vTPM | `enable_vtpm = true` | Enables measured boot and key attestation |
| Shielded VM — Integrity Monitoring | `enable_integrity_monitoring = true` | Detects tampering with the boot sequence |
| No public IP | `disable_public_ip = true` | The Workbench proxy handles browser access; no external IP is exposed |
| Per-instance service account | `google_service_account.instance` (one per bundle instance) | Each instance gets its own SA — no shared SA across Workbench notebooks |
| Read-only BigQuery access | `roles/bigquery.dataViewer` (not dataEditor) | Workbench is an exploration environment. Write access would allow ad-hoc schema mutations from notebook cells. Users who need to write back should use their personal GCP identity or a separate pipeline bundle. |
| Resource labels | Massdriver default tags | Enforces cost attribution and environment tagging |

### Checkov skips

None. Existing Vertex AI Workbench Checkov checks (CKV_GCP_89, CKV_GCP_126, CKV_GCP_127) target the deprecated `google_notebooks_instance` resource and do not fire against `google_workbench_instance`. CMEK for disk encryption is intentionally out of scope — Google-managed encryption is used.

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- The landing zone provides `project_id`, `network.region`, and `primary_subnet.self_link`. The instance is placed in the landing zone's subnet, zone `-a`.
- The subnet must have Private Google Access enabled for the instance to reach GCP APIs (BigQuery, GCS) without a public IP. The `gcp-network` bundle enables this by default.
- GPU availability is zone-dependent. If a GPU type is not available in `<region>-a`, change `local.zone` in `src/main.tf` to a zone with quota.
- The `proxy_url` artifact field may be empty immediately after deploy. It populates within 2–5 minutes after the instance reaches ACTIVE state.

## Presets

| Preset | Machine Type | Disk | GPU | Idle Timeout |
|---|---|---|---|---|
| Small | `e2-standard-4` | 150 GB | none | 3 hours |
| Medium | `n1-standard-8` | 200 GB | none | 3 hours |
| GPU | `n1-standard-8` | 200 GB | NVIDIA_TESLA_T4 x 1 | 3 hours |
