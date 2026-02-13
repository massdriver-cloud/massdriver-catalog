---
name: massdriver
description: Helps develop Massdriver bundles, artifact definitions, and platform integrations. Auto-activates when working with massdriver.yaml, bundles/, artifact-definitions/, or platforms/ directories. Provides patterns, scaffolding guidance, and validation rules for the Massdriver catalog.
---

# Massdriver Bundle Development

You are helping develop infrastructure bundles and artifact definitions for Massdriver. This skill provides patterns, guard rails, and workflows for the massdriver-catalog repository.

## Auto-Activation Triggers

This skill should be loaded when:
- Working in `bundles/` or `artifact-definitions/` or `platforms/` directories
- Editing `massdriver.yaml` files
- User asks about bundles, artifacts, connections, or Massdriver patterns

## Core Concepts

**Bundle**: Reusable IaC module with declarative configuration (`massdriver.yaml` + `src/` code)

**Artifact Definition**: Schema contract defining data structures passed between bundles. Supports:
- **Schema** → Generates UI form for manual artifact creation
- **Instructions** (`instructions/`) → Markdown walkthroughs (e.g., how to get credentials from AWS Console)
- **Exports** (`exports/`) → Downloadable files (e.g., kubeconfig)
- **Environment Defaults** (`ui.environmentDefaultGroup`) → Set as default for an environment; packages auto-receive it
- **Connection Presentation** → Linkable handles vs environment-default-only (enables cross-project sharing)

**Artifact**: Instance of an artifact definition containing actual data (credentials, connection strings, resource IDs). Created by:
- Bundles (via `massdriver_artifact` resource in artifacts.tf)
- Users (entering data via UI form generated from artifact definition schema)

**Platform**: An artifact definition for cloud authentication (`platforms/*/massdriver.yaml`). Technically identical to artifact definitions - the separate directory is purely organizational to distinguish infrastructure artifacts from authentication/onboarding artifacts. Platforms are pre-configured credential schemas (AWS IAM role, GCP service account, etc.) that jumpstart cloud onboarding.

**Connection**: How bundles receive artifacts. When a bundle declares a connection (e.g., `$ref: aws-iam-role`), users assign an artifact of that type to it. At deploy time, the artifact data flows into the bundle as a Terraform variable.

**Key Flow**: Edit `massdriver.yaml` → `mass bundle build` (generates schemas) → `tofu validate` → `mass bundle publish`

## Bundle Scoping and Resource Lifecycle

**This is critical for designing composable, maintainable bundles.** A bundle should contain resources that share the same operational lifecycle - they're created, updated, and destroyed together as a unit.

### The Lifecycle Principle

Ask these questions when deciding what belongs in a bundle:

1. **"If I delete this bundle, what should disappear?"** - All those resources belong together
2. **"If I change this setting, what else must change?"** - Those resources share configuration lifecycle
3. **"Who owns this operationally?"** - Resources with different owners should be separate bundles
4. **"How often does this change?"** - Resources with vastly different change frequencies should be separate

### Lifecycle Tiers (from long-lived to ephemeral)

**Foundational Infrastructure** (rarely changes, shared by many things):
- Networks/VPCs, subnets, NAT gateways, route tables
- Container registries, DNS zones
- *Owned by: Platform team*

**Stateful Services** (medium lifecycle, careful changes):
- Databases, caches, message queues, storage buckets
- Search clusters, data warehouses
- *Owned by: Platform team or application team*

**Compute & Applications** (frequent changes):
- Kubernetes deployments, serverless functions
- Application containers, API gateways
- *Owned by: Application team*

### What Stays IN the Bundle (Supporting Resources)

Resources that are **specific to and managed with** the primary resource:

```
aws-rds-postgres bundle contains:
├── aws_db_instance (primary resource)
├── aws_db_subnet_group (RDS-specific, uses VPC subnets)
├── aws_security_group (RDS-specific ingress rules)
├── aws_kms_key (encryption for this DB only)
├── aws_db_parameter_group (DB configuration)
├── aws_iam_role (enhanced monitoring for this DB)
└── CloudWatch alarms (monitoring this DB)
```

