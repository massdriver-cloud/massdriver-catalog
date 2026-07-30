# Marketing Static Site

Provisions hosting for a prebuilt static site (HTML, CSS, JS): a private S3 origin, a CloudFront distribution with Origin Access Control, path-based redirects, and a security response-headers policy. It emits no resource and connects only to AWS authentication; there is no network or cluster dependency.

## What it provisions

- A private origin bucket. Visitors reach content only through CloudFront, never the bucket directly.
- A CloudFront distribution serving the site from edge locations, with TLS from an ACM certificate you supply.
- A CloudFront Function that applies the `redirects` list at the edge (useful for preserving old URLs after a platform migration) and normalizes trailing slashes so `/about` and `/about/` resolve to the same page.
- A response-headers policy adding HSTS, no-sniff, and clickjacking protection to every response.

## Parameters worth knowing

- `domain_name` is immutable. Changing it means a new distribution and a DNS cutover.
- `acm_certificate_arn` must be an issued certificate in us-east-1; CloudFront requires that region regardless of where the rest of your infrastructure runs.
- `price_class` controls which edge locations serve the site. Fewer locations cost less.

## One manual step after deploy

Point a CNAME (or ALIAS/ANAME) record at the CloudFront distribution's domain name, shown in the instance panel after deploy. This bundle does not manage your DNS zone.

## Operational notes

- This bundle provisions infrastructure only. Upload the built site (including a `404.html`) to the bucket through your deploy pipeline.
- `src/main.tf` provisions the bucket, distribution, Origin Access Control, response-headers policy, and CloudFront Function.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
