# Massdriver Catalog

A bootstrap catalog for self-hosted Massdriver instances containing artifact definitions, infrastructure bundles, and cloud credentials. This catalog helps you quickly model your platform architecture and developer experience before implementing infrastructure code.

**This is your platform foundation.** While this guide walks you through the concepts, you're not just following a tutorial—you're building your actual platform. This repository will serve as your platform team's source of truth for artifact definitions and bundles. Design your infrastructure architecture, iterate on the developer experience, and refine your abstractions here—then fill in your OpenTofu/Terraform implementation when you're ready.

**tl;dr:** [Jump to Quick Start](#customizing-your-catalog)

## Quick Start Workflow

This catalog is yours to customize and extend. Here's the recommended workflow:

1. **Clone this repository** to your organization (keep it private—it will contain your infrastructure code)
2. **Set up GitHub Actions** to automatically publish to your private Massdriver or use included `make` task to publish
3. **Start experimenting** with bundles in your editor—edit schemas, add parameters, define connections
4. **Watch the developer experience get built** in real-time in Massdriver as you iterate on your abstractions

The beauty of this approach: you can refine the entire developer experience—what parameters developers see, how bundles connect, what artifacts are produced—all before writing a single line of infrastructure code.

## Key Concepts

If you're new to Massdriver, here are the core concepts you'll encounter:

- **Bundle**: A reusable, versioned definition of infrastructure or application components. Bundles encapsulate your IaC code (Terraform/OpenTofu/Helm), configuration schemas, dependencies, and policies into a single deployable unit. Think of them as "infrastructure packages" with built-in guardrails.

- **Artifact Definition**: A JSON Schema contract that defines how infrastructure components can connect to each other. Artifact definitions ensure type safety—you can't connect incompatible components. Each has `data` (encrypted secrets/credentials) and `specs` (public metadata).

- **Artifact**: The actual instance of an artifact definition produced by a deployed bundle. For example, when you deploy a PostgreSQL bundle, it emits a PostgreSQL artifact containing connection details that other bundles can consume.

- **Parameters (params)**: User-configurable inputs for a bundle, like instance sizes, database names, or feature flags. These define what developers can customize when deploying infrastructure.

- **Connections**: Dependencies between bundles. When a bundle declares it needs a connection to a "network" artifact, you must link it to another bundle that produces a network artifact. This is how you compose infrastructure components.

- **Project**: A logical grouping of related infrastructure, like "ecommerce-platform" or "data-pipeline". Projects contain one or more environments.

- **Environment**: A deployment target within a project, like "development", "staging", or "production". Each environment has its own canvas where you design and deploy infrastructure.

- **Canvas**: The visual diagram in the Massdriver UI where you add bundles, connect them together, and configure parameters. It's your infrastructure design board.

- **Package**: An instance of a bundle configured and deployed to a specific environment. When you add a bundle to your canvas and configure it, you're creating a package. Think of it like the relationship between a class and an object in programming—bundles are the reusable definitions, packages are the deployed instances.


## What's Inside

### 📁 `credential-artifact-definitions/`

**Credential definitions** are special artifact definitions that define how Massdriver authenticates to your cloud providers. They specify the authentication contract between Massdriver and your cloud accounts.

This catalog includes baseline definitions for the three major cloud providers:
- `aws-iam-role.json` - AWS IAM Role credentials
- `azure-service-principal.json` - Azure Service Principal credentials  
- `gcp-service-account.json` - GCP Service Account credentials

**Note**: These are starting points. Customize them to match the provider block requirements of your OpenTofu/Terraform code.

### 📁 `artifact-definitions/`

**Artifact definitions** are JSON Schema-based contracts that define how infrastructure components can interact with each other in Massdriver. Think of them as type definitions for your infrastructure—they ensure that when you connect a database to an application, both sides speak the same language.

Each artifact definition has two parts:
- **`data`**: Encrypted connection details passed between bundles during automation—IAM policies that downstream services can assume, secret store IDs for credential access, database hostnames, API endpoints, security group IDs. This is the connective tissue that's often cumbersome to automate manually but is vital for compliance and security.
- **`specs`**: Public metadata (region, tags, capabilities) visible in the UI

> [!TIP]
> **Security best practice**: While artifact `data` is encrypted at rest and in transit (and access is logged when queried via API), we recommend passing references to your cloud secret stores rather than the secrets themselves. For example, pass an AWS Secrets Manager ARN, Azure Key Vault ID, or GCP Secret Manager resource name—then let downstream bundles retrieve secrets directly from your cloud provider. This provides an additional security layer and prevents secrets from being stored outside your cloud environment.

This catalog includes **example artifact definitions** for common infrastructure patterns:
- `network.json` - Example network/VPC abstraction (subnets, CIDR blocks, routing)
- `postgres.json` - Example PostgreSQL database connection contract
- `mysql.json` - Example MySQL database connection contract
- `bucket.json` - Example object storage bucket access contract

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
- ✅ **Connection schemas** - Define dependencies on artifacts from other bundles, enabling secure access to their encrypted data (credentials, IAM policies) and specs (metadata)
- ✅ **Artifact schemas** - Define what infrastructure this bundle produces for others to consume
- ✅ **UI schemas** - Control how the configuration form looks and behaves
- 🚧 Placeholder OpenTofu/Terraform code (replace with yours)

These bundles let you model first, implement later. Use the schemas to plan your architecture and test the developer experience in the Massdriver UI, then fill in the actual infrastructure code when you're ready.

## Customizing Your Catalog

### Prerequisites

- Self-hosted Massdriver instance configured
- [Massdriver CLI (`mass`)](https://docs.massdriver.cloud/cli) installed and authenticated
- OpenTofu or Terraform installed (for implementing bundles)

### Quick Start

1. **Clone this repository**
   ```bash
   git clone <your-private-repo-url>
   cd massdriver-catalog
   ```

2. **Explore and customize**
   - Review artifact definitions in `artifact-definitions/`
   - Explore bundle schemas in `bundles/*/massdriver.yaml`

3. **Model your platform**
   - Open the Massdriver UI
   - Create **projects** - Logical groupings of infrastructure that can reproduce environments. Examples include application domains ("ecommerce", "api", "billing") or platform infrastructure ("network", "compute platform", "data platform")
   - Create **environments** within projects - Named environments ("dev", "staging", "production"), [preview environments](https://docs.massdriver.cloud/preview_environments/overview) ("PR 123"), or regional deployments ("Production US East 1", "US West 2")
   - Add bundles to your **canvas** (the visual diagram where you design your architecture)
   - **Connect** bundles together—linking outputs (artifacts) from one bundle to inputs (connections) of another passing configuration between provisioning pipelines (no copypasta! no brittle scripts!)
   - Configure **parameters** to test what the developer experience feels like

4. **Implement infrastructure code**
   - Customize credential definitions to match your provider blocks
   - When ready, replace placeholder code in `bundles/*/src/` with your OpenTofu/Terraform
   - Test locally with `tofu init` and `tofu plan` or run rapid infrastructure testing with [`mass bundle publish --development`](https://docs.massdriver.cloud/concepts/versions#rapid-infrastructure-testing)
   - Update schemas if your implementation needs different parameters

5. **Publish to Massdriver**
   ```bash
   make
   ```

   > [!IMPORTANT]
   > You'll probably want to replace `make` with our Artifact Definition and Bundle publishing [GitHub Actions](https://github.com/massdriver-cloud/actions).
   
   **Publishing** makes your artifact definitions and bundles available in your Massdriver instance. Once published, you'll see them in the Massdriver UI and can add them to your environment canvases.
   
   This command will:
   - Clean up any previous build artifacts
   - Publish credential definitions to your Massdriver instance
   - Publish artifact definitions to your Massdriver instance
   - Build all bundles (generates schema JSON files from `massdriver.yaml`)
   - Publish all bundles to your Massdriver instance using your default `mass` CLI profile



## Workflow

This catalog is designed for a three-phase approach: model your architecture, implement the infrastructure code, then continuously improve.

### Phase 1: Architecture Modeling (Now)

1. Use the provided artifact definitions and bundle schemas as-is (no infrastructure code needed yet)
2. Create projects and environments in the Massdriver UI
3. Add bundles to your canvas (creating packages)
4. Connect them by linking artifact outputs to connection inputs
5. Configure parameters to test what the developer experience feels like
6. Design artifact `data` to transmit sensitive data between bundles
7. Design artifact `specs` to surface infrastructure metadata into the Massdriver UI
8. Iterate on artifact definitions and bundle scopes until they feel right

**Goal**: Understand what services you want to offer, how they connect, and what the developer experience should be. You're designing the self-service platform interface *before* writing any infrastructure code.

**Key insight**: This phase is about discovering the right abstractions. Does it make sense to have separate `postgres` and `mysql` bundles? Should your network bundle produce separate "public subnet" and "private subnet" artifacts, or one combined "network" artifact? The schemas let you explore these questions quickly without committing to implementation details.

**Don't aim for perfection—aim for feedback.** Get a working version in front of your developers and iterate based on their input. The abstractions that make sense on paper often need refinement once developers actually use them. You can always add more bundles, refine parameters, or adjust artifact definitions later. Real developer feedback is more valuable than theoretical perfection.

### Phase 2: Implementation (When Ready)

> [!TIP]
> Check out the [Getting Started Guide](https://docs.massdriver.cloud/getting-started/overview) for detailed documentation on bundle and artifact definition development.

1. Replace placeholder OpenTofu/Terraform in `bundles/*/src/`
2. Test your infrastructure code locally with `tofu plan`
3. Update parameter schemas if your implementation needs different inputs
4. Publish with `make` (or git push with our [GitHub Actions](https://github.com/massdriver-cloud/actions)) to make bundles available in Massdriver
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
├── credential-artifact-definitions/    # Cloud provider credentials
│   ├── aws-iam-role.json
│   ├── azure-service-principal.json
│   └── gcp-service-account.json
├── artifact-definitions/               # Infrastructure artifact contracts
│   ├── bucket.json
│   ├── mysql.json
│   ├── network.json
│   └── postgres.json
└── bundles/                            # Infrastructure and application bundles
    ├── application/                    # Example Application
    ├── bucket/                         # Object storage
    ├── mysql/                          # MySQL database
    ├── network/                        # VPC/Network
    └── postgres/                       # PostgreSQL database
```

## Customization Guide

### Credential Definitions

The credential definitions in `credential-artifact-definitions/` define the authentication contracts for cloud providers. Customize these to match your organization's provider block requirements.

**Example**: If your AWS provider block requires additional fields like `external_id` or `session_name`, add them to the `aws-iam-role.json` schema.

### Artifact Definitions

Artifact definitions in `artifact-definitions/` define the contracts between bundles—what data gets passed from one to another.

Each artifact definition must have two top-level sections:
- **`data`**: Encrypted-at-rest information like credentials, connection strings, IAM policies, and security group IDs. This data is securely passed to downstream bundles that need it.
- **`specs`**: Public metadata like cloud region, tags, or capability flags. This information is searchable and displayed in the UI but doesn't contain secrets.

Customize artifact definitions to:
- Add cloud-specific metadata in `specs` (region, availability zones, resource tags)
- Include additional connection details in `data` that your applications need (ports, endpoints, credentials)
- Define IAM policy structures and security group references
- Add validation rules to ensure data integrity

**Example**: If your applications need to know whether a database supports read replicas, add a `read_replicas` field to the artifact's `specs`. If they need the replica endpoint, add it to the artifact's `data`.

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

**Example**: If your params schema defines a `database_name` parameter, access it in Terraform as `var.params.database_name`. If your connections schema requires a network artifact, access its VPC ID as `var.connections.network.data.infrastructure.vpc_id`.

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

### Coming Soon

- 🚀 GitHub Actions workflow for automated publishing
- 📦 Additional bundle templates (Kubernetes, VMs, Functions, Queues)
- 🎨 Bundle icon generation
- 🔗 Landing zone bundle (combines multiple artifacts)

See [open issues](https://github.com/massdriver-cloud/massdriver-catalog/issues) for the full roadmap.

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
