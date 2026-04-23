# gcp-storage-bucket

Google Cloud Storage bucket with configurable storage class, optional versioning, and lifecycle rules. Use this bundle to provision a managed object store for data platform workloads — Cloud Run pipelines, BigQuery exports, Vertex Workbench datasets, and similar.

## Use Cases

- Staging area for data ingestion before loading into BigQuery
- Durable dataset storage with versioning and access via scoped service accounts
- Archive tier for cost-optimized long-term retention
- Intermediate storage between pipeline stages

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_storage_bucket.main` | GCS bucket | Storage class, location, versioning, and lifecycle rules set at provision time |

This bundle does NOT create any IAM bindings. Consumer bundles (e.g., `gcp-cloud-run-service`) create their own service accounts and bind the appropriate roles on this bucket when connected on the canvas.

## Connections

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id` for resource placement |

## Artifact Produced

**Artifact type:** `catalog-demo/gcp-storage-bucket`

| Field | Description |
|---|---|
| `project_id` | GCP project ID that owns the bucket |
| `bucket_name` | Globally-unique GCS bucket name (derived from the Massdriver name prefix) |
| `bucket_url` | Canonical `gs://` URL for use with gsutil and client libraries |
| `bucket_self_link` | GCS REST API resource URL (`https://www.googleapis.com/storage/v1/b/<name>`) |
| `location` | GCS location where the bucket is deployed |
| `storage_class` | Active storage class of the bucket |

Consumer bundles bind IAM roles on the bucket using `bucket_name` and `project_id` from this artifact. Example pattern:

```hcl
resource "google_storage_bucket_iam_member" "runtime_object_user" {
  bucket = var.storage_bucket.bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.runtime.email}"
}
```

## Compliance

### Hardcoded security controls

| Setting | Value | Reason |
|---|---|---|
| `uniform_bucket_level_access` | `true` | Disables legacy object-level ACLs. All access is IAM-only, which prevents split access-control models that are difficult to audit (Checkov CKV_GCP_29). |
| `public_access_prevention` | `"enforced"` | Blocks all public object access regardless of IAM or ACLs. Prevents accidental data exposure via `allUsers` or `allAuthenticatedUsers` (Checkov CKV_GCP_114). |

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_62` | Bucket access logging requires a separate log-sink bucket not in scope here. Enabling logging without a target bucket causes a plan-time error. Operators who need access logs should provision a dedicated log bucket and wire `logging.log_bucket` manually. |
| `CKV_GCP_63` | Checks that a bucket does not log to itself. Because no `logging` block is configured, this check fires as a false positive. |
| `CKV_GCP_78` | Retention lock (WORM) makes objects immutable for a fixed duration and cannot be removed once set. It is not appropriate for all workloads. Add a `retention_policy` param if your workload requires WORM. |

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `storage.googleapis.com` must be enabled in the landing zone before deploying. Add it to `enabled_apis` in the `gcp-landing-zone` package.
- The `gcp_authentication` credential has `storage.admin` or equivalent IAM on the project.
- Bucket names are derived from the Massdriver `name_prefix` and are globally unique — operators do not choose the raw bucket name.
- Bucket location cannot be changed after creation. Choosing the wrong location requires decommissioning and reprovisioning with data migration.

## Presets

| Preset | Storage Class | Location | Versioning | Lifecycle |
|---|---|---|---|---|
| Staging | STANDARD | US | Off | Delete objects after 30 days |
| Durable | STANDARD | US | On | None — retain all versions |
| Archive | COLDLINE | US | On | Transition to ARCHIVE after 365 days |
