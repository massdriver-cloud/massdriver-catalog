# Marketing Static Site

A plain static website — HTML, CSS, JS you built ahead of time, no server rendering anything per-request. Fast, cheap, and there's very little that can break at 2am because there's no application server to crash.

## What you get

- A private storage bucket nobody can reach directly — every visitor goes through CloudFront, never straight to the bucket.
- A global CDN in front of it, so visitors load your site from a location near them instead of one single server far away.
- Redirects for old URLs (moving from your old platform means some links people already have will point at paths that no longer exist) — handled at the edge, before the request even reaches your bucket.
- The trailing-slash behavior you're used to from most static site generators (`/about/` and `/about` both find the right page) preserved automatically.
- A baseline of security response headers (HSTS, no-sniff, clickjacking protection) applied to every response, without you having to configure your site generator to add them.

## Things you can't change later

The custom domain name is locked in once deployed — changing it means a new distribution and a new DNS cutover, not a quick edit.

## One manual step after deploy

Point your DNS provider's CNAME (or ALIAS/ANAME, if you're on Route 53 or similar) at the CloudFront distribution's domain name, shown in the instance panel after deploy. This bundle can't do that step for you unless it also owns your DNS zone.

## Customize it

1. Edit the `redirects` list in `massdriver.yaml`'s examples to match your actual old-platform → new-site path mapping.
2. `src/main.tf` provisions the real S3 bucket, CloudFront distribution, Origin Access Control, response headers policy, and CloudFront Function — nothing here is a placeholder.
3. Upload your built site (and a `404.html`) to the bucket through your normal deploy pipeline — this bundle provisions the infrastructure, not your build output.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
