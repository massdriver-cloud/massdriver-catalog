locals {
  # One schema per app, named after the app. Schema-per-app rather than
  # database-per-app is what makes controlled sharing possible at all —
  # PostgreSQL cannot grant across databases, so two apps that may ever need to
  # read each other's data have to live in the same one.
  schema = var.app_name
  role   = "${var.app_name}_app"

  # Deduplicated list of the schemas this app reads from. USAGE on the schema is
  # a prerequisite for any table grant inside it, and granting it twice is an error.
  source_schemas = toset([for t in var.shared_tables : t.schema])

  shared_by_key = { for t in var.shared_tables : "${t.schema}.${t.table}" => t }

  read_privileges       = ["SELECT"]
  read_write_privileges = ["SELECT", "INSERT", "UPDATE", "DELETE"]
}

resource "random_password" "app" {
  length  = 32
  special = false
}

resource "postgresql_role" "app" {
  name     = local.role
  login    = true
  password = random_password.app.result

  # No CREATEDB and no CREATEROLE. The app can do anything it likes inside its own
  # schema and nothing at all outside it.
  create_database = false
  create_role     = false
  superuser       = false
  inherit         = true
}

resource "postgresql_schema" "app" {
  name  = local.schema
  owner = postgresql_role.app.name

  # Owning the schema is what gives the app full control of its own tables without
  # any per-table grant. Everything it creates here belongs to it from the start,
  # so no policy block is needed — and the one this resource offers is deprecated.
}

# Reading another app's data takes two grants: USAGE on their schema, then the
# privileges on the specific table. Both are declared here, so the sharing graph
# is visible on the canvas instead of living in somebody's migration script.
resource "postgresql_grant" "source_schema_usage" {
  for_each = local.source_schemas

  database    = var.postgres_cluster.auth.database
  role        = postgresql_role.app.name
  schema      = each.value
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "shared_table" {
  for_each = local.shared_by_key

  database    = var.postgres_cluster.auth.database
  role        = postgresql_role.app.name
  schema      = each.value.schema
  object_type = "table"
  objects     = [each.value.table]
  privileges  = each.value.access == "read_write" ? local.read_write_privileges : local.read_privileges

  depends_on = [postgresql_grant.source_schema_usage]
}
