# Changelog

## 0.0.0

Initial release.

- One `src` step run by the Bicep provisioner, deploying `src/template.bicep` to Azure Resource
  Manager
- A required `azure_authentication` connection, so a bundle cannot be placed on the canvas without
  a subscription to deploy into
- Placeholder `resource_name`, `instance_count` and `enable_monitoring` params, plus a `location`
  enum of six Azure regions, with Development and Production examples
- No state file — ARM compares the template against the resource group on every deploy, so there
  are no state locks and no import step, and removing a resource from the template does not delete
  it from Azure
- Publishes no resource yet; the commented storage account in `src/template.bicep` shows the shape
  to follow
