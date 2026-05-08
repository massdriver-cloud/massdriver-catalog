# Compute Helm values from params + connections.
{
  replicaCount: .params.replicas,
  image: .params.image,
  ingress: {
    enabled: true,
    host: .params.domain_name
  }
}
+ (if .connections.database then {
    database: {
      host: .connections.database.auth.hostname,
      readerHost: (.connections.database.auth.reader_endpoint // .connections.database.auth.hostname),
      port: .connections.database.auth.port,
      name: .connections.database.auth.database,
      user: .connections.database.auth.username,
      secretArn: .connections.database.secret_arn
    }
  } else {} end)
+ (if .connections.bucket then {
    storage: {
      bucket: .connections.bucket.name,
      region: .connections.bucket.region,
      kmsKeyArn: (.connections.bucket.kms_key_arn // null)
    }
  } else {} end)
+ (if .connections.kubernetes_cluster then {
    cluster: {
      name: .connections.kubernetes_cluster.name,
      region: .connections.kubernetes_cluster.region,
      oidcProviderArn: .connections.kubernetes_cluster.oidc.provider_arn
    }
  } else {} end)
