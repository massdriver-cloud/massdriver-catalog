# gcp-storage-bucket

Google Cloud Storage bucket with configurable storage class, optional versioning, and lifecycle rules. Use this bundle to provision a managed object store for data platform workloads — Cloud Run pipelines, BigQuery exports, Vertex Workbench datasets, and similar. The landing zone's workload service account is automatically granted object read/write access.

## Purpose

- Provisions a GCS bucket with configurable storage class and location
- Optionally enables versioning for durable datasets and non-current version lifecycle management
- Supports lifecycle rules for automated cost optimization (Delete and SetStorageClass transitions)
- Enforces `uniform_bucket_level_access` and `public_access_prevention = "enforced"` as non-negotiable security baselines
- Grants `roles/storage.objectUser` to the landing zone's workload service account on the bucket
- Emits a `catalog-demo/gcp-storage-bucket` artifact so downstream bundles can reference the bucket without hard-coding names or project IDs

## Resources Created

| Resource | Type | Notes |
|---|---|---|
| `google_storage_bucket.main` | GCS bucket | Storage class, location, versioning, and lifecycle rules set at provision time |
| `google_storage_bucket_iam_member.workload_object_user` | IAM binding | Grants `roles/storage.objectUser` to the landing zone workload SA |

## Artifacts Consumed (Connections)

| Connection | Artifact Type | How It Is Used |
|---|---|---|
| `gcp_authentication` | `gcp-service-account` | Deploy credential — project ID and service account key for the Google provider |
| `landing_zone` | `catalog-demo/gcp-landing-zone` | Provides `project_id` and `workload_identity.service_account_email` for the objectUser IAM binding |

## Artifacts Produced

The bundle publishes a `catalog-demo/gcp-storage-bucket` artifact with all fields needed for downstream bundles to read and write objects.

| Field | Description |
|---|---|
| `project_id` | GCP project ID that owns the bucket |
| `bucket_name` | Globally-unique GCS bucket name (derived from Massdriver name prefix) |
| `bucket_url` | Canonical `gs://` URL for use with gsutil and client libraries |
| `bucket_self_link` | GCS REST API resource URL (`https://www.googleapis.com/storage/v1/b/<name>`) |
| `location` | GCS location where the bucket was deployed |
| `storage_class` | Active storage class of the bucket |

Downstream bundles that need additional access (e.g., read-only) should bind `roles/storage.objectViewer` on the bucket using `bucket_name` and `project_id` from this artifact.

## Compliance

### Hardcoded security baselines

Two settings are enforced at the Terraform level and cannot be changed via parameters:

| Setting | Value | Reason |
|---|---|---|
| `uniform_bucket_level_access` | `true` | Disables legacy object-level ACLs. All access is controlled by IAM only. Prevents split access-control models that are difficult to audit and easy to misconfigure (Checkov CKV_GCP_29). |
| `public_access_prevention` | `"enforced"` | Blocks all public object access regardless of IAM policies or ACLs. Prevents accidental data exposure via `allUsers` or `allAuthenticatedUsers` grants (Checkov CKV_GCP_114). Non-negotiable baseline for all environments in this data platform series. |

### Checkov skips

| Check | Reason |
|---|---|
| `CKV_GCP_62` | Bucket access logging requires a separate log-sink GCS bucket. That bucket is not part of this bundle's scope — enabling logging here without a target bucket causes a plan-time error. Operators who need access logs should provision a dedicated log bucket and wire `logging.log_bucket` manually. |
| `CKV_GCP_63` | Checks that a bucket does not log access requests to itself. Because no `logging` block is configured (see CKV_GCP_62), this bucket cannot log to itself. Checkov fails this check in the absence of any logging configuration, making the finding a false positive in this context. |
| `CKV_GCP_78` | Retention lock (WORM) makes objects immutable for a fixed duration and cannot be shortened or removed once set. It is not universally appropriate — it prevents deletion of any object, including accidental uploads. Add a `retention_policy` param if your workload requires WORM guarantees. |

### Production gating

The `halt_on_failure` expression in `massdriver.yaml` blocks deployments with unresolved high-severity Checkov findings when the environment target matches `prod`, `prd`, or `production`.

## Assumptions

- `storage.googleapis.com` must be enabled in the landing zone before deploying this bundle. Add it to `enabled_apis` in the `gcp-landing-zone` package config.
- The `gcp_authentication` credential has `storage.admin` or equivalent IAM on the project.
- The landing zone's workload SA is granted `roles/storage.objectUser` automatically; read-only or admin access for other consumers must be added by the downstream bundle.
- Bucket names are derived from the Massdriver `name_prefix` and are globally unique — operators do not pick the raw bucket name.

## Presets

| Preset | Storage Class | Location | Versioning | Lifecycle |
|---|---|---|---|---|
| Staging | STANDARD | US | Off | Delete objects after 30 days |
| Durable | STANDARD | US | On | None — retain all versions indefinitely |
| Archive | COLDLINE | US | On | Transition to ARCHIVE class after 365 days |

## Bucket Naming

GCS bucket names are globally unique across all GCP projects. This bundle derives the bucket name from the Massdriver `name_prefix`, which incorporates the environment slug and package name. Operators do not choose the raw name — name collisions are avoided by construction.

## Location Immutability

A bucket's location cannot be changed after creation. Selecting the wrong location requires decommissioning the package and reprovisioning. Choose carefully at deploy time based on where your compute resources run.
