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
> - `connections:` → **`dependencies:`**, and `artifacts:` → **`resources:`**, each entry now pinning a
>   resource type and version: `resource_type: postgres-schema@0.0.0`. Every bundle and template in
>   this repo uses that shape; nothing is left on `$ref:`.

## Key Concepts

If you're new to Massdriver, here are the core concepts you'll encounter:

- **Bundle**: A reusable, versioned definition of infrastructure or application components. Bundles encapsulate your IaC code (Terraform/OpenTofu/Helm), configuration schemas, dependencies, and policies into a single deployable unit. Think of them as "infrastructure packages" with built-in guardrails.

- **Resource Type** (formerly *artifact definition*): A JSON Schema contract that defines how infrastructure components can connect to each other. Resource types ensure type safety—you can't connect incompatible components.

- **Resource** (formerly *artifact*): A live, materialized resource type emitted by a deployed bundle. For example, when you deploy a PostgreSQL bundle, it emits a PostgreSQL resource containing connection details that other bundles can consume.

- **Parameters (params)**: User-configurable inputs for a bundle, like instance sizes, database names, or feature flags. These define what developers can customize when deploying infrastructure.

- **Dependencies** (the `dependencies:` key in `massdriver.yaml`): Inputs a bundle needs from other bundles, each pinned to a resource type and version. A bundle declaring `postgres-schema@0.0.0` can only be linked to something that produces one.

- **Project**: A logical grouping of related infrastructure, like "ecommerce-platform" or "data-pipeline". Projects contain one or more environments.

- **Environment** (formerly *target*): A deployment context within a project, like "development", "staging", or "production". Each environment has its own canvas where you design and deploy infrastructure.

- **Canvas**: The visual diagram in the Massdriver UI where you add bundles, connect them together, and configure parameters. It's your infrastructure design board.

- **Instance** (formerly *package*): A configured deployment of a bundle in a specific environment. When you add a bundle to your canvas and configure it, you're creating an instance. Think of it like the relationship between a class and an object in programming—bundles are the reusable definitions, instances are the deployed objects.

## What Is In The Catalog

Three groups of bundles. Who is allowed to place which is set by `repo:pull` grants conditioned on
`managed_by`, so a citizen project simply does not see the platform-tier ones — adding the
component fails rather than deploying something nobody meant to deploy.

### Platform tier — `managed_by: platform` only

Placed once per environment by the people who own the infrastructure. Application teams connect to
what these produce; they never configure them.

| Bundle | What it is | Produces |
| --- | --- | --- |
| `gcp-network` | VPC, subnet, Private Service Access range for Cloud SQL, and the serverless connector Cloud Run uses to reach private addresses | `network`, `serverless-connector` |
| `gcp-artifact-registry` | The repository every application image is built into | `container-registry` |
| `gcp-cloud-sql-postgres` | The shared PostgreSQL instance. Private address only, unless an operator opts it into direct SQL management | `postgres-database` |
| `pg-admin` | The real pgAdmin console, connected as the administrator. Internal only, one instance | `cloud-run-service` |

### Data access tier — `platform` and `engineering`

These decide who can reach which data. Citizen projects cannot place them, which is the point:
a citizen developer cannot issue themselves access to another team's tables.

| Bundle | What it is | Produces |
| --- | --- | --- |
| `pg-schema` | A schema inside the shared database, owned by a login created for one app. The app creates its own tables in it | `postgres-schema` |
| `pg-table-access` | A login granted access to a named list of tables that already exist, table by table, never schema-wide | `postgres-table-grants` |
| `gcp-bigquery-federation` | A BigQuery dataset and a connection to Cloud SQL, so app tables can be queried with `EXTERNAL_QUERY` without copying the data | `analytics-dataset` |

### Application tier — everyone, including citizen projects

| Bundle | What it is |
| --- | --- |
| `templates/gcp-cloud-run` | What `mass bundle new` scaffolds a new app from |
| `artist-portal`, `tour-dates`, `merch-inventory`, `fan-signups` | Four working apps, each owning a schema |
| `hello-cloud-run` | The smallest thing that proves the build and deploy path works |
| `gcp-cloud-storage-bucket`, `gcp-firestore` | Object storage and a document database |

## How Applications Authenticate To Anything

No application in this platform holds a credential that a person typed into it. Every one arrives
as a connection on the canvas, which means it can be traced, revoked, and rotated in one place.

