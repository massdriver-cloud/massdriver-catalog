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

- **Connections** (the `connections:` key in `massdriver.yaml`, surfaced in the product as **dependencies**): Inputs a bundle needs from other bundles. When a bundle declares it needs a connection to a `virtual-network` resource, you must link it to a bundle that produces a virtual-network resource.

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
├── virtual-network/
│   └── massdriver.yaml    # Network/VPC contract
├── postgres-database/
│   └── massdriver.yaml    # PostgreSQL connection contract
├── mysql-database/
│   └── massdriver.yaml    # MySQL connection contract
├── object-storage/
│   └── massdriver.yaml    # Object storage contract
└── workload/
    └── massdriver.yaml    # Workload metadata contract
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

This catalog includes template bundles with complete schemas and placeholder infrastructure code:

- `network/` - Network/VPC provisioning
- `postgres/` - PostgreSQL database provisioning
- `mysql/` - MySQL database provisioning
- `bucket/` - Object storage bucket provisioning
- `application/` - Application deployment template

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
| `opentofu` | OpenTofu | OpenTofu module template |
| `terraform` | Terraform | Terraform module template |
| `bicep` | Bicep | Azure Bicep template |
| `helm-chart` | Helm | Deploy external Helm charts |

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

For more details, see the [Bundle Templates](https://docs.massdriver.cloud/bundle-development/publishing/bundle-templates) guide.

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

## Tour of the Demo Bundles & Resource Types

The bundles and resource types ship pre-wired with realistic shapes so you can poke at the UX on the canvas before writing any IaC. Below is a quick map of what's in each one and which `massdriver.yaml` features it showcases — useful when you want to find a working example of `$md.enum`, the `app:` block, conditional `dependencies`, etc.

> [!TIP]
> The IaC under each `bundles/*/src/` is `random_pet`-based stub code so the canvas works end-to-end. **Swap it for your real OpenTofu / Terraform once you've got the schema shape you want** — the `_massdriver_variables.tf` file regenerates from your params + connections on every `mass bundle build`, so you can change the schema and your variables stay in sync.

### `network/` bundle ↔ `virtual-network` resource type

Produces a virtual network with subnets that other bundles attach to.

- **`params.examples`**: Small (/24 dev) · Medium (staging) · Large (production multi-AZ) — preset dropdown in the UI.
- **`$md.immutable: true`** on `cidr` — once set, the form blocks edits.
- **`message.pattern`** override on the CIDR pattern (so users see "Must be a valid IPv4 CIDR block, like 10.0.0.0/16" instead of a raw regex).
- **Conditional `dependencies`** block: `flow_log_retention_days` is required only when `enable_flow_logs` is `true`.
- **Array constraints** on `subnets` (`minItems: 1`, `maxItems: 12`, `uniqueItems`) and `dns_servers` (`maxItems: 4`).
- **UI**: `ui:widget: updown` on retention, `ui:help` on every non-obvious field, `ui:options.orderable/addable/removable` on the subnets array.
- **Alarms** (`src/alarms.tf`): `Egress Throughput Anomaly`, `NAT Port Exhaustion`.

### `postgres/` bundle ↔ `postgres-database` resource type

Produces a PostgreSQL instance, depends on a `virtual-network`.

- **Human-readable version selector** via `oneOf` + `const` + `title` (Postgres `12` is labelled "out of community support — upgrade soon"; `16` is labelled "current").
- **`$md.enum`** on `subnet_filter` — populates a dropdown from the linked network's `.subnets`.
- **Multi-annotation combo** on `username`: `$md.immutable: true` + `$md.copyable: false` (won't change post-deploy, won't carry into a cloned env).
- **`$md.sensitive: true`** on the resource-type's `auth.password` (masks the value in the UI and audit-logs every download).
- **T-shirt sizing** (`xs`/`s`/`m`/`l`/`xl`), `allocated_storage_gb` with `multipleOf: 10`, `backup_retention_days` with `minimum`/`maximum`, conditional `multi_az_zones` when `high_availability: true`.
- **Alarms**: `High Connections`, `Storage 80% Full`, and a conditional `Replication Lag` that only emits when HA is on.

### `mysql/` bundle ↔ `mysql-database` resource type

Same shape as `postgres/`, with MySQL-specific touches:

- **`character_set` and `collation`** enums, both `$md.immutable: true`.
- **Conditional `slow_query_log_long_query_time_seconds`** required only when `slow_query_log_enabled: true`.
- **`username` capped at 32 chars** via `maxLength` (MySQL's username limit).
- **Alarms**: conditional `Slow Query Rate`, conditional `Replication Lag`, `Storage 80% Full`.

### `bucket/` bundle ↔ `object-storage` resource type

Object storage. No upstream connections.

- **`access_level`** as `oneOf` with `title` labels ("Private — no anonymous access (recommended)", "Public Read+Write — rarely safe").
- **`object_lock`** marked `$md.immutable: true` (one-way switch) with a `dependencies` block requiring `object_lock_retention_days` and `versioning_enabled` when on.
- **`lifecycle_rules`** array (max 8, unique items) with per-rule transition + storage class enum; UI lets you reorder / add / remove rules.
- **CORS origins** array with origin-URL pattern validation.
- **Alarms**: `5xx Error Rate`, conditional `Anonymous Access Anomaly` (only when the bucket is private).

### `application/` bundle ↔ `workload` resource type

A containerized app that connects to a network + Postgres + (optional) bucket.

- **Full `app:` block** showcasing both halves:
  - **`app.envs`** — JQ expressions that lift connection values into env vars (`DATABASE_HOST`, `DATABASE_URL` via string-concat, `BUCKET_NAME` with `// ""` fallback when no bucket is linked).
  - **`app.secrets`** — declares `JWT_SECRET` (`required: true`), `SENTRY_DSN` and `GOOGLE_OAUTH_CLIENT_SECRET` (optional). The UI blocks deploy until required secrets are set.
- **`$md.enum`** on `database_policy` and `bucket_policy` — populates from the linked resource's `.policies` array.
- **`environment` and `log_level`** as `oneOf` enums with explanatory `title` labels.
- **`cpu_limit`/`memory_limit`** as plain `enum`s modeled on Kubernetes resource strings.
- **`image` regex** that requires `image:tag` or `image@digest` (no implicit `:latest`).
- **Alarms**: `Pod Restart Rate`, `5xx Error Rate`, `p95 Latency`.

### `resource-types/*/instructions/`

Each resource type ships per-source form-fill walkthroughs that render alongside the resource creation form in the Massdriver UI. They tell operators how to harvest each schema field from the matching cloud (`AWS RDS PostgreSQL.md`, `Azure VNet.md`, `GCP Cloud Storage.md`, etc.) or from a self-hosted setup. Same pattern as `platforms/<cloud>/instructions/` — replace or extend with your team's onboarding steps.

> [!NOTE]
> The bundle `src/*.tf` files use the new `massdriver_resource` (the replacement for the deprecated `massdriver_artifact`, gone in provider v2.0) and `massdriver_instance_alarm` resources from `massdriver-cloud/massdriver ~> 2.0`. Reference these when you wire your real cloud resources up.

## The Access Model

Three kinds of people share this platform, and they need different amounts of rope.

- **Platform Ops** manage the infrastructure code. They own the shared services, the bundle
  catalog, and the cloud credentials.
- **Developers** are professional engineers. They build and run their own projects, and they
  are allowed to ship things that face the public internet.
- **Citizen Developers** build apps outside their main job. They should be able to see what
  everyone else has built, so they stop solving the same problem twice. They should not be
  able to change anyone else's work, and they should not be able to put anything on the
  public internet without a human agreeing to it first.

### How Massdriver decides who can do what

A group holds a list of policies. A policy has three parts: an effect (allow or deny), a
list of actions, and an optional set of conditions. Conditions match against attributes on
the thing you are acting on.

Two rules control everything else:

1. **Conditions AND together inside one policy.** A policy with two conditions matches only
   when both are true.
2. **Policies OR together across every group you belong to.** They are loaded into one flat
   list, and after that the system cannot tell which group each policy came from.

The second rule is the one that surprises people. **A group is not a boundary.** Putting a
narrow policy in a small group does not keep it narrow. If you are also in a group that can
see a hundred projects, a policy with no conditions reaches all hundred.

So: **to limit an action, put the condition on that action's own policy.** Conditions on a
different policy in the same group do nothing for it.

A policy with no conditions at all never looks at the thing you are acting on. It matches
everything. The only thing holding it back is what you can already see, and what you can see
is set by your `project:view` policies — possibly in an entirely different group.

### The four attributes

| Key | Scope | Values | What it decides |
| --- | --- | --- | --- |
| `managed_by` | project | `platform`, `engineering`, `citizen` | Who is responsible for this project. Drives discovery. |
| `team` | project | `platform`, `artists` | Which team owns it. Drives "change only my own project". |
| `tier` | environment | `dev`, `staging`, `production` | How careful to be. Drives deploy versus propose. |
| `exposure` | component | `internal`, `external` | Whether this app faces the public internet. |

**`managed_by` answers "who builds this", not "who uses this".** An earlier draft of this
model used an `audience` attribute with values like `internal` and `external`. That breaks
the first time a citizen developer ships something customer-facing: either the app drops out
of citizen discovery, or every citizen developer gains view access to a customer-facing
project. Who builds a thing and who consumes it are different questions, and only the first
one belongs in an access rule.

**`team` exists because `managed_by` alone cannot express "mine".** `managed_by: citizen`
gets you "every citizen developer sees every citizen project." It cannot get you "…but
changes only their own," because a policy has no idea which projects belong to the person
reading it. That needs a second value plus a small per-team group.

**`exposure` sits on components, not projects, because that is the only place it works.**
`project:design` — adding a component to a canvas and wiring it up — is the only action in
the whole model that gates creating infrastructure, and it conditions on component
attributes. Put `exposure` on the project instead and you can describe intent, but you
cannot enforce it. On components it also handles the normal case where one project holds an
internal admin tool and a public API.

### Which attribute can gate which action

Each action accepts conditions from exactly one scope. This is fixed and you cannot change it.

| Action | Accepts conditions from |
| --- | --- |
| `project:view`, `project:update`, `project:delete` | project attributes |
| `project:design` | **component** attributes |
| `environment:create`, `environment:deploy`, `environment:configure`, `environment:decommission` | environment attributes |
| `repo:pull`, `repo:push`, `repo:grant` | repo attributes |
| `instance:configure`, `instance:deploy`, `instance:plan`, `instance:propose` | project, environment, and component attributes |
| `resource:*` | none |

There is also a set of built-in keys you can use as conditions anywhere they make sense:
`md-id`, `md-project`, `md-environment`, `md-component`, `md-repo`, `md-instance`,
`md-bundle`. These are how you pin a policy to one named project when no custom attribute
fits.

> [!WARNING]
> The API call that lists valid conditions for an action returns **only custom attributes**.
> It does not mention the `md-*` keys. Ask it about `instance:deploy` before you have
> declared any custom attributes and it returns an empty object, which reads as "this action
> cannot be limited." That is wrong. `instance:deploy` accepts several kinds of conditions.

### The groups

**Platform Ops** — every action, no conditions. They are the people who fix it when it breaks.

**Developers**

| Actions | Conditions |
| --- | --- |
| `project:view` | `managed_by`: platform, engineering, citizen |
| `project:design` | `exposure`: internal, external |
| `instance:configure`, `instance:deploy`, `instance:plan` | `managed_by`: engineering + `tier`: dev, staging |
| `instance:propose` | `managed_by`: engineering + `tier`: production |
| `environment:create`, `environment:configure`, `environment:deploy` | `tier`: dev, staging |
| `repo:create`, `repo:view`, `repo:pull`, `repo:push`, `resource:view` | none |

**Citizen Developers** — everybody in the program joins this one. It gives read access and
nothing else.

| Actions | Conditions |
| --- | --- |
| `project:view` | `managed_by`: citizen, platform |
| `repo:view`, `resource:view` | none |

Citizen projects and the shared platform are both visible. Seeing the platform matters: the
shared database is the thing their apps are built on, and they cannot use what they cannot
find. They can look at it and change nothing.

**Citizen Developers - Artists** — one group like this per citizen team. This is the half
that grants change access, and every policy in it carries its own fence.

| Actions | Conditions |
| --- | --- |
| `project:design` | `exposure`: internal + `md-project`: artists |
| `instance:configure`, `instance:deploy`, `instance:plan` | `team`: artists + `tier`: dev |
| `instance:propose` | `team`: artists + `tier`: staging, production |
| `environment:create`, `environment:configure`, `environment:deploy` | `md-project`: artists + `tier`: dev |
| `repo:view`, `resource:view` | none |

A citizen developer in both groups sees every citizen project and can change only the artists
project. In `dev` they deploy on their own. In `staging` and `production` they can only
propose, and somebody with deploy rights decides. That is the point where the work stops and
asks a human.

They cannot add a component marked `external`, so no citizen app reaches the public internet
until a developer or an operator places it.

### Three things that will bite you

**A condition on the wrong kind of key turns an allow into "everyone."** Before a policy is
evaluated, condition keys that cannot appear on the target are removed. If that empties the
condition set, an allow policy matches everything. `instance:deploy` with a condition on a
repo-scoped attribute is not a narrow policy — it is an organization-wide grant. It saves
without complaint, and it reads back exactly as you wrote it. The only way to catch it is to
check each key against the list above.

**The same mistake in a deny does nothing at all.** A deny whose conditions empty out is
dropped instead of widened. It sits in the list looking like protection.

**Deny cannot be used to carve out an exception.** Conditions only match positively. There is
no way to write "deny everything except X." Write the allow correctly instead.

### Setting it up

Attributes, groups, and policies are managed in the web app under **Settings**, or through
the Massdriver MCP server. The CLI does not cover them.

Tagging projects and environments does have CLI commands:

```bash
mass project update scp -a managed_by=platform,team=platform
mass project update artists -a managed_by=citizen,team=artists

mass environment update scp-dev -a tier=dev
mass environment update artists-dev -a tier=dev
```

`-a` replaces the whole attribute set for that project or environment, so pass every
attribute you want to keep, every time.

Declare an attribute with `required` off, tag everything that already exists, and only then
mark it required. Marking an attribute required while older projects are missing it leaves
you with resources that cannot be updated until you go back and fill it in.

`managed_by` and `tier` are required. A project with no `managed_by` matches no citizen view
condition and is invisible to them, which is the safe direction to fail, but it is confusing
to debug. Requiring the attribute means the question gets answered when the project is
created. `team` and `exposure` stay optional: `team` so operators can make scratch projects
without inventing one, and `exposure` because a citizen developer must tag a component
`internal` to place it at all, which gets you the same result without forcing the tag onto
networks and databases where the idea does not apply.

### Known gap

`repo:push` is granted to Developers with no conditions, so they can publish a new version of
any bundle in the catalog, including the platform bundles. Closing it needs a repo-scoped
attribute — `catalog_tier` with values like `platform` and `application` — and a condition on
the push policy. It is listed here rather than fixed because it is a deliberate choice about
how much you trust your engineers, not an oversight.

## Standing Up the Platform

The order below is the order things have to happen in. Resource types before bundles, because a
bundle cannot be built until the types it references exist. Attributes before grants and
policies, because a grant that names an attribute the organization has not declared is dropped
without a word and shares with everybody.

Placeholders used throughout:

| Placeholder | Meaning |
| --- | --- |
| `ORG_ID` | Massdriver organization ID, visible in the app URL |
| `PROJECT_ID` | GCP project ID — not the display name, not the number |

### 1. Point the CLI at the right organization

The CLI reads `~/.config/massdriver/config.yaml`:

```yaml
version: 1
profiles:
  default:
    organization_id: ORG_ID
    api_key: md_your_service_account_key_here
    templates_path: /absolute/path/to/this/repo/templates
```

Check what you are actually connected to before anything else:

```bash
mass whoami
```

> [!WARNING]
> Publishing to the wrong organization does not warn you. It succeeds, and the work lands
> somewhere else. `mass whoami` is the only thing that tells you which organization the next
> command will change, and an editor or AI plugin can hold a different key than your shell does.

If a publish fails with `You do not have permission to...`, the service account is authenticated
but belongs to no group. A brand-new organization does not put it in one. Add it under
**Settings → Groups → Organization Admin → Service Accounts**.

### 2. Create the cloud credential

In the Google Cloud Console, enable the APIs this platform uses. One link does all of them:

```
https://console.cloud.google.com/flows/enableapi?apiid=run.googleapis.com,artifactregistry.googleapis.com,cloudresourcemanager.googleapis.com,iam.googleapis.com,iamcredentials.googleapis.com,compute.googleapis.com,servicenetworking.googleapis.com,vpcaccess.googleapis.com,sqladmin.googleapis.com,secretmanager.googleapis.com,storage.googleapis.com&project=PROJECT_ID
```

Then create a service account at
`https://console.cloud.google.com/iam-admin/serviceaccounts/create?project=PROJECT_ID`, give it
**Owner**, and create a **JSON** key.

> [!CAUTION]
> That file is a long-lived credential with owner access to the whole GCP project. Do not commit
> it. Delete it once it is loaded into Massdriver.

Owner gets you running fastest and grants far more than this platform needs. Once you know which
bundles you run, narrow it to `roles/run.admin`, `roles/artifactregistry.admin`,
`roles/cloudsql.admin`, `roles/compute.networkAdmin`, `roles/secretmanager.admin`,
`roles/iam.serviceAccountAdmin`, `roles/storage.admin`.

### 3. Publish the credential type and load the key

Credentials are resource types, and every resource type lives in a repository that must exist
first:

```bash
mass repository create gcp-service-account -t resource-type
mass resource-type publish platforms/gcp/massdriver.yaml
mass resource create -f ~/Downloads/PROJECT_ID-abc123.json -t gcp-service-account -n "Massdriver Sandbox"
```

> [!IMPORTANT]
> Load GCP keys with the CLI, not the web uploader. The `private_key` field is a PEM block
> containing literal `\n` escapes, and the form breaks it on the round trip. The credential looks
> fine and then fails at deploy time with an authentication error. Other platforms are not
> affected.

### 4. Publish the rest of the catalog

```bash
make publish-resource-types
```

Then each bundle. `mass bundle build` regenerates the Terraform variables from
`massdriver.yaml`, so it runs before every publish:

```bash
mass bundle build   --bundle-directory bundles/gcp-network
mass repository create gcp-network -t bundle
mass bundle publish --development --bundle-directory bundles/gcp-network
```

`--development` publishes to the development channel. Instances pinned to `@latest+dev` pick the
new version up on their next deploy, which is what you want while a bundle is still moving.

To check a bundle before publishing it:

```bash
tofu -chdir=bundles/gcp-network/src init -backend=false
tofu -chdir=bundles/gcp-network/src validate
```

### 5. Declare the attributes

Custom attributes, groups, and policies have no CLI commands. Use the web app under
**Settings**, or the Massdriver MCP server.

Declare all four before writing any policy or grant. See [The Access Model](#the-access-model)
for what each one decides.

Then tag what already exists:

```bash
mass project update scp     -a managed_by=platform,team=platform
mass project update artists -a managed_by=citizen,team=artists

mass environment update scp-dev     -a tier=dev
mass environment update artists-dev -a tier=dev
```

`-a` replaces the whole set rather than adding to it, so pass every attribute you want to keep
each time.

### 6. Share the credential

Importing a credential does not make it usable. Until it is granted, no environment can see it
and nothing on the canvas has anything to connect to.

Grant `resource:export` on the credential, with a recipient condition of `tier: dev`. That is
what keeps a sandbox key out of a production environment — not a naming convention, and not
somebody remembering.

Then set it as an environment default for `scp-dev` and `artists-dev`, so every component
inherits it and nobody has to pick a credential by hand.

### 7. Decide which bundles each kind of project may use

This is where "citizen developers can only deploy serverless" stops being a policy document.

Grant `repo:pull` on each bundle repository with a recipient condition on `managed_by`:

| Bundles | Granted to |
| --- | --- |
| `gcp-network`, `gcp-artifact-registry`, `gcp-cloud-sql-postgres` | `managed_by: platform` |
| `pg-table-set`, `gcp-cloud-storage-bucket`, `gcp-firestore`, and the app bundles | `managed_by: platform, engineering, citizen` |

A citizen project cannot place a VPC or a database cluster because it was never granted the
bundle. Adding the component fails outright rather than deploying something nobody meant to
deploy. Widening the catalog later is one grant.

### 8. Build the platform tier

In `scp`, add and deploy in this order — everything else assumes these exist:

1. **`gcp-network`** — pick a CIDR that will not overlap anything you peer to later. Creates the
   subnet, the Private Service Access range Cloud SQL needs, and the serverless connector Cloud
   Run uses to reach private addresses. Takes about four minutes, most of it the connector.
2. **`gcp-artifact-registry`** — where every app image is built to.
3. **`gcp-cloud-sql-postgres`** — the shared database. Around ten minutes.

Link `gcp-network`'s `network` output to the database's `network` input before deploying it.

> [!TIP]
> The connector name comes from the instance name prefix, and GCP caps connector names at 25
> characters. Long project or environment names push it over. The bundle truncates automatically,
> so know this if a name-length error appears on a first deploy.

### 9. Share the platform with the app projects

The apps live in a different project from the platform, so the platform's outputs need grants
too — same mechanism as the credential, `resource:export` with a `tier: dev` condition, on the
registry and the serverless connector.

Then set both as environment defaults on `artists-dev`. After that, every app added to that
environment binds to the shared registry and connector on its own. Nothing to wire per app.

### 10. Scaffold an app

```bash
mass bundle new --name checkout-api --template-name gcp-cloud-run
```

The scaffold takes a `postgres-table-set`, so it gets a schema and login of its own rather than
the shared cluster's admin credential. Replace `build/app/` with the real application, keeping
the `PORT` environment variable — Cloud Run sets it and the container has to listen on it.

Then add two components to the project: a `pg-table-set` for the app's data, and the app itself,
linking the table set's `table_set` output to the app's `database` input.

> [!NOTE]
> `mass bundle new` renders the whole template tree, not just `massdriver.yaml`, which blanks the
> `{{dependencies}}` / `{{resources}}` / `{{params}}` placeholders in `operator.md`. The runbook
> still looks fine afterwards, so it is easy to miss. Diff it against the template and restore.

### What happens on deploy

The app bundle runs in two steps. The first archives `build/app/`, uploads it, and runs a Cloud
Build job that pushes an image to Artifact Registry. The second deploys that image to Cloud Run.
Both derive the same image tag independently from `md_metadata.package.deployment_enqueued_at`,
so neither depends on the other's output.

Nothing builds on anyone's laptop. No `docker`, no `gcloud`.

> [!NOTE]
> The first deploy in a brand-new GCP project is the one most likely to fail, and it is almost
> always IAM propagation rather than a bundle defect. The Cloud Build service account needs
> `storage.objectViewer` on the staging bucket, and the caller needs `iam.serviceAccountUser` on
> the build service account. Each bundle's `operator.md` covers its own failure modes.

### Before pg-table-set can deploy

Creating a schema and granting access to a table are SQL statements. The Google Cloud API cannot
express either, so `pg-table-set` opens a real PostgreSQL connection, and the instance needs an
address the provisioner can reach.

With `iac_authorized_networks` empty, `gcp-cloud-sql-postgres` has no public address at all and
`pg-table-set` cannot run. Add the egress address of whatever executes your infrastructure code:

| Name | Address range |
| --- | --- |
| Massdriver provisioner egress | *the CIDR your deployments leave from* |

Everything else is still refused, and every connection stays encrypted. If you do not know the
address, deploy `pg-table-set` once and read the source address of the refused connection in
Cloud SQL's logs, under `resource.type="cloudsql_database"`.

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

1. Replace placeholder OpenTofu/Terraform in `bundles/*/src/`
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
│   ├── mysql-database/
│   │   └── massdriver.yaml
│   ├── object-storage/
│   │   └── massdriver.yaml
│   ├── postgres-database/
│   │   └── massdriver.yaml
│   ├── virtual-network/
│   │   └── massdriver.yaml
│   └── workload/
│       └── massdriver.yaml
├── bundles/                            # Infrastructure-as-Code modules
│   ├── application/                    # Example Application
│   ├── bucket/                         # Object storage
│   ├── mysql/                          # MySQL database
│   ├── network/                        # VPC/Network
│   └── postgres/                       # PostgreSQL database
├── templates/                          # Bundle templates for mass bundle new
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

When you're ready to implement the actual infrastructure provisioning, replace the placeholder OpenTofu/Terraform code in `bundles/*/src/`.

**How it works**: Massdriver bundles combine policy as code, IaC, and pipelines into a single deployable unit. They define the interface (inputs/outputs), dependencies (connections), and workflow steps—bringing compliance and security scanning into the bundle itself, instead of maintaining snowflake pipelines scattered across hundreds of repos. Massdriver automatically generates input variables from your params and connections schemas, then executes your IaC code with those values.

To implement a bundle:

1. **Keep** the `_massdriver_variables.tf` file - it's auto-generated by `mass bundle build` from your schemas. (Optional: You can stop defining variables directly in OpenTofu/Terraform/Bicep and just define them in `massdriver.yaml`. The build process will generate them.)
2. **Replace** `main.tf` with your infrastructure code
3. **Add** additional `.tf` files as needed (variables.tf, outputs.tf, etc.)
4. **Use** Massdriver-provided variables:
   - [`var.md_metadata`](https://docs.massdriver.cloud/getting-started/using-bundle-metadata#md_metadata-structure) - Massdriver metadata (name prefix, instance ID, environment, default tags, etc.)
5. **Output** resource data that matches your `artifacts:` schema (connection details, resource IDs, etc.)

**Example**: If your params schema defines a `database_name` parameter, access it in Terraform as `var.database_name`. If your `connections:` schema requires a `virtual-network` resource named `net`, access its VPC ID as `var.net.data.infrastructure.vpc_id`.

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
