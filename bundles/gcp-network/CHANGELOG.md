# Changelog

All notable changes to this bundle are documented here.

## [0.1.0] - 2026-08-11

### Added

- Initial release. Creates a VPC with configurable regional subnets and secondary ranges.
- Private Service Access peering for Cloud SQL / Memorystore private IP connectivity.
- Serverless VPC Access connector for Cloud Run / Cloud Functions to reach private IPs.
- Emits `network` and `serverless_connector` resources for application bundles to connect to.
