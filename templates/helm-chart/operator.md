# {{ name }} runbook

## Deploy fails with `chart "nginx" version "15.0.0" not found in ... repository`

```
Error: chart "nginx" version "15.0.0" not found in https://charts.bitnami.com/bitnami repository
```

The repository is reachable and the chart exists, but not at that version. Either the version was
mistyped, or the repository stopped publishing it — chart repositories prune old releases, and a
version that installed fine last month can disappear.

List what the repository still publishes:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

```bash
helm repo update bitnami
```

```bash
helm search repo bitnami/nginx --versions
```

Then set `chart.version` to a version that is in that list and redeploy:

```bash
mass instance deploy artists-dev-portal -P '.chart.version = "25.1.5"' -m "15.0.0 no longer published" -f
```

Do not fix this by clearing `chart.version`. An empty version installs whatever is newest at that
moment, which is how two instances of the same bundle end up running two different things.

## Deploy fails with `chart "nginx-bogus" not found in ... repository`

```
Error: chart "nginx-bogus" not found in https://charts.bitnami.com/bitnami repository
```

The repository answered, and it has no chart by that name. The chart name is the short name inside
the repository — `nginx`, not `bitnami/nginx` and not a URL. Check the spelling against the
repository's own index:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

```bash
helm search repo bitnami/ | head -20
```

## Deploy fails with `is not a valid chart repository or cannot be reached`

```
Error: looks like "https://charts.example.invalid/bitnami" is not a valid chart repository or
cannot be reached: Get "https://charts.example.invalid/bitnami/index.yaml": dial tcp: lookup
charts.example.invalid: no such host
```

Nothing answered at that URL. Read the tail of the message to tell the two causes apart:

- **`no such host` or a connection refused** — the URL is wrong, or the repository has moved.
  Confirm the exact `index.yaml` the error names loads in a browser.
- **a 401 or 403** — the repository is private. This bundle has no place to put registry
  credentials, so a private repository needs either a different bundle shape or the chart vendored
  into `chart/`.

Reproduce it locally before changing anything; if `helm` can reach it from your machine and the
deploy cannot, the problem is egress from wherever the provisioner runs, not the URL.

## Publish fails with `get resource type kubernetes-cluster: resourceType Resource type not found`

```
Error: get resource type kubernetes-cluster: input:3:2: resourceType Resource type not found
```

Every bundle from this template requires a `kubernetes_cluster` connection. That resource type is
defined in this repository, under `platforms/kubernetes/`, but a fresh organization does not have
it until somebody publishes it.

```bash
mass repository create kubernetes-cluster -t resource-type
```

```bash
mass resource-type publish platforms/kubernetes/massdriver.yaml
```

Or publish all the credential types this catalog defines at once:

```bash
make publish-platforms
```

This blocks `mass bundle lint` and `mass bundle build` too, not just publish.

## Deploy fails with `Kubernetes cluster unreachable`

```
Error: Kubernetes cluster unreachable: Get "https://34.72.10.4/version": dial tcp 34.72.10.4:443:
i/o timeout
```

The chart never got as far as being installed. The connected `kubernetes_cluster` credential has an
API server address, a CA certificate and a bearer token, and one of them is no longer good.

- **Timeout** — the API server is not reachable from wherever the provisioner runs. A cluster with
  a private endpoint, or one whose authorized-networks list does not include the provisioner's
  egress address, will always fail this way. Retrying does not help.
- **`Unauthorized`** — the bearer token has expired or been revoked. Tokens do not renew
  themselves. Update the credential in Massdriver and redeploy.
- **`x509: certificate signed by unknown authority`** — the cluster was rebuilt and its CA changed,
  so the stored certificate belongs to a cluster that no longer exists.

