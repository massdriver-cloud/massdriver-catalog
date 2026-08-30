# Bicep bundle

A starting point for a bundle that builds Azure infrastructure with Bicep. It is deliberately
empty: it stands up a working deploy pipeline first, so you can prove the wiring before you write
any real infrastructure.

## What you get

- `massdriver.yaml` with your bundle's name and description already filled in, at version `0.0.0`.
- A required `azure_authentication` connection, so the bundle cannot deploy without a subscription
  to deploy into.
- `src/template.bicep` with the parameters already declared and one commented-out storage account
  showing the shape of a real resource.
- `operator.md`, a runbook for the failures a new bundle actually hits.
- `CHANGELOG.md` and this file.

## Make a new bundle from this template

```bash
mass bundle new -n artist-portal -t bicep -o bundles
```

## Change these first

1. **`src/template.bicep`** — uncomment the storage account, or replace it with what you actually
   need. Every resource should carry `tags: md_metadata.default_tags` so Massdriver's own tags land
   on it. Right now `md_metadata` is declared and never used, and the Bicep linter says so.
2. **Keep the parameters in step.** Every param in `massdriver.yaml` needs a matching `param` in
   `src/template.bicep`, spelled the same way. As shipped, `tags` and `advanced` are in
   `massdriver.yaml` with nothing matching them in the Bicep file. Either add them or remove them
   before you deploy — a mismatch is rejected by Azure, not by the linter.
3. **`massdriver.yaml` params** — `resource_name`, `instance_count` and `enable_monitoring` are
   stand-ins. Replace them with the settings your infrastructure actually has, and update the
   Development and Production examples to match.
4. **`location`** — the list of Azure regions is a short starter set. Trim it to the regions your
   organization actually uses, or extend it.
5. **`source_url` in `massdriver.yaml`** — it still says `YOUR_ORG/YOUR_REPO`.
6. **`operator.md`** — it is written with worked example names: an `artist-portal` bundle deployed
   as instance `artists-dev-portal`, in `eastus`. Swap those for your own so every command runs as
   written.

## Why the Azure credential is a required connection

The other infrastructure templates in this catalog start with no connections at all, because they
can target any cloud. This one only targets Azure, so there is exactly one thing it always needs: a
service principal with a subscription to deploy into. Making it required means a bundle cannot be
placed on the canvas without one, and the failure shows up as a missing connection rather than an
authentication error twenty minutes into a deploy.

The credential itself is a platform resource type in this repository, under `platforms/azure/`. It
has to be published to your organization before a bundle referencing it can be published at all.

## Why Bicep instead of Terraform or OpenTofu

Bicep talks to Azure Resource Manager directly. There is no state file: what exists is whatever is
in the resource group, and ARM works out the difference each time you deploy. That removes a whole
class of problem — no state locks, no drift between a state file and reality, no import step to
adopt something that already exists.

It also removes a safety net. ARM deploys in incremental mode, which means deleting a resource from
`src/template.bicep` does not delete it from Azure. It simply stops being managed. Terraform and
OpenTofu would have destroyed it, because they remember what they created and Bicep does not.

Choose Bicep when the work is Azure-only and you want the shortest path to ARM. Choose OpenTofu
when the bundle spans more than one cloud, or when you want deletions to be handled for you.

## A note on curly braces

`mass bundle new` renders every file in this folder, not just `massdriver.yaml`, and only `name`
and `description` exist while it does. Any other doubled-brace expression in these files becomes an
empty string in the scaffolded bundle, and several forms — including an empty pair of doubled
braces — stop the scaffold with an error instead. That is why the runbook here uses real values
rather than Massdriver's runtime tags.
