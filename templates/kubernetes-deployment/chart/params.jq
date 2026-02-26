# Transform massdriver params to helm values
# https://docs.massdriver.cloud/provisioners/helm
{
  image: .params.image,
  replicas: .params.replicas,
  port: .params.port,
  resources: .params.resources,
  env: .params.env
}
