# WordPress on Kubernetes

WordPress deployed with the Bitnami Helm chart onto a Kubernetes cluster you link on the canvas, backed by a MySQL-compatible database you also link on the canvas. This is the "off-the-shelf app" bundle: DevOps publishes it once, and anyone — including the marketing team — can deploy a site by drawing two lines and filling in a short form.

## What it shows

- **Composing published infrastructure** — this bundle provisions no cloud infrastructure of its own. It consumes the `kubernetes-cluster` and `mysql-database` resources produced by other bundles in this catalog, so a non-engineer deploys a working site without touching credentials, YAML, or kubectl.
- **The `app:` block** — `app.envs` lifts connection data into the app's runtime environment with JQ expressions (`WORDPRESS_DATABASE_HOST` from `.connections.database.auth.hostname`, and so on). `app.secrets` declares `WORDPRESS_ADMIN_PASSWORD` as **required**, so the platform blocks deploys to an environment until someone sets it — no more "we forgot the prod secret" incidents. `WORDPRESS_SMTP_PASSWORD` is optional, for outgoing mail.
- **`$md.enum` policy picker** — `database_policy` is a dropdown populated from the linked database's `policies` list. The app declares the access level it wants (pick read-write); the selection is stamped on the Kubernetes namespace as an annotation so platform tooling can see what each workload requested.
- **Self-service guardrails** — Marketing Site / Development presets, an immutable `admin_username` with a friendly validation message, and a `replicas` field capped at 5 with help text explaining the ReadWriteMany storage requirement.

## What it produces

An `application` resource: `id` (`namespace/release`), `url` (only when `service_type` is `LoadBalancer` and the cloud load balancer has an address — never a placeholder), and `health_path` (`/wp-login.php`).

## Two passwords, on purpose

The `WORDPRESS_ADMIN_PASSWORD` app secret is what gates deploys in the UI and gets injected into the app's runtime environment. App secrets never pass through Terraform, so the password the Helm chart seeds WordPress with is a separate, Terraform-generated random password. To log in with your own password, set the app secret and reset the seeded one — the operator guide has the one-liner.

## Notes

- No alarms ship with this bundle: pod- and container-level metrics on EKS need Container Insights (or a Prometheus stack) on the cluster, which is the cluster bundle's concern, not this one's.
- `service_type: LoadBalancer` creates a cloud load balancer (~$16–25/mo on AWS). `ClusterIP` is free but internal-only.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