**To Google Cloud.** One service account key, imported once, granted to environments tagged
`tier: dev`, and set as an environment default. Every component inherits it. Nobody picks a
credential, and the sandbox key cannot reach a production environment even by mistake.

**To the database.** Never with the shared administrative credential. An app gets its own
PostgreSQL login, and which one depends on what it needs:

- `pg-schema` gives it a login that owns one schema. It can do anything inside that schema and
  nothing outside it.
- `pg-table-access` gives it a login granted specific tables in other people's schemas, with no
  schema of its own and no ability to create anything.

An app can hold both, and usually should: one for its own data, one for what it borrows. They are
separate connections on the canvas, so "what can this app reach?" is a question you answer by
looking rather than by reading SQL.

**Between projects.** The apps live in different projects from the platform, so the platform's
outputs are shared with `resource:export` grants conditioned on `tier: dev`, then set as
environment defaults. A new app in a dev environment binds to the shared registry, connector and
database on its own.

**pgAdmin is the exception that proves it.** It is the one component holding the administrative
credential, and it is internal-only, single-instance, and placed in the platform project where no
citizen developer can put one.

## Which Database Bundle To Use

The answer depends on how the organisation decided to divide its data, and all three ways are
supported.

| How the data is divided | Bundle | Cross-app sharing |
| --- | --- | --- |
| A database per application | `gcp-cloud-sql-postgres` per app | Impossible — PostgreSQL cannot grant across databases |
| A schema per application, one shared database | `pg-schema` | Yes, one table at a time |
| Already loaded, however it got there | `pg-table-access` | That is what it is for |

Data gets in the same way in all three: the application's own migrations at startup, or a bulk load
by whoever owns the data. None of these bundles create tables — see the note in
`bundles/pg-table-access/README.md` about why that is partly a choice and partly a constraint of
the Terraform provider.

The middle two combine, and that combination is what most people mean when they ask how to share a
database safely. An application owns a schema and writes whatever it likes there, and separately
holds a second login granting it read access to a few named tables belonging to other teams. The
live example: `merch-inventory` owns `merch_inventory`, and reads `tour_dates.shows` through a
login issued from the platform project.

The grant is issued from the platform project on purpose. Placing it beside the application would
say the citizen developer granted themselves access to another team's data, which is precisely the
thing this is meant to prevent.

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
| `team` | project | `platform`, `artists`, `tourdates`, `merch`, `fans` | Which team owns it. Drives "change only my own project". |
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

**Citizen Developers - <team>** — one group like this per citizen team. There are four:
Artists, Tour Dates, Merch, Fans. This is the half that grants change access, and every policy
in it carries its own fence.

Taking the Artists one as the pattern — substitute the team's own name everywhere:

| Actions | Conditions |
| --- | --- |
| `project:design` | `exposure`: internal + `md-project`: artists |
| `instance:configure`, `instance:deploy`, `instance:plan` | `team`: artists + `tier`: dev |
| `instance:propose` | `team`: artists + `tier`: staging, production |
| `environment:create`, `environment:configure`, `environment:deploy` | `md-project`: artists + `tier`: dev |
| `repo:view`, `resource:view` | none |

Every fence is repeated on every policy on purpose. It reads as duplication and it is not —
drop the condition from one row and that action reaches every project the person can see,
which is all four.

A citizen developer in both groups sees every citizen project and can change only their own. In `dev` they deploy on their own. In `staging` and `production` they can only
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

All four are required. A project with no `managed_by` matches no citizen view condition and is
invisible to them; a component with no `exposure` matches no design condition and cannot be
placed. Both fail in the safe direction, but they fail confusingly — the person sees "you
cannot do that" with nothing pointing at the missing tag. Requiring the attribute moves the
question to the moment the project or component is created, where it is obvious.

The cost is that `team` is a closed list. Onboarding a new team means extending the allowed
values before the project can be created, and that edit is a read-modify-write of the whole
list — pass every existing value along with the new one or you will drop the others.

### The projects

| Project | `managed_by` | `team` | What is in it |
| --- | --- | --- | --- |
| `scp` | platform | platform | The network, the registry, and the shared Postgres |
| `artists` | citizen | artists | Artist Portal |
| `tourdates` | citizen | tourdates | Tour Dates |
| `merch` | citizen | merch | Merch Inventory |
| `fans` | citizen | fans | Fan Signups |

