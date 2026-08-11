# GCP Artifact Registry

Creates a place in Google Cloud to store container images. Your application images get pushed
here, and services like Cloud Run pull from here when they start.

## What you get

One Artifact Registry repository in the region you pick, holding Docker images.

## Settings

**Repository Name** — what the repository is called. You cannot rename it later, so pick
something that describes what goes in it, like `app-images`.

**Location** — the region the images are stored in. Pick the same region your applications run
in. If they are far apart, starting a service is slower and Google charges you for moving the
image between regions.

**Immutable Tags** — when this is on, a tag like `v1.2.0` always points at the same image
forever. Nobody can push a different image over that tag. This is worth turning on for anything
running in production, because it means the image running today is the same image that was
tested. You cannot turn this off later.

**Delete Untagged Images After (days)** — every time you move a tag to a new build, the old
image loses its tag but stays in storage and keeps costing money. This deletes those leftovers
after the number of days you set. Set it to 0 to keep everything.

## Connecting other things to it

This bundle produces a **Container Registry** resource. Any bundle that needs to pull or push
images can connect to it — a Cloud Run service picks the **Pull** policy, a build pipeline picks
**Push and Pull**.

## Pushing images to it

The registry address looks like this:

```
us-central1-docker.pkg.dev/your-project/app-images-abc123
```

You can see the exact value on the resource in Massdriver after deploying. To push an image
from your machine:

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
docker tag my-app:latest us-central1-docker.pkg.dev/your-project/app-images-abc123/my-app:v1
docker push us-central1-docker.pkg.dev/your-project/app-images-abc123/my-app:v1
```
