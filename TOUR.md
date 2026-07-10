# Feature Tour

An index of Massdriver features and where this catalog demonstrates each one. The [README tour](./README.md#tour-of-the-bundles--resource-types) walks bundle-by-bundle; this file is the reverse lookup — pick a feature, jump to a working example.

Every example here is real: the schemas render in the UI, and the OpenTofu underneath provisions actual AWS infrastructure.

## Form & schema features (`params:`)

| Feature | What it does | Best example | Also in |
|---|---|---|---|
| `params.examples` presets | Dev/Staging/Prod preset dropdown pre-fills the form | [`aws-vpc`](./bundles/aws-vpc/massdriver.yaml) (`Development` has no NAT, `Production` has HA NAT) | every bundle |
| `oneOf` + `const` + `title` | Dropdowns with human labels instead of raw values | [`aws-vpc`](./bundles/aws-vpc/massdriver.yaml) `nat_gateway` — costs spelled out in the labels | `db_version` in [`aws-rds-postgres`](./bundles/aws-rds-postgres/massdriver.yaml), `memory_mb` in [`aws-lambda-api`](./bundles/aws-lambda-api/massdriver.yaml) |
| `$md.immutable` | Field locks after first deploy | [`aws-vpc`](./bundles/aws-vpc/massdriver.yaml) `cidr` (re-IPing is a rebuild) | `region` everywhere, `character_set`/`collation` in [`aws-rds-mariadb`](./bundles/aws-rds-mariadb/massdriver.yaml), `object_lock` in [`aws-s3-bucket`](./bundles/aws-s3-bucket/massdriver.yaml) (a genuine one-way AWS switch) |
| `$md.copyable: false` | Value won't carry into a cloned/preview environment | `username` in [`aws-rds-postgres`](./bundles/aws-rds-postgres/massdriver.yaml) (combined with `$md.immutable`) | `admin_username` in [`k8s-wordpress`](./bundles/k8s-wordpress/massdriver.yaml) |
| `$md.enum` (dynamic dropdowns) | Options populated from a *linked resource's* data at configure time | `placement_subnet` in [`aws-rds-postgres`](./bundles/aws-rds-postgres/massdriver.yaml) — lists the connected network's subnets, wired to real AZ pinning in the Terraform | `database_policy` in [`k8s-wordpress`](./bundles/k8s-wordpress/massdriver.yaml) — lists the connected database's access policies |
| Conditional `dependencies` | A field appears/becomes required based on another field | [`aws-vpc`](./bundles/aws-vpc/massdriver.yaml) — `flow_log_retention_days` required only when `enable_flow_logs` is on | `max_storage_gb` in [`aws-rds-postgres`](./bundles/aws-rds-postgres/massdriver.yaml), `slow_query_log_seconds` in [`aws-rds-mariadb`](./bundles/aws-rds-mariadb/massdriver.yaml), `object_lock_retention_days` in [`aws-s3-bucket`](./bundles/aws-s3-bucket/massdriver.yaml) |
| `message.pattern` | Friendly validation errors instead of raw regexes | `cidr` in [`aws-vpc`](./bundles/aws-vpc/massdriver.yaml) ("Must be a valid IPv4 CIDR block…") | `database_name`/`username` in both RDS bundles, `repository_name` in [`aws-ecr-repo`](./bundles/aws-ecr-repo/massdriver.yaml) |
| Numeric constraints | `minimum`/`maximum`/`multipleOf` enforced in the form | `allocated_storage_gb` in [`aws-rds-postgres`](./bundles/aws-rds-postgres/massdriver.yaml) (20–1000, steps of 10) | `timeout_seconds` in [`aws-lambda-api`](./bundles/aws-lambda-api/massdriver.yaml) (1–900) |
| `ui:order`, `ui:help`, `ui:widget` | Field ordering, inline guidance, widget selection (`updown`) | [`aws-vpc`](./bundles/aws-vpc/massdriver.yaml) `ui:` section | every bundle |

## Resource types (contracts between bundles)

| Feature | What it does | Where |
|---|---|---|
| Capability-noun naming | Resource types and bundles share one namespace in v2 — types are capabilities (`postgres-database`), bundles are implementations (`aws-rds-postgres`) | [README note](./README.md#-resource-types) + every pairing in this catalog |
| `$md.sensitive` | Masks values in UI/GraphQL, audit-logs downloads | `auth.password` in [`postgres-database`](./resource-types/postgres-database/massdriver.yaml) and [`mysql-database`](./resource-types/mysql-database/massdriver.yaml); `user.token` in [`kubernetes-cluster`](./resource-types/kubernetes-cluster/massdriver.yaml) |
| `exports:` (file downloads) | One-click download of a rendered file from a live resource | [`kubernetes-cluster`](./resource-types/kubernetes-cluster/massdriver.yaml) → [kubeconfig template](./resource-types/kubernetes-cluster/exports/kubeconfig.yaml.liquid) — note the flat `artifact.authentication.…` payload access (no v1 `data` envelope) |
| `instructions/` | Form-fill walkthroughs rendered next to the manual resource-creation form | every resource type — e.g. [registering an existing EKS cluster](./resource-types/kubernetes-cluster/instructions/Amazon%20EKS.md) |
| `connectionOrientation` + `environmentDefaultGroup` | Whether a resource links on the canvas or auto-assigns as an environment default | [`kubernetes-cluster`](./resource-types/kubernetes-cluster/massdriver.yaml) and [`container-registry`](./resource-types/container-registry/massdriver.yaml) are environment defaults (shared runtime + registry); databases/network are canvas links |
| Policies arrays | Contract carries the access levels consumers can request; feeds `$md.enum` dropdowns | [`object-storage`](./resource-types/object-storage/massdriver.yaml) carries **real IAM policy ARNs** emitted by [`aws-s3-bucket`](./bundles/aws-s3-bucket/src/iam.tf); [`postgres-database`](./resource-types/postgres-database/massdriver.yaml) carries named grant levels |
| Schema validation in contracts | `pattern`, `minimum`/`maximum`, `additionalProperties: false` catch bad data before provisioning | [`aws-network`](./resource-types/aws-network/massdriver.yaml) — VPC/subnet/SG ID patterns, CIDR regex |

## Application features

| Feature | What it does | Where |
|---|---|---|
| `app.envs` (JQ lifting) | Connection data becomes app env vars at deploy — no copy-paste of hostnames/creds | [`k8s-wordpress`](./bundles/k8s-wordpress/massdriver.yaml) lifts the linked database's `auth` into `WORDPRESS_DATABASE_*` |
| `app.secrets` (deploy gating) | Required secrets block deployment until set; optional ones don't | [`k8s-wordpress`](./bundles/k8s-wordpress/massdriver.yaml) — `WORDPRESS_ADMIN_PASSWORD` required, `WORDPRESS_SMTP_PASSWORD` optional |
| Serverless app path | Your own compute published as a bundle: function URL, logs, IAM, alarms | [`aws-lambda-api`](./bundles/aws-lambda-api) — working TODO API; start yours from [`templates/aws-lambda`](./templates/aws-lambda) |
| Static site path | Fastest deploy in the catalog | [`aws-s3-static-site`](./bundles/aws-s3-static-site) — replace `src/site/` with your build output |
| Off-the-shelf app path | Compose DevOps-published bundles on the canvas; links route connection data | [`k8s-wordpress`](./bundles/k8s-wordpress) + [`aws-rds-mariadb`](./bundles/aws-rds-mariadb) on a [`aws-eks-cluster`](./bundles/aws-eks-cluster) |

## IaC patterns (`src/`)

| Feature | What it does | Where |
|---|---|---|
| `massdriver_resource` | Emits the bundle's resource (v2 replacement for deprecated `massdriver_artifact`); payload is flat, matching the resource-type schema exactly | every bundle's [`src/artifacts.tf`](./bundles/aws-vpc/src/artifacts.tf) |
| `massdriver_instance_alarm` | Registers cloud alarms on the instance health panel | [`aws-rds-postgres/src/alarms.tf`](./bundles/aws-rds-postgres/src/alarms.tf) — four alarms on real `AWS/RDS` metrics |
| Conditional alarms | Alarm only exists when the feature is on | `NAT Port Exhaustion` in [`aws-vpc/src/alarms.tf`](./bundles/aws-vpc/src/alarms.tf) (per NAT gateway), `Replication Lag` in both RDS bundles (HA only) |
| Credential connections → provider auth | Provider blocks consume the platform credential's flat fields | [`aws-vpc/src/main.tf`](./bundles/aws-vpc/src/main.tf) `assume_role` from [`aws-iam-role`](./platforms/aws/massdriver.yaml) |
| Deriving config from connections | Region comes from the linked network — a cluster can't land in the wrong region | [`aws-eks-cluster/src/main.tf`](./bundles/aws-eks-cluster/src/main.tf), both RDS bundles |
| Subnet-tier placement | Terraform filters the network contract's subnets by tier | private-subnet selection in [`aws-eks-cluster/src/main.tf`](./bundles/aws-eks-cluster/src/main.tf) |
| Helm/Kubernetes providers from a cluster connection | Chart deploys authenticated by the `kubernetes-cluster` resource | [`k8s-wordpress/src/main.tf`](./bundles/k8s-wordpress/src/main.tf) |
| Checkov posture | Skip only permanent architectural choices (with a reason per line); let configurable checks warn in dev | every bundle's `src/.checkov.yml` — [`aws-s3-static-site`](./bundles/aws-s3-static-site/src/.checkov.yml)'s "public by design" vs [`aws-s3-bucket`](./bundles/aws-s3-bucket/src/.checkov.yml)'s locked-down defaults is the instructive contrast |
| Generated variables | `_massdriver_variables.tf` regenerates from params + connections on `mass bundle build` | every bundle's `src/` |

## Operations & docs

| Feature | What it does | Where |
|---|---|---|
| `operator.md` runbooks | Mustache-templated 2am runbooks rendered with live instance data | [`aws-vpc/operator.md`](./bundles/aws-vpc/operator.md) — subnet table from `{{artifacts.network.subnets}}`, triage commands with real IDs |
| Bundle `README.md` | Rendered in the UI; each explains what it shows, what it produces, and costs | every bundle |
| `CHANGELOG.md` | Keep-a-Changelog per bundle, versioned with the bundle | every bundle |

## Platform & workflow

| Feature | What it does | Where |
|---|---|---|
| Platform credentials | Resource types modeling cloud credentials; schema mirrors the provider's auth inputs | [`platforms/aws`](./platforms/aws/massdriver.yaml) (enabled by default); nine more clouds ready in [`platforms/`](./platforms) |
| Preview environments | Fork an environment per PR with overrides; pin shared infra instead of cloning it | [`preview.yaml`](./preview.yaml) — reuses the shared EKS + ECR as environment defaults, overrides WordPress/MariaDB params |
| Bundle templates | `mass bundle new` scaffolds for each app type | [`templates/aws-lambda`](./templates/aws-lambda) (serverless), [`templates/helm-chart`](./templates/helm-chart) (containers), [`templates/opentofu`](./templates/opentofu) (anything else) |
| Publish pipeline | Resource types first (bundles' `$ref`s resolve server-side), OCI repo per bundle, then publish | [`Makefile`](./Makefile), [`.github/workflows/`](./.github/workflows) |
| Development channel | `mass bundle publish --development` + `latest+dev` pins for fast iteration | [README](./README.md#quick-start) |

## The deliberate gap

There is **no cache (Redis) or queue (SQS) bundle** in this catalog, on purpose. When an app needs a capability DevOps hasn't published, the governed move is to request it — not to improvise infrastructure. Watch the Massdriver Claude Code plugin hit this wall gracefully: it names exactly what to ask your platform team for, then keeps building everything that *is* available.
