# Compute Helm values from params + connections at deploy time.
# Output is merged with chart/values.yaml then passed to helm.
# PASSWORDS / TOKENS are deliberately omitted — workloads pull DB credentials
# from AWS Secrets Manager via IRSA at runtime, not from env vars.
{
  replicaCount: .params.replicas,
  appEnv: {
    DB_HOST:               .connections.database.auth.hostname,
    DB_READER_HOST:        (.connections.database.auth.reader_endpoint // .connections.database.auth.hostname),
    DB_PORT:               (.connections.database.auth.port | tostring),
    DB_NAME:               .connections.database.auth.database,
    DB_USER:               .connections.database.auth.username,
    DB_SECRET_ARN:         .connections.database.secret_arn,
    S3_BUCKET:             .connections.bucket.name,
    S3_REGION:             .connections.bucket.region,
    S3_ENDPOINT:           .connections.bucket.endpoint,
    EKS_CLUSTER_NAME:      .connections.eks.name,
    EKS_CLUSTER_REGION:    .connections.eks.region
  }
}
