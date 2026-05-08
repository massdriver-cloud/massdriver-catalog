# Compute Helm values from params at deploy time. Output is merged into
# chart/values.yaml before `helm install`.
{
  replicaCount: .params.replicas
}
