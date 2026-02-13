# Massdriver Pattern Reference

Complete examples for bundles, artifact definitions, and platforms. Use these for copy-paste and learning.

## Complete Bundle Examples

### Infrastructure Bundle (Database Pattern)

This pattern shows a database bundle that:
- Requires a network connection
- Produces a database artifact with auth credentials and access policies
- Uses immutable version field

**massdriver.yaml**:
```yaml
schema: draft-07
name: postgres
description: "PostgreSQL database with connection pooling"
source_url: https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/postgres
version: 0.1.0

params:
  required:
    - db_version
    - database_name
    - username
  properties:
    db_version:
      type: string
      title: PostgreSQL Version
      description: PostgreSQL major version
      default: "16"
      $md.immutable: true
      enum:
        - "14"
        - "15"
        - "16"
    database_name:
      type: string
      title: Database Name
      description: Name of the default database
      default: "mydb"
      pattern: ^[a-z][a-z0-9_]*$
    username:
      type: string
      title: Database Username
      default: "postgres"
      pattern: ^[a-z][a-z0-9_]*$

connections:
  required:
    - network
  properties:
    network:
      $ref: network
      title: Network

artifacts:
  required:
    - database
  properties:
    database:
      $ref: postgres
      title: PostgreSQL Database

steps:
  - path: src
    provisioner: opentofu:1.10

ui:
  ui:order:
    - db_version
    - database_name
    - username
    - "*"
```

**src/main.tf**:
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

locals {
  name = "${var.md_metadata.name_prefix}-postgres"
}

resource "random_password" "main" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "main" {
  name       = local.name
  subnet_ids = [for s in var.network.subnets : s.id if s.type == "private"]
  tags       = var.md_metadata.default_tags
}

resource "aws_db_instance" "main" {
  identifier     = local.name
  engine         = "postgres"
  engine_version = var.db_version

  db_name  = var.database_name
  username = var.username
  password = random_password.main.result

  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_subnet_group_name = aws_db_subnet_group.main.name

  skip_final_snapshot = true
  tags                = var.md_metadata.default_tags
}
```

**src/artifacts.tf**:
```hcl
resource "massdriver_artifact" "database" {
  field = "database"
  name  = "PostgreSQL ${var.md_metadata.name_prefix}"

  artifact = jsonencode({
    id = aws_db_instance.main.id
    auth = {
      hostname = aws_db_instance.main.endpoint
      port     = 5432
      database = var.database_name
      username = var.username
      password = random_password.main.result
    }
    policies = [
      { id = "read-only", name = "Read Only" },
      { id = "read-write", name = "Read/Write" },
      { id = "admin", name = "Admin" }
    ]
  })
}
```

---

### Application Bundle (Multiple Connections Pattern)

This pattern shows an application that:
- Requires network and database connections
- Has an optional bucket connection
- Uses `$md.enum` for dynamic policy selection

**massdriver.yaml**:
```yaml
schema: draft-07
name: application
description: "Containerized application deployment"
source_url: https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/application
version: 0.1.0

params:
  required:
    - image
    - replicas
  examples:
    - __name: Development
      image: "nginx:latest"
      replicas: 1
    - __name: Production
      image: "nginx:stable"
      replicas: 3
  properties:
    image:
      type: string
      title: Container Image
      default: "nginx:latest"
    replicas:
      type: integer
      title: Replicas
      default: 2
      minimum: 1
      maximum: 10
    database_policy:
      type: string
      title: Database Access Policy
      $md.enum:
        connection: database
        options: .policies
        value: .name

connections:
  required:
    - network
    - database
  properties:
    network:
      $ref: network
    database:
      $ref: postgres
    bucket:
      $ref: bucket  # Optional - not in required array

artifacts:
  required:
    - application
  properties:
    application:
      $ref: application

steps:
  - path: src
    provisioner: opentofu:1.10

ui:
  ui:order:
    - image
    - replicas
    - database_policy
    - "*"
