# OpenTofu bundle

A starting point for a bundle whose infrastructure is written in OpenTofu. This is the default for
this catalog — every bundle already published here runs on OpenTofu — so a bundle scaffolded from
this template fits the repository's existing tooling without any extra setup.

It is deliberately empty. It stands up a working deploy pipeline first, so you can prove the wiring
before you write any real infrastructure.

## What you get

- `massdriver.yaml` with your bundle's name and description already filled in, at version `0.0.0`.
- `src/main.tf` with one example resource that creates nothing real, and an output you can read in
  the deploy log.
- `src/providers.tf` with the Massdriver provider wired up, and commented blocks for AWS, Azure and
  Google. Uncomment the one you need.
- `src/resources.tf` showing how to publish a resource other bundles can connect to.
- `operator.md`, a runbook for the failures a new bundle actually hits.
- `CHANGELOG.md` and this file.

## Make a new bundle from this template

```bash
mass bundle new -n artist-portal -t opentofu -o bundles
```

## Change these first

1. **`src/providers.tf`** — uncomment the cloud provider you are using, in both the
   `required_providers` block and the `provider` block below it.
2. **`massdriver.yaml` params** — `instance_name`, `instance_count` and `enable_monitoring` are
   stand-ins. Replace them with the settings your infrastructure actually has, and update the
   Development and Production examples to match.
3. **`massdriver.yaml` step** — change `provisioner: opentofu` to a pinned version. Every published
   bundle in this catalog uses `provisioner: opentofu:1.10`; match it unless you have a reason not
   to. An unpinned provisioner can change underneath you between two deploys of the same bundle.
4. **`src/main.tf`** — delete `null_resource.example` and write the real thing.
5. **`src/resources.tf`** — publish a resource so other bundles can connect to this one. A bundle
   that publishes nothing can still deploy, but nothing else on the canvas can use it.
6. **`source_url` in `massdriver.yaml`** — it still says `YOUR_ORG/YOUR_REPO`.
7. **`operator.md`** — it is written with worked example names: an `artist-portal` bundle deployed
   as instance `artists-dev-portal`. Swap those for your own bundle and instance id so every
   command runs as written.

After changing params, run `mass bundle build` before you publish. That regenerates
`src/_massdriver_variables.tf` from `massdriver.yaml`, which is where every `var.` in your OpenTofu
comes from.

## Checking your work locally

Once the bundle is in `bundles/`, the repository's own targets pick it up automatically:

```bash
make validate-bundles
```

That builds every bundle and runs `tofu init` and `tofu validate` in each `src/` directory. It
catches syntax errors and missing providers before a deploy does. Run `make clean` afterwards so
local `.terraform` directories and lock files are not published with the bundle.

## Why the example resource does nothing

`null_resource` needs no cloud account, no credential and no connection. A freshly scaffolded
bundle can be published and deployed straight away, which tells you the pipeline works before any
real infrastructure is involved. When something breaks later, you know it was your change and not
the setup.

## Why OpenTofu and Terraform are separate templates

They are two different programs. They read the same language, but they download providers from
different registries — `registry.opentofu.org` rather than `registry.terraform.io` — are released
on different schedules, and are covered by different licences. A bundle picks one at scaffold time
and keeps it: the choice lives in `massdriver.yaml` as `provisioner: opentofu`, not as a setting
somebody can flip later.

Keeping them apart means each template can say true things about its own tool. Two places where
the difference is not cosmetic:

- A provider that exists on Terraform's registry is not guaranteed to exist on OpenTofu's. That
  failure shows up at deploy time, not when you write the code.
- `.terraform.lock.hcl` records which registry each provider came from. Running `terraform init`
  in an OpenTofu bundle's `src/` rewrites it, and running `tofu init` rewrites it back.

## Why there are no connections yet

Connections are what this bundle needs from other bundles — a network, a database, a cloud
credential. The template ships with none, because what you need depends entirely on what you
build. Add them to the `connections:` block in `massdriver.yaml` by hand, pointing each one at a
resource type that is published in your organization.

The `-c` flag on `mass bundle new` does not work with this template. It writes the connection name
but leaves the `$ref` empty, and the bundle then fails to publish. The runbook covers the error and
the fix.

## A note on curly braces

`mass bundle new` renders every file in this folder, not just `massdriver.yaml`, and only `name`
and `description` exist while it does. Any other doubled-brace expression in these files becomes an
empty string in the scaffolded bundle, and several forms — including an empty pair of doubled
braces — stop the scaffold with an error instead. That is why the runbook here uses real values
rather than Massdriver's runtime tags.
