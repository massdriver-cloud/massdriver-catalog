# AWS S3 Static Site

Simple static website hosting using Amazon S3. Perfect for marketing pages, landing pages, and documentation sites.

## Features

- **S3 Website Hosting** - Native static website hosting with custom error pages
- **Public Access** - Configured for public read access
- **Optional Versioning** - Enable version history for content recovery
- **Inline Content** - Define HTML content directly in parameters

## Architecture

```
Internet → S3 Website Endpoint → index.html / error.html
```

## Connections

| Name | Type | Description |
|------|------|-------------|
| `aws_authentication` | `aws-iam-role` | AWS credentials for deployment |

## Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `site_name` | string | `marketing-site` | Name for your site (used in bucket name) |
| `html_content` | string | - | HTML content for index.html |
| `error_page` | string | - | HTML content for error.html |
| `enable_versioning` | boolean | `false` | Enable S3 versioning for content history |

## Outputs

- `website_url` - Public HTTP endpoint for the website
- `bucket_name` - S3 bucket name for CLI operations

## Usage Notes

- Website URL is HTTP only; use CloudFront for HTTPS
- Bucket names must be globally unique
- Content updates trigger immediate deployment

## Changelog

### 0.0.2

- Add configurable versioning parameter
- Use `.checkov.yml` for security policy configuration
- Add Checkov halt_on_failure for production environments
