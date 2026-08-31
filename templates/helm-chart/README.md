# Helm chart bundle

A starting point for a bundle that installs a Helm chart from a chart repository into a Kubernetes
cluster. You do not write the chart. You point at one that already exists, pin the version you
want, and override the values you care about.

## What you get

- `massdriver.yaml` with your bundle's name and description already filled in, at version `0.0.0`.
- Three settings for the chart — repository URL, chart name, and version — plus the namespace to
  install into.
- A required `kubernetes_cluster` connection, so the bundle cannot deploy without a cluster.
- `chart/values.yaml`, where your overrides of the chart's own defaults go.
- `operator.md`, a runbook for the failures a new bundle actually hits.
- `CHANGELOG.md` and this file.

The Helm release is named after the Massdriver instance. An instance called `artists-dev-portal`
installs a release called `artists-dev-portal`.

## Make a new bundle from this template

```bash
mass bundle new -n artist-portal -t helm-chart -o bundles
```

## Change these first

1. **The chart defaults in `massdriver.yaml`** — the examples install nginx from Bitnami, which is
   only there to be something that works. Point `chart.repository` and `chart.name` at the chart
   you actually run.
2. **Pin `chart.version`.** Leaving it empty means "whatever is newest at the moment of the
   deploy", so two deploys of the same bundle can install two different things. A pinned version is
   visible in the instance settings and in the deployment history, which is what makes an upgrade a
   reviewable change rather than a surprise.
3. **`namespace`** — it defaults to `default`. Give each environment its own.
4. **`chart/values.yaml`** — your overrides of the chart's defaults. These are merged over the
   chart's own `values.yaml`; anything you leave out keeps the chart's default.
5. **`source_url` in `massdriver.yaml`** — it still says `YOUR_ORG/YOUR_REPO`.
6. **`operator.md`** — it is written with worked example names: an `artist-portal` bundle deployed
   as instance `artists-dev-portal` into namespace `artists-dev`. Swap those for your own so every
   command runs as written.

## Feeding connection data into the chart

`chart/values.yaml` is a plain file, so it cannot know a database hostname that only exists at
deploy time. For that, add a `chart/values.jq` next to it. It is a JQ expression evaluated against
this instance's params and connections, and whatever it produces is merged into the values the
chart receives. That is how a database password from a connected bundle reaches a chart without
anyone copying it anywhere.

## Why the chart is remote instead of copied into the bundle

Copying the chart's source into `chart/` is the other way to do this, and this template chose not
to. The reasons:

- **Upgrades are a setting, not a merge.** Moving to a new chart release is a version number
  change, deployed and rolled back like any other config change. A vendored chart means pulling
  upstream changes in by hand and reconciling them against your edits, every time.
- **You are not on the hook for the templates.** The chart's maintainers own its Kubernetes
  manifests. You own the values.
- **The bundle stays small**, and there is exactly one place — the version param — where anyone can
  see what is actually installed.

The trade-off is a dependency on someone else's server. The chart repository has to be reachable
when a deploy runs, and the version you pinned has to still be published. Chart repositories do
prune old versions, and a version that installed fine last month can vanish. That is a real failure
and it is the first entry in the runbook.

If you need to change the chart's templates rather than its values, this is the wrong shape. Copy
the chart into `chart/`, delete the `chart:` block from the step config in `massdriver.yaml`, and
maintain it as your own.

## Why the release name is the instance name

Every Massdriver instance gets a name that is unique across the whole organization, like
`artists-dev-portal`. Using it as the Helm release name means two environments can install the same
chart into the same cluster without colliding, and that you can go straight from a name on the
canvas to `helm status` in a terminal with nothing to look up in between.

## A note on curly braces

`mass bundle new` renders every file in this folder before it becomes a bundle, and it uses the
same doubled-brace syntax Helm does. Helm expressions written in these files are not passed
through: some become empty strings, and some stop the scaffold with an error. Chart templating
belongs in a chart, not in this folder's documentation.