Each citizen project holds two components: a `pg-schema` for its schema and login, and the
app itself. They are separate projects rather than four apps in one because the project is the
visibility boundary — one project would mean any citizen developer who can change one app can
change all of them.

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
| `pg-schema`, `gcp-cloud-storage-bucket`, `gcp-firestore`, and the app bundles | `managed_by: platform, engineering, citizen` |

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

The scaffold takes a `postgres-schema`, so it gets a schema and login of its own rather than
the shared cluster's admin credential. Replace `build/app/` with the real application, keeping
the `PORT` environment variable — Cloud Run sets it and the container has to listen on it.

Then add two components to the project: a `pg-schema` for the app's data, and the app itself,
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

### Every management task, and the command for it

Everything below was used to build the platform described here. Attributes, groups, and policies
are the only things with no CLI — they live in the web app under **Settings**, or go through the
Massdriver MCP server.

**Projects and environments**

```bash
mass project create tourdates --name "Tour Dates" \
  -d "Show schedule, built by the touring team." \
  -a managed_by=citizen,team=tourdates

mass environment create tourdates dev --name dev -a tier=dev

mass project update artists      -a managed_by=citizen,team=artists
mass environment update scp-dev  -a tier=dev
```

`-a` replaces the whole attribute set rather than merging into it. Pass every attribute you want
to keep, every time, on both commands.

**Catalog**

```bash
mass repository create gcp-network -t bundle
mass repository create network     -t resource-type

mass resource-type publish resource-types/network/massdriver.yaml

mass bundle build   --bundle-directory bundles/gcp-network
mass bundle publish --development --bundle-directory bundles/gcp-network
```

`mass bundle build` regenerates the Terraform variables from `massdriver.yaml`. Run it after every
schema change, before publishing, or the bundle ships with stale variables.

`make publish-resource-types` does the create-and-publish loop for every resource type at once.

**Credentials and resources**

```bash
mass resource create -f ~/Downloads/key.json -t gcp-service-account -n "Massdriver Sandbox"
mass resource list

mass environment default artists-dev <resource-id>
```

**Blueprints**

```bash
mass component add tourdates pg-schema --id data --name "Tour Dates Data" \
  -d "This app's own schema and login inside the shared database." \
  -a exposure=internal

mass component link tourdates-data.table_set tourdates-app.database \
  --from-version latest+dev --to-version latest+dev

mass component remove tourdates-data
```

`--from-version latest+dev` is what tracks the development channel. Without the `+dev` suffix the
component pins to released versions only and will not see anything published with
`--development`.

**Instances and deployments**

```bash
mass instance deploy tourdates-dev-data -m "Schema and scoped login for tour dates" -f
mass instance deploy tourdates-dev-data --plan
mass instance deploy tourdates-dev-app  --propose

mass instance version tourdates-dev-app latest+dev
mass instance remote-reference set tourdates-dev-data postgres_cluster scp-dev-db.database
mass instance destroy tourdates-dev-app

mass deployment logs <deployment-id>
mass deployment approve <deployment-id>
```

`-f` streams the logs until the deployment finishes, which is usually what you want for anything
you are watching. `--propose` creates the deployment without running it, for the environments
where somebody else has to approve.

An instance pinned to an older version will not pick up a new publish. `mass instance version`
re-pins it. This is easy to miss: a deploy that succeeds against the version it was pinned to
looks exactly like a deploy of the code you just published.

**Things with no CLI**

| Task | Where |
| --- | --- |
| Declare, change, or delete a custom attribute | Settings → Custom Attributes |
| Create a group, add members, author policies | Settings → Groups |
| Grant a resource to environments (`resource:export`) | The resource's sharing settings |
| Grant a bundle repository to projects (`repo:pull`) | The repository's sharing settings |

### The shared database has a public address, and that is a demo compromise

Read this before showing anyone the platform, because it is the thing a security-minded person
in the room will spot.

Creating a schema and granting on a table are SQL statements. The Google Cloud API cannot express
either, so `pg-schema` opens a real PostgreSQL connection, and the provisioner runs outside
your network. To let it in, `gcp-cloud-sql-postgres` turns on a public IP whenever
`iac_authorized_networks` has an entry.

What that does and does not allow, precisely:

- The instance accepts connections from the listed addresses only. Everything else is refused at
  the Cloud SQL layer, before authentication.
