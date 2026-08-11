# Changelog

All notable changes to this bundle are documented here.

## [0.1.0] - 2026-08-11

### Added

- Initial release. A campaign web app: visitors submit what the tooth fairy pays at their
  house and their zip code; the app converts the zip to a state on submit and never stores
  the zip itself. Displays a live national average, a state-by-state breakdown, and a chart
  of how the rate has changed over time.
- Built on the `gcp-cloud-run` two-step build+deploy template: `build/` compiles the app
  inside GCP via Cloud Build (no local `docker` or `gcloud` needed), `deploy/` runs it on
  Cloud Run.
- Connects to a Firestore database (required) for storage; public access is on by default
  since this is a public campaign site.
- The page polls a small JSON endpoint every few seconds for live-updating results — see
  `operator.md` and the bundle README for the tradeoff against Firestore listeners or SSE.
