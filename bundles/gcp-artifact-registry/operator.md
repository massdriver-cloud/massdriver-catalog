# Artifact Registry runbook

## A deploy fails with `Permission denied` or `403`

The GCP service account connected to this bundle cannot manage Artifact Registry.

Check that the Artifact Registry API is enabled on the project:

```
https://console.cloud.google.com/apis/library/artifactregistry.googleapis.com?project=cory-sandbox-362007
```

If the API is on, the service account is missing a role. It needs
`roles/artifactregistry.admin` at minimum, or `roles/owner`.

## A deploy fails with `oauth2: cannot fetch token` or an invalid key error

The credential itself is broken, not the permissions. This is almost always a mangled private
key from importing the JSON through the web UI instead of the CLI. Re-import it:

```bash
mass resource create -n cory-sandbox-362007 -t gcp-service-account -f ~/Downloads/key.json
```

Then redeploy. Nothing about the bundle needs to change.

## A workload cannot pull images

Confirm the image actually exists at the tag the workload is asking for:

```bash
gcloud artifacts docker images list {{resources.registry.registry_url}}
```

If the image is there, the consuming workload's service account is missing
`roles/artifactregistry.reader` on this repository. Check that the consuming bundle connected to
this registry and selected the **Pull** policy.

If the image is *not* there, the push went somewhere else — check the region in the registry URL.
`us-central1-docker.pkg.dev` and `us-east1-docker.pkg.dev` are different registries and pushing
to the wrong one succeeds silently.

## An image tag will not overwrite

Immutable Tags is on. This is intentional — a published tag cannot be moved to a different
image. Push a new tag instead.

Turning it off requires recreating the repository, which deletes every image in it. Do not do
this to unblock a deploy; push a new tag.

## Deleting the repository

Destroying this instance deletes every image in the repository, and Artifact Registry has no
undelete. If anything in production is still pulling from it, those workloads stop being able to
start — including autoscaling events on services that are currently healthy, because a running
container does not re-pull until it restarts. Confirm nothing references the registry URL before
destroying.

## Costs are climbing

Storage is billed per GB. Check what is actually in there:

```bash
gcloud artifacts docker images list {{resources.registry.registry_url}} --include-tags
```

Untagged images piling up means **Delete Untagged Images After** is set to 0 or is too long.
Lowering it takes effect on the next deploy. Note the policy only ever deletes untagged images —
tagged images are never removed automatically, so a large tagged history has to be pruned by hand.
