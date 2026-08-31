locals {
  # Cloud SQL publishes its instance identifier as "<project>:<region>:<instance>",
  # which is also the exact form the BigQuery connection wants. It carries the
  # region, so the region is read off the instance rather than asked for as a
  # param: BigQuery will only run a federated query when the dataset, the
  # connection, and the Cloud SQL instance are all in one location, and a
  # dropdown that can be set wrong is a dropdown that will be set wrong.
  instance_parts = split(":", var.postgres_cluster.id)
  is_cloud_sql   = length(local.instance_parts) == 3
  location       = local.is_cloud_sql ? local.instance_parts[1] : ""

  # BigQuery dataset IDs take letters, digits, and underscores only, so the
  # hyphens name_prefix is built from have to be rewritten. name_prefix is
  # unique per instance per environment, which is what keeps two environments
  # in the same GCP project from fighting over one dataset name.
  dataset_id = substr(replace("${var.dataset_name}_${var.md_metadata.name_prefix}", "-", "_"), 0, 1024)

  # Named after the dataset it serves. A project can hold many connections, and
  # the only place this name is ever seen is inside a query, where "which
  # dataset does this belong to" is the question being asked.
  connection_id = substr("${local.dataset_id}_postgres", 0, 1024)

  # What an analyst types into EXTERNAL_QUERY. BigQuery accepts the connection
  # in this dotted form, and building it here means nobody has to assemble it
  # by hand out of three fields on the canvas.
  external_query_connection = "${var.gcp_service_account.project_id}.${local.location}.${local.connection_id}"

  # GCP only accepts lowercase letters, digits, `-` and `_` in label keys and
  # values, capped at 63 characters. Massdriver's default tags are not written
  # to that spec, and an out-of-spec label fails the whole apply — so normalize
  # rather than passing them through untouched.
  gcp_labels = {
    for key, value in var.md_metadata.default_tags :
    substr(lower(replace(key, "/[^a-zA-Z0-9_-]/", "_")), 0, 63) => substr(lower(replace(value, "/[^a-zA-Z0-9_-]/", "_")), 0, 63)
  }

  # Republished from the analytics login rather than restated as a param: what
  # this dataset can actually read is whatever that login was granted, so the
  # canvas shows the real answer instead of a hopeful one.
  federated_tables = [
    for t in var.analytics_login.shared_tables : {
      schema = t.schema
      table  = t.table
    }
  ]

  analyst_dataset_role = var.analyst_access == "read_and_save" ? "roles/bigquery.dataEditor" : "roles/bigquery.dataViewer"

  customer_managed_encryption = var.encryption_key != ""
}

# BigQuery itself is on by default in most projects; the Connection API is not,
# and a missing one fails the apply with a 403 rather than anything that names
# the real problem. disable_on_destroy is false so tearing this down never
# switches BigQuery off for anything else in the project.
resource "google_project_service" "bigquery" {
  project            = var.gcp_service_account.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "bigquery_connection" {
  project            = var.gcp_service_account.project_id
  service            = "bigqueryconnection.googleapis.com"
  disable_on_destroy = false
}

# BigQuery encrypts everything it stores either way; this is for organisations
# that have to hold the key themselves. The account that does the encrypting is
# not the one this bundle deploys with — BigQuery has a dedicated service agent
# per project for it, and the key is unusable until that agent can use it.
data "google_bigquery_default_service_account" "encryption" {
  count = local.customer_managed_encryption ? 1 : 0

  project    = var.gcp_service_account.project_id
  depends_on = [google_project_service.bigquery]
}

resource "google_kms_crypto_key_iam_member" "bigquery" {
  count = local.customer_managed_encryption ? 1 : 0

  crypto_key_id = var.encryption_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_bigquery_default_service_account.encryption[0].email}"
}

