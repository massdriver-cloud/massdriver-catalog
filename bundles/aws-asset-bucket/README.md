# AWS Asset Bucket

An S3 bucket for the files your application serves or stores — images, user uploads, generated
reports, static assets.

## What you get

- A private bucket, encrypted with its own KMS key
- Versioning, so an overwritten or deleted file can be recovered
- Access logging to a companion log bucket
- A rule that rejects any request arriving over plain HTTP
- Three ready-made access policies your application can pick from

## Access policies, and how consumers use them

This bundle creates three real IAM policies scoped to the bucket:

- **read** — download and list files
- **write** — read, plus upload and delete
- **admin** — full control, including changing bucket settings

A bundle that connects to this bucket picks one by name in its own form, and attaches the
policy to its execution role. Pick the narrowest one that works: an application that only
serves images needs `read`, not `admin`.

## Naming

You give a short name describing the contents, like `user-uploads`. A random suffix is added
because S3 bucket names must be unique across every AWS account in the world. The name cannot
be changed later — renaming a bucket in S3 means creating a new one and copying everything
over.

## Browser uploads

Leave **Browser Origins Allowed to Upload** empty unless a web page talks to this bucket
directly. If it does, list the exact sites, like `https://example.com`. Avoid wildcards — a
permissive CORS rule lets any site read responses from your bucket.

## Keeping costs down

Two settings control storage growth:

**Delete Old Versions After** is the one that matters most. With versioning on, every
overwrite keeps the old copy forever unless you set this. Ninety days is a reasonable default.

**Move Old Files to Cheaper Storage** shifts files that are rarely read into colder tiers.
Infrequent Access is about half the price of standard storage but costs more per read, so it
pays off for files read less than about once a month. Deep Archive is the cheapest by a wide
margin but takes up to twelve hours to restore, so use it only for things you hope never to
need.