These all share the same lifecycle - when you delete the database, you delete its subnet group, its security group, its encryption key, etc.

### What Becomes a CONNECTION (Dependencies)

Resources that **exist independently** and are **shared** by multiple things:

```
aws-rds-postgres connections:
├── aws_authentication → massdriver/aws-iam-role (credential to deploy)
└── network → massdriver/aws-vpc (VPC created by another bundle)
```

The VPC has its own lifecycle - it was created before the database and will outlive it. Multiple databases, applications, and services share it.

### Anti-Pattern: Coupled Lifecycles

**BAD** - Creating a VPC inside a database bundle:
```hcl
# Don't do this in a postgres bundle!
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "private" { ... }
resource "aws_db_instance" "main" { ... }
```

Problems:
- Deleting the database deletes the network (catastrophic if shared)
- Can't deploy multiple databases to the same network
- Can't reuse the network for other services
- Violates single-responsibility principle

**GOOD** - Taking network as a connection:
```yaml
# massdriver.yaml
connections:
  required:
    - aws_authentication
    - network
  properties:
    aws_authentication:
      $ref: massdriver/aws-iam-role
    network:
      $ref: massdriver/aws-vpc
```

```hcl
# main.tf - uses the network, doesn't create it
resource "aws_db_subnet_group" "main" {
  subnet_ids = [for s in var.network.data.infrastructure.private_subnets : s.arn]
}

resource "aws_db_instance" "main" {
  db_subnet_group_name = aws_db_subnet_group.main.name
  # ...
}
```

### Discovering Existing Bundles and Artifacts

Before creating a bundle, check what already exists:

```bash
# List available bundles (potential patterns to follow)
mass bundle list

# List artifact definitions (potential connections)
mass def list

# Get details on an artifact definition schema
mass def get massdriver/aws-vpc
mass def get massdriver/postgresql-authentication
```

If a network bundle exists, use it as a connection. If a database artifact definition exists, produce that artifact type.

### Scoping Decision Tree

```
Is this resource...
│
├─ Shared by multiple things? ──────────────────────> Separate bundle (connection)
│   (VPC, K8s cluster, DNS zone)
│
├─ Created before and lives after primary? ─────────> Separate bundle (connection)
│   (Network for a database, cluster for an app)
│
├─ Owned by a different team? ──────────────────────> Separate bundle (connection)
│   (Platform team's network vs app team's database)
│
├─ Changes on a very different schedule? ───────────> Separate bundle (connection)
│   (VPC changes yearly, app deploys daily)
│
└─ Specific to and dies with the primary resource? ─> Same bundle
    (DB security group, DB parameter group, DB KMS key)
```

### Real-World Scoping Examples

**AWS VPC Bundle** (foundational):
- VPC, subnets, internet gateway, NAT gateways, route tables, flow logs
- All network foundation that rarely changes
- Produces: `massdriver/aws-vpc` artifact

**AWS RDS PostgreSQL Bundle** (stateful service):
- RDS instance, DB subnet group, security group, KMS key, parameter group, monitoring
- Takes: `massdriver/aws-vpc` (network), `massdriver/aws-iam-role` (auth)
- Produces: `massdriver/postgresql-authentication` artifact

**K8s Application Bundle** (compute):
- Deployment, service, ingress, HPA, configmaps
- Takes: `massdriver/kubernetes-cluster`, `massdriver/postgresql-authentication`
- Produces: `massdriver/api` artifact (optional)

**GCP Network Layering** (fine-grained for multi-region):
- `gcp-global-network`: Just the VPC (global)
- `gcp-subnetwork`: Regional subnet, takes global-network as connection
- Enables: one global network, multiple regional subnets with separate lifecycles

## How Artifacts Enable IaC

Artifacts bridge configuration to bundle deployments:

```
1. Artifact definition schema → UI form (user enters data)
2. Saved form → Artifact stored in Massdriver
3. User assigns artifact to package connection in project environment
4. Bundle deploys → Artifact data flows via connection variable
5. Terraform uses the data (provider auth, resource config, etc.)
```

