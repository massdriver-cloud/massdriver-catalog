# Massdriver Catalog

A bootstrap catalog for self-hosted Massdriver instances containing artifact definitions, infrastructure bundles, and cloud credentials. This catalog helps you quickly model your platform architecture and developer experience before implementing infrastructure code.

**This is your platform foundation.** While this guide walks you through the concepts, you're not just following a tutorial—you're building your actual platform. This repository will serve as your platform team's source of truth for artifact definitions and bundles. Design your infrastructure architecture, iterate on the developer experience, and refine your abstractions here—then fill in your OpenTofu/Terraform implementation when you're ready.

**tl;dr:** [Jump to Quick Start](#customizing-your-catalog)

## Quick Start Workflow

This catalog is yours to customize and extend. Here's the recommended workflow:

1. **Clone this repository** to your organization (keep it private—it will contain your infrastructure code)
2. **Configure GitHub Secrets** (see [Quick Start](#quick-start)) to enable automatic publishing on push to `main`
3. **Start experimenting** with bundles in your editor—edit schemas, add parameters, define connections
4. **Watch the developer experience get built** in real-time in Massdriver as you iterate on your abstractions

The beauty of this approach: you can refine the entire developer experience—what parameters developers see, how bundles connect, what artifacts are produced—all before writing a single line of infrastructure code.

## Key Concepts

If you're new to Massdriver, here are the core concepts you'll encounter:

- **Bundle**: A reusable, versioned definition of infrastructure or application components. Bundles encapsulate your IaC code (Terraform/OpenTofu/Helm), configuration schemas, dependencies, and policies into a single deployable unit. Think of them as "infrastructure packages" with built-in guardrails.

- **Artifact Definition**: A JSON Schema contract that defines how infrastructure components can connect to each other. Artifact definitions ensure type safety—you can't connect incompatible components.
-
- **Artifact**: The actual instance of an artifact definition produced by a deployed bundle. For example, when you deploy a PostgreSQL bundle, it emits a PostgreSQL artifact containing connection details that other bundles can consume.

- **Parameters (params)**: User-configurable inputs for a bundle, like instance sizes, database names, or feature flags. These define what developers can customize when deploying infrastructure.

- **Connections**: Dependencies between bundles. When a bundle declares it needs a connection to a "network" artifact, you must link it to another bundle that produces a network artifact. This is how you compose infrastructure components.

- **Project**: A logical grouping of related infrastructure, like "ecommerce-platform" or "data-pipeline". Projects contain one or more environments.

- **Environment**: A deployment target within a project, like "development", "staging", or "production". Each environment has its own canvas where you design and deploy infrastructure.

- **Canvas**: The visual diagram in the Massdriver UI where you add bundles, connect them together, and configure parameters. It's your infrastructure design board.

- **Package**: An instance of a bundle configured and deployed to a specific environment. When you add a bundle to your canvas and configure it, you're creating a package. Think of it like the relationship between a class and an object in programming—bundles are the reusable definitions, packages are the deployed instances.

## What's Inside

### 📁 `artifact-definitions/`

**Artifact definitions** are schema-based contracts that define how infrastructure components can interact with each other in Massdriver. Think of them as type definitions for your infrastructure—they ensure that when you connect a database to an application, both sides speak the same language.

Each artifact definition is a directory containing a `massdriver.yaml` file:

```
artifact-definitions/
├── network/
│   └── massdriver.yaml    # Network/VPC contract
├── postgres/
│   └── massdriver.yaml    # PostgreSQL connection contract
├── mysql/
│   └── massdriver.yaml    # MySQL connection contract
├── bucket/
│   └── massdriver.yaml    # Object storage contract
└── application/
    └── massdriver.yaml    # Application metadata contract
```

> **💡 Note on Sensitive Fields**: Artifact definitions support the [`$md.sensitive`](https://docs.massdriver.cloud/json-schema-cheat-sheet/massdriver-annotations#mdsensitive) annotation to mark fields containing credentials, passwords, or other secrets. Fields marked as sensitive are automatically masked as `[SENSITIVE]` in GraphQL queries and UI displays while remaining accessible for actual infrastructure connections. All artifact data is encrypted at rest and in transit, and downloads of sensitive data are tracked in audit logs.

**⚠️ These are examples to get you started.** Edit these schemas to match your organization's infrastructure patterns and the data your bundles need to exchange. The field names, structure, and validation rules should reflect what your actual OpenTofu/Terraform code produces and consumes.

**Why they matter**: Artifact definitions enable type-safe infrastructure composition. You can't accidentally connect a PostgreSQL artifact to a bundle expecting MySQL—the system validates compatibility at design time, before any infrastructure is deployed.

Use these example artifact definitions to:

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
- ✅ **Connection schemas** - Define cloud service dependencies on artifacts from other bundles, enabling secure access to their details during automation.
- ✅ **Artifact schemas** - Define what infrastructure this bundle produces for others to consume
- ✅ **UI schemas** - Control how the configuration form looks and behaves
- 🚧 Placeholder OpenTofu/Terraform code (replace with yours)

These bundles let you model first, implement later. Use the schemas to plan your architecture and test the developer experience in the Massdriver UI, then fill in the actual infrastructure code when you're ready.

### 📁 `platforms/`

**Platform integrations** define how Massdriver connects to your cloud providers and infrastructure platforms. Each platform directory contains everything needed to authenticate and interact with that platform.

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

_dist/                      # Built artifacts (auto-generated, do not edit)
  ├── aws-iam-role.json
  ├── azure-service-principal.json
  ├── gcp-service-account.json
  └── kubernetes-cluster.json
```

**The `massdriver.yaml` Format**:

Each platform has a declarative `massdriver.yaml` that drives the build process:

```yaml
name: aws-iam-role               # Artifact definition name
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

**Export Templates** (optional): The `exports/` directory enables self-service artifact downloads. Export templates allow developers to download pre-configured files based on deployed artifact data—like generating a kubeconfig file from a Kubernetes namespace, VPN configuration files with certificates, database connection strings, or environment variable files for local development.

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

## Customizing Your Catalog

### Prerequisites

- Self-hosted Massdriver instance configured
- [Massdriver CLI (`mass`)](https://docs.massdriver.cloud/cli) installed and authenticated
- OpenTofu or Terraform installed (for implementing bundles)

> [!IMPORTANT]
> This catalog requires Massdriver CLI version 1.13.7 or higher. Check your version with `mass version` and upgrade if needed: [Download latest release](https://github.com/massdriver-cloud/mass/releases/tag/1.13.7)

### Quick Start

1. **Clone this repository**

   ```bash
   git clone <your-private-repo-url>
   cd massdriver-catalog
   ```

2. **Update GitHub URLs**

   Replace `YOUR_ORG` with your actual GitHub organization name throughout the repository. This updates `source_url` fields in bundles and links in operator runbooks to point to your repository.

3. **Configure GitHub Secrets and Variables**

   This repository includes GitHub Actions workflows that automatically publish artifact definitions and bundles to your Massdriver instance on push to `main`. To enable this, configure the following in your GitHub repository:

   **Required Secrets** (Settings → Secrets and variables → Actions → Secrets):
   - `MASSDRIVER_API_KEY` - Your Massdriver API key. Generate one in your Massdriver instance under Settings → API Keys.

   **Required Variables** (Settings → Secrets and variables → Actions → Variables):
   - `MASSDRIVER_ORG_ID` - Your Massdriver organization ID. You can find this in your Massdriver instance URL or in the organization settings.

   **Optional Variables** (for self-hosted instances):
   - `MASSDRIVER_URL` - The API URL of your self-hosted Massdriver instance (e.g., `https://api.massdriver.yourdomain.com`). If not set, defaults to `https://api.massdriver.cloud`.

   Once configured, any push to the `main` branch will automatically:
   - Publish all artifact definitions in `artifact-definitions/`
   - Build and publish all bundles in `bundles/`

   > [!TIP]
   > The bundle publish action automatically skips publishing if no changes are detected in a bundle directory, optimizing CI/CD performance. For development workflows, you can modify the workflows to use the `development: true` flag for auto-generated version suffixes.

4. **Set up pre-commit hooks (optional but recommended)**

   ```bash
   pip install pre-commit
   pre-commit install
   ```

   This will automatically format JSON/YAML, validate Terraform, and check for common issues before each commit.

5. **Explore and customize**
   - Review artifact definitions in `artifact-definitions/`
   - Explore bundle schemas in `bundles/*/massdriver.yaml`

6. **Model your platform**

First publish the template bundles to your organization. After you get a feel for organization your resources in Massdriver, you'll update these modules with your IaC.

```bash
make all
```

- Open the Massdriver UI
- Create **projects** - Logical groupings of infrastructure that can reproduce environments. Examples include application domains ("ecommerce", "api", "billing") or platform infrastructure ("network", "compute platform", "data platform")
- Create **environments** within projects - Named environments ("dev", "staging", "production"), [preview environments](https://docs.massdriver.cloud/preview_environments/overview) ("PR 123"), or regional deployments ("Production US East 1", "US West 2")
- Add bundles to your **canvas** (the visual diagram where you design your architecture)
- **Connect** bundles together—linking outputs (artifacts) from one bundle to inputs (connections) of another passing configuration between provisioning pipelines (no copypasta! no brittle scripts!)
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

   **Automatic Publishing (Recommended)**: If you've configured GitHub Secrets and Variables (step 3), artifact definitions and bundles are automatically published on push to `main`. Simply push your changes:

   ```bash
   git push origin main
   ```

   **Manual Publishing**: Alternatively, you can publish manually using the included Makefile:

   ```bash
   make all
   ```

   This command will:
   - Clean up any previous build artifacts
   - Publish artifact definitions to your Massdriver instance
   - Build all bundles (generates schema JSON files from `massdriver.yaml`)
   - Validate all bundles with OpenTofu, Helm, etc.
   - Publish all bundles to your Massdriver instance using your default `mass` CLI profile

   **Publishing** makes your artifact definitions and bundles available in your Massdriver instance. Once published, you'll see them in the Massdriver UI and can add them to your environment canvases.

## Workflow

This catalog is designed for a three-phase approach: model your architecture, implement the infrastructure code, then continuously improve.

### Phase 1: Architecture Modeling (Now)

1. Use the provided artifact definitions and bundle schemas as-is (no infrastructure code needed yet)
2. Create projects and environments in the Massdriver UI
3. Add bundles to your canvas (creating packages)
4. Connect them by linking artifact outputs to connection inputs
5. Configure parameters to test what the developer experience feels like
6. Iterate on artifact definitions and bundle scopes until they feel right

**Goal**: Understand what services you want to offer, how they connect, and what the developer experience should be. You're designing the self-service platform interface _before_ writing any infrastructure code.

**Key insight**: This phase is about discovering the right abstractions. Does it make sense to have separate `postgres` and `mysql` bundles? Should your network bundle produce separate "public subnet" and "private subnet" artifacts, or one combined "network" artifact? The schemas let you explore these questions quickly without committing to implementation details.

**Don't aim for perfection—aim for feedback.** Get a working version in front of your developers and iterate based on their input. The abstractions that make sense on paper often need refinement once developers actually use them. You can always add more bundles, refine parameters, or adjust artifact definitions later. Real developer feedback is more valuable than theoretical perfection.

### Phase 2: Implementation (When Ready)

> [!TIP]
> Check out the [Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview) for detailed documentation on bundle and artifact definition development.

1. Replace placeholder OpenTofu/Terraform in `bundles/*/src/`
2. Test your infrastructure code locally with `tofu plan`
3. Update parameter schemas if your implementation needs different inputs
4. Push to `main` to automatically publish bundles via GitHub Actions, or use `make all` for manual publishing
5. Deploy packages to test environments and validate everything works

**Goal**: Fill in the infrastructure code that matches your architectural model.

**Key benefit**: Because you already validated the architecture and developer experience in Phase 1, you're implementing against a proven design. You know what parameters developers need, what connections make sense, and what artifacts to produce.

### Phase 3: Continuous Improvement

1. Add more bundles as needed
2. Create custom artifact definitions for your organization
3. Refine parameter validation and UI schemas
4. Use [release channels and strategies](https://docs.massdriver.cloud/concepts/versions#release-channels) to automate version distribution and upgrades across environments
5. 👋 Say farewell to ticket ops

## Repository Structure

```
.
├── README.md                           # This file
├── Makefile                            # Automation for publishing
├── artifact-definitions/               # Infrastructure artifact contracts
│   ├── application/
│   │   └── massdriver.yaml
│   ├── bucket/
│   │   └── massdriver.yaml
│   ├── mysql/
│   │   └── massdriver.yaml
│   ├── network/
│   │   └── massdriver.yaml
│   └── postgres/
│       └── massdriver.yaml
├── bundles/                            # Infrastructure-as-Code modules
│   ├── application/                    # Example Application
│   ├── bucket/                         # Object storage
│   ├── mysql/                          # MySQL database
│   ├── network/                        # VPC/Network
│   └── postgres/                       # PostgreSQL database
└── platforms/                          # Supported cloud platforms & default auth methods
    ├── aws/                            # IAM Role
    ├── azure/                          # Service Principal
    ├── gcp/                            # Service Account
    ├── kubernetes/                     # Namespace + kubeconfig
    └── .../                            # + add any cloud your IaC supports
```

## Customization Guide

### Artifact Definitions

[Artifact definitions](https://docs.massdriver.cloud/concepts/artifact-definitions) in `artifact-definitions/` define the contracts between bundles—what data gets passed from one to another.

[Customize artifact definitions](https://docs.massdriver.cloud/guides/custom-artifact-definition) to:

- **Pass connection info between bundles** - A database bundle outputs hostname, port, credentials. An application bundle receives those as inputs and can connect immediately.
- **Validate data before it's used** - Ensure CIDR blocks are valid IP ranges, database names match naming rules, or ports are in valid ranges. Catch config errors before provisioning.
- **Mark sensitive fields** - Use `$md.sensitive: true` on passwords, API keys, certificates. They get masked in UIs and logs but are available to bundles that need them.

> [!TIP]
> When you standardize what your bundles produce—defining consistent artifact schemas—you can automate compliance and security policies across all resources of that type. This eliminates the brittle copy-paste scripts and custom glue code typically needed to wire infrastructure together, replacing them with validated, reusable contracts.

### Bundle Schemas

Each bundle's `massdriver.yaml` defines the complete contract for that infrastructure component:

- **params**: Input parameters that users configure when deploying (instance sizes, database names, feature flags, etc.). These become variables in your IaC code. They provide extra UI controls and validations not available in most IaC tools.

- **connections**: Input artifacts that this bundle depends on. For example, a database bundle might require a connection to a network artifact. Connections securely pass data (credentials, IAM policies, endpoints) from one bundle to another during provisioning. These become variables in your IaC code, and Massdriver validates that only compatible artifacts can be connected.

- **artifacts**: Output artifacts that this bundle produces for other bundles to consume. For example, a database bundle produces a database artifact containing connection details. You populate these in your IaC code's outputs.

- **ui**: UI schema that controls how the configuration form is rendered—field ordering, help text, conditional visibility, custom widgets, etc. This follows the React JSON Schema Form specification.

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
   - [`var.md_metadata`](https://docs.massdriver.cloud/getting-started/using-bundle-metadata#md_metadata-structure) - Massdriver metadata (name, package ID, environment)
5. **Output** artifact data that matches your artifacts schema (connection details, resource IDs, etc.)

**Example**: If your params schema defines a `database_name` parameter, access it in Terraform as `var.database_name`. If your connections schema requires a `network` artifact named `net`, access its VPC ID as `var.net.data.infrastructure.vpc_id`.

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

- 🚀 **[GitHub Actions](https://github.com/massdriver-cloud/actions)** - This repository includes pre-configured workflows that automatically publish artifact definitions and bundles on push to `main`. See the [Quick Start](#quick-start) section for setup instructions.

## Best Practices

### Do ✅

- **Start with modeling**: Use the schemas to plan before implementing
- **Single-purpose bundles**: Keep bundles focused (e.g., `postgres`, not `rds`)
- **Iterate on abstractions**: Refine artifact definitions based on usage
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
- 🎯 **[Core Artifact Definitions](https://github.com/massdriver-cloud/artifact-definitions)** - Standard artifact types in the Massdriver SaaS Platform. They're great to use as inspiration or a foundation.
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
