locals {
  # Each entry is "schema.table". Split once here so nothing downstream has to
  # parse it again, and tag it with the access it was listed under.
  granted = merge(
    { for t in var.read : t => { schema = split(".", t)[0], table = split(".", t)[1], access = "read" } },
    { for t in var.read_write : t => { schema = split(".", t)[0], table = split(".", t)[1], access = "read_write" } },
  )

  # Reaching a table takes two grants: USAGE on its schema, then the privileges on
  # the table itself. Deduplicated because granting USAGE twice is an error.
  source_schemas = toset([for t in local.granted : t.schema])

  read_privileges       = ["SELECT"]
  read_write_privileges = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "random_password" "login" {
  length  = 32
  special = false
}

resource "postgresql_role" "login" {
  name     = var.login_name
  login    = true
  password = random_password.login.result

  # No CREATEDB, no CREATEROLE, not a superuser, and no schema of its own. This login
  # exists to reach the tables listed below and has no way to make itself anything more.
  create_database = false
  create_role     = false
  superuser       = false
  inherit         = true
}

resource "postgresql_grant" "schema_usage" {
  for_each = local.source_schemas

  database    = var.postgres_cluster.auth.database
  role        = postgresql_role.login.name
  schema      = each.value
  object_type = "schema"
  privileges  = ["USAGE"]
}

# One grant per named table. Nothing grants on a whole schema, so a table added to
# that schema later is unreachable until somebody puts it on the list on purpose.
resource "postgresql_grant" "table" {
  for_each = local.granted

  database    = var.postgres_cluster.auth.database
  role        = postgresql_role.login.name
  schema      = each.value.schema
  object_type = "table"
  objects     = [each.value.table]
  privileges  = each.value.access == "read_write" ? local.read_write_privileges : local.read_privileges

  depends_on = [postgresql_grant.schema_usage]
}
