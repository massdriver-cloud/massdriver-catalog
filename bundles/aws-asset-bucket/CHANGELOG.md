# Changelog

## 0.1.0

Initial release.

- Private S3 bucket encrypted with a dedicated KMS key
- Versioning with configurable expiry for old versions
- Access logging to a companion log bucket
- Bucket policy denying non-TLS requests
- Optional CORS rules for browser uploads
- Optional lifecycle transitions to colder storage classes
- Publishes an `object-storage` resource with read / write / admin IAM policies