**Example: AWS RDS Bundle with credential + network artifacts**
```yaml
# Bundle's massdriver.yaml
connections:
  required:
    - aws_authentication
    - network
  properties:
    aws_authentication:
      $ref: aws-iam-role  # Credential artifact for provider auth
    network:
      $ref: network       # Infrastructure artifact from another bundle
```

```hcl
# Bundle's src/main.tf
provider "aws" {
  region = var.network.region  # Or var.region from params
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}

resource "aws_db_instance" "main" {
  vpc_security_group_ids = [for s in var.network.subnets : s.id]
}
```

## Artifact Definition Capabilities

All artifact definitions (including platforms) support these features:

**Schema** → Generates UI form; structure must match what consuming bundles expect

**Instructions** (`instructions/`) → Markdown walkthroughs showing users how to obtain values (e.g., getting IAM role ARN from AWS Console)

**Exports** (`exports/`) → Downloadable files (e.g., kubeconfig for Kubernetes credentials)

**Environment Defaults** (`ui.environmentDefaultGroup`) → Artifact can be set as default for an environment. Packages in that environment automatically receive it without explicit connection.

**Connection Presentation** → Controls whether connections appear as:
- Linkable handles (user draws connections in UI)
- Environment defaults only (automatic, no visible connection)

This enables cross-project resource sharing: Project A manages a network, Project B deploys into it but doesn't manage it.

## Schema Validation

Massdriver validates `massdriver.yaml` files against JSON schemas:
- Bundles: https://api.massdriver.cloud/json-schemas/bundle.json
- Artifact Definitions: https://api.massdriver.cloud/json-schemas/artifact-definition.json

## Critical Rules

### 1. NEVER Edit Generated Files
These files are auto-generated by `mass bundle build` - changes will be overwritten:
- `schema-*.json` - Generated from massdriver.yaml sections
- `_massdriver_variables.tf` - Generated from params + connections schemas

### 2. Namespace Collision Warning
**Params and connections share the same Terraform variable namespace.**

```yaml
# BAD - These will conflict as var.network in Terraform
params:
  properties:
    network:          # Creates var.network
connections:
  properties:
    network:          # Also creates var.network - COLLISION!
```

Always use distinct names for params and connections.

### 3. Artifact $ref Must Match Definition Name
The `$ref` value must exactly match the artifact definition directory name:

```yaml
# massdriver.yaml
connections:
  properties:
    network:
      $ref: network  # References artifact-definitions/network/massdriver.yaml
```

### 4. artifacts.tf Must Match massdriver.yaml
Every entry in `massdriver.yaml` artifacts section needs a corresponding `massdriver_artifact` resource:

```yaml
# massdriver.yaml
artifacts:
  properties:
    database:         # <-- field name
      $ref: postgres
```

```hcl
# src/artifacts.tf
resource "massdriver_artifact" "database" {
  field = "database"  # <-- Must match the field name above
  # ...
}
```

### 5. Always Include massdriver Provider

```hcl
terraform {
  required_providers {
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}
```

## File Responsibilities

| File | Purpose | Editable? |
|------|---------|-----------|
| `massdriver.yaml` | Source of truth - params, connections, artifacts, UI | Yes |
| `src/main.tf` | Your IaC code (resources, data sources) | Yes |
| `src/artifacts.tf` | massdriver_artifact resources | Yes |
| `operator.md` | Runbook with mustache templating | Yes |
| `icon.svg` | Bundle icon | Yes |
| `schema-*.json` | Generated schemas | **Never** |
| `_massdriver_variables.tf` | Generated variables | **Never** |

## Quick Start Workflows

### Creating a New Bundle

**Step 0: Scope the bundle correctly (CRITICAL)**

Before writing any code, determine what belongs in this bundle:

```bash
# Check what bundles and artifacts already exist
mass bundle list
mass def list

# Inspect artifact schemas for potential connections
mass def get massdriver/aws-vpc
mass def get massdriver/postgresql-authentication
```

Ask yourself:
- What foundational resources does this need? → Those become **connections**
- What resources are specific to this and share its lifecycle? → Those go **in the bundle**
- What artifact type should this produce? → Check if a definition exists