- `ssl_mode` is `ENCRYPTED_ONLY`, so an unencrypted connection is impossible on either address.
- **No application uses it.** Apps get `auth.hostname`, which is the private address, and reach it
  over the serverless connector. The public address is published separately as
  `management_hostname`, which only infrastructure code reads.
- With `iac_authorized_networks` empty, no public address exists at all.

It is still a compromise, and it was made to get a demo running rather than because it is the
right long-term shape. Two things are wrong with it:

**The allowlist is a single address, and the provisioner egresses from a pool.** Deploys fail
intermittently with `connection timed out` against the public address, and succeed on retry, for
no reason visible in the logs. If you hit that, redeploy. The real fix is to allowlist the
provisioner's whole egress range rather than one address observed once.

**A database holding every app's data should not be reachable from the internet at all**, however
narrow the allowlist. Two ways to get there:

- Create the app's login with the Cloud SQL API instead, which needs no network path, and let each
  app create its own schema on first request — it already creates its own tables that way. The
  instance goes back to private-only. What this costs is `shared_tables`: cross-app grants are SQL,
  and nothing would have a path to issue them.
- Or invert who grants. Let the app that **owns** a table declare which other apps may read it, and
  issue that grant itself at startup, since it owns the object. No provisioner access needed, and
  approval sits with the team whose data it is — which is the better governance answer anyway.

### Before pg-schema can deploy

Creating a schema and granting access to a table are SQL statements. The Google Cloud API cannot
express either, so `pg-schema` opens a real PostgreSQL connection, and the instance needs an
address the provisioner can reach.

With `iac_authorized_networks` empty, `gcp-cloud-sql-postgres` has no public address at all and
`pg-schema` cannot run. Add the egress address of whatever executes your infrastructure code:

| Name | Address range |
| --- | --- |
| Massdriver provisioner egress | *the CIDR your deployments leave from* |

Everything else is still refused, and every connection stays encrypted. If you do not know the
address, deploy `pg-schema` once and read the source address of the refused connection in
Cloud SQL's logs, under `resource.type="cloudsql_database"`.

## Compliance: What Is Skipped, And What Is Knowingly Wrong

Two separate lists. The first is checks suppressed in `.checkov.yml`, each with the reason it
cannot apply. The second is real weaknesses this platform has — written down because a demo
platform that hides them teaches the wrong lesson.

Nothing here is skipped because it was inconvenient. Every suppression is a check that cannot pass
in any environment for a factual reason, not a preference. Where a control was genuinely worth
having, it was implemented instead — `gcp-cloud-sql-postgres` went from six failing checks to one
by adding the pgaudit and logging flags rather than silencing them.

### Suppressed checks

| Check | Where | Why it cannot apply |
| --- | --- | --- |
| `CKV_GCP_6` — Cloud SQL requires SSL | `gcp-cloud-sql-postgres/src` | The check inspects `require_ssl`, which `hashicorp/google ~> 6.0` removed. The bundle sets `ssl_mode = "ENCRYPTED_ONLY"`, the replacement for it. The attribute the check looks for cannot exist in a plan from this provider version, whatever the configuration says. |
| `CKV_GCP_83` — Pub/Sub topic encrypted with CMEK | every app's `build` step | The topic exists only because `google_cloudbuild_trigger` requires an event-source field. Nothing publishes to it and nothing subscribes, so it never carries data of any kind. |

`gcp-bigquery-federation` has no suppressions. `CKV_GCP_81` (CMEK on a BigQuery dataset) failed
initially and was fixed by adding an optional `encryption_key` parameter and the key binding the
BigQuery service agent needs, rather than silenced.

### Deliberate weaknesses, and what each would take to close

**The shared database has a public IP address.** Creating a schema and granting on a table are SQL
statements, and the Google Cloud API cannot express either — so `pg-schema` and `pg-table-access`
open a real PostgreSQL connection, and the provisioner runs outside your network.

The exposure is bounded: connections are accepted only from the addresses in
`iac_authorized_networks`, `ssl_mode` is `ENCRYPTED_ONLY` so an unencrypted connection is
impossible on either address, and **no application uses it** — apps take the private address over
the serverless connector, and the public one is published in a separate `management_hostname`
field only infrastructure code reads. With the list empty, no public address exists at all.

It is still a database holding every app's data, reachable from outside. To close it: create the
login with the Cloud SQL API, which needs no network path, and let each app create its own schema
on first request the way it already creates its own tables. What that costs is `pg-table-access` —
cross-app grants are SQL and nothing would have a path to issue them.

