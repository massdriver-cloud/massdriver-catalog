# GCP Data Platform — POC Starter Catalog

A starter catalog of Massdriver bundles covering the primary components of a GCP data platform, including Pub/Sub → BigQuery and Pub/Sub → Cloud Run push subscription pipelines for event-driven workloads. Intended as a starting point for your POC — use any subset, customize to fit your patterns, bring your own networking.

## What's in this catalog

### Bundles

| Bundle | Role |
| --- | --- |
| `gcp-network` | Minimal regional VPC and subnet. Useful for test environments; for production, import your existing network as an artifact (see below). |
| `gcp-landing-zone` | Environment foundation. Project-level IAM bindings for humans/groups, optional org-policy guardrails, service API enablement, optional budget with notifications. |
| `gcp-pubsub-topic` | Pub/Sub topic with optional DLQ. Low-volume / Standard / High-throughput presets. |
| `gcp-storage-bucket` | Cloud Storage bucket with uniform bucket-level access and public-access prevention enforced. Staging / Durable / Archive presets. |
| `gcp-bigquery-dataset` | BigQuery dataset with delete protection on Production. Dev / Staging / Production presets. |
| `gcp-bigquery-table` | BigQuery table. When a Pub/Sub topic is wired, creates a BigQuery subscription that delivers messages into the table. Pub/Sub-compatible default schema or custom schema JSON. |
| `gcp-cloud-run-service` | Cloud Run v2 service. Creates its own runtime service account and auto-binds roles on any connected upstream resources. Supports incoming push subscriptions and VPC connector egress. Internal / Public API / Worker presets. |
| `gcp-vertex-workbench` | Vertex AI Workbench instance. Creates a per-instance service account. When connected to a BigQuery dataset, grants the instance SA read-only access. Small / Medium / GPU presets. |
| `gcp-log-sink` | Project-level Cloud Logging sink with configurable filter. Routes matching log entries to a BigQuery dataset or GCS bucket. Terraform precondition enforces exactly one destination. |

### Artifact definitions

Each bundle produces an artifact that downstream bundles consume. Artifact definitions are reusable contracts — if you already have infrastructure you want to represent in Massdriver, you can import it as an artifact and connect it to bundles without re-provisioning.

| Artifact | Key fields |
| --- | --- |
| `gcp-network` | project_id, network_name, region, primary_subnet, optional secondary ranges / PSA / Cloud NAT / additional subnets |
| `gcp-landing-zone` | project_id, network, enabled_apis, budget (optional), iam_bindings (summary) |
| `gcp-workload-identity` | project_id, service_account_email / id / name |
| `gcp-pubsub-topic` | project_id, topic_name, topic_id, optional DLQ fields |
| `gcp-storage-bucket` | project_id, bucket_name, bucket_url, bucket_self_link, location, storage_class |
| `gcp-bigquery-dataset` | project_id, dataset_id, dataset_full_name, location |
| `gcp-bigquery-table` | project_id, dataset_id, table_id, table_full_name |
| `gcp-cloud-run-service` | project_id, service_name, service_url, location, latest_ready_revision, runtime SA email/member |
| `gcp-vertex-workbench` | project_id, instance_name, location, proxy_url, instance SA email/member |
| `gcp-log-sink` | project_id, sink_name, destination, writer_identity, destination_type |
| `gcp-vpc-connector` | project_id, region, name, connector_id, optional network / ip_cidr_range / egress_settings (import-only) |

## How the bundles compose

```
             gcp-network  ─►  gcp-landing-zone
                                    │
                    ┌───────────────┼───────────────────────────┐
                    ▼               ▼                           ▼
          gcp-pubsub-topic   gcp-storage-bucket          gcp-bigquery-dataset
                    │                                           │
                    │                                           ▼
                    │                                 gcp-bigquery-table
                    │        (optional topic wired to table → BQ subscription)
                    │
                    ▼
          gcp-cloud-run-service / gcp-vertex-workbench
          (incoming topic → push subscription,
           outgoing topic → publisher role,
           optional vpc-connector → private egress,
           creates its own SA)

                    ▼
              gcp-log-sink  ─►  (gcp-bigquery-dataset or gcp-storage-bucket)
```

