# Massdriver Bootstrap Repository

A getting started repository for self-hosted Massdriver instances. This repo helps you quickly model your platform architecture, plan your developer experience, and bootstrap your infrastructure-as-code setup.

## The Problem This Solves

After setting up a self-hosted Massdriver instance, teams often face a chicken-and-egg problem:

1. **Where do I start?** You need to configure supported clouds, design artifact abstractions, write Terraform/OpenTofu modules, *and then* think about developer experience.
2. **Analysis paralysis**: It's hard to visualize project structure, environments, and service offerings before writing infrastructure code.
3. **Missing baseline**: No starting point for credential definitions or artifact abstractions that work across cloud providers.

This repository flips the script: **model first, implement later**.

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

This repo includes baseline definitions for the three major cloud providers:
- `aws-iam-role.json` - AWS IAM Role credentials
- `azure-service-principal.json` - Azure Service Principal credentials  
- `gcp-service-account.json` - GCP Service Account credentials

**Note**: These are starting points. Customize them to match the provider block requirements of your OpenTofu/Terraform code.

### 📁 `artifact-definitions/`

**Artifact definitions** are JSON Schema-based contracts that define how infrastructure components can interact with each other in Massdriver. Think of them as type definitions for your infrastructure—they ensure that when you connect a database to an application, both sides speak the same language.

Each artifact definition has two parts:
- **`data`**: Encrypted connection details (credentials, endpoints, security groups)
- **`specs`**: Public metadata (region, tags, capabilities) visible in the UI

This repo includes starter definitions for common infrastructure:
- `network.json` - Network/VPC abstractions (subnets, CIDR blocks, routing)
- `postgres.json` - PostgreSQL database connection contracts
- `mysql.json` - MySQL database connection contracts
- `bucket.json` - Object storage bucket access contracts

**Why they matter**: Artifact definitions enable type-safe infrastructure composition. You can't accidentally connect a PostgreSQL artifact to a bundle expecting MySQL—the system validates compatibility at design time, before any infrastructure is deployed.

Use artifact definitions to:
- Define the contract between your IaC modules (what data gets passed from one to another)
- Model how services connect together in your architecture
- Design your project and environment structure
- Plan the developer experience before writing infrastructure code

### 📁 `bundles/`

**Bundles** are reusable, versioned definitions of cloud infrastructure or application components. A bundle encapsulates everything needed to provision and manage a piece of infrastructure: the IaC code, configuration schemas, dependencies, outputs, and policies.

Bundles provide a safe self-service framework where you (the platform team) encode best practices into ready-to-use modules, and developers get a simple interface to deploy what they need.

This repo includes template bundles with complete schemas and placeholder infrastructure code:
- `network/` - Network/VPC provisioning
- `postgres/` - PostgreSQL database provisioning
- `mysql/` - MySQL database provisioning
- `bucket/` - Object storage bucket provisioning
- `application/` - Application deployment template

Each bundle includes:
- ✅ Complete `massdriver.yaml` configuration
- ✅ **Parameter schemas** - Define what users configure (instance sizes, database names, etc.)
- ✅ **Connection schemas** - Define what infrastructure this bundle depends on (e.g., a database needs a network)
- ✅ **Artifact schemas** - Define what infrastructure this bundle produces for others to consume
- ✅ **UI schemas** - Control how the configuration form looks and behaves
- 🚧 Placeholder OpenTofu/Terraform code (replace with yours)

**The key insight**: Bundles let you model first, implement later. Use the schemas to plan your architecture and test the developer experience in the Massdriver UI, then fill in the actual infrastructure code when you're ready.

## Getting Started

### Prerequisites

