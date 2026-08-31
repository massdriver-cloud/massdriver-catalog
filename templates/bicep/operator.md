# {{ name }} runbook

## Publish fails with `get resource type azure-service-principal: resourceType Resource type not found`

```
Error: get resource type azure-service-principal: input:3:2: resourceType Resource type not found
```

Every bundle from this template requires an `azure_authentication` connection, and that connection
points at the `azure-service-principal` resource type. The type is defined in this repository, but
a fresh organization does not have it until somebody publishes it.

```bash
mass repository create azure-service-principal -t resource-type
```

```bash
mass resource-type publish platforms/azure/massdriver.yaml
```

Or publish all the credential types this catalog defines at once:

```bash
make publish-platforms
```

This blocks `mass bundle build` and `mass bundle lint` too, not just publish — none of them can
resolve the connection until the type exists.

## Publish fails with `at '/connections/properties/<name>/$ref': got null, want string`

```
Error: bundle failed schema validation:
  - jsonschema validation failed with 'https://api.massdriver.cloud/json-schemas/bundle.json#'
- at '/connections': 'allOf' failed
  - at '/connections/properties/network/$ref': got null, want string
```

The bundle was scaffolded with `mass bundle new -c network=...`. The template writes the connection
name but leaves its `$ref` empty. Fill it in by hand in `massdriver.yaml` with a resource type that
is published in your organization, then check it:

```bash
mass bundle lint --bundle-directory bundles/artist-portal
```

The `azure_authentication` connection is not affected — it is written into the template directly
and always has a `$ref`.

## Deploy fails with `The subscription is not registered to use namespace 'Microsoft.Storage'`

```
Code: MissingSubscriptionRegistration
Message: The subscription is not registered to use namespace 'Microsoft.Storage'.
See https://aka.ms/rps-not-found for how to register subscriptions.
```

Azure gates each service behind a resource provider that has to be registered per subscription.
A subscription that has never created a storage account has never registered `Microsoft.Storage`.
This is a one-time action per subscription, not per bundle or per environment.

Sign in as the service principal from the environment's Azure Service Principal credential, then
register the namespace the error names:

```bash
az account set --subscription 8f2c1d3a-5b47-4e19-9c60-1a2b3c4d5e6f
```

```bash
az provider register --namespace Microsoft.Storage --wait
```

```bash
az provider show --namespace Microsoft.Storage --query registrationState -o tsv
```

Wait for `Registered` before redeploying. Registration can take several minutes and the deploy will
keep failing the same way until it finishes.

If the register command itself is refused, the service principal has no rights to register
providers on the subscription. Ask whoever owns the subscription to run it once; the bundle does
not need that permission afterwards.

## Deploy fails with `Operation could not be completed as it results in exceeding approved quota`

```
Code: QuotaExceeded
Message: Operation could not be completed as it results in exceeding approved standardDSv3Family
Cores quota. Additional details - Location: eastus, Current Limit: 10, Current Usage: 10,
Additional Required: 4, (Minimum) New Limit Required: 14.
```

Quota is per subscription, per region, per family. The message tells you which of the three is
short. Confirm the current picture:

```bash
az vm list-usage --location eastus -o table
```

Three ways out, in order of how fast they work:

- Lower `instance_count` on this instance and redeploy. Immediate.
- Deploy into a different region by changing `location`. Quota in `eastus2` is separate from
  `eastus`.
- Request an increase from Azure. That is a support ticket and takes time, so do not wait on it if
  a demo or a deadline is close.

## Deploy fails with `AuthorizationFailed`

```
Code: AuthorizationFailed
Message: The client '123xyz99-ab34-56cd-e7f8-456abc1q2w3e' with object id '...' does not have
authorization to perform action 'Microsoft.Storage/storageAccounts/write' over scope
'/subscriptions/8f2c1d3a-5b47-4e19-9c60-1a2b3c4d5e6f/resourceGroups/artists-dev'.
```

The service principal is authenticating correctly and is simply not allowed to do this. It is a
role assignment problem, not a credential problem — rotating the client secret will not help.

See what it does have:

```bash
az role assignment list --assignee 123xyz99-ab34-56cd-e7f8-456abc1q2w3e --all -o table
```

The action named in the message tells you which role is missing. `Contributor` on the subscription
covers everything these bundles do; a narrower role is fine as long as it grants that action at
that scope.

## Deploy fails with `The template parameters 'tags, advanced' in the parameters file are not valid`

```
Code: InvalidTemplate
Message: Deployment template validation failed: The template parameters 'tags, advanced' in the
parameters file are not valid; they are not present in the original template and can therefore
not be provided.
```

Params flow from `massdriver.yaml` into the Bicep deployment, and ARM rejects any parameter the
compiled template does not declare. The names have to match on both sides.

As shipped, this template has that mismatch already: `massdriver.yaml` declares `tags` and
`advanced`, and `src/template.bicep` has no `param` for either. Add matching declarations:

```bicep
@description('Tags to apply to resources')
param tags array = []
```

or delete those params from `massdriver.yaml`. Either fixes it; leaving them out of sync does not.

Compile locally to see exactly which parameters the template really has:

```bash
az bicep build --file bundles/artist-portal/src/template.bicep --stdout
```

## `az bicep build` warns `Parameter "md_metadata" is declared but never used`

```
Warning no-unused-params: Parameter "md_metadata" is declared but never used.
[https://aka.ms/bicep/linter-diagnostics#no-unused-params]
```

This is a warning, not a failure, and a freshly scaffolded bundle always prints it. It is still
worth fixing, because `md_metadata` is how Massdriver's own tags reach your resources. Without it,
nothing you create is tagged with the environment, project or target, and cost reporting and
cleanup scripts cannot see it.

Use it on every resource you declare:

```bicep
tags: md_metadata.default_tags
```

`md_metadata.name_prefix` is also there, and is the safe way to build resource names that stay
unique across environments.

## You deleted a resource from `src/template.bicep` and it is still in Azure

This is how ARM works and not a bug. Deployments run in incremental mode: ARM creates and updates
what the template describes and leaves everything else alone. There is no state file recording that
this bundle once created the resource, so nothing knows to remove it.

Delete it deliberately:

```bash
az resource delete --resource-group artists-dev --name artistportalassets --resource-type Microsoft.Storage/storageAccounts
```

Decommissioning the Massdriver instance has the same limitation for anything already orphaned this
way, so clean up as you go rather than at the end.

## Nothing above matches — read the raw Azure error

The message on the canvas is a summary, and ARM's real error is usually nested several levels down
inside it. The full text is in the deployment log:

```bash
mass deployment list artists-dev-portal --limit 5
```

```bash
mass deployment logs 12345678-1234-1234-1234-123456789012
```

Use the deployment id from the first command in the second. Look for the innermost `code` and
`message` pair — the outer ones are almost always a generic `DeploymentFailed`.
