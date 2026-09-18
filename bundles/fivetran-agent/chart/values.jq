# The provisioner runs this filter and sends the result to Helm as values.
{
  replicaCount: .params.replicas,

  resources: {
    limits: {
      cpu: .params.cpu_limit,
      memory: .params.memory_limit
    },
    requests: {
      cpu: "250m",
      memory: "512Mi"
    }
  },

  # The agent reads the token from a secret. Massdriver holds the token, and it
  # never writes the value into the chart.
  agent: {
    tokenSecretName: (.md.package.name + "-token")
  }
}