- Self-hosted Massdriver instance configured
- [Massdriver CLI (`mass`)](https://docs.massdriver.cloud/cli) installed and authenticated
- OpenTofu or Terraform installed (for implementing bundles)

### Quick Start

1. **Clone this repository**
   ```bash
   git clone <your-private-repo-url>
   cd massdriver-bootstrap
   ```

2. **Explore and customize**
   - Review artifact definitions in `artifact-definitions/`
   - Explore bundle schemas in `bundles/*/massdriver.yaml`
   - Customize credential definitions to match your provider blocks
   - Use the schemas to model your projects and environments

3. **Model your platform**
   - Open the Massdriver UI
   - Create **projects** (logical groupings of infrastructure, like "ecommerce-platform")
   - Create **environments** within projects (like "dev", "staging", "production")
   - Add bundles to your **canvas** (the visual diagram where you design your architecture)
   - **Connect** bundles together—linking outputs (artifacts) from one bundle to inputs (connections) of another
   - Configure **parameters** to test what the developer experience feels like

4. **Implement infrastructure code**
   - When ready, replace placeholder code in `bundles/*/src/` with your OpenTofu/Terraform
   - Test locally with `opentofu init` and `opentofu plan`
   - Update schemas if your implementation needs different parameters

5. **Publish to Massdriver**
   ```bash
   make
   ```
   
   **Publishing** makes your artifact definitions and bundles available in your Massdriver instance. Once published, you'll see them in the Massdriver UI and can add them to your environment canvases.
   
   This command will:
   - Clean up any previous build artifacts
   - Publish credential definitions to your Massdriver instance
   - Publish artifact definitions to your Massdriver instance
   - Build all bundles (generates schema JSON files from `massdriver.yaml`)
   - Publish all bundles to your Massdriver instance using your default `mass` CLI profile

### Publishing Individually

You can also publish components individually:

```bash
# Publish only credential definitions
make publish-credentials

# Publish only artifact definitions
make publish-artdefs

# Build bundles (generates schema files)
make build-bundles

# Publish only bundles
make publish-bundles

# Clean generated files
make clean
```

## Workflow

This repository is designed for a three-phase approach: model your architecture, implement the infrastructure code, then continuously improve.

### Phase 1: Architecture Modeling (Now)

1. Use the provided artifact definitions and bundle schemas as-is (no infrastructure code needed yet)
2. Create projects and environments in the Massdriver UI
3. Add bundles to your canvas (creating packages)
4. Connect them by linking artifact outputs to connection inputs
5. Configure parameters to test what the developer experience feels like
6. Iterate on artifact definitions and bundle scopes until they feel right

**Goal**: Understand what services you want to offer, how they connect, and what the developer experience should be. You're designing the self-service platform interface *before* writing any infrastructure code.

**Key insight**: This phase is about discovering the right abstractions. Does it make sense to have separate `postgres` and `mysql` bundles? Should your network bundle produce separate "public subnet" and "private subnet" artifacts, or one combined "network" artifact? The schemas let you explore these questions quickly without committing to implementation details.

### Phase 2: Implementation (When Ready)

1. Replace placeholder OpenTofu/Terraform in `bundles/*/src/`
2. Test your infrastructure code locally with `opentofu plan`
3. Update parameter schemas if your implementation needs different inputs
4. Publish with `make` to make bundles available in Massdriver
5. Deploy packages to test environments and validate everything works

**Goal**: Fill in the infrastructure code that matches your architectural model.

**Key benefit**: Because you already validated the architecture and developer experience in Phase 1, you're implementing against a proven design. You know what parameters developers need, what connections make sense, and what artifacts to produce.

### Phase 3: Continuous Improvement

1. Add more bundles as needed
2. Create custom artifact definitions for your organization
3. Refine parameter validation and UI schemas
4. Share bundles across teams

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
    ├── application/                    # Application deployment template
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

Artifact definitions in `artifact-definitions/` define the contracts between bundles—what data gets passed from one IaC module to another.

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

- **params**: Input parameters that users configure when deploying (instance sizes, database names, feature flags, etc.). These become variables in your IaC code via `var.params.*`.

- **connections**: Input artifacts that this bundle depends on. For example, a database bundle might require a connection to a network artifact. These become variables in your IaC code via `var.connections.*`. Massdriver validates that only compatible artifacts can be connected.

- **artifacts**: Output artifacts that this bundle produces for other bundles to consume. For example, a database bundle produces a database artifact containing connection details. You populate these in your IaC code's outputs.

- **ui**: UI schema that controls how the configuration form is rendered—field ordering, help text, conditional visibility, custom widgets, etc. This follows the React JSON Schema Form specification.

Customize these schemas to match your desired developer experience. The schemas define the self-service interface your developers will use, so invest time in making them clear, well-documented, and user-friendly.

### Bundle Implementation

When you're ready to implement the actual infrastructure provisioning, replace the placeholder OpenTofu/Terraform code in `bundles/*/src/`.

**How it works**: Massdriver bundles are wrappers around your existing IaC code. The schemas define the interface (what goes in, what comes out), and your IaC code does the actual provisioning. Massdriver automatically generates input variables from your params and connections schemas, then executes your IaC code with those values.

To implement a bundle:

1. **Keep** the `_massdriver_variables.tf` file - it's auto-generated by `mass bundle build` from your schemas
2. **Replace** `main.tf` with your infrastructure code
3. **Add** additional `.tf` files as needed (variables.tf, outputs.tf, etc.)
4. **Use** Massdriver-provided variables:
   - `var.md_metadata` - Massdriver metadata (name, package ID, environment)
   - `var.params` - User-configured parameters from your params schema
   - `var.connections` - Artifacts from connected bundles from your connections schema
5. **Output** artifact data that matches your artifacts schema (connection details, resource IDs, etc.)

**Example**: If your params schema defines a `database_name` parameter, access it in Terraform as `var.params.database_name`. If your connections schema requires a network artifact, access its VPC ID as `var.connections.network.data.infrastructure.vpc_id`.

## What's Next?

### Coming Soon

- 🚀 GitHub Actions workflow for automated publishing
- 📦 Additional bundle templates (Kubernetes, VMs, Functions, Queues)
- 🎨 Bundle icon generation
- 🔗 Landing zone bundle (combines multiple artifacts)

### Roadmap Ideas

See `TODOS.md` for planned enhancements.

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
- 🎯 **[Bundle Examples](https://github.com/massdriver-cloud/artifact-definitions)** - Core artifact definitions
- 💬 **[Massdriver Slack](https://massdriver.cloud/slack)** - Community support

## Support

Questions or issues? 
- Review existing bundle schemas for patterns
- Reach out to Massdriver support
- 

## License

Private repository - customize for your organization's needs.

---

**Remember**: This repo is your platform foundation. Clone it, customize it, make it yours. The goal is to help you think through architecture and developer experience before writing infrastructure code. Start modeling today, implement tomorrow.
