---
templating: mustache
---

# Static Site Runbook

{{#resources.site}}

## Publish a change

Edit the files in the bundle's `src/site` folder, then:

```bash
mass bundle publish --development
```

Deploy the component afterwards. The provisioner uploads the files; no cloud credentials are
involved.

## The page still shows the old content

Almost always caching, not a failed deploy. Visitors and the delivery network hold a copy for
as long as **How Long Visitors Cache Pages** allows.

Confirm the new file actually reached the bucket:

```bash
aws s3 ls s3://{{resources.site.bucket}}/ --recursive
```

If the file is there with a recent timestamp, the deploy worked and you are seeing a cached
copy. Force the network to drop it:

```bash
aws cloudfront create-invalidation --distribution-id {{resources.site.id}} --paths '/*'
```

Invalidations take a minute or two. The first 1,000 paths each month are free.

While iterating, set the cache to 1 minute so this stops happening.

## The whole site returns 403

Symptom: every path returns `403 Forbidden`, including the home page.

The delivery network is being refused by the bucket. Check that the bucket policy still names
this distribution:

```bash
aws s3api get-bucket-policy --bucket {{resources.site.bucket}} \
  --query Policy --output text | python3 -m json.tool
```

Look for `AWS:SourceArn` matching this distribution. If it is missing or names a different one,
redeploy — the bundle owns that policy.

## One page returns 403 but others work

The file is not in the bucket under that exact name. Paths are case sensitive, and there is no
directory listing:

```bash
aws s3 ls s3://{{resources.site.bucket}}/ --recursive
```

Requesting `/about` serves `about` only if that key exists — you usually want `/about.html`, or
a folder containing its own `index.html`.

For a single page app this should not happen at all. If it does, **Single Page App** is off;
turn it on so unknown paths fall back to the index page.

## The page downloads instead of rendering

The file was stored with the wrong content type, so the browser will not display it. Check what
it was given:

```bash
aws s3api head-object --bucket {{resources.site.bucket}} --key index.html \
  --query ContentType --output text
```

It should be `text/html; charset=utf-8`. The bundle sets this from the file extension, so an
unusual extension falls back to a generic type. Rename the file to a standard extension and
publish again.

## Checking traffic

Access logs land in the log bucket, delivered in batches within an hour or so:

```bash
aws s3 ls s3://{{resources.site.bucket}}/ --recursive | head
```

Logs are kept for 90 days and then deleted automatically.

{{/resources.site}}

{{^resources.site}}

This site has not been deployed yet. Deploy it, then return here for operational procedures.

Note that the first deploy takes several minutes longer than later ones, because the delivery
network has to be created and propagated.

{{/resources.site}}
