# Changelog

## 0.0.0

Initial release.

- One `src` step run by the Terraform provisioner
- Placeholder `instance_name`, `instance_count` and `enable_monitoring` params, with Development
  and Production examples
- `null_resource.example` so a freshly scaffolded bundle publishes and deploys with no cloud
  credential, proving the pipeline before any real infrastructure exists
- Massdriver provider wired up in `src/providers.tf`, with commented AWS, Azure and Google blocks
  to uncomment
- Publishes no resource yet; `src/resources.tf` carries the `massdriver_resource` pattern to follow
