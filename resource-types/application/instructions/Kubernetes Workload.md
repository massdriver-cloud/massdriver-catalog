# Register a Kubernetes workload as an application

Use this form to register a Deployment, StatefulSet, or other Kubernetes workload that already runs in a cluster — typically one you didn't ship through a Massdriver bundle — so other bundles in the environment can reference it.

You will need [`kubectl`](https://kubernetes.io/docs/tasks/tools/) configured against the cluster the workload lives in.

---

### **Name**

Use the workload's metadata name (and only that — Massdriver's `name` doesn't carry the namespace, keep names disambiguated across environments instead):

```bash
kubectl get deployment -n <namespace> -o name | sed 's|deployment.apps/||'
```

Paste a single workload name (for example `payments-api`) into **Name**.

---

### **Deployment ID** *(optional)*

The image tag or revision is a good stable answer:

```bash
kubectl get deployment <name> -n <ns> \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# or
kubectl get deployment <name> -n <ns> \
  -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
```

Paste the image tag (for example `ghcr.io/acme/payments-api:sha-7a2f3e9b`) or the revision number into **Deployment ID**.

---

### **Service URL** *(optional)*

The address consumers use to reach the workload. For an Ingress-fronted service:

```bash
kubectl get ingress -n <ns> -o jsonpath='{.items[?(@.spec.rules[0].host)].spec.rules[0].host}'
```

Paste `https://<host>` into **Service URL**. For an in-cluster-only service, use the cluster DNS:

```bash
echo "http://<svc-name>.<ns>.svc.cluster.local"
```

---

### **Health Check URL** *(optional)*

If the container declares a readiness or liveness probe with an `httpGet`, use it:

```bash
kubectl get deployment <name> -n <ns> -o json \
  | jq -r '.spec.template.spec.containers[0].readinessProbe.httpGet | "\(.scheme // "http")://<service-url>\(.path)"'
```

Paste the resulting URL (for example `https://payments-api.example.com/health`) into **Health Check URL**.

---

### **Tags** *(optional)*

Lift selected labels from the workload onto Massdriver tags:

```bash
kubectl get deployment <name> -n <ns> \
  -o jsonpath='{.metadata.labels}'
```

Add the ones that identify ownership, tier, or on-call (`team`, `tier`, `owner`, `runbook`). Skip Kubernetes' own bookkeeping labels (`app.kubernetes.io/...`) — they tend to be noise outside the cluster.