```

**src/main.tf** (handling optional connections):
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    massdriver = {
      source  = "massdriver-cloud/massdriver"
      version = "~> 1.3"
    }
  }
}

locals {
  name         = var.md_metadata.name_prefix
  has_bucket   = var.bucket != null
}

resource "kubernetes_deployment" "main" {
  metadata {
    name   = local.name
    labels = var.md_metadata.default_tags
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = local.name }
    }

    template {
      metadata {
        labels = { app = local.name }
      }

      spec {
        container {
          image = var.image
          name  = "app"

          # Database connection (required)
          env {
            name  = "DATABASE_HOST"
            value = var.database.auth.hostname
          }

          # Bucket connection (optional)
          dynamic "env" {
            for_each = local.has_bucket ? [1] : []
            content {
              name  = "BUCKET_NAME"
              value = var.bucket.name
            }
          }
        }
      }
    }
  }
}
```

---

### Foundation Bundle (No Connections Pattern)

**massdriver.yaml**:
```yaml
schema: draft-07
name: network
description: "Virtual private cloud network"
source_url: https://github.com/YOUR_ORG/massdriver-catalog/tree/main/bundles/network
version: 0.1.0

params:
  required:
    - cidr
  properties:
    cidr:
      type: string
      title: Network CIDR
      default: "10.0.0.0/16"
      pattern: ^([0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$
    subnets:
      type: array
      title: Subnets
      default:
        - name: "public-a"
          cidr: "10.0.1.0/24"
          type: "public"
        - name: "private-a"
          cidr: "10.0.10.0/24"
          type: "private"
      items:
        type: object
        required: [name, cidr, type]
        properties:
          name:
            type: string
          cidr:
            type: string
          type:
            type: string
            enum: [public, private]

connections:
  required: []
  properties: {}

artifacts:
  required:
    - network
  properties:
    network:
      $ref: network

steps:
  - path: src
    provisioner: opentofu:1.10

ui:
  ui:order:
    - cidr
    - subnets
    - "*"
```

---

## Artifact Definition Patterns

Artifact definitions support the same capabilities as platforms: `schema`, `ui` (with `environmentDefaultGroup`), `instructions/`, and `exports/`. The examples below show common patterns.

### Database Artifact (Credentials + Policies)

**artifact-definitions/postgres/massdriver.yaml**:
```yaml
name: postgres
label: PostgreSQL

schema:
  title: PostgreSQL Database
  description: PostgreSQL database with connection details and access policies
  type: object
  required:
    - auth
    - id
    - policies
  properties:
    auth:
      title: Authentication
      type: object
      required:
        - hostname
        - port
        - database
        - username
        - password
      properties:
        hostname:
          title: Host
          type: string
        port:
          title: Port
          type: integer
          default: 5432
        database:
          title: Database
          type: string
        username:
          title: Username
          type: string
        password:
          $md.sensitive: true
          $md.copyable: false
          title: Password
          type: string
    id:
      title: ID
      type: string
    policies:
      title: Access Policies
      type: array
      items:
        type: object
        required:
          - id
          - name
        properties:
          id:
            type: string
          name:
            type: string
```

### Network Artifact (Environment Default)

**artifact-definitions/network/massdriver.yaml**:
```yaml
name: network
label: Network

ui:
  environmentDefaultGroup: networks

schema:
  title: Network
  type: object
  required:
    - id
    - cidr
    - subnets
  properties:
    id:
      title: ID
      type: string
    cidr:
      title: CIDR
      type: string
    subnets:
      title: Subnets
      type: array
      items:
        type: object
        required:
          - id
          - cidr
        properties:
          id:
            type: string
          cidr:
            type: string
          type:
            type: string
            enum:
              - public
              - private
```

### Minimal Artifact

**artifact-definitions/application/massdriver.yaml**:
```yaml
name: application
label: Application

schema:
  title: Application
  type: object
  required:
    - deployment_id
    - name
  properties:
    deployment_id:
      title: Deployment ID
      type: string
    name:
      title: Name
      type: string
    tags:
      type: object
      additionalProperties:
        type: string
```

### Artifact with Instructions and Exports

Artifact definitions can include instructions and exports just like platforms:

**artifact-definitions/external-api/massdriver.yaml**:
```yaml
name: external-api
label: External API

ui:
  environmentDefaultGroup: integrations
  instructions:
    - label: Getting Your API Key
      path: ./instructions/API Key.md

exports:
  - label: OpenAPI Spec
    path: ./exports/openapi.json

schema:
  title: External API Configuration
  type: object
  required:
    - base_url
    - api_key
  properties:
    base_url:
      title: Base URL
      type: string
    api_key:
      $md.sensitive: true
      title: API Key
      type: string
```

---

## Platform Definition Pattern

Platforms are artifact definitions for cloud authentication. They're technically identical to artifact definitions in `artifact-definitions/` - the separate `platforms/` directory is purely organizational to distinguish infrastructure artifacts from authentication/onboarding artifacts.

**platforms/aws/massdriver.yaml**:
```yaml
name: aws-iam-role
label: AWS IAM Role
icon: https://example.com/aws-icon.svg

ui:
  environmentDefaultGroup: credentials  # Can be set as environment default
  instructions:
    - label: AWS CLI
      path: ./instructions/AWS CLI.md
    - label: AWS Console
      path: ./instructions/AWS Console.md

exports: []  # Optional: downloadable files

schema:
  title: AWS IAM Role
  description: IAM role for Massdriver to assume when deploying resources
  type: object
  required: [arn, external_id]
  properties:
    arn:
      title: Role ARN
      description: ARN of the IAM role to assume
      type: string
      pattern: ^arn:aws:iam::[0-9]{12}:role/.+$
    external_id:
      $md.sensitive: true
      title: External ID
      description: External ID for secure role assumption
      type: string
```

**How bundles consume platform credentials:**

```yaml
# Bundle's massdriver.yaml - declares it needs AWS credentials
connections:
  required:
    - aws_authentication
  properties:
    aws_authentication:
      $ref: aws-iam-role
      title: AWS Credentials
```

```hcl
# Bundle's src/main.tf - uses credential to configure provider
provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn    = var.aws_authentication.arn
    external_id = var.aws_authentication.external_id
  }
}
```

**Environment Defaults Flow:**
1. Admin creates AWS credential artifact via platform UI form
2. Admin sets credential as default for "production" environment
3. User adds RDS bundle to "production" environment
4. Bundle automatically receives the credential (no manual connection needed)
5. Terraform provider authenticates using the role ARN

**Cross-Project Sharing:**
- Project A (Platform Team): Manages VPC, sets network as shareable
- Project B (App Team): Deploys into the VPC but cannot modify it
- Connection presentation controls visibility: linkable handle vs env-default-only

---

## operator.md Pattern

```markdown
---
templating: mustache
---

# PostgreSQL Runbook

**Slug:** `{{slug}}`

## Configuration

| Setting | Value |
|---------|-------|
| Version | `{{params.db_version}}` |
| Database | `{{params.database_name}}` |

## Connections

{{#connections.network}}
**Network ID:** `{{connections.network.id}}`
{{/connections.network}}

## Quick Connect

```bash
PGPASSWORD={{artifacts.database.auth.password}} psql \
  -h {{artifacts.database.auth.hostname}} \
  -U {{artifacts.database.auth.username}} \
  -d {{artifacts.database.auth.database}}
```
```

---

## Anti-Patterns to Avoid

### Namespace Collision
```yaml
# BAD - Both create var.database
params:
  properties:
    database:
connections:
  properties:
    database:

# GOOD - Distinct names
params:
  properties:
    database_name:
connections:
  properties:
    database:
```

### Mismatched Field Names
```yaml
# massdriver.yaml
artifacts:
  properties:
    postgres_db:      # <-- field name
```
```hcl
# BAD
resource "massdriver_artifact" "database" {
  field = "database"  # Should be "postgres_db"!
}
```

### Don't Include .json in $ref
```yaml
# BAD
$ref: network.json

# GOOD
$ref: network
```

### Never Edit Generated Files
- `schema-*.json`
- `_massdriver_variables.tf`
