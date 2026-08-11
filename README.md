# Massdriver Catalog

This catalog is a bootstrap kit for self-hosted Massdriver instances. It contains resource types, infrastructure bundles, and cloud credentials. Use this catalog to model your platform architecture and developer experience. Do this before you write infrastructure code.

**This repository is your platform foundation.** It is your platform team's source of truth for resource types and bundles. Use it to design your infrastructure architecture, improve the developer experience, and refine your abstractions. Add your OpenTofu or Terraform implementation when you are ready.

> [!NOTE]
> **Massdriver v2:** This catalog works with Massdriver v2 (Mass CLI version `2.0.0` or higher, GraphQL `/v2/`). Massdriver v2 renamed these core concepts:
> - `targets` → **environments**
> - `packages` → **instances**
> - `artifact definitions` → **resource types**
> - `artifacts` → **resources**
>
> The keys `connections:` and `artifacts:` in `massdriver.yaml` stay the same. A future release will add backward-compatible renames to `dependencies:` and `resources:`. Until then, this repository uses `connections:` and `artifacts:` in every `massdriver.yaml` file, with a comment that points to the new names.

**Summary:** [Jump to Quick Start](#customizing-your-catalog)

## Quick Start Workflow

You can customize and extend this catalog. Follow this workflow:

1. **Clone this repository** to your organization. Keep it private. It will contain your infrastructure code.
2. **Configure GitHub Secrets** (see [Quick Start](#quick-start)). This enables automatic publishing on push to `main`.
3. **Experiment** with bundles in your editor. Edit schemas, add parameters, and define connections.
4. **See the developer experience appear** in Massdriver as you iterate on your abstractions.

This approach lets you refine the developer experience before you write infrastructure code. You can test what parameters developers see, how bundles connect, and what resources bundles produce.

## Key Concepts

If you are new to Massdriver, learn these core concepts first:

- **Bundle**: A reusable, versioned definition of infrastructure or application components. A bundle contains your IaC code (Terraform, OpenTofu, or Helm), configuration schemas, dependencies, and policies in one deployable unit. Each bundle is an infrastructure package with built-in policy checks.

- **Resource Type** (formerly *artifact definition*): A JSON Schema contract that defines how infrastructure components connect to each other. Resource types enforce type safety. You cannot connect incompatible components.

- **Resource** (formerly *artifact*): A live resource type instance that a deployed bundle emits. For example, when you deploy a PostgreSQL bundle, it emits a PostgreSQL resource. That resource contains connection details that other bundles can use.

- **Parameters (params)**: User-configurable inputs for a bundle, such as instance sizes, database names, or feature flags. Params define what developers can customize when they deploy infrastructure.

- **Connections** (the `connections:` key in `massdriver.yaml`; the product shows these as **dependencies**): Inputs a bundle needs from other bundles. When a bundle declares that it needs a connection to a `network` resource, you must link it to a bundle that produces a network resource.

- **Project**: A logical group of related infrastructure, such as "ecommerce-platform" or "data-pipeline". A project contains one or more environments.

- **Environment** (formerly *target*): A deployment context within a project, such as "development", "staging", or "production". Each environment has its own canvas, where you design and deploy infrastructure.

- **Canvas**: The visual diagram in the Massdriver UI. On the canvas, you add bundles, connect them, and configure parameters.

- **Instance** (formerly *package*): A configured deployment of a bundle in a specific environment. When you add a bundle to your canvas and configure it, you create an instance. A bundle is the reusable definition. An instance is the deployed result.

## What's Inside

### 📁 `resource-types/`

**Resource types** (formerly called *artifact definitions*) are schema-based contracts. They define how infrastructure components interact with each other in Massdriver. A resource type is a type definition for your infrastructure. It ensures that when you connect a database to an application, both sides use the same data format.

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

> **💡 Note on Sensitive Fields**: Resource types support the [`$md.sensitive`](https://docs.massdriver.cloud/json-schema-cheat-sheet/massdriver-annotations#mdsensitive) annotation. Use it to mark fields that contain credentials, passwords, or other secrets. Massdriver masks sensitive fields as `[SENSITIVE]` in GraphQL queries and UI displays. Bundles can still use these fields for actual infrastructure connections. Massdriver encrypts all resource data at rest and in transit, and it records downloads of sensitive data in audit logs.

**⚠️ These are examples to get you started.** Edit these schemas to match your organization's infrastructure patterns and the data your bundles need to exchange. The field names, structure, and validation rules must match what your actual OpenTofu or Terraform code produces and consumes.

**Why they matter**: Resource types enforce type-safe infrastructure composition. The system checks compatibility at design time, before you deploy any infrastructure. The system does not let you connect a PostgreSQL resource to a bundle that expects MySQL.

Use these example resource types to:

- Define the contract between your IaC modules (what data passes from one module to another)
- Model how services connect in your architecture
- Design your project and environment structure
- Plan the developer experience before you write infrastructure code
- **Then customize them** to match your organization's specific needs

### 📁 `bundles/`

**Bundles** are reusable, versioned definitions of cloud infrastructure or application components. A bundle contains everything needed to provision and manage a piece of infrastructure: the IaC code, configuration schemas, dependencies, outputs, and policies.

Bundles give you a self-service framework. The platform team encodes best practices into ready-to-use modules. Developers get a simple interface to deploy what they need.

This catalog ships a working GCP Cloud Run platform. It splits into two tiers by audience:

**Platform tier** — owned by the platform team. Application developers do not place these bundles
themselves. These bundles use infrastructure terms, because an infrastructure engineer reads them.

- `gcp-network/` - VPC, subnets, private service access for Cloud SQL, and a serverless VPC connector
- `gcp-artifact-registry/` - Container image registry that application builds push into

**Application tier** — self-service on the canvas. These bundles are written for someone who has never
worked with a VPC before. Dangerous options are defaulted or hidden, and the help text avoids
infrastructure jargon.

- `hello-cloud-run/` - A worked example generated from the `gcp-cloud-run` template
- `gcp-cloud-sql-postgres/` - Managed PostgreSQL, private IP only
- `gcp-cloud-storage-bucket/` - Object storage for uploads, exports, and files
- `gcp-firestore/` - Firestore document database

Each bundle includes:

- ✅ Complete `massdriver.yaml` configuration
- ✅ **Parameter schemas** - Define your IaC variables (tfvars, Helm values). Customize the UI form for user configuration (instance sizes, database names, and so on).
- ✅ **Connection schemas** (the `connections:` key — the product shows these as **dependencies**) - Define resources from other bundles that this bundle needs. This gives the bundle secure access to their details during automation.
- ✅ **Artifact schemas** (the `artifacts:` key — the product shows these as **resources**) - Define what infrastructure this bundle produces for other bundles to use.
- ✅ **UI schemas** - Control how the configuration form looks and behaves
- 🚧 Placeholder OpenTofu/Terraform code (replace with yours)

> [!NOTE]
> The `connections:` and `artifacts:` keys keep their v1 names inside `massdriver.yaml`. A future release will add backward-compatible renames to `dependencies:` and `resources:`. Until then, use the v1 keys here.

These bundles let you model first and implement later. Use the schemas to plan your architecture and test the developer experience in the Massdriver UI. Then add the actual infrastructure code when you are ready.

For more details, see the [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) and [Module Patterns](https://docs.massdriver.cloud/guides/module-patterns) guides.

### 📁 `templates/`

**Bundle templates** are starter scaffolds for new bundles. Use the Massdriver CLI with a template to create a new infrastructure module. The new module has the correct structure and boilerplate.

Available templates:

| Template | Provisioner | Description |
|----------|-------------|-------------|
| `gcp-cloud-run` | OpenTofu | Build a container in GCP and deploy it to Cloud Run (two-step) |
| `opentofu` | OpenTofu | OpenTofu module template |
| `terraform` | Terraform | Terraform module template |
| `bicep` | Bicep | Azure Bicep template |
| `helm-chart` | Helm | Deploy external Helm charts |

Use `gcp-cloud-run` when you onboard a new application. This template gives the application its own
bundle: its own schema, its own runbook, and its own version history. Teams do not need to share one
generic "app" bundle and adjust it to fit each use case:

```bash
mass bundle new --name checkout-api --template-name gcp-cloud-run
```

Add the application's source to `build/app/`. This directory ships with a small working example. Then
publish the bundle. The developer does not install `docker` or `gcloud`. See
[Building without Docker](#building-without-docker-or-gcloud).

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

**Platform integrations** are resource types. They model the credentials Massdriver uses to connect to your cloud providers and infrastructure platforms. They live in their own directory, separate from `resource-types/`, so they are easy to find. You publish them the same way, with `mass resource-type publish`. Each platform directory contains everything needed to authenticate with that platform and interact with it.

> [!TIP]
> **Customize these to match how *you* authenticate.** The platform schemas in this catalog are a starting point, not a fixed rule. Your team might authenticate AWS with static access keys instead of an assumed IAM role. If so, replace the schema in `aws/massdriver.yaml` with the fields your `aws` provider block actually uses. If you use a managed identity for Azure, workload identity federation for GCP, or an OIDC token for Kubernetes, model that here instead.
>
> The fields in `schema:` must match the inputs to your IaC tool's provider configuration (Terraform or OpenTofu provider blocks, Helm `kubeconfig`, and so on). Massdriver collects those values and passes them to your bundles at deploy time. Update `instructions/` with your team's onboarding steps, so developers know what to paste where.

Massdriver can manage any platform your IaC tooling supports. To add a new platform, such as Snowflake, Datadog, or Confluent Cloud, you only need to define its credential schema.

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

The `schema` section must match your OpenTofu or Terraform provider authentication configuration. For example, AWS IAM Role credentials match the `aws` provider's `assume_role` block. Azure Service Principal credentials match the `azurerm` provider configuration.

**Export Templates** (optional): The `exports/` directory enables self-service resource downloads. With export templates, developers can download pre-configured files built from deployed resource data. Examples: a kubeconfig file from a Kubernetes cluster credential, VPN configuration files with certificates, database connection strings, or environment variable files for local development.

Templates use Liquid syntax. Each template can read the full artifact payload through the `artifact` variable. When a developer clicks the download button in the Massdriver UI, Massdriver renders the template with that developer's specific artifact data. Massdriver then downloads the result as a ready-to-use configuration file.

You define export configuration in the `massdriver.yaml` file:
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

This template reads fields from the deployed artifact's `data` payload. Developers can download correctly configured files right away. They do not copy and paste data by hand.

> **Note**: The `massdriver.yaml` format used here is a prototype. Future versions of Massdriver may adopt a more declarative authoring experience based on it.

**Included platforms**:

- `aws/` - AWS IAM Role authentication
- `azure/` - Azure Service Principal authentication
- `gcp/` - GCP Service Account authentication
- `kubernetes/` - Kubernetes cluster connection

**Extending Massdriver**: Your platform team can add support for any cloud or SaaS platform. Create a new platform directory and define its `massdriver.yaml` file. Design the `schema` section to match your OpenTofu provider or Helm authentication configuration. Massdriver captures those credential values and passes them securely to your automation workflows.

Update your supported cloud platforms and onboarding instructions with:

```bash
make publish-platforms
```

This compiles the `massdriver.yaml` definitions into `dist.json` artifacts for publishing.

### 📄 `preview.yaml`

**Preview environments** are short-lived environments. Massdriver forks them from a base environment, typically `production` or `staging`. Use a preview environment to stand up a full stack for a pull request, a demo, or a one-off experiment. You do not wire each instance by hand. Massdriver clones the canvas, then applies the overrides you declare in `preview.yaml`. You can pin specific bundle versions, use cheaper instance sizes, scope secrets, and set values from environment variables like `${GITHUB_PR}`.

The `preview.yaml` file at the repository root is a working example. You can adapt it:

- **`project` / `baseEnvironment`** — which environment to fork from.
- **`attributes`** — ABAC tags for the new environment (lifecycle, branch, region).
- **`environmentDefaults`** — pin shared resources, such as a Kubernetes cluster. The preview reuses these resources; it does not clone them.
- **`instances`** — per-instance overrides for `version`, `params`, and `secrets`. An instance listed without overrides inherits from the fork. An instance omitted from the file is still cloned from the parent.

Use it from CI, typically in a `pull_request` GitHub Action, to fork the environment:

```bash
mass environment preview "pr${GITHUB_PR}" -f preview.yaml
```

When the PR closes, decommission and delete the environment:

```bash
mass environment decommission "pr${GITHUB_PR}" --follow
mass environment delete "pr${GITHUB_PR}"
```

See the [Preview Environments workflow guide](https://docs.massdriver.cloud/workflows/preview) for the full CLI reference, CI examples, and the complete `preview.yaml` schema.

## Tour of the GCP Cloud Run Platform

This catalog ships a complete, working Cloud Run platform. It does not ship schema mockups. Every
bundle below has real OpenTofu code, a runbook, and a Checkov policy posture. You can use the bundles
as they are, or you can read them as worked examples when you build your own.

The platform follows one design rule. **A developer must be able to ship a service without knowledge of
a VPC, and without installing any tool.** Every design decision below follows this rule.

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

Developers place components on the right side of the diagram and connect them. The platform team places
the left side once. After that, the platform team rarely changes it.

### Platform tier

This tier is written for an infrastructure engineer. It uses real operations vocabulary on purpose:
CIDR ranges, secondary ranges, private service access, and retention windows. In a network bundle,
vague language causes more problems than technical terms.

**`gcp-network/`** — the foundation. It creates a VPC with subnets and a Private Service Access range.
Cloud SQL uses this range to connect over a private IP address. It also creates a Serverless VPC
Connector, so Cloud Run can reach private resources. It emits a `network` resource and a
`serverless-connector` resource.

**`gcp-artifact-registry/`** — a Docker-format Artifact Registry repository. Application builds push
images into this repository. Cloud Run pulls images from it. It emits a `container-registry` resource.

### Application tier

This tier is written for someone who has never worked with a VPC. Dangerous options are defaulted or
hidden; they are not shown with a warning. The help text uses plain English.

**`gcp-cloud-run/` (template) and `hello-cloud-run/` (worked example)** — the main application bundle.
See [Building without Docker](#building-without-docker-or-gcloud). It emits a `cloud-run-service`
resource. This resource includes the service's public URL.

**`gcp-cloud-sql-postgres/`** — managed PostgreSQL on a **private IP address only**. There is no
public-IP option, so you cannot select it by mistake. It connects to `gcp-network` and uses its Private
Service Access range. Presets range from a small development instance to a regional-HA production
instance.

**`gcp-cloud-storage-bucket/`** — a bucket with uniform bucket-level access. Public-access prevention is
on by default. Versioning, access logging, and CMEK are optional.

**`gcp-firestore/`** — a Firestore database in Native mode. Point-in-time recovery and delete protection
default to on. Location and mode are marked immutable, because GCP does not let you change them after
creation. A form that appeared to allow this change would mislead the user.

### Building without Docker or gcloud

One constraint shaped the Cloud Run design: **developers do not have `docker` or `gcloud` installed, and
a self-service platform must not require either tool.** So Massdriver builds the image inside GCP.

`gcp-cloud-run` is a **two-step bundle**:

1. **`build/`** — archives the application source from `build/app/`. It uploads the archive to a staging
   bucket. It runs a Cloud Build job that produces the container image and pushes the image to Artifact
   Registry.
2. **`deploy/`** — deploys that image as a Cloud Run service.

The two steps share `md_metadata`. Each step **independently derives the same image tag** from
`md_metadata.package.deployment_enqueued_at`; the steps do not pass the tag between them. Understand this
before you modify either step. It keeps the two steps decoupled. The tag stays the same for a given
deployment, and neither step depends on the other step's output.

A stale image is the failure that is hardest to notice. For this reason, the deploy step waits for the
specific build that matches the current tag. It does not assume that the most recent image is correct.

### Two audiences, two vocabularies

The same idea is described differently, depending on who reads the form. This is intentional. Keep this
pattern if you extend the catalog:

| Concept | Platform tier says | Application tier says |
|---|---|---|
| Serverless VPC connector | "Serverless VPC Connector, /28 CIDR, min/max instances" | (hidden — connected automatically) |
| Private Service Access | "PSA allocated range, `/16`–`/24`, peered to `servicenetworking`" | "Your database is only reachable from your own services" |
| Cloud Run concurrency | — | "How many requests one copy of your app handles at once" |
| Deletion protection | "`deletion_protection`, blocks `terraform destroy`" | "Protect this from being deleted by accident" |

### Compliance posture

Checkov runs against every bundle. This catalog follows one rule: **skip a check only when it is
irrelevant in every environment.** Every other finding is either fixed in the code, or gated so that it
fails the build in production while staying configurable in development.

This gating enforces the policy in production. A blanket skip also applies to production, without
warning. When a check is skipped, the `.checkov.yml` entry states a factual reason. For example: the
attribute the check inspects no longer exists in the current provider version, and another control
enforces the same rule. The entry does not state a preference.

### `resource-types/*/instructions/`

A resource type can ship form-fill walkthroughs, one per source. Massdriver renders each walkthrough
next to the resource creation form in the UI. A walkthrough tells an operator how to find each schema
field's value on an existing cloud resource. `container-registry/` has one. The other resource types are
candidates for a walkthrough if you plan to import existing infrastructure. `platforms/<cloud>/instructions/`
uses the same pattern.

> [!NOTE]
> The bundle `src/*.tf` files use `massdriver_resource` and `massdriver_instance_alarm` from
> `massdriver-cloud/massdriver ~> 2.0`. `massdriver_resource` replaces the deprecated
> `massdriver_artifact`, which provider v2.0 removed.

## Customizing Your Catalog

### Prerequisites

- Self-hosted Massdriver instance running **server v2.0.0 or higher**
- [Massdriver CLI (`mass`)](https://docs.massdriver.cloud/cli) **v2.0.0 or higher**, installed and authenticated
- OpenTofu or Terraform installed (to implement bundles)

> [!IMPORTANT]
> This catalog works with Massdriver v2 (CLI v2 and GraphQL `/v2/`). Check your CLI version with `mass version`. This command also reports the connected server version. If you are still on v1, upgrade both the server and the CLI before you publish. In v2, OCI repositories work differently, and v1 publish flows will not work.

> [!TIP]
> **Claude Code Users**: Install the Massdriver Claude Code Plugin. It adds AI-assisted bundle development, with built-in policy checks, patterns, and validation rules:
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

   Replace `YOUR_ORG` with your GitHub organization name throughout the repository. This updates the `source_url` fields in bundles and the links in operator runbooks. Both then point to your repository.

3. **Configure GitHub Secrets and Variables**

   This repository includes GitHub Actions workflows. They automatically publish resource types and bundles to your Massdriver instance on push to `main`. To enable this, configure the following in your GitHub repository:

   **Required Secrets** (Settings → Secrets and variables → Actions → Secrets):
   - `MASSDRIVER_API_KEY` - Your Massdriver service-account API key. See [Service account permissions](#service-account-permissions) below for the permissions this account needs.

   **Required Variables** (Settings → Secrets and variables → Actions → Variables):
   - `MASSDRIVER_ORG_ID` - Your Massdriver organization ID. You can find this in your Massdriver instance URL or in the organization settings.

   **Optional Variables** (for self-hosted instances):
   - `MASSDRIVER_URL` - The API URL of your self-hosted Massdriver instance, for example `https://api.massdriver.yourdomain.com`. If you do not set it, it defaults to `https://api.massdriver.cloud`.

   After you configure this, every push to the `main` branch triggers these actions:
   - Check that each resource type's OCI repository exists, then publish all resource types in `resource-types/` (and any enabled platforms in `platforms/`)
   - Check that each bundle's OCI repository exists, then build and publish all bundles in `bundles/`

   > [!TIP]
   > To publish snapshot or development versions on every PR push, rename [`publish-bundles-dev.yml.example`](./.github/workflows/publish-bundles-dev.yml.example) to enable it. It runs `mass bundle publish --development` on any bundle changed in the PR.

#### OCI repositories

In Massdriver v2, Massdriver publishes every **bundle and every resource type** (platforms included) into its own OCI repository. **The repository must exist before publish can succeed.** A repository takes the exact name of the bundle or resource type it holds. All repositories share one namespace, so a bundle and a resource type cannot use the same name.

The CI workflows create repositories automatically. Before each publish, they call `mass repository create <name> -t bundle` (or `-t resource-type`) and ignore the "already exists" error. Locally, `make create-repos` does the same thing for everything in the catalog.

If a repository needs custom attributes, for example `-a owner=data,service=database`, the workflow cannot infer them. Create those repositories once by hand:

```bash
mass repository create my-bundle -t bundle -a owner=data,service=database
```

After that, normal pushes keep publishing into the same repository.

#### Service account permissions

The service account behind `MASSDRIVER_API_KEY` must be able to do the following:

- **Create OCI repositories** — required for the idempotent `mass repository create` step.
- **Publish to OCI repositories** — required for `mass bundle publish`.
- **Publish resource types** — required for `mass resource-type publish` (used for both `resource-types/` and `platforms/`).

In your Massdriver instance, grant the service account a role that includes these permissions. Do this before you point CI at the service account. If the workflow fails on the first run with an authorization error, this is almost always the cause.

#### Publish order on first run

`mass bundle build` resolves every `$ref:` in `connections:` and `artifacts:` against your Massdriver server. So you must publish resource types before you build any bundle that references them. The default GitHub Actions workflows split by file path. A push to only `bundles/**` does not trigger the resource-types workflow.

On a fresh catalog, run `make publish-resource-types` once before you publish bundles. You can also push a change under `resource-types/` instead. Or run `make all` locally to do both steps in order.

4. **Set up pre-commit hooks (optional but recommended)**

   ```bash
   pip install pre-commit
   pre-commit install
   ```

   This formats JSON and YAML files, validates Terraform, and checks for common issues before each commit.

5. **Explore and customize**
   - Review resource types in `resource-types/`
   - Explore bundle schemas in `bundles/*/massdriver.yaml`

6. **Model your platform**

First, publish the template bundles to your organization. Explore how Massdriver organizes your resources. Then update these modules with your IaC code.

```bash
make all
```

- Open the Massdriver UI
- Create **projects**. A project is a logical group of infrastructure that can reproduce environments. Examples: application domains ("ecommerce", "api", "billing") or platform infrastructure ("network", "compute platform", "data platform").
- Create **environments** within projects. Examples: named environments ("dev", "staging", "production"), [preview environments](https://docs.massdriver.cloud/preview_environments/overview) ("PR 123"), or regional deployments ("Production US East 1", "US West 2").
- Add bundles to your **canvas**, the visual diagram where you design your architecture. Each placement creates an **instance** of that bundle.
- **Connect** instances to each other. Link resources produced by one bundle to the dependencies of another bundle. This passes configuration between provisioning pipelines automatically, without manual copying or custom scripts.
- Configure **parameters** to test the developer experience

7. **Implement infrastructure code**
   - When you are ready, replace the placeholder code in `bundles/*/src/` with your OpenTofu or Terraform code
   - Test locally with `tofu init` and `tofu plan`. Or run rapid infrastructure testing with [`mass bundle publish --development`](https://docs.massdriver.cloud/concepts/versions#rapid-infrastructure-testing).
   - Customize platform definitions to match your provider blocks, then publish them:
     ```bash
     make publish-platforms
     ```
   - Update schemas if your implementation needs different parameters

8. **Publish to Massdriver**

   **Automatic Publishing (Recommended)**: If you configured GitHub Secrets and Variables in step 3, Massdriver automatically publishes resource types and bundles on push to `main`. Push your changes:

   ```bash
   git push origin main
   ```

   **Manual Publishing**: You can also publish manually with the included Makefile:

   ```bash
   make all
   ```

   This command does the following:
   - Clean up any previous build artifacts
   - Ensure an OCI repository exists for every resource type and bundle (`make create-repos`)
   - Publish resource types to your Massdriver instance
   - Build all bundles (generates schema JSON files from `massdriver.yaml`)
   - Validate all bundles with OpenTofu, Helm, and other tools
   - Publish all bundles to your Massdriver instance. This step uses your default `mass` CLI profile.

   **Publishing** makes your resource types and bundles available in your Massdriver instance. After publishing, you can see them in the Massdriver UI. You can then add them to your environment canvases.

## Setting Up GCP

This is a complete walkthrough to connect a Google Cloud project to Massdriver. You will install the CLI and create a GCP service account. Then you will point the CLI at your organization, publish the GCP platform resource type, and load the credential into Massdriver.

Use your own values for these placeholders throughout this guide:

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `PROJECT_ID` | GCP project ID (not the display name, not the number) | `cory-sandbox-362007` |
| `ORG_ID` | Massdriver organization ID, visible in the app URL | `the-aspen-group` |

### 1. Install the Mass CLI

```bash
brew install massdriver
```

Alternatives: [pre-built binaries](https://github.com/massdriver-cloud/mass/releases) or `go install github.com/massdriver-cloud/mass`.

Confirm that you are on v2. Check both the CLI and the server it connects to:

```bash
mass version
```

### 2. Configure the CLI

The CLI reads `~/.config/massdriver/config.yaml`. Create this file if it does not exist:

```yaml
version: 1
profiles:
  default:
    organization_id: ORG_ID
    api_key: md_your_service_account_key_here
    templates_path: /absolute/path/to/this/repo/templates
```

Get the API key from your Massdriver organization settings. Create a **service account** to get the key. `templates_path` is optional. Set it if you want `mass bundle new` to use this repository's `templates/` directory.

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

**Always confirm which organization you are working in before you publish:**

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
> `mass whoami` tells you which organization a command will affect. You may have multiple profiles, or an editor or AI plugin configured with its own separate API key. Any of these can point at a **different organization than your CLI default**. Publishing to the wrong organization gives no warning — the publish succeeds, but it lands in the wrong place. Check `mass whoami` first.

If a later publish fails with `You do not have permission to...`, the service account is authenticated but has no policies. Add it to a group: **Settings → Groups → Organization Admin → Service Accounts**. A brand-new organization does not add service accounts to any group automatically.

### 3. Create the GCP service account

Massdriver assumes a GCP service account to manage infrastructure in your project. You do all of this in the Google Cloud Console. You do not need to install `gcloud`.

**Enable the required APIs.** Open the link below. Confirm that the correct project is selected at the top of the page. Click **Enable**. This enables everything the Cloud Run stack needs in one step: Cloud Run, Artifact Registry, VPC, Cloud SQL, Secret Manager, and Cloud Storage:

```
https://console.cloud.google.com/flows/enableapi?apiid=run.googleapis.com,artifactregistry.googleapis.com,cloudresourcemanager.googleapis.com,iam.googleapis.com,iamcredentials.googleapis.com,compute.googleapis.com,servicenetworking.googleapis.com,vpcaccess.googleapis.com,sqladmin.googleapis.com,secretmanager.googleapis.com,storage.googleapis.com&project=PROJECT_ID
```

This takes one or two minutes.

**Create the service account** at `https://console.cloud.google.com/iam-admin/serviceaccounts/create?project=PROJECT_ID`:

1. **Name:** `massdriver` — the account ID fills in automatically. Click **Create and continue**.
2. **Grant access:** in the role dropdown, select **Owner**. Click **Continue**.
3. Leave the user-access section empty. Click **Done**.

**Create a key:**

1. From the service accounts list, click `massdriver@PROJECT_ID.iam.gserviceaccount.com`.
2. Open the **Keys** tab → **Add key** → **Create new key**.
3. Choose **JSON** → **Create**. The file downloads automatically.

> [!CAUTION]
> That JSON file is a long-lived credential with **owner** access to the entire GCP project. Do not commit it to this repository. Delete it from your Downloads folder after you upload it to Massdriver.

> [!NOTE]
> **On `roles/owner`:** owner is the simplest way to start, and it gets you running fastest. It grants more access than most organizations want long-term. Once you know which bundles you deploy, narrow the service account to the specific roles those bundles need. For the Cloud Run stack, use: `roles/run.admin`, `roles/artifactregistry.admin`, `roles/cloudsql.admin`, `roles/compute.networkAdmin`, `roles/secretmanager.admin`, `roles/iam.serviceAccountAdmin`, `roles/storage.admin`.

### 4. Publish the GCP platform resource type

Platform credentials are resource types. In Massdriver v2, every resource type publishes into an OCI repository. That repository must exist first:

```bash
mass repository create gcp-service-account -t resource-type
mass resource-type publish platforms/gcp/massdriver.yaml
```

Or use the Makefile. It creates the repository for you:

```bash
make publish-platforms ENABLED_PLATFORMS=gcp
```

Expected output:

```
✅ Repository `gcp-service-account` created (type: resource-type)
Resource type GCP Service Account published successfully!
```

You can safely run `mass repository create` more than once. If the repository already exists, the command exits with a non-zero status, and the Makefile ignores this error.

### 5. Load the credential into Massdriver

> [!IMPORTANT]
> **For GCP, use the CLI, not the UI dropzone.** The web uploader currently corrupts the GCP key JSON on upload. The `private_key` field is a PEM block that contains literal `\n` escapes, and the form breaks the key when it round-trips this data. A credential imported through the UI looks fine at first. It then fails at deploy time with an authentication error.
>
> Import the credential with `mass resource create` instead. This problem is specific to the GCP key format. Other platforms are not affected.

The key file that Google gave you already matches the `gcp-service-account` schema, field for field. You can import it as-is:

```bash
mass resource create \
  -n my-gcp-project \
  -t gcp-service-account \
  -f ~/Downloads/PROJECT_ID-abc123.json
```

- `-n` — the name this credential appears under in Massdriver. Use a name that identifies the GCP project it grants access to.
- `-t` — the resource type published in step 4.
- `-f` — path to the JSON key downloaded in step 3.

Verify that it landed in the right organization:

```bash
mass resource list
```

If Massdriver cannot find the resource type, step 4 did not publish to this organization. Check `mass whoami` again.

After you import the credential, it appears in the Massdriver UI at `https://app.massdriver.cloud/orgs/ORG_ID/` under **Credentials**. You can set it as an environment default, and you can attach it to any environment in this organization.

Delete the local JSON key file after the import succeeds.

### 6. Grant projects access to the credential

The import does **not** make the credential usable. A resource in Massdriver stays private to the organization until you share it. Until you add a grant, the GCP service account does not appear as a selectable credential when you build a project. The environment shows nothing to connect to.

In the Massdriver UI, open the credential you imported in step 5. Go to its **grants / sharing** settings. Add the **`resource:export`** action. `resource:export` lets a project consume the resource as a dependency. Visibility follows automatically from the grant.

You have two choices about scope:

- **Organization-wide** — add `resource:export` with no conditions. Every project in the organization can use this GCP service account. This is the simplest option. It usually fits a sandbox or a single-cloud-account setup.
- **Scoped to specific projects** — add `resource:export` with **recipient conditions**. Conditions restrict the grant by attribute, for example only projects tagged for a given team, environment class, or data classification. Use this method to keep a production GCP account unreachable from every project in the organization.

Scoped grants match on **custom attributes**. The attributes you filter on must already be declared on the organization and set on the recipient projects. If a condition references an attribute key the organization does not define, Massdriver drops that condition without warning. This widens the grant to everyone.

Declare and set your attributes first. Then add the conditional grant. Then confirm that the credential is visible from a project you expect to have access, and invisible from one you do not.

Repeat this process for every credential you import. Each GCP service account is granted independently.

### 7. Deploy the Cloud Run stack

After you import and grant the credential, publish the catalog and stand up the platform. Order matters
on a fresh organization. Resource types must exist before you build any bundle that references them.

```bash
make publish-resource-types
make all
```

#### Create a project and environment

In the UI, create a project, then create an environment inside it. Attach the GCP credential you
imported in step 5 as an **environment default**. Every bundle on the canvas then inherits this
credential. Developers do not need to select a credential themselves.

#### Stand up the platform tier first

Add these two bundles, configure them, and deploy them. Your application developers never place these
bundles. You add them once per environment.

1. **`gcp-network`** — pick a CIDR range that does not overlap with anything you peer to later. The
   defaults give you a subnet, a Private Service Access range for Cloud SQL, and a Serverless VPC
   Connector for Cloud Run.
2. **`gcp-artifact-registry`** — the repository that receives application images.

Deploy both bundles before you continue. Everything in the application tier assumes that they exist.

> [!TIP]
> The Serverless VPC Connector name comes from the instance name prefix. GCP limits connector names to
> 25 characters. A long project or environment name can push the name over this limit. The bundle
> truncates the name automatically. Know this if you see a name-length error on your first deploy.

#### Scaffold an application

Generate a bundle for the application from the template. The new bundle gets its own schema, runbook,
and version history:

```bash
mass bundle new --name checkout-api --template-name gcp-cloud-run
```

Replace the contents of `build/app/` with the application source. This directory ships with a small
working example: a `Dockerfile` and a minimal HTTP server. You can deploy the scaffold unmodified, to
confirm that the pipeline works, before you point it at real code. Then:

```bash
cd checkout-api
mass bundle publish --development
```

`--development` publishes a development-channel version for rapid iteration. Instances pinned to
`@latest+dev` pick up this version on their next deploy.

#### Wire it up on the canvas

Add the application bundle and whatever data services it needs. Then connect them:

| Connect from | To | Why |
|---|---|---|
| `gcp-artifact-registry` → registry | app → container registry | where the built image is pushed and pulled |
| `gcp-network` → network | `gcp-cloud-sql-postgres` → network | database gets a private IP on your VPC |
| `gcp-cloud-sql-postgres` → database | app → database | connection details injected at deploy |
| `gcp-cloud-storage-bucket` → bucket | app → bucket | bucket name and access injected |
| `gcp-firestore` → database | app → firestore | Firestore database injected |

Deploy the data services, then the application last.

#### What happens on deploy

The application bundle runs in two steps. The first step archives `build/app/`, uploads the archive,
and runs a Cloud Build job. That job produces the image and pushes it to Artifact Registry. The second
step deploys that image to Cloud Run. Both steps independently derive the same image tag from
`md_metadata.package.deployment_enqueued_at`. Neither step depends on the other step's output.

Nothing builds on the developer's machine. The developer does not need `docker` or `gcloud`.

When the deploy finishes, the instance's resource contains the service's public URL. You can `curl`
this URL right away.

> [!NOTE]
> The first deploy in a brand-new GCP project is the deploy most likely to fail. The cause is almost
> always IAM propagation, not a bundle defect. The Cloud Build service account needs
> `storage.objectViewer` on the staging bucket, and the caller needs `iam.serviceAccountUser` on the
> build service account. Each bundle's `operator.md` covers its own failure modes in detail.

## Workflow

This catalog follows a three-phase approach. First, you model your architecture. Second, you implement the infrastructure code. Third, you continuously improve it.

### Phase 1: Architecture Modeling (Now)

1. Use the provided resource types and bundle schemas as-is. You do not need infrastructure code yet.
2. Create projects and environments in the Massdriver UI.
3. Add bundles to your canvas. Each bundle you add becomes an instance.
4. Link resources produced by one bundle to the dependencies of another bundle.
5. Configure parameters to test the developer experience.
6. Iterate on resource types and bundle scopes until they meet your needs.

**Goal**: Understand what services you want to offer, how they connect, and what the developer experience should be. You design the self-service platform interface before you write any infrastructure code.

**Key insight**: This phase helps you find the right abstractions. For example, you can decide whether to use separate `postgres` and `mysql` bundles, or one combined bundle. You can decide whether your network bundle should produce separate "public subnet" and "private subnet" resources, or one combined "network" resource. The schemas let you explore these questions quickly, without commitment to implementation details.

**Do not aim for a perfect design. Aim for feedback.** Show a working version to your developers, and iterate based on their input. An abstraction that looks correct on paper often needs refinement once developers use it. You can always add more bundles, refine parameters, or adjust resource types later. Developer feedback is more valuable than a theoretical design.

### Phase 2: Implementation (When Ready)

> [!TIP]
> See the [Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview) for detailed documentation on bundle and resource type development.

1. Write the OpenTofu/Terraform for any new bundles you add in `bundles/<name>/src/`
2. Test your infrastructure code locally with `tofu plan`
3. Update parameter schemas if your implementation needs different inputs
4. Push to `main` to publish bundles automatically with GitHub Actions, or use `make all` to publish manually
5. Deploy instances to test environments, and confirm that they work

**Goal**: Fill in the infrastructure code that matches your architectural model.

**Key benefit**: You already validated the architecture and developer experience in Phase 1. Now you implement against a proven design. You know what parameters developers need, which connections are appropriate, and what resources to produce.

### Phase 3: Continuous Improvement

1. Add more bundles as needed
2. Create custom resource types for your organization
3. Refine parameter validation and UI schemas
4. Use [release channels and strategies](https://docs.massdriver.cloud/concepts/versions#release-channels) to automate version distribution and upgrades across environments
5. Rely less on manual, ticket-based operations

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

[Resource types](https://docs.massdriver.cloud/concepts/resource-types) in `resource-types/` define the contracts between bundles: what data passes from one bundle to another. Massdriver's docs may still link these as "artifact definitions". That is the v1 name. See the docs for the complete schema reference.

Customize resource types to:

- **Pass connection info between bundles** - A database bundle outputs hostname, port, and credentials. An application bundle receives those as inputs and connects immediately.
- **Validate data before it is used** - Ensure CIDR blocks are valid IP ranges, database names match naming rules, and ports are in valid ranges. This catches configuration errors before you provision infrastructure.
- **Mark sensitive fields** - Use `$md.sensitive: true` on passwords, API keys, and certificates. Massdriver masks these fields in UIs and logs. Bundles that need them can still access them.

> [!TIP]
> When you standardize what your bundles produce, you define consistent resource type schemas. Then you can automate compliance and security policies across all resources of that type. This removes the need for fragile copy-paste scripts and custom glue code to wire infrastructure together. Validated, reusable contracts replace them instead.

### Bundle Schemas

Each bundle's `massdriver.yaml` defines the complete contract for that infrastructure component. See the [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for the complete schema reference.

- **params**: Input parameters that users configure when they deploy (instance sizes, database names, feature flags, and so on). These become variables in your IaC code. Params add UI controls and validation that most IaC tools do not provide.

- **connections** (the v1 key; the v2 product shows these as **dependencies**): Input resources that this bundle depends on. For example, a database bundle might require a connection to a virtual-network resource. Connections pass data securely, such as credentials, IAM policies, and endpoints, from one bundle to another during provisioning. These become variables in your IaC code. Massdriver checks that only compatible resources connect.

- **artifacts** (the v1 key; the v2 product shows these as **resources**): Output resources that this bundle produces for other bundles to use. For example, a database bundle produces a database resource that contains connection details. You populate these resources in your IaC code's outputs.

- **ui**: A UI schema that controls how the configuration form renders: field ordering, help text, conditional visibility, custom widgets, and more. This follows the React JSON Schema Form specification.

> [!NOTE]
> The keys `connections:` and `artifacts:` keep their v1 names inside `massdriver.yaml`. A future release will add backward-compatible renames to `dependencies:` and `resources:`. For now, every bundle and template in this repository uses the v1 keys.

> [!WARNING]
> Params and connections share the same namespace in your IaC code. If you have a param named "database" and a connection named "database", they conflict as the same variable, for example `variable "database"` in Terraform. Use distinct names to avoid collisions.

Customize these schemas to match the developer experience you want. The schemas define the self-service interface your developers will use. Make them clear, well-documented, and easy to use.

### Bundle Implementation

When you add a bundle of your own, put its OpenTofu or Terraform code in `bundles/<name>/src/`. The GCP
bundles in this catalog are already fully implemented. Read them as worked examples, not as scaffolding
to replace.

**How it works**: A Massdriver bundle combines policy as code, IaC, and pipelines into one deployable
unit. It defines the interface (inputs and outputs), dependencies (connections), and workflow steps.
This brings compliance and security scanning into the bundle itself. You do not maintain separate,
inconsistent pipelines across hundreds of repositories. Massdriver automatically generates input
variables from your params and connections schemas. It then runs your IaC code with those values.

To implement a bundle:

1. **Keep** the `_massdriver_variables.tf` file. `mass bundle build` generates it automatically from
   your schemas. Optional: you do not have to define variables directly in OpenTofu, Terraform, or
   Bicep. You can define them in `massdriver.yaml` instead. The build process generates them for you.
2. **Replace** `main.tf` with your infrastructure code
3. **Add** more `.tf` files as needed, such as `variables.tf` and `outputs.tf`
4. **Use** Massdriver-provided variables:
   - [`var.md_metadata`](https://docs.massdriver.cloud/getting-started/using-bundle-metadata#md_metadata-structure) - Massdriver metadata, such as the name prefix, instance ID, environment, and default tags
5. **Output** resource data that matches your `artifacts:` schema, such as connection details and resource IDs

**Example**: If your params schema defines a `database_name` parameter, access it in Terraform as `var.database_name`. If your `connections:` schema requires a `network` resource named `net`, access its VPC ID as `var.net.vpc_id`.

> [!IMPORTANT]
> In v2, connection and resource payloads are **flat**. There is no `data:` or `specs:` envelope — a
> field declared as `vpc_id` reads as `var.net.vpc_id`, not `var.net.data.infrastructure.vpc_id`.
> If you port a v1 bundle, this is the change most likely to cause errors. The old path fails at
> plan time with an unhelpful "this object does not have an attribute named" error.

## What's Next?

### Learn More About Massdriver

After you model your architecture and implement your first bundles, learn more about Massdriver with the getting started guide:

- 📚 **[Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview)** - Step-by-step tutorials that cover:
  - How to publish and deploy bundles
  - How to connect bundles with resources
  - How to create bundles from existing OpenTofu or Terraform modules
  - How to use bundle deployment metadata for tagging and naming

- 💻 **[Getting Started Repository](https://github.com/massdriver-cloud/getting-started)** - Example bundles with detailed walkthroughs that teach you:
  - How to work with the Mass CLI
  - Bundle development best practices
  - Real-world patterns and techniques

These resources add to this catalog. They show you how to work with bundles after you implement them.

### Automation

- 🚀 **[GitHub Actions](https://github.com/massdriver-cloud/actions)** - This repository includes pre-configured workflows. They use `actions/setup@v6`, the v2-compatible release, and automatically publish resource types and bundles on push to `main`. See the [Quick Start](#quick-start) section for setup instructions.

## Best Practices

### Do ✅

- **Model first**: Use the schemas to plan before you implement
- **Single-purpose bundles**: Keep bundles focused, for example `postgres`, not `rds`
- **Iterate on abstractions**: Refine resource types based on usage
- **Test the developer experience**: Configure bundles in the UI before you implement them
- **Version your bundles**: Use semantic versioning for stable releases

### Don't ❌

- **Rush to implementation**: Model your architecture first
- **Create generic bundles**: Be specific about use cases
- **Skip documentation**: Update descriptions and help text
- **Ignore validation**: Use JSON Schema to prevent errors
- **Forget the UI**: A good user experience makes adoption easier

## Resources

- 🌐 **[Massdriver Documentation](https://docs.massdriver.cloud)** - Official documentation
- 📚 **[Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview)** - An introduction to bundle development
- 💻 **[Getting Started Repository](https://github.com/massdriver-cloud/getting-started)** - Accompanying code
- 🎯 **[Core Resource Types](https://github.com/massdriver-cloud/artifact-definitions)** - Standard resource types in the Massdriver SaaS Platform. The upstream repository is still named `artifact-definitions`. Use it as a starting point or a source of ideas.
- 💬 **[Massdriver Slack](https://massdriver.cloud/slack)** - Community support

## Support

For questions or issues:

- Review existing bundle schemas for patterns in this catalog
- See the [Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview) for detailed tutorials
- Join the [Slack community](https://massdriver.cloud/slack) for help
- Contact Massdriver support

## License

This is a private repository. Customize it for your organization's needs.

---

**Remember**: This catalog is your platform foundation. Clone it, and customize it for your organization. The goal is to help you think through architecture and developer experience before you write infrastructure code.
