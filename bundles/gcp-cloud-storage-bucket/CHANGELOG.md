# Changelog

## 0.0.0

Initial release.

- Creates a private GCS bucket with uniform bucket-level access and public access prevention
  always on.
- Optional versioning, access logging (to a dedicated logs bucket), customer-managed encryption
  (Cloud KMS), and an automatic delete-after-N-days lifecycle rule.
- Emits an `object-storage` resource with `Read`, `Read and Write`, and `Admin` IAM policies for
  consuming bundles to bind to.