**Example thought process for an RDS PostgreSQL bundle:**
- Needs a VPC → `massdriver/aws-vpc` exists, use as connection
- Needs AWS credentials → `massdriver/aws-iam-role` exists, use as connection
- DB instance, subnet group, security group, KMS key → all RDS-specific, go IN bundle
- Should produce database credentials → `massdriver/postgresql-authentication` exists, produce that

1. Create bundle directory:
   ```bash
   mkdir -p bundles/my-bundle/src
   ```

2. Create `massdriver.yaml` with connections for dependencies (see `snippets/massdriver-yaml.yaml` for template)

3. Create `src/main.tf` with your infrastructure code (only resources specific to this bundle)

4. Create `src/artifacts.tf` with `massdriver_artifact` resources for each artifact

5. Create `operator.md` for operational runbook

6. Build and validate:
   ```bash
   cd bundles/my-bundle
   mass bundle build
   cd src && tofu init && tofu validate
   ```

7. Publish:
   ```bash
   mass bundle publish
   ```

### Adding a Connection to a Bundle

1. Add connection to `massdriver.yaml`:
   ```yaml
   connections:
     required:
       - network    # Add to required if mandatory
     properties:
       network:
         $ref: network
         title: Network
   ```

2. Rebuild to generate variables:
   ```bash
   mass bundle build
   ```

3. Use connection data in Terraform:
   ```hcl
   # Connection becomes a variable with artifact's structure
   resource "example" "main" {
     vpc_id     = var.network.id
     subnet_ids = [for s in var.network.subnets : s.id]
   }
   ```

### Creating an Artifact Definition

1. Create directory and `massdriver.yaml`:
   ```bash
   mkdir -p artifact-definitions/my-artifact
   ```

2. Create `artifact-definitions/my-artifact/massdriver.yaml`:
   ```yaml
   name: my-artifact
   label: My Artifact

   schema:
     title: My Artifact
     description: Description of what this artifact represents
     type: object
     required:
       - id
     properties:
       id:
         title: ID
         type: string
   ```

3. Publish:
   ```bash
   mass definition publish artifact-definitions/my-artifact/massdriver.yaml
   ```

### Creating a Platform

1. Create platform directory:
   ```bash
   mkdir -p platforms/my-cloud/instructions
   ```

2. Create `platforms/my-cloud/massdriver.yaml`:
   ```yaml
   name: my-cloud-credentials
   label: My Cloud Credentials
   icon: https://example.com/my-cloud-icon.svg

   ui:
     environmentDefaultGroup: credentials  # Groups with other credentials
     instructions:
       - label: Console Setup
         path: ./instructions/Console Setup.md

   exports: []  # Optional: downloadable files like kubeconfig

   schema:
     title: My Cloud Credentials
     description: Authentication for My Cloud provider
     type: object
     required:
       - api_key
     properties:
       api_key:
         $md.sensitive: true
         title: API Key
         description: Your My Cloud API key
         type: string
       region:
         title: Region
         description: Default region for operations
         type: string
         examples:
           - "us-east-1"
   ```

3. Create onboarding instructions (`platforms/my-cloud/instructions/Console Setup.md`):
   ```markdown
   # Getting Your API Key

   1. Log into My Cloud Console
   2. Navigate to Settings → API Keys
   3. Click "Create New Key"
   4. Copy the key and paste it below
   ```

4. Publish:
   ```bash
   mass definition publish platforms/my-cloud/massdriver.yaml
   ```

**Platform Schema Design Rules:**
- Schema must match what Terraform/OpenTofu provider needs for authentication
- Mark sensitive fields with `$md.sensitive: true`
- Provide `examples` to help users understand expected formats

**Instruction Templating:**
Instructions support dynamic variables like `{{EXTERNAL_ID}}` that are populated when displayed to users. This allows pre-filling values that Massdriver generates (like external IDs for AWS role trust policies).

## Common Patterns

### Provider Blocks Mirror Credential Artifact Schemas

**Critical:** When configuring cloud providers, the provider block arguments must match the credential artifact definition schema. The artifact defines what authentication data is available; the provider block consumes it.

