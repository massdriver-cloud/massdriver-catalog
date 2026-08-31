# Changelog

## 0.0.0

Initial release.

- Creates a GCP Artifact Registry Docker repository.
- Optional immutable tags, and a cleanup policy that deletes untagged images after a
  configurable number of days.
- Emits a `container-registry` resource with `reader` and `writer` IAM policies for
  consuming bundles to bind to.
