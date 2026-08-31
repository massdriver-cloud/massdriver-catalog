# {{ name }} runbook

## Deploy fails with `provider registry registry.opentofu.org does not have a provider named ...`

```
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider
acmecorp/notreal: provider registry registry.opentofu.org does not have a
provider named registry.opentofu.org/acmecorp/notreal
```

OpenTofu resolves providers from `registry.opentofu.org`. A provider that exists on
`registry.terraform.io` is not automatically there — this is the most common surprise when copying
a module in from somewhere else.

Check the source address in `src/providers.tf` for a typo first. If the name is right and the
provider genuinely is not published to OpenTofu's registry, your options are to declare an explicit
mirror, or to switch this bundle to the `terraform` template. Changing `provisioner: opentofu` to
`provisioner: terraform` on an instance that has already deployed is not a safe in-place edit — the
state is written by one tool and read by the other. Stand up a new instance instead.

## Publish fails with `at '/connections/properties/<name>/$ref': got null, want string`

The full error:

```
Error: bundle failed schema validation:
  - jsonschema validation failed with 'https://api.massdriver.cloud/json-schemas/bundle.json#'
- at '/connections': 'allOf' failed
  - at '/connections/properties/network/$ref': got null, want string
```

The bundle was scaffolded with `mass bundle new -c network=...`. The template writes the connection
name but leaves its `$ref` empty, so the bundle is invalid the moment it is created. Nothing is
wrong with your change.

Open `massdriver.yaml` and fill the `$ref` in by hand with a resource type that is published in
your organization:

```yaml
connections:
  required:
    - network
  properties:
    network:
      $ref: network@0.0.0
```

Then check it before you publish:

```bash
mass bundle lint --bundle-directory bundles/artist-portal
```

## Publish fails with `resourceType Resource type not found`

```
Error: get resource type network@0.0.0: input:3:2: resourceType Resource type not found
```

The resource type named in a `$ref` does not exist in your organization. Either the name is wrong,
or the resource type is defined in this catalog but has never been published.

List what this catalog defines:

```bash
ls resource-types
```

If it is there, create its repository and publish it:

```bash
mass repository create network -t resource-type
```

```bash
mass resource-type publish resource-types/network/massdriver.yaml
```

Cloud credential types — `azure-service-principal`, `kubernetes-cluster`, and the rest — live under
`platforms/` instead, and `make publish-platforms` publishes them all.

## Publish fails on the `connections` and `artifacts` deprecation warnings

```
Warning: the 'connections' field is deprecated; migrate to 'dependencies'. The legacy term does not support versioned resource types
Warning: the 'artifacts' field is deprecated; migrate to 'resources'. The legacy term does not support versioned resource types
```

Every bundle from this template prints these. On their own they are warnings and the publish
succeeds. They only stop the publish when you pass `--fail-warnings`:

```bash
mass bundle publish --development --fail-warnings --bundle-directory bundles/artist-portal
```

To clear them for good, rename `connections:` to `dependencies:` and `artifacts:` to `resources:`
in `massdriver.yaml`, and change each `$ref:` to a versioned `resource_type:` — the versioned form
only works under the new keys.

## The very first publish of a new bundle name fails before it uploads anything

Bundles are published into an OCI repository, and the repository has to exist first. It is not
created for you.

```bash
mass repository create artist-portal -t bundle
```

The command is safe to re-run; it exits non-zero if the repository is already there. Then publish
as normal:

```bash
mass bundle publish --development --bundle-directory bundles/artist-portal
```

## Deploy fails with `Error: No value for required variable`

```
Error: No value for required variable

  on _massdriver_variables.tf line 19:
  19: variable "instance_name" {

The root module input variable "instance_name" is not set, and has no default
value.
```

A required param has no value on this instance. That happens when a new required param is added to
`massdriver.yaml` and an existing instance is redeployed without anyone filling it in — the form
only prompts for it when someone opens it.

Set it and deploy in one step:

```bash
mass instance deploy artists-dev-portal -P '.instance_name = "artist-portal"' -m "set instance_name" -f
```

`--patch` edits the last deployed configuration in place. Use `--params` only when you mean to
replace the whole configuration from a file.

If the missing variable is `md_metadata`, you are running `tofu` by hand in `src/` rather than
through a deployment. Massdriver supplies `md_metadata` at deploy time; there is nothing to fix in
the bundle.

## Deploy fails with `Error: Reference to undeclared input variable`