**Example: AWS Provider with aws-iam-role artifact**

The `aws-iam-role` artifact definition schema:
```yaml
# platforms/aws/massdriver.yaml (or artifact-definitions/aws-iam-role)
schema:
  properties:
    arn:
      title: IAM Role ARN
      type: string
    external_id:
      title: External ID
      type: string  # Optional field
```

The provider block must use ALL relevant fields from the artifact:
```hcl
# src/main.tf
provider "aws" {
  region = var.region
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = try(var.aws_authentication.external_id, null)  # Handle optional field
  }
  default_tags {
    tags = var.md_metadata.default_tags
  }
}
```

**Example: GCP Provider with gcp-service-account artifact**
```hcl
provider "google" {
  project     = var.gcp_authentication.project_id
  region      = var.region
  credentials = var.gcp_authentication.service_account_key
}
```

**Example: Azure Provider with azure-service-principal artifact**
```hcl
provider "azurerm" {
  features {}
  subscription_id = var.azure_authentication.subscription_id
  tenant_id       = var.azure_authentication.tenant_id
  client_id       = var.azure_authentication.client_id
  client_secret   = var.azure_authentication.client_secret
}
```

**Key Rules:**
1. **Inspect the artifact schema first** - Run `mass def get <credential-artifact>` to see all available fields
2. **Use all authentication fields** - Missing fields (like `external_id`) cause auth failures
3. **Handle optional fields** - Use `try()` or conditional logic for optional schema properties
4. **Match types exactly** - If the schema says `integer`, don't treat it as a string

### Accessing Connection Data in Terraform

```hcl
# Simple field access
var.network.id
var.network.cidr

# Nested object
var.database.auth.hostname
var.database.auth.password

# Array iteration
[for s in var.network.subnets : s.id]
[for s in var.network.subnets : s.id if s.type == "private"]
```

### Creating Artifacts (artifacts.tf)

```hcl
resource "massdriver_artifact" "database" {
  field = "database"  # Must match artifacts property name in massdriver.yaml
  name  = "PostgreSQL ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    # Structure must match artifact-definitions/postgres/massdriver.yaml schema
    id = aws_rds_cluster.main.id
    auth = {
      hostname = aws_rds_cluster.main.endpoint
      port     = 5432
      database = var.database_name
      username = var.username
      password = random_password.main.result
    }
    policies = [
      { id = "read", name = "Read Only" },
      { id = "write", name = "Read/Write" }
    ]
  })
}
```

### Adding Alarms to Bundles

