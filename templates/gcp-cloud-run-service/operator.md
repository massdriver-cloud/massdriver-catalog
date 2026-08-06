# {{ name }}

{{ description }}

## Non-obvious constraints

- Cloud Run revisions are immutable. New config triggers a new revision; traffic defaults to 100% on latest.
- Service account name derives from the bundle's name prefix, capped at 30 characters. Renaming the package destroys and recreates the SA.
- Ingress changes trigger a full revision replacement (cold start on next request).

## Troubleshooting

- Revision fails readiness check: the container port in `src/main.tf` must match what the running process binds to.
- Image pull errors: the runtime service account needs `roles/artifactregistry.reader` on the image repo.

## Useful commands

```
gcloud run services describe $SERVICE --region $REGION
gcloud run services logs read $SERVICE --region $REGION --limit 100
gcloud run services update-traffic $SERVICE --to-revisions $REVISION=100 --region $REGION
```
