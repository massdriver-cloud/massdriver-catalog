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

  # The token comes from the Fivetran account credential. One record serves
  # every environment, and the platform team rotates it in one place.
  agent: {
    token: .connections.fivetran_account.agent_token,
    groupId: (.connections.fivetran_account.group_id // "")
  }
}