resource "google_bigquery_dataset" "analytics" {
  project       = var.gcp_service_account.project_id
  dataset_id    = local.dataset_id
  friendly_name = var.dataset_name
  description   = "Managed by Massdriver — ${var.md_metadata.name_prefix}"
  location      = local.location
  labels        = local.gcp_labels

  # Nothing this bundle creates lands in the dataset — a federated query reads
  # the source database directly. This only bites tables an analyst saves here,
  # which is why it is off by default.
  default_table_expiration_ms = var.keep_saved_tables_for_days > 0 ? var.keep_saved_tables_for_days * 86400000 : null

  delete_contents_on_destroy = var.allow_delete_with_contents

  dynamic "default_encryption_configuration" {
    for_each = local.customer_managed_encryption ? [var.encryption_key] : []
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }

  # The key grant has to exist first: a dataset created against a key BigQuery
  # cannot use yet fails outright rather than retrying.
  depends_on = [
    google_project_service.bigquery,
    google_kms_crypto_key_iam_member.bigquery,
  ]

  lifecycle {
    precondition {
      condition     = local.is_cloud_sql
      error_message = "The connected PostgreSQL database does not look like a Cloud SQL instance — its ID is '${var.postgres_cluster.id}' and BigQuery needs the '<project>:<region>:<instance>' form. This bundle federates Cloud SQL specifically. Check what is wired into 'postgres_cluster' on the canvas."
    }
  }
}

resource "google_bigquery_connection" "postgres" {
  project       = var.gcp_service_account.project_id
  connection_id = local.connection_id
  location      = local.location
  friendly_name = "${var.dataset_name} (${var.analytics_login.auth.database})"
  description   = "Reads ${var.analytics_login.auth.database} as ${var.analytics_login.auth.username}. Managed by Massdriver — ${var.md_metadata.name_prefix}."

  cloud_sql {
    instance_id = var.postgres_cluster.id
    database    = var.analytics_login.auth.database
    type        = "POSTGRES"

    # The connection stores this login and every federated query runs as it,
    # whoever pressed run. That is the whole access control story on the
    # database side, and it is why this is the table set's scoped login and
    # not the instance's admin credential.
    credential {
      username = var.analytics_login.auth.username
      password = var.analytics_login.auth.password
    }
  }

  depends_on = [google_project_service.bigquery_connection]

  lifecycle {
    precondition {
      # BigQuery reaches Cloud SQL from outside the platform network, over the
      # instance's public endpoint. `management_hostname` is how the database
      # bundle says that endpoint exists at all — it is null on an instance
      # that is only reachable privately, and no IAM binding or credential
      # will get a query through to one of those.
      condition     = try(length(var.postgres_cluster.management_hostname) > 0, false)
      error_message = "The shared PostgreSQL instance has no address reachable from outside the platform network, so BigQuery cannot open a connection to it. Add an entry to 'iac_authorized_networks' on the gcp-cloud-sql-postgres component and redeploy it — that is what gives the instance a public endpoint. BigQuery does not need an entry of its own; it authenticates as a service account rather than from a fixed address."
    }

    precondition {
      # A table set from a different cluster carries a login that exists in a
      # database this connection will never open. It fails at query time as a
      # password error, hours later, in somebody else's console.
      condition     = var.analytics_login.auth.hostname == var.postgres_cluster.auth.hostname
      error_message = "The analytics login and the database are on different instances — the login points at ${var.analytics_login.auth.hostname} and the instance is ${var.postgres_cluster.auth.hostname}. Wire 'analytics_login' to a pg-schema that sits on the same database as 'postgres_cluster'."
    }
  }
}

# Every BigQuery connection gets its own Google-managed service account, and
# that account — not the credential this bundle deploys with — is what opens the
# Cloud SQL socket. Without this role the connection exists, looks healthy, and
# fails on the first query.
resource "google_project_iam_member" "connection_cloudsql_client" {
  project = var.gcp_service_account.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_bigquery_connection.postgres.cloud_sql[0].service_account_id}"
}

# Running a federated query takes three separate grants, and missing any one of
# them reads as a different error. They are bound together here so that listing
# somebody under "who is allowed to run these queries" is the only step.
resource "google_bigquery_dataset_iam_member" "analyst" {
  for_each = toset(var.analysts)

  project    = var.gcp_service_account.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  role       = local.analyst_dataset_role
  member     = each.value
}

resource "google_bigquery_connection_iam_member" "analyst" {
  for_each = toset(var.analysts)

  project       = var.gcp_service_account.project_id
  location      = google_bigquery_connection.postgres.location
  connection_id = google_bigquery_connection.postgres.connection_id
  role          = "roles/bigquery.connectionUser"
  member        = each.value
}

# Project-scoped because that is the only scope BigQuery offers for it: running
# a query means creating a job, and jobs are billed to the project rather than
# to a dataset. It carries no read access on its own — a person with this and
# nothing else can start a query and read nothing.
resource "google_project_iam_member" "analyst_job_user" {
  for_each = toset(var.analysts)

  project = var.gcp_service_account.project_id
  role    = "roles/bigquery.jobUser"
  member  = each.value
}