### Topology notes

- **Subscriptions live on the consumer bundle, not on their own canvas tile.** Wire a topic into a `gcp-bigquery-table` and the table bundle creates a BigQuery subscription internally. Wire a topic into a `gcp-cloud-run-service` via the `incoming_topic` input and the service creates a push subscription. This matches real-world ownership (the consumer configures ack deadline, retry, schema mapping) and halves the canvas-tile count for a typical pipeline.
- **Cloud Run services have two distinct Pub/Sub inputs.** `incoming_topic` creates a push subscription that delivers messages into the service URL. `pubsub_topic` (outgoing) grants the service's runtime SA publisher role on that topic. A middleware service can wire both — receive from one topic, publish to another.
- **The landing zone owns project-level IAM and guardrails**, not workload service accounts. Data resources (topic, bucket, dataset, table) produce artifacts with role-scoped policies but don't bind any service account themselves. Runtimes (Cloud Run, Workbench) create their own per-service service accounts and bind roles on connected upstream resources — standard per-workload-SA least-privilege.

## Getting started

Before getting started with the catalog, set up your [self-hosted instance.](https://docs.massdriver.cloud/platform-operations/self-hosted/install)

### 1. Clone the catalog

```bash
git clone git@github.com:massdriver-cloud/massdriver-catalog.git
cd massdriver-catalog
git checkout demo/0422-gcp-data-plat-kafka
```

### 2. Configure the Massdriver CLI

The CLI reads its config from `$HOME/.config/massdriver/config.yaml` (or `$XDG_CONFIG_HOME/massdriver/config.yaml` if `XDG_CONFIG_HOME` is set). Create it with your organization ID and a Service Account API key:

```yaml
version: 1
profiles:
  default:
    organization_id: YOUR_ORG_ID
    api_key: YOUR_SERVICE_ACCOUNT_TOKEN
    url: https://api.YOUR_DOMAIN
    templates_path: ~/path/to/your/massdriver-catalog/templates
```

- **organization_id** — hover over your org logo in the Massdriver UI to find it
- **api_key** — create a Service Account in Settings → Service Accounts and copy its token

Or use environment variables: `MASSDRIVER_ORGANIZATION_ID`, `MASSDRIVER_API_KEY`.

Full reference: https://docs.massdriver.cloud/reference/cli/overview#configuration

### 3. Enable platforms and publish the catalog

```bash
# In this repo
make ENABLED_PLATFORMS=gcp
make publish-artifact-definitions publish-bundles
```

### 4. Upload your GCP credential

Export a service account key from a project where you want to deploy the POC. Upload it as a Massdriver credential:

```bash
mass artifact import \
  -f ~/path/to/gcp-sa.json \
  -n "GCP POC" \
  -t {YOUR_ORG_ID}/gcp-service-account
```

**Note:** GCP service account keys currently need to be imported via the CLI as shown above. There's an escaping bug in the UI credential form that mangles the newline characters in GCP private keys (GCP is the only provider affected — the keys are multi-line PEM). A fix is in flight. In the meantime, two workarounds: import via CLI, or provision the service account in-platform via a Massdriver bundle and consume the resulting artifact.

The credential needs permissions to manage the resources you plan to deploy (Compute Admin for network, Project IAM Admin for landing zone, Pub/Sub Admin, Storage Admin, BigQuery Admin, Cloud Run Admin, Workbench Admin, Logging Admin, Service Usage Admin for API enablement, and Serverless VPC Access Admin if you're importing a VPC connector).

### 5. Bring your own network

**Option A — provision a new network for POC testing:**
Add the `gcp-network` bundle to an environment canvas, connect your GCP credential, pick a region and CIDR, deploy. The bundle provisions a minimal VPC with one subnet, Private Google Access, flow logs, and a baseline deny-all ingress firewall rule.

**Option B — import your existing network:**
The `gcp-network` artifact is designed to represent a rich existing network (primary + additional subnets, secondary ranges for GKE, Private Services Access, Cloud NAT). You can import your network directly as an artifact instead of provisioning one.

```bash
mass artifact import \
  -f path/to/my-network.json \
  -n "Prod VPC" \
  -t {YOUR_ORG_ID}/gcp-network
```

See `artifact-definitions/gcp-network/massdriver.yaml` for the full schema — every field you might need for an existing production network is already defined, most of them optional.

### 6. (Optional) Import an existing VPC connector

If your Kafka producer (or any Cloud Run service in the catalog) needs private egress through a Serverless VPC Access connector, the `gcp-vpc-connector` artifact definition is import-only — no provisioning bundle. Create the connector in GCP however you normally would:

```bash
gcloud compute networks vpc-access connectors create my-connector \
  --region=us-central1 \
  --network=my-vpc \
  --range=10.8.0.0/28
```

Then import it as an artifact:

```bash
mass artifact import \
  -f path/to/connector.json \
  -n "Shared VPC Connector" \
  -t {YOUR_ORG_ID}/gcp-vpc-connector
```

Wire it into any `gcp-cloud-run-service` on the canvas via the `vpc_connector` input.

### 7. Build up the environment

1. **Landing zone** — add `gcp-landing-zone` to the canvas. Connect the network. Configure IAM bindings for your team (e.g., `roles/viewer` → your analysts group), any org policy guardrails you want enforced, and an optional budget.
2. **Data resources** — add any of `gcp-pubsub-topic`, `gcp-storage-bucket`, `gcp-bigquery-dataset`, `gcp-bigquery-table`. Each connects to the landing zone for `project_id` context. Tables connect to a dataset (required) and optionally to a topic (creates the BQ subscription).
3. **Runtimes** — add `gcp-cloud-run-service` or `gcp-vertex-workbench`. Connect the landing zone (required) plus any upstream data artifacts. For Cloud Run: wire `incoming_topic` to create a push subscription; wire `pubsub_topic` for outgoing publisher role; wire `vpc_connector` for private egress.
4. **Observability** — add `gcp-log-sink` to route log entries to a BigQuery dataset or GCS bucket. Wire exactly one destination; the Terraform precondition enforces this.

### 8. Deploy

From the canvas UI or CLI:

```bash
mass package deploy <project>-<env>-<manifest> -m "initial deploy"
```

## Iterating with development releases

During a POC you'll almost certainly want to tweak bundles — adjust a default, add a param, change an IAM binding, tighten a compliance rule. Cutting a new semver version for each iteration is slow and clutters the version history. Use **development releases** instead.

### How it works

Publishing a bundle with `--development` creates a `X.Y.Z-dev` release tagged with a timestamp (or your local git SHA). It:

- Doesn't bump the bundle's official version in `massdriver.yaml`.
- Each new dev publish is a new pointer the package can be pinned to.
- Is only usable when a package is explicitly pinned to the dev release — production packages on `1.2.3` are unaffected.

This lets you iterate on a bundle, redeploy, and see results in seconds without polluting your version history. When you're happy with the changes, bump the version and publish a real one (`1.3.0`) and re-pin the package.

### The iteration loop

```bash
# 1. Edit a bundle (e.g., bundles/gcp-cloud-run-service/src/*.tf)

# 2. Publish a development release
cd bundles/gcp-cloud-run-service
mass bundle publish --development

# 3. In the UI, pin the package to the dev release
#    (Package → Settings → Version → select "0.1.1-dev.<timestamp>")

# 4. Redeploy with a comment describing what you changed
mass package deploy <project>-<env>-<manifest> -m "testing stricter egress rule"

# 5. Inspect results, adjust, go back to step 1.
```

For runtime templates where app developers have scaffolded per-app bundles with `mass bundle new`, the same loop works — publish the app bundle itself as a development release while iterating on its Terraform or params.

### When to cut a real version

Once the bundle behaves the way you want, bump `version:` in the bundle's `massdriver.yaml` and publish:

```bash
mass bundle publish
```

Re-pin the package to the new version in the UI. Going forward, production packages track numbered releases; only environments you explicitly move to the dev pointer follow your in-flight changes.

### Tips

- Commit your bundle changes to git before publishing a dev release. The dev release records the state at publish time, so you want it to point at something you can check out later.
- Use `-m` on every `mass package deploy` to leave a breadcrumb for yourself (and anyone reviewing the canvas history) about what each iteration was testing.
- Dev releases are per-bundle, so you can iterate on `gcp-cloud-run-service` while leaving `gcp-landing-zone` on a stable numbered release.

## Customizing for your team

### Runtime templates

`gcp-cloud-run-service` is an example of a **runtime template** — an opinionated bundle that codifies your organization's runtime standards (SA identity, compliance controls, upstream IAM conventions).

The expected pattern in production:
- Platform/ops team forks or customizes the runtime template bundles to enforce their org's standards.
- Application developers run `mass bundle new` using the template to generate a **per-app** bundle that declares their service's specific connections, env vars, and dependencies.

Both the template and the per-app bundle are Massdriver bundles, so they get the same canvas, deploy, and compliance treatment.

A ready-to-use application template for Cloud Run is included at `templates/gcp-cloud-run-service/`. App developers scaffold a new bundle with:

```bash
mass bundle new --template gcp-cloud-run-service
```

The CLI prompts for bundle name and description, then shows a list of artifact definitions published in your org — developers pick which upstream resources their service needs (Pub/Sub topic, BigQuery dataset, GCS bucket, anything else). The resulting bundle is lean — only `image` is exposed as a param by default; developers add more params as their app needs them. `src/iam.tf` includes commented-out IAM binding examples, `src/push_subscription.tf` has an example push-subscription block, and `src/main.tf` has a commented VPC connector block — all ready to uncomment based on what they picked.

### Compliance strategy

Every bundle has a Checkov gate. Findings only halt deployment when `md-target` matches `prod|prd|production`. Lower environments surface findings as warnings but still deploy. Adjust the `halt_on_failure` expression in each bundle's `massdriver.yaml` to match your naming conventions.

### Presets

Each bundle ships with 2–3 presets mapped to common environment tiers. The presets are just starting points — you can override any param at deploy time or create new presets suited to your stack.

## Assumptions and prerequisites

- **Cloud Billing must be enabled** on the GCP billing account for budgets to work.
- The GCP service account credential needs admin-level permissions on the resources it provisions. For production use, narrow it down per-environment.
- GCS bucket names are globally unique — deployments derive the name from Massdriver's `name_prefix` so uniqueness is automatic, but this means you can't pick your own name.
- BigQuery dataset `location`, GCS bucket `location`, and BigQuery table `table_id` are immutable after creation — to change, you destroy and recreate (and export/reimport data).
- Vertex Workbench requires a minimum 150 GB boot disk.
- **BigQuery subscriptions require the target table to exist before the subscription can deliver messages.** The `gcp-bigquery-table` bundle creates the table and the subscription atomically, so this is handled when you use it — but if you connect a topic directly to a hand-created table, make sure the table is there first.
- **VPC Access connectors are regional.** A connector must be in the same region as the Cloud Run service using it. If you import a connector as an artifact, the region is part of the artifact payload — wire to a service in the matching region.

## What's NOT in this catalog (yet)

Things you may want for a fuller production setup — not included, but straightforward to add:
- VPC Service Controls / service perimeters
- Cloud KMS key ring bundle (for CMEK on the data resources)
- Cloud Scheduler / Cloud Tasks for event-driven triggers
- Cloud SQL / AlloyDB for transactional workloads
- GKE for containerized workloads at scale
- Artifact Registry for container images
- Secret Manager secrets
- Monitoring / alerting workspace with dashboards
- Dataflow / Dataproc for batch or streaming pipelines
- VPC Access connector provisioning bundle (currently import-only)
- AWS-side artifact definitions for S3 / Kafka / IAM-role-based cross-cloud auth

## Bundle-level docs

Each bundle has:
- `README.md` — what it does, what it creates, what it produces, compliance posture
- `operator.md` — a 2am runbook. Non-obvious constraints, troubleshooting, day-2 operations, useful commands

## Support during the POC

Reach out any time. Happy to hop on a call to help troubleshoot, talk through design choices, or recommend patterns based on what you're seeing.
