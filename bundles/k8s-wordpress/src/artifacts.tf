# The `application` schema allows `url` to be absent, so it is only included
# when a load balancer address is actually known — never a placeholder.
resource "massdriver_resource" "app" {
  field = "app"
  name  = "WordPress ${var.md_metadata.name_prefix}"

  resource = jsonencode(merge(
    {
      id          = "${kubernetes_namespace.main.metadata[0].name}/${helm_release.wordpress.name}"
      health_path = "/wp-login.php"
    },
    local.url != null ? { url = local.url } : {}
  ))
}
