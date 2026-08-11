# Importing an existing GCP Artifact Registry repository

Use this if you already have an Artifact Registry repository and want Massdriver to connect
workloads to it, rather than creating a new one with the `gcp-artifact-registry` bundle.

&nbsp;

## Step 1

In the Google Cloud Console, go to **Artifact Registry → Repositories** and click the repository
you want to import.

&nbsp;

## Step 2

Fill in the form to the left using the values from that page:

* **ID** — the full resource name, shown as
  `projects/PROJECT_ID/locations/LOCATION/repositories/REPOSITORY_NAME`
* **Name** — the repository name on its own (the last segment of the ID)
* **Registry URL** — the host and path shown at the top of the repository page, in the form
  `LOCATION-docker.pkg.dev/PROJECT_ID/REPOSITORY_NAME`. Do not include `https://` or an image tag.
* **Location** — the region shown in the repository list, for example `us-central1`
* **Format** — `DOCKER` for container images

&nbsp;

## Step 3

Under **Access Policies**, add the roles you want consuming bundles to be able to request. The
`id` of each policy is the GCP IAM role that gets bound to the consumer's service account:

* `roles/artifactregistry.reader` — pull only. This is what a Cloud Run service needs.
* `roles/artifactregistry.writer` — push and pull. This is what a CI pipeline needs.

&nbsp;

## Step 4

Make sure the service account Massdriver uses can read this repository. If the repository lives
in a different GCP project than the one Massdriver manages, grant that service account
`roles/artifactregistry.reader` on the repository's project.

&nbsp;

## Step 5

Click **Create**. The registry is now available as a dependency for any bundle that declares a
`container-registry` connection.
