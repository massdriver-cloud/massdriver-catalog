# Object Storage

A private bucket for your app to store files in — uploaded images, generated reports, backups, whatever isn't a fit for a database row.

## What you get

- A bucket that's locked down from the public internet, no matter what — this can't be changed by a parameter, on purpose.
- Every object encrypted at rest with its own dedicated key (not the shared AWS default key), so you can control and audit exactly who's allowed to decrypt.
- Two ready-made access levels — read-only and read-write — that your app picks up automatically through its own scoped identity. Nobody has to hand out or rotate an access key.
- Optional versioning, so an accidental overwrite or delete isn't permanent.

## What this bucket is not for

If you need to serve files directly to the public internet (product images on a marketing site, downloadable assets), don't make this bucket public — put a CDN in front of it instead. This catalog's static-site bundle shows that pattern.

## Things you can't change later

The bucket name is locked in once deployed, since S3 bucket names have to be globally unique across all of AWS — pick something you won't need to fight over later.

## Customize it

1. Edit `massdriver.yaml` if you need more than the two access levels shipped here (e.g. a delete-only policy for a cleanup job).
2. `src/main.tf` is real Terraform/OpenTofu — an actual bucket, KMS key, and IAM policies, not placeholders.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
