# Changelog

## 0.0.0

Initial release.

- One `chart` step run by the Helm provisioner, installing a chart from a remote chart repository
  rather than one copied into the bundle, so upgrades are a version change instead of a merge
- Repository URL, chart name and chart version are separate params, which puts the installed
  version in the instance settings and in the deployment history
- A required `kubernetes_cluster` connection, so a bundle cannot be placed on the canvas without a
  cluster to install into
- Release name taken from the Massdriver instance name, so two environments can install the same
  chart into one cluster without colliding
- `chart/values.yaml` for overrides of the chart's defaults, merged over them at deploy time
- Publishes no resource yet