To check the same thing by hand, download the kubeconfig from the environment's Kubernetes Cluster
credential in Massdriver — it has a "Kube Config" download button — and use it:

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml kubectl get nodes
```

## Deploy fails with `another operation (install/upgrade/rollback) is in progress`

```
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress
```

A previous release operation never reached a terminal state. Helm records the release as
`pending-install`, `pending-upgrade` or `pending-rollback` and refuses to start another one.
Usually the earlier deploy was killed partway through rather than failing cleanly.

Look at the release before touching it:

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml helm status artists-dev-portal -n artists-dev
```

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml helm history artists-dev-portal -n artists-dev
```

- **Stuck on `pending-upgrade`, with an earlier `deployed` revision in the history** — roll back to
  that revision. The release returns to a terminal state and the next Massdriver deploy proceeds
  normally:
  ```bash
  KUBECONFIG=~/Downloads/kubeconfig.yaml helm rollback artists-dev-portal 3 -n artists-dev
  ```
- **Stuck on `pending-install`, with no successful revision in the history** — there is nothing to
  roll back to. Remove the failed release and let Massdriver install it again:
  ```bash
  KUBECONFIG=~/Downloads/kubeconfig.yaml helm uninstall artists-dev-portal -n artists-dev
  ```

A `helm rollback` you run by hand is only a way to unstick the release. The next Massdriver deploy
overwrites it with whatever the instance settings say, so change the settings as well if the old
version is the one you want to keep.

## Deploy fails with `timed out waiting for the condition` and the release is gone afterwards

```
Error: release artists-dev-portal failed, and has been uninstalled due to atomic being set:
timed out waiting for the condition
```

Helm installed the chart, waited for its pods to become ready, gave up, and removed everything it
had created. The chart is fine; something inside it never started. Because the rollback already
happened, there is nothing left to inspect after the fact — you have to watch while it runs.

Start the deploy without following it, then watch the namespace:

```bash
mass instance deploy artists-dev-portal -m "retry, watching pods"
```

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml kubectl get pods -n artists-dev -w
```

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml kubectl get events -n artists-dev --sort-by=.lastTimestamp
```

What the pod status tells you:

- **`ImagePullBackOff` / `ErrImagePull`** — the cluster cannot pull the chart's image. A private
  registry needs an image pull secret, set through the chart's own values in `chart/values.yaml`.
- **`Pending`, never scheduled** — no node has room, or the chart asks for a storage class this
  cluster does not have. The events list names which.
- **`CrashLoopBackOff`** — the container starts and exits. Missing required configuration is the
  usual cause; the values you set in `chart/values.yaml` are the place to fix it.
- **`Running` but never `Ready`** — the readiness probe is failing. If the app is simply slow to
  start, the chart's own probe settings are what to raise, not the deploy.

## Deploy fails with `cannot re-use a name that is still in use`

```
Error: INSTALLATION FAILED: cannot re-use a name that is still in use
```

A Helm release named `artists-dev-portal` already exists in that namespace, and it was not created
by this instance. The release name comes from the Massdriver instance name, so this means someone
installed the chart by hand first, or an earlier instance with the same name was decommissioned in
Massdriver without its release being removed from the cluster.

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml helm list -n artists-dev
```

If the existing release is genuinely the same workload and nobody depends on its history, remove it
and let Massdriver install it cleanly:

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml helm uninstall artists-dev-portal -n artists-dev
```

That deletes the running workload. If it is serving traffic, do it in a maintenance window — the
new install starts from nothing.

## The chart installed, but a value you set in `chart/values.yaml` had no effect

Values are merged over the chart's own defaults by key path, and a key path the chart does not use
is silently ignored. Nothing warns you about a typo.

Compare what the release actually received against what the chart expects:

```bash
KUBECONFIG=~/Downloads/kubeconfig.yaml helm get values artists-dev-portal -n artists-dev
```

```bash
helm show values nginx --repo https://charts.bitnami.com/bitnami --version 15.0.0
```

The second command prints the chart's full default values. Your key has to sit at the same path,
spelled the same way. This is the single most common cause of "the deploy succeeded and nothing
changed", and it bites hardest right after a chart version upgrade, when a chart renames a value.

## Nothing above matches — read the raw Helm output

The message on the canvas is a summary. The full Helm output is in the deployment log:

```bash
mass deployment list artists-dev-portal --limit 5
```

```bash
mass deployment logs 12345678-1234-1234-1234-123456789012
```

Use the deployment id from the first command in the second.
