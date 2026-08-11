# GCP Network

The platform-owned VPC. Application bundles connect to it — they never configure a network of
their own.

## What you get

- One VPC with regional subnets you define (CIDR + optional secondary ranges per subnet, for
  future GKE pod/service ranges).
- A Private Service Access peering, so Cloud SQL (and Memorystore) instances can get a private
  IP instead of a public one with an authorized-networks allowlist.
- A Serverless VPC Access connector, so Cloud Run and Cloud Functions can reach those private IPs
  without going out to the public internet and back.

## Settings

**Network CIDR** — the address space for the whole VPC. Cannot change after creation; size it for
where you expect this platform to grow, not just today's footprint.

**Subnets** — one entry per region you run workloads in. Each needs its own non-overlapping CIDR.
Add secondary ranges only if something on that subnet needs them (GKE pods/services); most
subnets won't.

**Private Service Access** — on by default. Turning it off means no bundle in this project can
ever use a private-IP Cloud SQL instance. The reserved range size (prefix length) caps how many
private-IP service instances can attach; widening it later requires recreating the peering.

**Connector Region / CIDR / Min / Max / Machine Type** — the Serverless VPC Access connector.
It must live in the same region as any Cloud Run service that uses it. Size it like a small,
always-on fleet: min instances is what's running at idle, max is the ceiling under load.

## Connecting other things to it

This bundle produces two resources:

- **Network** — subnet self-links and the network self-link. A Cloud SQL bundle connects to this
  to get a private IP.
- **Serverless VPC Connector** — what a Cloud Run bundle sets as `vpc_access.connector`.

Both are meant to be environment defaults or direct links, not something an application developer
picks parameters for.
