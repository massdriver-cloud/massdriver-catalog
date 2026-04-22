# Massdriver Local Config

## Environment slug conventions

A Massdriver package slug has the shape `<project>-<env>-<manifest>` where the
`<env>` segment is the ENVIRONMENT NAME and the `<manifest>` segment is the
manifest name for the bundle on that environment's canvas. The environment
portion is the SECOND segment only — do not include the manifest in pattern
matching.

## Production pattern

Only the environment segment (second segment) should be matched against this
pattern, NOT the full slug:

production_pattern: ^(prod|prd|production)$

## Test environments (explicit allow list)

These environments are TEST / DEVELOPMENT and must always be allowed:

- `claude` (in `gcp-claude` project — first demo)
- `dataplat-claude` (NOT production; used for the GCP data platform Kafka demo)

Package slugs on these environments will look like `gcp-claude-*` or
`dataplat-claude-*`. Even if the manifest name contains strings that look
production-adjacent (e.g. `aisquadds`, `logsink`, `landingzone`), these are
NOT production targets — the environment segment is what matters.
