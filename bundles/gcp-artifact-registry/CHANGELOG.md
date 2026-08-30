# Changelog

All notable changes to this bundle are documented here.

## [0.1.0] - 2026-08-10

### Added

- Initial release. Creates a GCP Artifact Registry Docker repository.
- Optional immutable tags, and a cleanup policy that deletes untagged images after a
  configurable number of days.
- Emits a `container-registry` resource with `reader` and `writer` IAM policies for
  consuming bundles to bind to.
