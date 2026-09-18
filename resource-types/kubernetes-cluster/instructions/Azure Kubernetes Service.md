# Import an Azure Kubernetes Service Cluster

```bash
az aks show --name <CLUSTER> --resource-group <GROUP> \
  --query "{id:id, name:name, region:location, version:kubernetesVersion}"
az aks get-credentials --name <CLUSTER> --resource-group <GROUP> --admin --file -
```

| Field | Source |
|---|---|
| `authentication.host` | The `server` value in the kubeconfig. |
| `authentication.cluster_ca_certificate` | The `certificate-authority-data` value. |
| `authentication.client_certificate` | The `client-certificate-data` value. |
| `authentication.client_key` | The `client-key-data` value. |

## Warning

The admin kubeconfig grants full rights on the cluster. Do not paste it into a
chat or a ticket. Massdriver masks these fields, and it records every download.