**That allowlist is a NAT range, not one address.** The provisioner egresses from a pool, so a
single `/32` fails intermittently — a deploy times out, and the identical configuration succeeds
on the next attempt. The list therefore covers the range rather than one host, which is wider than
ideal and the reason the paragraph above matters more, not less.

**`repo:push` is granted to Developers with no conditions.** They can publish a new version of any
bundle in the catalog, including the platform bundles and the shared database. Conditioning it
needs a repo-scoped attribute, which this organization has not declared — `repo_team` on each
repository, and one condition on the push policy.

**`exposure` gates component placement, not bundle parameters.** A citizen developer cannot add a
component declared `external`, which is what stops them publishing a site to the internet. The
condition does not reach inside a bundle's parameters, so somebody determined could place an
internal component and turn its `public_access` on. Closing it needs a repository grant that keeps
internet-facing bundles out of citizen projects entirely.

**The four demo applications are reachable without signing in.** `public_access` is on so the URLs
are clickable. Every one of them talks to a database, and none of them authenticates a visitor.
They are demonstrations, not software anybody should run.

**The GCP service account is a project Owner.** Fastest way to start, far more than this platform
needs. Once you know which bundles you run, narrow it to `roles/run.admin`,
`roles/artifactregistry.admin`, `roles/cloudsql.admin`, `roles/compute.networkAdmin`,
`roles/secretmanager.admin`, `roles/iam.serviceAccountAdmin`, `roles/storage.admin`.

**pgAdmin holds the cluster's administrative credential.** It is internal-only and single-instance,
and turning its `public_access` on would put full access to every app's data behind one password.
There is no configuration of this platform where that is the right call.

**Production checks are gated, not skipped.** Bundles that still fail a check carry
`halt_on_failure: '.params.md_metadata.default_tags["md-target"] == "production"'`, so the finding
is a warning in development and a hard stop in production. That is the pattern to copy — a blanket
skip applies in production too, and nobody revisits it.

## Rebuilding This Organization From Nothing

Every command needed to reproduce the platform described here, in the order it has to happen.
Attributes, groups, policies and grants have no CLI — those steps say where to do them instead.

Run `mass whoami` first, and again any time you are unsure. Publishing to the wrong organization
succeeds silently.

### 1. The credential

```bash
mass repository create gcp-service-account -t resource-type
mass resource-type publish platforms/gcp/massdriver.yaml
mass resource create -f ~/Downloads/PROJECT_ID-abc123.json \
  -t gcp-service-account -n "Massdriver Sandbox"
mass resource list
```

Use the CLI rather than the web uploader for GCP keys — the form corrupts the `private_key` PEM
block and the failure only shows up at deploy time.

### 2. Attributes

**Settings → Custom Attributes.** Declare all four before writing any policy or grant, because a
condition naming an undeclared key is dropped silently and the policy then applies to everything.

| Key | Scope | Values |
| --- | --- | --- |
| `managed_by` | PROJECT | `platform`, `engineering`, `citizen` |
| `team` | PROJECT | `platform`, `artists`, `tourdates`, `merch`, `fans` |
| `tier` | ENVIRONMENT | `dev`, `staging`, `production` |
| `exposure` | COMPONENT | `internal`, `external` |

Create each with `required` off, tag everything that already exists, then mark them required.
Marking one required first leaves you with resources that cannot be updated until you go back and
fill it in.

### 3. Resource types and bundles

```bash
make publish-resource-types
```

Then each bundle. `mass bundle build` regenerates the Terraform variables from `massdriver.yaml`,
so it runs before every publish:

```bash
mass repository create gcp-network -t bundle
mass bundle build   --bundle-directory bundles/gcp-network
mass bundle publish --development --bundle-directory bundles/gcp-network
```

Repeat for `gcp-artifact-registry`, `gcp-cloud-sql-postgres`, `pg-admin`, `pg-schema`,
`pg-table-access`, `gcp-bigquery-federation`, `gcp-cloud-storage-bucket`, `gcp-firestore`,
`hello-cloud-run`, and the four apps.

### 4. Projects and environments

