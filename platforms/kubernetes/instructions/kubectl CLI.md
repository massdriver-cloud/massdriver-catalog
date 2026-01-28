# Connect Your Kubernetes Cluster to Massdriver

To connect your cluster, fill out the **Kube Config** form in Massdriver. You’ll need three values from your kubeconfig or cluster:

---

### 🔐 **Authentication → Cluster → Server**

Run:

```bash
kubectl config view --raw -o jsonpath="{.clusters[0].cluster.server}"
```

Paste the URL (starts with `https://...`) into the **Server** field.

---

### 🔐 **Authentication → Cluster → Certificate Authority Data**

Run:

```bash
kubectl config view --raw -o jsonpath="{.clusters[0].cluster.certificate-authority-data}"
```

Paste the full base64-encoded string into the **Certificate Authority Data** field.

---

### 🔐 **Authentication → User → Token**

If your kubeconfig already includes a token:

```bash
kubectl config view --raw -o jsonpath="{.users[0].user.token}"
```

If it doesn’t, create one:

```bash
kubectl create serviceaccount massdriver
kubectl create clusterrolebinding massdriver-binding --clusterrole=cluster-admin --serviceaccount=default:massdriver
kubectl get secret $(kubectl get sa massdriver -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 -d
```

Paste the token into the **Token** field under **User**.
