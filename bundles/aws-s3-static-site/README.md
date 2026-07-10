# AWS S3 Static Site

A static website served straight from an S3 bucket. It ships with a tiny sample site, so the moment it deploys there's a working URL that renders in a browser — no build pipeline, no placeholder resources. It's the fastest deploy in the catalog, which makes it the live-demo favorite.

## What it shows

- **Fastest deploy in the catalog** — one bucket, a website configuration, a public-read policy, and two HTML files. Deploys in seconds and hands back a clickable URL on the `application` artifact.
- **Self-service experience** — Development / Production presets (the only real difference is cache time), an immutable `region`, and friendly validation messages on the index/error document names.
- **Cache control as a parameter** — `cache_max_age_seconds` sets the `Cache-Control` header on every uploaded file. 0 while you iterate, higher for launch.
- **Operator guide** (`operator.md`) — a 2am runbook for the three ways static sites break: AccessDenied XML, stale content, and a missing site.
- **IaC code** (`src/`) — real, minimal OpenTofu: bucket, website configuration, public access block, public-read policy, and a `fileset` loop that uploads everything under `src/site/` with correct MIME types.

## Replace the sample site with your own

The sample page in `src/site/` exists so the bundle renders out of the box. To publish your real site:

1. Build your site (`npm run build`, `hugo`, `jekyll build` — whatever you use).
2. Replace the contents of `src/site/` with your build output (the `dist/`, `public/`, or `_site/` folder contents, not the folder itself).
3. Make sure your entry page matches the `index_document` param (default `index.html`) and your 404 page matches `error_document` (default `error.html`).
4. Publish the bundle and redeploy. Only files whose content changed are re-uploaded.

## What it produces

An `application` resource: the bucket ARN as its ID, the live website URL, and `/` as the health check path.

## No TLS on the website endpoint

S3 website endpoints are HTTP only — the URL this bundle emits starts with `http://`. That's fine for demos and internal tools. For production, put CloudFront with an ACM certificate in front of the bucket for HTTPS and a custom domain; that's out of scope for this bundle.

## No alarms — on purpose

S3 request metrics (4xx/5xx rates) are an opt-in, paid CloudWatch feature, so this bundle ships no alarms rather than a misleading one. The operator guide covers triage instead.

## Costs to know about

Effectively free at demo scale: pennies per month for storage and requests. There are no always-on resources.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
