# Massdriver Catalog

A bootstrap catalog for self-hosted Massdriver instances containing resource types, infrastructure bundles, and cloud credentials. This catalog helps you quickly model your platform architecture and developer experience before implementing infrastructure code.

**This is your platform foundation.** While this guide walks you through the concepts, you're not just following a tutorial—you're building your actual platform. This repository will serve as your platform team's source of truth for resource types and bundles. Design your infrastructure architecture, iterate on the developer experience, and refine your abstractions here—then fill in your OpenTofu/Terraform implementation when you're ready.

> [!NOTE]
> **Massdriver v2:** This catalog targets Massdriver v2 (Mass CLI ≥ `2.0.0`, GraphQL `/v2/`). v2 renamed several core concepts:
> - `targets` → **environments**
> - `packages` → **instances**
> - `artifact definitions` → **resource types**
> - `artifacts` → **resources**
>
> The keys `connections:` and `artifacts:` inside `massdriver.yaml` are **unchanged** — backward-compatible renames to `dependencies:` and `resources:` are coming in a future release. Until then this repo continues to use `connections:` and `artifacts:` in every `massdriver.yaml`, with a comment pointing to the new names.

**tl;dr:** [Jump to Quick Start](#customizing-your-catalog)

## Quick Start Workflow

This catalog is yours to customize and extend. Here's the recommended workflow:

1. **Clone this repository** to your organization (keep it private—it will contain your infrastructure code)
2. **Configure GitHub Secrets** (see [Quick Start](#quick-start)) to enable automatic publishing on push to `main`
3. **Start experimenting** with bundles in your editor—edit schemas, add parameters, define connections
4. **Watch the developer experience get built** in real-time in Massdriver as you iterate on your abstractions

The beauty of this approach: you can refine the entire developer experience—what parameters developers see, how bundles connect, what resources are produced—all before writing a single line of infrastructure code.

## Key Concepts

If you're new to Massdriver, here are the core concepts you'll encounter:

- **Bundle**: A reusable, versioned definition of infrastructure or application components. Bundles encapsulate your IaC code (Terraform/OpenTofu/Helm), configuration schemas, dependencies, and policies into a single deployable unit. Think of them as "infrastructure packages" with built-in guardrails.

- **Resource Type** (formerly *artifact definition*): A JSON Schema contract that defines how infrastructure components can connect to each other. Resource types ensure type safety—you can't connect incompatible components.

- **Resource** (formerly *artifact*): A live, materialized resource type emitted by a deployed bundle. For example, when you deploy a PostgreSQL bundle, it emits a PostgreSQL resource containing connection details that other bundles can consume.

- **Parameters (params)**: User-configurable inputs for a bundle, like instance sizes, database names, or feature flags. These define what developers can customize when deploying infrastructure.

- **Connections** (the `connections:` key in `massdriver.yaml`, surfaced in the product as **dependencies**): Inputs a bundle needs from other bundles. When a bundle declares it needs a connection to a `network` resource, you must link it to a bundle that produces a network resource.

- **Project**: A logical grouping of related infrastructure, like "ecommerce-platform" or "data-pipeline". Projects contain one or more environments.

- **Environment** (formerly *target*): A deployment context within a project, like "development", "staging", or "production". Each environment has its own canvas where you design and deploy infrastructure.

- **Canvas**: The visual diagram in the Massdriver UI where you add bundles, connect them together, and configure parameters. It's your infrastructure design board.

- **Instance** (formerly *package*): A configured deployment of a bundle in a specific environment. When you add a bundle to your canvas and configure it, you're creating an instance. Think of it like the relationship between a class and an object in programming—bundles are the reusable definitions, instances are the deployed objects.

## What's Inside

### 📁 `resource-types/`

**Resource types** (formerly called *artifact definitions*) are schema-based contracts that define how infrastructure components can interact with each other in Massdriver. Think of them as type definitions for your infrastructure—they ensure that when you connect a database to an application, both sides speak the same language.

Each resource type is a directory containing a `massdriver.yaml` file:

```
resource-types/
├── network/
│   └── massdriver.yaml    # VPC, subnets, and private service access contract
├── serverless-connector/
│   └── massdriver.yaml    # Serverless VPC connector contract
├── container-registry/
│   └── massdriver.yaml    # Container image registry contract
├── postgres-database/
│   └── massdriver.yaml    # PostgreSQL connection contract
├── object-storage/
│   └── massdriver.yaml    # Object storage bucket contract
├── firestore-database/
│   └── massdriver.yaml    # Firestore document database contract
└── cloud-run-service/
    └── massdriver.yaml    # Running service + public URL contract
```

> **💡 Note on Sensitive Fields**: Resource types support the [`$md.sensitive`](https://docs.massdriver.cloud/json-schema-cheat-sheet/massdriver-annotations#mdsensitive) annotation to mark fields containing credentials, passwords, or other secrets. Fields marked as sensitive are automatically masked as `[SENSITIVE]` in GraphQL queries and UI displays while remaining accessible for actual infrastructure connections. All resource data is encrypted at rest and in transit, and downloads of sensitive data are tracked in audit logs.

**⚠️ These are examples to get you started.** Edit these schemas to match your organization's infrastructure patterns and the data your bundles need to exchange. The field names, structure, and validation rules should reflect what your actual OpenTofu/Terraform code produces and consumes.

**Why they matter**: Resource types enable type-safe infrastructure composition. You can't accidentally connect a PostgreSQL resource to a bundle expecting MySQL—the system validates compatibility at design time, before any infrastructure is deployed.

Use these example resource types to:

- Define the contract between your IaC modules (what data gets passed from one to another)
- Model how services connect together in your architecture
- Design your project and environment structure
- Plan the developer experience before writing infrastructure code
- **Then customize them** to match your organization's specific needs

### 📁 `bundles/`

**Bundles** are reusable, versioned definitions of cloud infrastructure or application components. A bundle encapsulates everything needed to provision and manage a piece of infrastructure: the IaC code, configuration schemas, dependencies, outputs, and policies.

Bundles provide a safe self-service framework where you (the platform team) encode best practices into ready-to-use modules, and developers get a simple interface to deploy what they need.

This catalog ships a working GCP Cloud Run platform, split into two tiers by audience:

**Platform tier** — owned by the platform team, and deliberately not something application developers
place themselves. These speak in infrastructure terms because an infrastructure engineer is the reader.

- `gcp-network/` - VPC, subnets, private service access for Cloud SQL, and a serverless VPC connector
- `gcp-artifact-registry/` - Container image registry that application builds push into

**Application tier** — self-service on the canvas. These are written for someone who has never heard of
a VPC: dangerous options are defaulted or hidden, and the help text avoids infrastructure jargon.

- `hello-cloud-run/` - A worked example generated from the `gcp-cloud-run` template
- `gcp-cloud-sql-postgres/` - Managed PostgreSQL, private IP only
- `gcp-cloud-storage-bucket/` - Object storage for uploads, exports, and files
- `gcp-firestore/` - Firestore document database

Each bundle includes:

- ✅ Complete `massdriver.yaml` configuration
- ✅ **Parameter schemas** - Define your IaC variables (tfvars, Helm values) and customize the UI form for user configuration (instance sizes, database names, etc.)
- ✅ **Connection schemas** (the `connections:` key — the product surfaces these as **dependencies**) - Define resources from other bundles this one needs, enabling secure access to their details during automation.
- ✅ **Artifact schemas** (the `artifacts:` key — the product surfaces these as **resources**) - Define what infrastructure this bundle produces for others to consume.
- ✅ **UI schemas** - Control how the configuration form looks and behaves
- 🚧 Placeholder OpenTofu/Terraform code (replace with yours)

> [!NOTE]
> The `connections:` and `artifacts:` keys keep their v1 names inside `massdriver.yaml`. Backward-compatible renames to `dependencies:` and `resources:` are coming — until then, prefer the v1 keys here.

These bundles let you model first, implement later. Use the schemas to plan your architecture and test the developer experience in the Massdriver UI, then fill in the actual infrastructure code when you're ready.

For more details, see the [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) and [Module Patterns](https://docs.massdriver.cloud/guides/module-patterns) guides.

### 📁 `templates/`

**Bundle templates** are starter scaffolds for creating new bundles. Use them with the Massdriver CLI to quickly bootstrap new infrastructure modules with the correct structure and boilerplate.

Available templates:

| Template | Provisioner | Description |
|----------|-------------|-------------|
| `gcp-cloud-run` | OpenTofu | Build a container in GCP and deploy it to Cloud Run (two-step) |
| `opentofu` | OpenTofu | OpenTofu module template |
| `terraform` | Terraform | Terraform module template |
| `bicep` | Bicep | Azure Bicep template |
| `helm-chart` | Helm | Deploy external Helm charts |

`gcp-cloud-run` is the one to reach for when onboarding a new application. Scaffolding it gives that
app its own bundle — its own schema, its own runbook, its own version history — rather than making
every team share one generic "app" bundle they each need to bend:

```bash
mass bundle new --name checkout-api --template-name gcp-cloud-run
```

Drop the application's source into `build/app/` (it ships with a small working example), then publish.
The developer never installs `docker` or `gcloud`; see [Building without Docker](#building-without-docker-or-gcloud).

**Usage with the CLI:**

```bash
# Set custom template path (optional - for local development)
export MD_TEMPLATES_PATH=/path/to/massdriver-catalog/templates

# Create a new bundle from a template
mass bundle new --name my-bundle --template-name opentofu
```

Each template includes:
- `massdriver.yaml` - Pre-configured with example params, connections, and artifacts
- `operator.md` - Runbook template for operational guidance
- `icon.svg` - Placeholder icon
- `src/` or `chart/` - IaC boilerplate for the specific provisioner

For more details, see the [Bundle Templates](https://docs.massdriver.cloud/guides/bundle-templates) guide.

### 📁 `platforms/`

**Platform integrations** are resource types that model the credentials Massdriver uses to connect to your cloud providers and infrastructure platforms. They live in their own directory (rather than under `resource-types/`) for discoverability — operationally they're published with `mass resource-type publish`, just like everything in `resource-types/`. Each platform directory contains everything needed to authenticate and interact with that platform.

> [!TIP]
> **Customize these to match how *you* authenticate.** The platform schemas shipped here are a starting point, not a prescription. If your team authenticates AWS with static access keys instead of an assumed IAM role, replace `aws/massdriver.yaml`'s schema with the fields your `aws` provider block actually consumes. If you front Azure with a managed identity, GCP with workload identity federation, or Kubernetes with an OIDC token, model that here. The fields in `schema:` should mirror the inputs to your IaC tool's provider configuration (Terraform/OpenTofu provider blocks, Helm `kubeconfig`, etc.) — Massdriver collects those values and hands them to your bundles at deploy time. Update `instructions/` with your team's onboarding steps so developers know what to paste where.

Massdriver can orchestrate any platform your IaC tooling supports. Adding a new platform (Snowflake, Datadog, Confluent Cloud, etc.) is as simple as defining its credential schema.

**Structure**:

```
platforms/aws/
├── massdriver.yaml       # Platform definition (source of truth)
├── icon.png              # Platform icon
├── instructions/         # Setup walkthroughs
│   ├── AWS CLI.md
│   ├── AWS Console.md
│   └── AWS One Click.md
└── exports/              # Downloadable templates (optional)
```

**The `massdriver.yaml` Format**:

Each platform has a declarative `massdriver.yaml` that drives the build process:

```yaml
name: aws-iam-role               # Resource type name
label: AWS IAM Role              # Display name in UI
icon: https://...                # Icon URL

ui:
  connectionOrientation: environmentDefault
  environmentDefaultGroup: credentials
  instructions:                  # References to markdown files
    - label: AWS CLI
      path: ./instructions/AWS CLI.md

exports:                         # Optional: downloadable templates
  - downloadButtonText: Kube Config
    fileFormat: yaml
    templatePath: ./exports/kubeconfig.yaml.liquid
    templateLang: liquid

schema:                          # JSON Schema as YAML
  title: AWS IAM Role
  type: object
  properties:
    # ... credential fields matching your OpenTofu provider auth
```

The `schema` section should match your OpenTofu/Terraform provider authentication configuration. For example, AWS IAM Role credentials match the `aws` provider's `assume_role` block, Azure Service Principal matches the `azurerm` provider config, etc.

**Export Templates** (optional): The `exports/` directory enables self-service artifact downloads. Export templates allow developers to download pre-configured files based on deployed artifact data—like generating a kubeconfig file from a Kubernetes cluster credential, VPN configuration files with certificates, database connection strings, or environment variable files for local development.

Templates use Liquid syntax and have access to the full artifact payload via the `artifact` variable. When a developer clicks the download button in Massdriver's UI, the template is rendered with their specific artifact data and downloaded as a ready-to-use configuration file.

Export configuration is defined in the `massdriver.yaml`:
- `downloadButtonText`: The label shown on the download button
- `fileFormat`: The file extension for the downloaded file
- `templatePath`: Path to the template file (relative to the platform directory)
- `templateLang`: Template language (currently only `liquid` is supported)

**Example template** (`exports/kubeconfig.yaml.liquid`):
```yaml
apiVersion: v1
clusters:
  - cluster:
      server: {{ artifact.data.authentication.cluster.server }}
      certificate-authority-data: {{ artifact.data.authentication.cluster.certificate-authority-data }}
    name: {{ artifact.id }}
users:
  - name: {{ artifact.id }}
    user:
      token: {{ artifact.data.authentication.user.token }}
```

This template references fields from the deployed artifact's `data` payload, allowing developers to instantly download correctly configured files without manual copy-paste.

> **Note**: The `massdriver.yaml` format used here is a prototype for a more declarative authoring experience that may be adopted in future versions of Massdriver.

**Included platforms**:

- `aws/` - AWS IAM Role authentication
- `azure/` - Azure Service Principal authentication
- `gcp/` - GCP Service Account authentication
- `kubernetes/` - Kubernetes cluster connection

**Extending Massdriver**: Your platform team can support any cloud or SaaS platform by creating a new platform directory and defining its `massdriver.yaml`. Design the `schema` section to match your OpenTofu provider or Helm authentication configuration. Massdriver captures those credential values and securely passes them to your automation workflows.

Update your supported cloud platforms and onboarding instructions with:

```bash
make publish-platforms
```

This compiles the `massdriver.yaml` definitions into `dist.json` artifacts for publishing.

### 📄 `preview.yaml`

**Preview environments** are short-lived environments forked from a base environment (typically `production` or `staging`) so you can stand up a full stack for a pull request, a demo, or a one-off experiment without hand-wiring every instance. Massdriver clones the canvas, then applies the overrides you declare in `preview.yaml` — pinning specific bundle versions, swapping in cheaper instance sizes, scoping secrets, and templating values with environment variables like `${GITHUB_PR}`.

The `preview.yaml` at the repo root is a working example you can adapt:

- **`project` / `baseEnvironment`** — which environment to fork from.
- **`attributes`** — ABAC tags applied to the new environment (lifecycle, branch, region).
- **`environmentDefaults`** — pin shared resources (e.g. a Kubernetes cluster) the preview should reuse instead of cloning.
- **`instances`** — per-instance overrides for `version`, `params`, and `secrets`. Instances listed without overrides inherit from the fork; instances omitted entirely are still cloned from the parent.

Use it from CI (typically a `pull_request` GitHub Action) to fork the environment:

```bash
mass environment preview "pr${GITHUB_PR}" -f preview.yaml
```

Then on PR close, decommission and delete it:

```bash
mass environment decommission "pr${GITHUB_PR}" --follow
mass environment delete "pr${GITHUB_PR}"
```

See the [Preview Environments workflow guide](https://docs.massdriver.cloud/workflows/preview) for the full CLI reference, CI examples, and the complete `preview.yaml` schema.

## Tour of the GCP Cloud Run Platform

The catalog ships a complete, working Cloud Run platform rather than schema mockups. Every bundle below
has real OpenTofu behind it, a runbook, and a Checkov policy posture. Use them as-is, or read them as
worked examples when you build your own.

The platform is organized around one idea: **an application developer should be able to ship a service
without knowing what a VPC is, and without installing anything.** Every design decision below follows
from that.

### The shape

```
  ┌─ platform tier (your team owns these) ─┐
  │                                        │
  │   gcp-network        gcp-artifact-registry
  │        │                      │
  └────────┼──────────────────────┼────────┘
           │                      │
     private service              │ images
       access │                   │
              ▼                   ▼
        gcp-cloud-sql-postgres   your-app (from gcp-cloud-run)
                    │             ▲   ▲
                    └─────────────┘   │
                                      │
        gcp-cloud-storage-bucket ─────┤
        gcp-firestore ────────────────┘
```

Developers place things on the right-hand side and connect them. The left-hand side is placed once by
the platform team and then mostly forgotten.

### Platform tier

Written for an infrastructure engineer. Real ops vocabulary is used deliberately here — CIDR ranges,
secondary ranges, private service access, retention windows — because vagueness in a network bundle is
worse than jargon.

**`gcp-network/`** — the foundation. Produces a VPC with subnets, a Private Service Access range so
Cloud SQL can be reached over private IP, and a Serverless VPC Connector so Cloud Run can talk to
private resources. Emits both a `network` and a `serverless-connector` resource.

**`gcp-artifact-registry/`** — a Docker-format Artifact Registry repository. Application builds push
images here; Cloud Run pulls from it. Emits a `container-registry` resource.

### Application tier

Written for someone who has never heard of a VPC. Dangerous options are defaulted or hidden rather than
surfaced with a warning, and the help text is plain English.

**`gcp-cloud-run/` (template) and `hello-cloud-run/` (worked example)** — the centerpiece. See
[Building without Docker](#building-without-docker-or-gcloud). Emits a `cloud-run-service` resource
including the service's public URL.

**`gcp-cloud-sql-postgres/`** — managed PostgreSQL on a **private IP only**; there is no public-IP
option to get wrong. Connects to `gcp-network` and consumes its Private Service Access range. Presets
cover a small dev instance through a regional-HA production instance.

**`gcp-cloud-storage-bucket/`** — a bucket with uniform bucket-level access and public-access
prevention on by default. Optional versioning, access logging, and CMEK.

**`gcp-firestore/`** — a Firestore database in Native mode, with point-in-time recovery and delete
protection defaulted on. Location and mode are marked immutable, because GCP will not let you change
them after creation and a form that appears to offer it is a trap.

### Building without Docker or gcloud

The constraint that shaped the Cloud Run design: **developers do not have `docker` or `gcloud`, and
requiring either would defeat the point of a self-service platform.** So the image is built inside GCP.

`gcp-cloud-run` is a **two-step bundle**:

1. **`build/`** — archives the application source from `build/app/`, uploads it to a staging bucket, and
   runs a Cloud Build that produces the container image and pushes it to Artifact Registry.
2. **`deploy/`** — deploys that image as a Cloud Run service.

The two steps share `md_metadata`, and both **independently derive the same image tag** from
`md_metadata.package.deployment_enqueued_at` rather than passing the tag between states. This is worth
understanding before modifying either step: it means the steps stay decoupled, and the tag is
deterministic for a given deployment without either step depending on the other's outputs.

Because a stale image is the failure mode that would be hardest to notice, the deploy step waits on the
specific build for the current tag rather than assuming the most recent image is the right one.

### Two audiences, two vocabularies

The same idea gets described differently depending on who reads the form. This is intentional, and worth
preserving if you extend the catalog:

| Concept | Platform tier says | Application tier says |
|---|---|---|
| Serverless VPC connector | "Serverless VPC Connector, /28 CIDR, min/max instances" | (hidden — connected automatically) |
| Private Service Access | "PSA allocated range, `/16`–`/24`, peered to `servicenetworking`" | "Your database is only reachable from your own services" |
| Cloud Run concurrency | — | "How many requests one copy of your app handles at once" |
| Deletion protection | "`deletion_protection`, blocks `terraform destroy`" | "Protect this from being deleted by accident" |

### Compliance posture

Checkov runs against every bundle. The rule the catalog follows: **a check is skipped only when it is
irrelevant in every environment.** Everything else is either genuinely fixed, or gated so that it fails
the build in production while staying configurable in development.

That gating is what makes the difference between a policy and a formality — a blanket skip silently
applies to production too. Where a check is skipped, the `.checkov.yml` entry states a factual reason
(for example, the attribute it inspects no longer exists in the current provider version and the control
is enforced another way), not a preference.

### `resource-types/*/instructions/`

Resource types can ship per-source form-fill walkthroughs that render alongside the resource creation
form in the UI, telling an operator how to harvest each schema field from an existing cloud resource.
`container-registry/` has one; the rest are candidates if you plan to import existing infrastructure.
Same pattern as `platforms/<cloud>/instructions/`.

> [!NOTE]
> The bundle `src/*.tf` files use `massdriver_resource` (the replacement for the deprecated
> `massdriver_artifact`, gone in provider v2.0) and `massdriver_instance_alarm` from
> `massdriver-cloud/massdriver ~> 2.0`.

## Customizing Your Catalog

### Prerequisites

- Self-hosted Massdriver instance running **server v2.0.0 or higher**
- [Massdriver CLI (`mass`)](https://docs.massdriver.cloud/cli) **v2.0.0 or higher**, installed and authenticated
- OpenTofu or Terraform installed (for implementing bundles)

> [!IMPORTANT]
> This catalog targets Massdriver v2 (CLI v2 + GraphQL `/v2/`). Check your CLI with `mass version`; the same command also reports the connected server version. If you're still on v1, upgrade both server and CLI before publishing — v2 changed how OCI repositories are managed and v1 publish flows will not work.

> [!TIP]
> **Claude Code Users**: Install the Massdriver Claude Code Plugin for AI-assisted bundle development with built-in guardrails, patterns, and validation rules:
> ```bash
> /plugin marketplace add massdriver-cloud/claude-plugins
> /plugin install massdriver@massdriver-cloud-claude-plugins
> ```

### Quick Start

1. **Clone this repository**

   ```bash
   git clone <your-private-repo-url>
   cd massdriver-catalog
   ```

2. **Update GitHub URLs**

   Replace `YOUR_ORG` with your actual GitHub organization name throughout the repository. This updates `source_url` fields in bundles and links in operator runbooks to point to your repository.

3. **Configure GitHub Secrets and Variables**

   This repository includes GitHub Actions workflows that automatically publish resource types and bundles to your Massdriver instance on push to `main`. To enable this, configure the following in your GitHub repository:

   **Required Secrets** (Settings → Secrets and variables → Actions → Secrets):
   - `MASSDRIVER_API_KEY` - Your Massdriver service-account API key. See [Service account permissions](#service-account-permissions) below for the privileges this account needs.

   **Required Variables** (Settings → Secrets and variables → Actions → Variables):
   - `MASSDRIVER_ORG_ID` - Your Massdriver organization ID. You can find this in your Massdriver instance URL or in the organization settings.

   **Optional Variables** (for self-hosted instances):
   - `MASSDRIVER_URL` - The API URL of your self-hosted Massdriver instance (e.g., `https://api.massdriver.yourdomain.com`). If not set, defaults to `https://api.massdriver.cloud`.

   Once configured, any push to the `main` branch will automatically:
   - Ensure each resource type's OCI repository exists, then publish all resource types in `resource-types/` (and any enabled platforms in `platforms/`)
   - Ensure each bundle's OCI repository exists, then build and publish all bundles in `bundles/`

   > [!TIP]
   > To publish snapshot/dev versions on every PR push, enable [`publish-bundles-dev.yml.example`](./.github/workflows/publish-bundles-dev.yml.example) by renaming it. It runs `mass bundle publish --development` against any bundles changed in the PR.

#### OCI repositories

In Massdriver v2, every **bundle and every resource type** (platforms included) is published into its own OCI repository, and **the repository must exist before publish will succeed**. A repository is named exactly after the bundle or resource type it holds, and all repositories share a single namespace — so a bundle and a resource type cannot use the same name.

The CI workflows handle creation automatically — they call `mass repository create <name> -t bundle` (or `-t resource-type`) before each publish and ignore the "already exists" error. Locally, `make create-repos` does the same thing for everything in the catalog.

If a repository needs custom attributes (for example, `-a owner=data,service=database`), the workflow can't infer them. Create those repositories once by hand:

```bash
mass repository create my-bundle -t bundle -a owner=data,service=database
```

After that, normal pushes will keep publishing into the same repo.

#### Service account permissions

The service account behind `MASSDRIVER_API_KEY` needs to be able to:

- **Create OCI repositories** — required for the idempotent `mass repository create` step.
- **Publish to OCI repositories** — required for `mass bundle publish`.
- **Publish resource types** — required for `mass resource-type publish` (used for both `resource-types/` and `platforms/`).

In your Massdriver instance, grant the service account the role(s) that include these permissions before pointing CI at it. If the workflow fails on first run with an authorization error, this is almost always the cause.

#### Publish order on first run

`mass bundle build` resolves every `$ref:` in `connections:` / `artifacts:` against your Massdriver server, so resource types must already be published before any bundle that references them will build. The default GitHub Actions workflows are split by file path — pushing only `bundles/**` will not trigger the resource-types workflow. On a fresh catalog, run `make publish-resource-types` (or push a change under `resource-types/`) once before publishing bundles, or run `make all` locally to do both in order.

4. **Set up pre-commit hooks (optional but recommended)**

   ```bash
   pip install pre-commit
   pre-commit install
   ```

   This will automatically format JSON/YAML, validate Terraform, and check for common issues before each commit.

5. **Explore and customize**
   - Review resource types in `resource-types/`
   - Explore bundle schemas in `bundles/*/massdriver.yaml`

6. **Model your platform**

First publish the template bundles to your organization. After you get a feel for organization your resources in Massdriver, you'll update these modules with your IaC.

```bash
make all
```

- Open the Massdriver UI
- Create **projects** - Logical groupings of infrastructure that can reproduce environments. Examples include application domains ("ecommerce", "api", "billing") or platform infrastructure ("network", "compute platform", "data platform")
- Create **environments** within projects - Named environments ("dev", "staging", "production"), [preview environments](https://docs.massdriver.cloud/preview_environments/overview) ("PR 123"), or regional deployments ("Production US East 1", "US West 2")
- Add bundles to your **canvas** (the visual diagram where you design your architecture) — each placement creates an **instance** of that bundle
- **Connect** instances together—linking resources produced by one bundle to dependencies of another, passing configuration between provisioning pipelines (no copypasta! no brittle scripts!)
- Configure **parameters** to test what the developer experience feels like

7. **Implement infrastructure code**
   - When ready, replace placeholder code in `bundles/*/src/` with your OpenTofu/Terraform
   - Test locally with `tofu init` and `tofu plan` or run rapid infrastructure testing with [`mass bundle publish --development`](https://docs.massdriver.cloud/concepts/versions#rapid-infrastructure-testing)
   - Customize platform definitions to match your provider blocks, then publish them:
     ```bash
     make publish-platforms
     ```
   - Update schemas if your implementation needs different parameters

8. **Publish to Massdriver**

   **Automatic Publishing (Recommended)**: If you've configured GitHub Secrets and Variables (step 3), resource types and bundles are automatically published on push to `main`. Simply push your changes:

   ```bash
   git push origin main
   ```

   **Manual Publishing**: Alternatively, you can publish manually using the included Makefile:

   ```bash
   make all
   ```

   This command will:
   - Clean up any previous build artifacts
   - Ensure an OCI repository exists for every resource type and bundle (`make create-repos`)
   - Publish resource types to your Massdriver instance
   - Build all bundles (generates schema JSON files from `massdriver.yaml`)
   - Validate all bundles with OpenTofu, Helm, etc.
   - Publish all bundles to your Massdriver instance using your default `mass` CLI profile

   **Publishing** makes your resource types and bundles available in your Massdriver instance. Once published, you'll see them in the Massdriver UI and can add them to your environment canvases.

## Setting Up GCP

End-to-end walkthrough for connecting a Google Cloud project to Massdriver: install the CLI, create a GCP service account, point the CLI at your organization, publish the GCP platform resource type, and load the credential into Massdriver.

Substitute your own values for these throughout:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `PROJECT_ID` | GCP project ID (not the display name, not the number) | `cory-sandbox-362007` |
| `ORG_ID` | Massdriver organization ID, visible in the app URL | `the-aspen-group` |

### 1. Install the Mass CLI

```bash
brew install massdriver
```

Alternatives: [pre-built binaries](https://github.com/massdriver-cloud/mass/releases) or `go install github.com/massdriver-cloud/mass`.

Confirm you're on v2 — both the CLI and the server it's talking to:

```bash
mass version
```

### 2. Configure the CLI

The CLI reads `~/.config/massdriver/config.yaml`. Create it if it doesn't exist:

```yaml
version: 1
profiles:
  default:
    organization_id: ORG_ID
    api_key: md_your_service_account_key_here
    templates_path: /absolute/path/to/this/repo/templates
```

Get the API key from your Massdriver organization settings by creating a **service account**. `templates_path` is optional — set it if you want `mass bundle new` to use this repo's `templates/` directory.

You can define more than one profile and switch between them with `MASSDRIVER_PROFILE`:

```yaml
profiles:
  default:
    organization_id: ORG_ID
    api_key: md_...
  staging:
    organization_id: OTHER_ORG_ID
    api_key: md_...
```

```bash
MASSDRIVER_PROFILE=staging mass whoami
```

**Always confirm which organization you're operating on before publishing:**

```bash
mass whoami
```

```
🤖 Service account
   ID:   188fc62f-7007-443f-9ceb-acd8b73eb74e
   Name: Catalog Publisher
   Organization: The Aspen Group (the-aspen-group)
```

> [!WARNING]
> `mass whoami` is the authority on which organization a command will affect. If you have multiple profiles, or an editor/AI plugin configured with its own separate API key, they can point at **different organizations than your CLI default**. Publishing into the wrong org is silent — it succeeds, it just lands somewhere you didn't intend. Check `mass whoami` first.

If publish later fails with `You do not have permission to...`, the service account is authenticated but has no policies. Add it to a group: **Settings → Groups → Organization Admin → Service Accounts**. A brand-new organization does not place service accounts into any group automatically.

### 3. Create the GCP service account

Massdriver assumes a GCP service account to manage infrastructure in your project. All of this is in the Google Cloud Console — no `gcloud` install required.

**Enable the required APIs.** Open the link below, confirm the correct project is selected at the top of the page, and click **Enable**. This enables everything the Cloud Run stack needs — Cloud Run, Artifact Registry, VPC, Cloud SQL, Secret Manager, and Cloud Storage — in one pass:

```
https://console.cloud.google.com/flows/enableapi?apiid=run.googleapis.com,artifactregistry.googleapis.com,cloudresourcemanager.googleapis.com,iam.googleapis.com,iamcredentials.googleapis.com,compute.googleapis.com,servicenetworking.googleapis.com,vpcaccess.googleapis.com,sqladmin.googleapis.com,secretmanager.googleapis.com,storage.googleapis.com&project=PROJECT_ID
```

Enabling takes a minute or two.

**Create the service account** at `https://console.cloud.google.com/iam-admin/serviceaccounts/create?project=PROJECT_ID`:

1. **Name:** `massdriver` — the account ID fills in automatically. Click **Create and continue**.
2. **Grant access:** in the role dropdown, select **Owner**. Click **Continue**.
3. Leave the user-access section empty. Click **Done**.

**Create a key:**

1. From the service accounts list, click `massdriver@PROJECT_ID.iam.gserviceaccount.com`.
2. Open the **Keys** tab → **Add key** → **Create new key**.
3. Choose **JSON** → **Create**. The file downloads automatically.

> [!CAUTION]
> That JSON file is a long-lived credential with **owner** access to the entire GCP project. Never commit it to this repository. Delete it from your Downloads folder once it's uploaded to Massdriver.

> [!NOTE]
> **On `roles/owner`:** owner is the simplest starting posture and is what gets you running fastest. It is broader than most organizations want long-term. Once you know which bundles you're actually deploying, narrow the service account to the specific roles those bundles need (for the Cloud Run stack: `roles/run.admin`, `roles/artifactregistry.admin`, `roles/cloudsql.admin`, `roles/compute.networkAdmin`, `roles/secretmanager.admin`, `roles/iam.serviceAccountAdmin`, `roles/storage.admin`).

### 4. Publish the GCP platform resource type

Platform credentials are resource types, and in Massdriver v2 every resource type is published into an OCI repository that must exist first:

```bash
mass repository create gcp-service-account -t resource-type
mass resource-type publish platforms/gcp/massdriver.yaml
```

Or via the Makefile, which handles repository creation for you:

```bash
make publish-platforms ENABLED_PLATFORMS=gcp
```

Expected output:

```
✅ Repository `gcp-service-account` created (type: resource-type)
Resource type GCP Service Account published successfully!
```

`mass repository create` is safe to re-run — if the repository already exists it exits non-zero and the Makefile ignores it.

### 5. Load the credential into Massdriver

> [!IMPORTANT]
> **For GCP, use the CLI — not the UI dropzone.** The web uploader currently mangles the GCP key JSON on the way in (the `private_key` field is a PEM block containing literal `\n` escapes, and round-tripping it through the form breaks the key). A credential imported through the UI will look fine and then fail at deploy time with an authentication error. Import it with `mass resource create` instead. Other platforms are unaffected — this is specific to the GCP key format.

The key file Google gave you already matches the `gcp-service-account` schema field-for-field, so it can be imported as-is:

```bash
mass resource create \
  -n my-gcp-project \
  -t gcp-service-account \
  -f ~/Downloads/PROJECT_ID-abc123.json
```

- `-n` — the name this credential appears under in Massdriver. Use something that identifies the GCP project it grants access to.
- `-t` — the resource type published in step 4.
- `-f` — path to the JSON key downloaded in step 3.

Verify it landed in the right organization:

```bash
mass resource list
```

If the resource type isn't found, step 4 didn't land in this organization — re-check `mass whoami`.

Once imported, the credential shows up in the Massdriver UI at `https://app.massdriver.cloud/orgs/ORG_ID/` under **Credentials**, is available as an environment default, and can be attached to any environment in this organization.

Delete the local JSON key file once the import succeeds.

### 6. Grant projects access to the credential

Importing the credential does **not** make it usable. A resource in Massdriver is private to the organization until it is explicitly shared, so until you add a grant the GCP service account will not appear as a selectable credential when you build out a project — the environment will simply show nothing to connect to.

In the Massdriver UI, open the credential you imported in step 5, go to its **grants / sharing** settings, and add the **`resource:export`** action. `resource:export` is what allows a project to consume the resource as a dependency; visibility follows automatically from the grant.

You have two choices about scope:

- **Organization-wide** — add `resource:export` with no conditions. Every project in the organization can use this GCP service account. Simplest, and usually right for a sandbox or a single-cloud-account setup.
- **Scoped to specific projects** — add `resource:export` with **recipient conditions**, which restrict the grant by attribute (for example, only projects tagged for a given team, environment class, or data classification). This is how you keep a production GCP account from being reachable by every project in the org.

Scoped grants match on **custom attributes**, so the attributes you want to filter on must already be declared on the organization and set on the recipient projects — a condition that references an attribute key the organization doesn't define is silently dropped, which quietly widens the grant to everyone. Declare and set your attributes first, then add the conditional grant, then confirm the credential is visible from a project you *expect* to have access and invisible from one you don't.

Repeat this for every credential you import — each GCP service account is granted independently.

### 7. Deploy the Cloud Run stack

With the credential imported and granted, publish the catalog and stand the platform up. Order matters
on a fresh organization: resource types must exist before any bundle that references them will build.

```bash
make publish-resource-types
make all
```

#### Create a project and environment

In the UI, create a project, then an environment inside it. Attach the GCP credential you imported in
step 5 as an **environment default** so every bundle on the canvas inherits it instead of asking each
developer to select a credential.

#### Stand up the platform tier first

Add these two, configure them, and deploy. Your application developers will never place these — you do
it once per environment.

1. **`gcp-network`** — pick a CIDR range that does not collide with anything you peer to later. The
   defaults give you a subnet, a Private Service Access range for Cloud SQL, and a Serverless VPC
   Connector for Cloud Run.
2. **`gcp-artifact-registry`** — the repository application images are pushed into.

Deploy both before continuing. Everything in the application tier assumes they exist.

> [!TIP]
> The Serverless VPC Connector name is derived from the instance name prefix, and GCP caps connector
> names at 25 characters. A long project or environment name can push it over the limit; the bundle
> truncates, but it is worth knowing if you see a name-length error on first deploy.

#### Scaffold an application

Generate a bundle for the application from the template, so it gets its own schema, runbook, and version
history:

```bash
mass bundle new --name checkout-api --template-name gcp-cloud-run
```

Replace the contents of `build/app/` with the application source. It ships with a small working example
(a `Dockerfile` and a minimal HTTP server) so you can deploy the scaffold unmodified to confirm the
pipeline works before pointing it at real code. Then:

```bash
cd checkout-api
mass bundle publish --development
```

`--development` publishes a dev-channel version for rapid iteration. Instances pinned to `@latest+dev`
pick it up on the next deploy.

#### Wire it up on the canvas

Add the application bundle plus whatever data services it needs, then connect them:

| Connect from | To | Why |
|---|---|---|
| `gcp-artifact-registry` → registry | app → container registry | where the built image is pushed and pulled |
| `gcp-network` → network | `gcp-cloud-sql-postgres` → network | database gets a private IP on your VPC |
| `gcp-cloud-sql-postgres` → database | app → database | connection details injected at deploy |
| `gcp-cloud-storage-bucket` → bucket | app → bucket | bucket name and access injected |
| `gcp-firestore` → database | app → firestore | Firestore database injected |

Deploy the data services, then the application last.

#### What happens on deploy

The application bundle runs in two steps. The first archives `build/app/`, uploads it, and runs a Cloud
Build that produces the image and pushes it to Artifact Registry. The second deploys that image to Cloud
Run. Both steps derive the same image tag from `md_metadata.package.deployment_enqueued_at`
independently, so neither depends on the other's outputs.

Nothing is built on the developer's machine — no `docker`, no `gcloud`.

When the deploy finishes, the service's public URL is on the instance's resource, ready to `curl`.

> [!NOTE]
> The first deploy in a brand-new GCP project is the one most likely to fail, and it is almost always
> IAM propagation rather than a bundle defect: the Cloud Build service account needs `storage.objectViewer`
> on the staging bucket, and the caller needs `iam.serviceAccountUser` on the build service account.
> Each bundle's `operator.md` covers its own failure modes in detail.

## Workflow

This catalog is designed for a three-phase approach: model your architecture, implement the infrastructure code, then continuously improve.

### Phase 1: Architecture Modeling (Now)

1. Use the provided resource types and bundle schemas as-is (no infrastructure code needed yet)
2. Create projects and environments in the Massdriver UI
3. Add bundles to your canvas (creating instances)
4. Connect them by linking resources produced by one bundle to the dependencies of another
5. Configure parameters to test what the developer experience feels like
6. Iterate on resource types and bundle scopes until they feel right

**Goal**: Understand what services you want to offer, how they connect, and what the developer experience should be. You're designing the self-service platform interface _before_ writing any infrastructure code.

**Key insight**: This phase is about discovering the right abstractions. Does it make sense to have separate `postgres` and `mysql` bundles? Should your network bundle produce separate "public subnet" and "private subnet" resources, or one combined "network" resource? The schemas let you explore these questions quickly without committing to implementation details.

**Don't aim for perfection—aim for feedback.** Get a working version in front of your developers and iterate based on their input. The abstractions that make sense on paper often need refinement once developers actually use them. You can always add more bundles, refine parameters, or adjust resource types later. Real developer feedback is more valuable than theoretical perfection.

### Phase 2: Implementation (When Ready)

> [!TIP]
> Check out the [Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview) for detailed documentation on bundle and resource type development.

1. Write the OpenTofu/Terraform for any new bundles you add in `bundles/<name>/src/`
2. Test your infrastructure code locally with `tofu plan`
3. Update parameter schemas if your implementation needs different inputs
4. Push to `main` to automatically publish bundles via GitHub Actions, or use `make all` for manual publishing
5. Deploy instances to test environments and validate everything works

**Goal**: Fill in the infrastructure code that matches your architectural model.

**Key benefit**: Because you already validated the architecture and developer experience in Phase 1, you're implementing against a proven design. You know what parameters developers need, what connections make sense, and what resources to produce.

### Phase 3: Continuous Improvement

1. Add more bundles as needed
2. Create custom resource types for your organization
3. Refine parameter validation and UI schemas
4. Use [release channels and strategies](https://docs.massdriver.cloud/concepts/versions#release-channels) to automate version distribution and upgrades across environments
5. 👋 Say farewell to ticket ops

## Repository Structure

```
.
├── README.md                           # This file
├── Makefile                            # Automation for publishing
├── preview.yaml                        # Preview environment fork config (see docs.massdriver.cloud/workflows/preview)
├── resource-types/                     # Resource type contracts (formerly artifact definitions)
│   ├── network/                        # VPC + subnets + private service access
│   ├── serverless-connector/           # Serverless VPC connector
│   ├── container-registry/             # Container image registry
│   ├── postgres-database/              # PostgreSQL connection details
│   ├── object-storage/                 # Object storage bucket
│   ├── firestore-database/             # Firestore document database
│   └── cloud-run-service/              # Running service + public URL
├── bundles/                            # Infrastructure-as-Code modules
│   ├── gcp-network/                    # PLATFORM: VPC, PSA, serverless connector
│   ├── gcp-artifact-registry/          # PLATFORM: container image registry
│   ├── hello-cloud-run/                # APP: worked example from the template
│   ├── gcp-cloud-sql-postgres/         # APP: managed PostgreSQL, private IP only
│   ├── gcp-cloud-storage-bucket/       # APP: object storage
│   └── gcp-firestore/                  # APP: Firestore database
├── templates/                          # Bundle templates for mass bundle new
│   ├── gcp-cloud-run/                  # Two-step build-in-GCP + deploy to Cloud Run
│   ├── opentofu/                       # OpenTofu module template
│   ├── terraform/                      # Terraform module template
│   ├── bicep/                          # Azure Bicep template
│   └── helm-chart/                     # External Helm chart template
└── platforms/                          # Cloud-credential resource types (split out for discoverability)
    ├── aws/                            # IAM Role
    ├── azure/                          # Service Principal
    ├── gcp/                            # Service Account
    ├── kubernetes/                     # Cluster auth + kubeconfig
    └── .../                            # + add any cloud your IaC supports
```

## Customization Guide

### Resource Types

[Resource types](https://docs.massdriver.cloud/concepts/resource-types) in `resource-types/` define the contracts between bundles—what data gets passed from one to another. (Massdriver's docs may still link these as "artifact definitions"; that's the v1 name.) See the docs for the complete schema reference.

Customize resource types to:

- **Pass connection info between bundles** - A database bundle outputs hostname, port, credentials. An application bundle receives those as inputs and can connect immediately.
- **Validate data before it's used** - Ensure CIDR blocks are valid IP ranges, database names match naming rules, or ports are in valid ranges. Catch config errors before provisioning.
- **Mark sensitive fields** - Use `$md.sensitive: true` on passwords, API keys, certificates. They get masked in UIs and logs but are available to bundles that need them.

> [!TIP]
> When you standardize what your bundles produce—defining consistent resource type schemas—you can automate compliance and security policies across all resources of that type. This eliminates the brittle copy-paste scripts and custom glue code typically needed to wire infrastructure together, replacing them with validated, reusable contracts.

### Bundle Schemas

Each bundle's `massdriver.yaml` defines the complete contract for that infrastructure component. See the [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for the complete schema reference.

- **params**: Input parameters that users configure when deploying (instance sizes, database names, feature flags, etc.). These become variables in your IaC code. They provide extra UI controls and validations not available in most IaC tools.

- **connections** (the v1 key, surfaced in the v2 product as **dependencies**): Input resources that this bundle depends on. For example, a database bundle might require a connection to a virtual-network resource. Connections securely pass data (credentials, IAM policies, endpoints) from one bundle to another during provisioning. These become variables in your IaC code, and Massdriver validates that only compatible resources can be connected.

- **artifacts** (the v1 key, surfaced in the v2 product as **resources**): Output resources that this bundle produces for other bundles to consume. For example, a database bundle produces a database resource containing connection details. You populate these in your IaC code's outputs.

- **ui**: UI schema that controls how the configuration form is rendered—field ordering, help text, conditional visibility, custom widgets, etc. This follows the React JSON Schema Form specification.

> [!NOTE]
> The keys `connections:` and `artifacts:` keep their v1 names inside `massdriver.yaml`. Backward-compatible renames to `dependencies:` and `resources:` are coming in a future release; for now, every bundle and template in this repo uses the v1 keys.

> [!WARNING]
> Params and connections share the same namespace in your IaC code. If you have a param named "database" and a connection named "database", they will conflict as the same variable (e.g., `variable "database"` in Terraform). Use distinct names to avoid collisions.

Customize these schemas to match your desired developer experience. The schemas define the self-service interface your developers will use, so invest time in making them clear, well-documented, and user-friendly.

### Bundle Implementation

When you add a bundle of your own, its OpenTofu/Terraform goes in `bundles/<name>/src/`. (The GCP
bundles shipped in this catalog are already fully implemented — read them as worked examples rather
than as scaffolding to replace.)

**How it works**: Massdriver bundles combine policy as code, IaC, and pipelines into a single deployable unit. They define the interface (inputs/outputs), dependencies (connections), and workflow steps—bringing compliance and security scanning into the bundle itself, instead of maintaining snowflake pipelines scattered across hundreds of repos. Massdriver automatically generates input variables from your params and connections schemas, then executes your IaC code with those values.

To implement a bundle:

1. **Keep** the `_massdriver_variables.tf` file - it's auto-generated by `mass bundle build` from your schemas. (Optional: You can stop defining variables directly in OpenTofu/Terraform/Bicep and just define them in `massdriver.yaml`. The build process will generate them.)
2. **Replace** `main.tf` with your infrastructure code
3. **Add** additional `.tf` files as needed (variables.tf, outputs.tf, etc.)
4. **Use** Massdriver-provided variables:
   - [`var.md_metadata`](https://docs.massdriver.cloud/getting-started/using-bundle-metadata#md_metadata-structure) - Massdriver metadata (name prefix, instance ID, environment, default tags, etc.)
5. **Output** resource data that matches your `artifacts:` schema (connection details, resource IDs, etc.)

**Example**: If your params schema defines a `database_name` parameter, access it in Terraform as `var.database_name`. If your `connections:` schema requires a `network` resource named `net`, access its VPC ID as `var.net.vpc_id`.

> [!IMPORTANT]
> In v2, connection and resource payloads are **flat**. There is no `data:` or `specs:` envelope — a
> field declared as `vpc_id` is read as `var.net.vpc_id`, not `var.net.data.infrastructure.vpc_id`.
> If you are porting a v1 bundle, this is the change most likely to bite you, because the old path
> fails at plan time with an unhelpful "this object does not have an attribute named" error.

## What's Next?

### Learn More About Massdriver

Once you've modeled your architecture and started implementing bundles, dive deeper into Massdriver with our comprehensive getting started guide:

- 📚 **[Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview)** - Step-by-step tutorials covering:
  - Publishing and deploying bundles
  - Connecting bundles with artifacts
  - Creating bundles from existing OpenTofu/Terraform modules
  - Using bundle deployment metadata for tagging and naming

- 💻 **[Getting Started Repository](https://github.com/massdriver-cloud/getting-started)** - Example bundles with detailed walkthroughs that teach you:
  - How to work with the Mass CLI
  - Bundle development best practices
  - Real-world patterns and techniques

These resources complement this catalog by showing you how to work with bundles once you have them implemented.

### Automation

- 🚀 **[GitHub Actions](https://github.com/massdriver-cloud/actions)** - This repository includes pre-configured workflows (using `actions/setup@v6`, the v2-compatible release) that automatically publish resource types and bundles on push to `main`. See the [Quick Start](#quick-start) section for setup instructions.

## Best Practices

### Do ✅

- **Start with modeling**: Use the schemas to plan before implementing
- **Single-purpose bundles**: Keep bundles focused (e.g., `postgres`, not `rds`)
- **Iterate on abstractions**: Refine resource types based on usage
- **Test the developer experience**: Configure bundles in the UI before implementing
- **Version your bundles**: Use semantic versioning for stable releases

### Don't ❌

- **Rush to implementation**: Model your architecture first
- **Create generic bundles**: Be specific about use cases
- **Skip documentation**: Update descriptions and help text
- **Ignore validation**: Use JSON Schema to prevent errors
- **Forget about UI**: Good UX makes adoption easier

## Resources

- 🌐 **[Massdriver Documentation](https://docs.massdriver.cloud)** - Official documentation
- 📚 **[Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview)** - Getting started with bundle development
- 💻 **[Getting Started Repository](https://github.com/massdriver-cloud/getting-started)** - Accompanying code
- 🎯 **[Core Resource Types](https://github.com/massdriver-cloud/artifact-definitions)** - Standard resource types in the Massdriver SaaS Platform (the upstream repo is still named `artifact-definitions`). Great to use as inspiration or a foundation.
- 💬 **[Massdriver Slack](https://massdriver.cloud/slack)** - Community support

## Support

Questions or issues?

- Review existing bundle schemas for patterns in this catalog
- Check out the [Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview) for detailed tutorials
- Join our [Slack community](https://massdriver.cloud/slack) for help
- Reach out to Massdriver support

## License

Private repository - customize for your organization's needs.

---

**Remember**: This catalog is your platform foundation. Clone it, customize it, make it yours. The goal is to help you think through architecture and developer experience before writing infrastructure code. Start modeling today, implement tomorrow.