```bash
mass project create scp --name "Shared Citizen Platform" \
  -d "The network, the registry, and the shared database." \
  -a managed_by=platform,team=platform
mass environment create scp dev --name dev -a tier=dev

mass project create artists --name "Artist Management" -a managed_by=citizen,team=artists
mass environment create artists dev --name dev -a tier=dev

mass project create tourdates --name "Tour Dates" -a managed_by=citizen,team=tourdates
mass environment create tourdates dev --name dev -a tier=dev

mass project create merch --name "Merch Inventory" -a managed_by=citizen,team=merch
mass environment create merch dev --name dev -a tier=dev

mass project create fans --name "Fan Signups" -a managed_by=citizen,team=fans
mass environment create fans dev --name dev -a tier=dev
```

Project and environment identifiers allow lowercase letters and digits only, up to 20 characters.
No hyphens — which is why the project is `tourdates` while its bundle is `tour-dates`.

`-a` replaces the whole attribute set rather than merging, so pass everything you want to keep each
time.

### 5. Groups and policies

**Settings → Groups.** Seven groups. See [The Access Model](#the-access-model) for the reasoning;
this is the shape.

| Group | Policies |
| --- | --- |
| Platform Ops | `organization:manage`, plus every project, environment, instance, repo and resource action, unconditioned |
| Developers | View everything; design where `exposure` is internal or external; instance actions where `managed_by: engineering`; propose only at production |
| Citizen Developers | `project:view` where `managed_by` is `citizen` or `platform`. Read-only. Everybody joins this one |
| Citizen Developers - Artists | Design, configure and deploy fenced to `team: artists` and `tier: dev`; propose above that |
| Citizen Developers - Tour Dates | The same, fenced to `tourdates` |
| Citizen Developers - Merch | The same, fenced to `merch` |
| Citizen Developers - Fans | The same, fenced to `fans` |

Every policy in a team group carries its own fence. That reads as duplication and is not — drop the
condition from one row and that action reaches every project the person can see.

### 6. Share the credential

On the credential's sharing settings, grant **`resource:export`** with a recipient condition of
`tier: dev`. That is what keeps a sandbox key out of a production environment.

Then set it as an environment default on every environment:

```bash
mass environment default scp-dev       <credential-resource-id>
mass environment default artists-dev   <credential-resource-id>
mass environment default tourdates-dev <credential-resource-id>
mass environment default merch-dev     <credential-resource-id>
mass environment default fans-dev      <credential-resource-id>
```

`mass resource list` gives you the id.

### 7. Decide which projects get which bundles

On each repository's sharing settings, grant **`repo:pull`** with a recipient condition on
`managed_by`. This is where "citizen developers can only ship serverless" becomes something the
platform enforces rather than something a document asserts.

| Repositories | Granted to |
| --- | --- |
| `gcp-network`, `gcp-artifact-registry`, `gcp-cloud-sql-postgres`, `pg-admin` | `platform` |
| `pg-schema`, `pg-table-access`, `gcp-bigquery-federation` | `platform`, `engineering` |
| The app bundles, `gcp-cloud-storage-bucket`, `gcp-firestore` | `platform`, `engineering`, `citizen` |

A citizen project cannot place a VPC because the bundle was never granted to it. Adding the
component fails outright.

### 8. The platform tier

```bash
mass component add scp gcp-network            --id network  --name "Platform Network"   -a exposure=internal
mass component add scp gcp-artifact-registry  --id registry --name "Container Registry" -a exposure=internal
mass component add scp gcp-cloud-sql-postgres --id db       --name "Shared Database"    -a exposure=internal
mass component add scp pg-admin               --id pgadmin  --name "Database Console"   -a exposure=internal

mass component link scp-network.network              scp-db.network              --from-version latest+dev --to-version latest+dev
mass component link scp-db.database                  scp-pgadmin.database        --from-version latest+dev --to-version latest+dev
mass component link scp-registry.registry            scp-pgadmin.container_registry --from-version latest+dev --to-version latest+dev
mass component link scp-network.serverless_connector scp-pgadmin.vpc_connector   --from-version latest+dev --to-version latest+dev
```

Deploy in dependency order. The network takes about four minutes, most of it the connector; the
database about ten.

```bash
mass instance deploy scp-dev-network  -m "platform network" -f
mass instance deploy scp-dev-registry -m "image registry"   -f
mass instance deploy scp-dev-db       -m "shared database"  -f
mass instance deploy scp-dev-pgadmin  -m "database console" -f
```

`--from-version latest+dev` is what tracks the development channel. Without the `+dev` suffix a
component pins to released versions only and never sees anything published with `--development`.

### 9. Share the platform with the app projects

The apps live in different projects, so the platform's outputs need `resource:export` grants of
their own, conditioned on `tier: dev`: the registry, the serverless connector, and the database.

Then make them environment defaults, so every app added later binds on its own:

```bash
mass environment default artists-dev scp-dev-registry.registry
mass environment default artists-dev scp-dev-network.serverless_connector
mass environment default artists-dev scp-dev-db.database
```

Repeat for `tourdates-dev`, `merch-dev` and `fans-dev`.

> [!NOTE]
> Environment defaults bind at the moment a component is created. A component that already exists
> keeps whatever it had, so wire those with an explicit override:
>
> ```bash
> mass instance remote-reference set artists-dev-data postgres_cluster scp-dev-db.database
> ```

### 10. Each app

Two components per project — the schema it owns, and the app itself:

```bash
mass component add artists pg-schema  --id data --name "Artist Portal Data" -a exposure=internal
mass component add artists artist-portal --id app  --name "Artist Portal"      -a exposure=internal

mass component link artists-data.table_set artists-app.database \
  --from-version latest+dev --to-version latest+dev

mass instance deploy artists-dev-data -m "schema and scoped login" -f
mass instance deploy artists-dev-app  -m "the app"                 -f
```

Repeat for `tourdates`/`tour-dates`, `merch`/`merch-inventory`, and `fans`/`fan-signups`.

Deploy the schema before the app. The app reads its connection from what the schema component
published, so the other order gives you an app with no database.

### 11. One team reading another team's table

The grant is issued from the platform project, not from the project that wants the data. Placing it
beside the app would say the citizen developer granted themselves access.

```bash
mass component add scp pg-table-access --id merchreads \
  --name "Merch reads Tour Dates" -a exposure=internal

mass component link scp-db.database scp-merchreads.postgres_cluster \
  --from-version latest+dev --to-version latest+dev

mass instance deploy scp-dev-merchreads -m "issue merch a read-only login" -f
```

Configure it with `login_name: merch_reads_tours` and `read: ["tour_dates.shows"]`.

Then grant the resulting login `resource:export` on `tier: dev`, and point the app at it:

```bash
mass instance remote-reference set merch-dev-app borrowed scp-dev-merchreads.grants
mass instance deploy merch-dev-app -m "show the borrowed table" -f
```

The table has to exist before the grant can be issued, so the owning app must have deployed and run
its migrations first.

### Useful while you work

```bash
mass instance list artists-dev
mass instance deploy <instance> --plan
mass instance deploy <instance> --propose
mass instance version <instance>@latest+dev
mass deployment logs <deployment-id>
mass deployment approve <deployment-id>
```

An instance pinned to an older version does not pick up a new publish, and the deploy still
succeeds — against the old version. `mass instance version` re-pins it.

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

## Repository Structure

```
.
├── README.md
├── Makefile                     # publishing automation
├── preview.yaml                 # preview environment fork config
├── platforms/                   # cloud-credential resource types
│   ├── gcp/                     # service account — the one this platform uses
│   └── aws, azure, kubernetes, ...
├── resource-types/              # the contracts bundles connect through
│   ├── network/ serverless-connector/ container-registry/
│   ├── postgres-database/       # a Postgres instance
│   ├── postgres-schema/         # a schema and the login that owns it
│   ├── postgres-table-grants/   # a login scoped to named tables
│   ├── analytics-dataset/ cloud-run-service/ object-storage/ firestore-database/
│   └── ...
├── bundles/
│   ├── gcp-network/             # platform tier
│   ├── gcp-artifact-registry/
│   ├── gcp-cloud-sql-postgres/
│   ├── pg-admin/                # pgAdmin, internal only
│   ├── pg-schema/               # data access tier
│   ├── pg-table-access/
│   ├── gcp-bigquery-federation/
│   ├── artist-portal/           # application tier
│   ├── artist-showcase/         # public, external-facing
│   ├── tour-dates/ merch-inventory/ fan-signups/
│   ├── hello-cloud-run/
│   └── gcp-cloud-storage-bucket/ gcp-firestore/
└── templates/                   # what `mass bundle new` scaffolds from
    ├── gcp-cloud-run/           # the one citizen apps use
    └── terraform/ opentofu/ bicep/ helm-chart/
```

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
