# Compute Helm values from params + connections.
# This file is rendered with jq before `helm install/upgrade`.
{
  replicaCount: .params.replicas,
  image: .params.image,
  ingress: {
    enabled: true,
    host: .params.domain_name
  },
  app: {
    logLevel: .params.log_level
  },
  database: {
    host: .connections.database.auth.hostname,
    readerHost: (.connections.database.auth.reader_endpoint // .connections.database.auth.hostname),
    port: .connections.database.auth.port,
    name: .connections.database.auth.database,
    user: .connections.database.auth.username,
    secretArn: .connections.database.secret_arn,
    iamAuthEnabled: .connections.database.iam_auth_enabled
  },
  storage: {
    bucket: .connections.bucket.name,
    region: .connections.bucket.region,
    endpoint: .connections.bucket.endpoint,
    kmsKeyArn: (.connections.bucket.kms_key_arn // null),
    prefix: .params.upload_prefix
  },
  cluster: {
    name: .connections.cluster.name,
    region: .connections.cluster.region,
    oidcProviderArn: .connections.cluster.oidc.provider_arn
  }
}