```
Error: Reference to undeclared input variable

  on main.tf line 20, in resource "null_resource" "example":
  20:     region = var.region

An input variable with the name "region" has not been declared.
```

Every `var.` in `src/` comes from `src/_massdriver_variables.tf`, and that file is generated from
the `params:` block in `massdriver.yaml`. Referencing a variable that is not a param means the
variable does not exist.

Add the param to `massdriver.yaml`, then regenerate and republish:

```bash
mass bundle build --bundle-directory bundles/artist-portal
```

```bash
mass bundle publish --development --bundle-directory bundles/artist-portal
```

Do not add the `variable` block to `_massdriver_variables.tf` by hand. The next build overwrites
that file. If you genuinely need a variable that is not a param, declare it in a separate file such
as `src/variables.tf`, which the build leaves alone.

## `tofu init` locally keeps rewriting `.terraform.lock.hcl`

```
Warning: Dependency lock file entries automatically updated

OpenTofu automatically rewrote some entries in your dependency lock file:
  - registry.terraform.io/hashicorp/null => registry.opentofu.org/hashicorp/null
```

Somebody ran `terraform init` in `src/` and committed the result. The two tools record different
registry addresses for the same provider and each rewrites the other's entries, so the file churns
on every checkout.

The lock file does not belong in a published bundle at all. Delete it before publishing:

```bash
make clean-lock
```

`make clean` removes the rest of the local leftovers — `.terraform` directories, state files and
generated schemas — that would otherwise be packaged into the bundle.

## Deploy fails with `Error acquiring the state lock`

Another process still holds this instance's state lock. A completely blank "Lock Info" block — no
ID, no holder, no timestamp — is normal for this backend and does not mean anything else is wrong.

Look before you touch anything:

```bash
mass deployment list artists-dev-portal --limit 5
```

If the most recent deployment is `RUNNING`, `PENDING` or `APPROVED`, leave it alone. It may
legitimately hold the lock. Wait for a terminal status and redeploy.

If every deployment is terminal and the lock error persists, the usual cause is an `ABORTED`
deployment whose apply had already started. Aborting only changes Massdriver's record of it — the
OpenTofu process keeps running against real infrastructure and holds the lock until it finishes on
its own. Retrying is the first move, and the retry after that process finishes succeeds with
nothing done to the lock directly.

If it is still stuck long after the apply could plausibly have finished:

```bash
mass instance orphan artists-dev-portal
```

That resets the instance to `INITIALIZED`, aborts lingering deployment records so a late worker
will not retry, and clears the lock. It keeps the state files. Only add `--delete-state` if you
also intend to discard the tracked infrastructure, which is irreversible and is never what a lock
problem calls for.

Do not reach for `tofu force-unlock`. The state lives with the deployment, not in your checkout,
and the conflict carries no lock ID to force against.

## Deploy fails with `state snapshot was created by OpenTofu v1.10.0, which is newer than current v1.8.0`

`massdriver.yaml` says `provisioner: opentofu` with no version, so the version can change between
two deploys of the same bundle. OpenTofu writes a version stamp into state and refuses to read a
state file written by a newer version.

Pin the version so this cannot happen again, matching the rest of the catalog:

```yaml
steps:
  - path: src
    provisioner: opentofu:1.10
```

Pin it to the version that wrote the state, not to an older one — a downgrade is not possible
without rewriting the state file. Publish and redeploy after changing it.

## Deploy fails with `Error: ... already exists`

The resource is already in the cloud but not in this bundle's state, usually because an earlier
deploy created it and then failed before recording it. OpenTofu will not adopt an object it did not
create.

The state lives with the deployment, so a local `tofu import` has nothing to write to. Adopt it
with an `import` block instead. Add it to `src/main.tf`:

```hcl
import {
  to = google_storage_bucket.assets
  id = "artist-portal-assets"
}
```

```bash
mass bundle publish --development --bundle-directory bundles/artist-portal
```

```bash
mass instance deploy artists-dev-portal -m "adopt existing bucket" -f
```

Remove the `import` block and publish again once that deploy succeeds. It is only needed for the
one-time recovery.

## Nothing above matches — read the raw provisioner output

The message shown on the canvas is a summary. The full OpenTofu output is in the deployment log:

```bash
mass deployment list artists-dev-portal --limit 5
```

```bash
mass deployment logs 12345678-1234-1234-1234-123456789012
```

Use the deployment id from the first command in the second.