Massdriver integrates cloud-native alarms for visibility in the UI. See [Monitoring and Alarms Guide](https://docs.massdriver.cloud/guides/monitoring-and-alarms) for full documentation.

**Use the Massdriver Terraform modules for simplified alarm setup:**
- [aws/alarm-channel](https://github.com/massdriver-cloud/terraform-modules/tree/main/aws/alarm-channel) - Creates SNS topic for alarm notifications
- [aws/cloudwatch-alarm](https://github.com/massdriver-cloud/terraform-modules/tree/main/aws/cloudwatch-alarm) - Creates CloudWatch alarm + registers with Massdriver

**AWS CloudWatch Example (Recommended - using modules):**
```hcl
# src/alarms.tf

# 1. Create alarm channel (SNS topic) - one per bundle
module "alarm_channel" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/alarm-channel?ref=main"
  md_metadata = var.md_metadata
}

# 2. Create alarms using the channel
module "alarm_high_cpu" {
  source      = "github.com/massdriver-cloud/terraform-modules//aws/cloudwatch-alarm?ref=main"
  md_metadata = var.md_metadata

  alarm_name   = "${var.md_metadata.name_prefix}-high-cpu"
  display_name = "High CPU Utilization"
  message      = "RDS CPU utilization is above 80%"

  namespace   = "AWS/RDS"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = "300"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  threshold           = "80"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  sns_topic_arn = module.alarm_channel.arn
}
```

**Module benefits:**
- Handles SNS topic creation and Massdriver webhook subscription
- Automatically registers `massdriver_package_alarm` for UI visibility
- Consistent alarm naming and tagging

**GCP Cloud Monitoring Example:**
```hcl
resource "google_monitoring_alert_policy" "high_cpu" {
  display_name = "${var.md_metadata.name_prefix}-high-cpu"
  combiner     = "OR"

  conditions {
    display_name = "CPU Utilization > 80%"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
    }
  }

  notification_channels = [google_monitoring_notification_channel.massdriver.id]
}

resource "google_monitoring_notification_channel" "massdriver" {
  display_name = "Massdriver Webhook"
  type         = "webhook_tokenauth"
  labels = {
    url = var.md_metadata.observability.alarm_webhook_url
  }
}

resource "massdriver_package_alarm" "high_cpu" {
  display_name      = "High CPU Utilization"
  cloud_resource_id = google_monitoring_alert_policy.high_cpu.name

  metric {
    name      = "cloudsql.googleapis.com/database/cpu/utilization"
    statistic = "Average"
  }

  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  period_minutes      = 5
}
```

**Azure Monitor Example:**
```hcl
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "${var.md_metadata.name_prefix}-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "CPU utilization is above 80%"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.massdriver.id
  }
}

resource "azurerm_monitor_action_group" "massdriver" {
  name                = "${var.md_metadata.name_prefix}-massdriver"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "massdriver"

  webhook_receiver {
    name        = "massdriver"
    service_uri = var.md_metadata.observability.alarm_webhook_url
  }
}

resource "massdriver_package_alarm" "high_cpu" {
  display_name      = "High CPU Utilization"
  cloud_resource_id = azurerm_monitor_metric_alert.high_cpu.id

  metric {
    namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    name      = "cpu_percent"
    statistic = "Average"
  }

  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  period_minutes      = 5
}
```

**cloudwatch-alarm module arguments:**

| Argument | Required | Description |
|----------|----------|-------------|
| `md_metadata` | Yes | Massdriver metadata variable |
| `alarm_name` | Yes | CloudWatch alarm name |
| `display_name` | Yes | Label shown in Massdriver UI |
| `message` | Yes | Alarm description |
| `sns_topic_arn` | Yes | SNS topic from alarm_channel module |
| `namespace` | Yes | AWS metric namespace (AWS/RDS, AWS/EC2, etc.) |
| `metric_name` | Yes | Metric name |
| `statistic` | Yes | Average, Sum, Maximum, etc. |
| `period` | Yes | Evaluation period in seconds |
| `comparison_operator` | Yes | GreaterThanThreshold, LessThanThreshold, etc. |
| `evaluation_periods` | Yes | Number of periods to evaluate |
| `threshold` | Yes | Alert trigger value |
| `dimensions` | Yes | Metric dimensions (map) |

### Sensitive Fields in Artifact Definitions

```yaml
# In artifact-definitions/*/massdriver.yaml schema section
schema:
  properties:
    password:
      $md.sensitive: true
      $md.copyable: false
      title: Password
      type: string
```

### Immutable Fields (Cannot Change After Creation)

```yaml
params:
  properties:
    db_version:
      type: string
      $md.immutable: true  # Cannot be changed after initial deployment
      enum: ["14", "15", "16"]
```

### Dynamic Dropdowns from Connection Data ($md.enum)

```yaml
params:
  properties:
    database_policy:
      type: string
      title: Database Access Policy
      $md.enum:
        connection: database       # Source connection name
        options: .policies         # JQ expression to options array
        value: .name              # JQ expression to extract option value
        label: .name              # JQ expression to extract option label (optional)
```

### UI Ordering

```yaml
ui:
  ui:order:
    - db_version          # Show first
    - database_name
    - username
    - "*"                 # All remaining fields
```

### Using md_metadata

```hcl
# Naming resources
resource "aws_db_instance" "main" {
  identifier = "${var.md_metadata.name_prefix}-postgres"
  tags       = var.md_metadata.default_tags
}

# Available metadata fields
var.md_metadata.name_prefix           # Unique name prefix
var.md_metadata.default_tags          # Tags to apply to resources
var.md_metadata.deployment.id         # Deployment identifier
var.md_metadata.observability.alarm_webhook_url  # Alerting endpoint
```

### Optional Connections

```yaml
# massdriver.yaml - don't add to required array
connections:
  required:
    - network    # Required
  properties:
    network:
      $ref: network
    bucket:
      $ref: bucket  # Optional - not in required array
```

```hcl
# Terraform - check for null
locals {
  has_bucket = var.bucket != null
}

resource "example" "main" {
  bucket_name = local.has_bucket ? var.bucket.name : null
}
```

## Validation Checklist

Before publishing a bundle:

- [ ] `mass bundle build` runs successfully
- [ ] No param/connection name conflicts (check massdriver.yaml)
- [ ] Every artifact has a matching `massdriver_artifact` resource
- [ ] `tofu init && tofu validate` passes
- [ ] Artifact JSON structure matches artifact definition schema
- [ ] Required providers include `massdriver-cloud/massdriver`

## End-to-End Testing

Static validation (`tofu validate`) only checks syntax. To verify a bundle actually works, deploy it through Massdriver's orchestrator:

```bash
# 1. Build and publish as development (not stable release)
mass bundle build
mass bundle publish --development

# 2. Create test project/environment (user may provide these)
mass project create example --name "Test Project"
mass env create example-test --name "Test Environment"

# 3. Create and configure package from the bundle
mass pkg create example-test-mydb --bundle my-database-bundle

# 4. Set package version and release channel
# Use 'development' channel to automatically receive --development releases
mass pkg version example-test-mydb@latest --release-channel development

# Configure with JSON params (--params flag, not --set)
echo '{"database_name": "testdb", "db_version": "16"}' | mass pkg cfg example-test-mydb --params=-

# 5. Deploy and monitor (use -m for deploy comments when iterating)
mass pkg deploy example-test-mydb -m "Initial deployment"
mass logs <deployment-id>          # View logs using deployment ID from deploy output
mass pkg get example-test-mydb     # Check deployment status

# 6. Verify artifacts are created correctly
# Artifact name format: {package-slug}-{field-name}
mass artifact get example-test-mydb-database
```

### Package Versions and Release Channels

Packages can be pinned to specific versions or follow release channels:

```bash
# Set to latest stable version
mass pkg version example-test-mydb@latest

# Set to specific version
mass pkg version example-test-mydb@1.2.3

# Set to version constraint (receives updates within constraint)
mass pkg version example-test-mydb@~1.2

# Use development release channel (receives --development publishes)
mass pkg version example-test-mydb@latest --release-channel development
```

**Release Channels:**
- `stable` (default): Only receives stable releases (`mass bundle publish`)
- `development`: Receives both stable AND development releases (`mass bundle publish --development`)

**Best Practice for Testing:**
Set the package to `development` channel once, then every `mass bundle publish --development` automatically makes the new version available without reconfiguring:

```bash
# One-time setup
mass pkg version example-test-mydb@latest --release-channel development

# Now iterate freely - package auto-updates to each new dev release
mass bundle publish --development  # v0.0.1-dev.timestamp1
mass pkg deploy example-test-mydb

# Make changes, republish
mass bundle publish --development  # v0.0.2-dev.timestamp2
mass pkg deploy example-test-mydb  # Automatically uses new version
```

**Important:**
- Always use `--development` flag when testing to avoid creating stable releases
- User may need to provide a project/environment to work in
- Credential assignment to packages may require manual setup in the UI (no CLI command yet)
- Ask user to set up credentials in the environment before deploying

**Testing Workflow:**
1. User sets up: project, environment, assigns credentials
2. Claude creates packages, configures them, sets to development channel
3. Claude deploys, checks logs and artifact output to verify correctness

**Deploy Comments for Iteration:**
When iterating through bundle changes (e.g., fixing Checkov findings), always include a deploy message with `-m` to help operators track what changed:

```bash
# Good practice - describe what this deploy tests/changes
mass pkg deploy example-test-mydb -m "Fix CKV2_AWS_69: Enable rds.force_ssl for encryption in transit"
mass pkg deploy example-test-mydb -m "Add deletion_protection param, enable enhanced monitoring"

# Avoid - no context for what changed
mass pkg deploy example-test-mydb
```

This creates an audit trail in Massdriver showing what each deployment intended to accomplish.

### Post-Deployment: Checkov Security Review

After a successful deployment, review Checkov findings from the deployment logs and create a `TODO.md` file **in each bundle's directory** (e.g., `bundles/aws-vpc/TODO.md`) documenting security improvements.

**Extract Checkov findings:**
```bash
mass logs <deployment-id> 2>&1 | grep -E "Check:|FAILED"
```

**TODO.md format:**
```markdown
# Bundle Improvements

Security improvements identified by Checkov.

## bundle-name

- [ ] **HIGH** - **CKV_XXX_123** - Description of the issue
  - How to fix it
  - Why it matters

- [ ] **MEDIUM** - **CKV_XXX_456** - Description
  - Implementation notes

- [x] **IGNORE** - **CKV_XXX_789** - Description
  - Reason for ignoring (e.g., intentional design decision)
```

**Priority ratings:**

| Priority | Criteria | Examples |
|----------|----------|----------|
| **HIGH** | Security vulnerability, data exposure risk, or compliance requirement | Encryption disabled, public exposure, missing auth |
| **MEDIUM** | Best practice, observability, or operational improvement | Logging disabled, no monitoring, missing tags |
| **LOW** | Optimization or nice-to-have enhancement | VPC endpoints, cost optimization |
| **IGNORE** | Intentional design decision or not applicable | Public IPs on public subnets, Multi-AZ disabled for dev |

**Common Checkov findings by category:**

| Category | Typical Findings |
|----------|------------------|
| **Encryption** | KMS keys, encryption at rest, TLS |
| **Logging** | CloudWatch logs, flow logs, audit trails |
| **Access Control** | IAM auth, security groups, public access |
| **Backup/DR** | Deletion protection, snapshots, Multi-AZ |
| **Monitoring** | Enhanced monitoring, Performance Insights |

Always document the rationale for IGNORE decisions - future maintainers need to understand why a security recommendation was intentionally skipped.

## Common Mistakes & Fixes

| Mistake | Fix |
|---------|-----|
| **Coupled lifecycles** (VPC in database bundle) | Foundational resources become connections, not inline resources. Check `mass bundle list` and `mass def list` for existing artifacts to use. |
| **Provider auth fails** (Cannot assume role) | Provider block must use ALL fields from credential artifact schema. Check `mass def get <credential>` and include optional fields like `external_id` using `try()`. |
| "variable not declared" | Run `mass bundle build` to generate `_massdriver_variables.tf` |
| Param and connection have same name | Rename one - they share Terraform namespace |
| artifacts.tf field doesn't match | Ensure `field = "X"` matches `artifacts.properties.X` in massdriver.yaml |
| $ref not found | Verify artifact definition exists with `mass def get <name>` |
| Edited generated file, changes lost | Never edit `schema-*.json` or `_massdriver_variables.tf` |
| Missing massdriver provider | Add to `required_providers` block |

## Commands Reference

```bash
# Single bundle operations
cd bundles/my-bundle
mass bundle build           # Generate schemas + _massdriver_variables.tf
tofu init && tofu validate  # Validate IaC
mass bundle publish         # Publish to Massdriver

# Repository-wide operations
make build-bundles          # Build all bundles
make validate-bundles       # Validate all bundles
make publish-bundles        # Publish all bundles
make publish-artifact-definitions  # Publish artifact definitions
make publish-platforms      # Publish platform definitions
make all                    # Clean, build, validate, publish everything
```

## See Also

- [PATTERNS.md](./PATTERNS.md) - Complete examples of bundles and artifact definitions
- [snippets/](./snippets/) - Copy-paste templates for common files
- [CLAUDE.md](../../../CLAUDE.md) - Project-specific conventions (customize for your org)

## Extensibility

Customers can customize patterns for their organization by adding to their project's `CLAUDE.md`:

```markdown
## Our Bundle Conventions

- All bundles must include `cost_center` param
- Use `acme-` prefix for bundle names
- Required tags: team, environment, compliance-scope
```

The skill will incorporate these org-specific patterns when working in that repository.
