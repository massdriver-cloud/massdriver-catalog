#!/bin/sh
set -e

# Cloud Run hands the port to listen on in PORT. pgAdmin reads its own variable.
export PGADMIN_LISTEN_PORT="${PORT:-8080}"

DATA_DIR="${PGADMIN_DATA_DIR:-/var/lib/pgadmin}"
mkdir -p "$DATA_DIR/storage"

# The server list. pgAdmin imports this once into its config database, so the
# instance is already there when you sign in instead of being typed in by hand.
cat > "$DATA_DIR/servers.json" <<JSON
{
  "Servers": {
    "1": {
      "Name": "${MD_DB_LABEL:-Shared Database}",
      "Group": "MusiCorp",
      "Host": "${DATABASE_HOST}",
      "Port": ${DATABASE_PORT:-5432},
      "MaintenanceDB": "${DATABASE_NAME}",
      "Username": "${DATABASE_USER}",
      "SSLMode": "require",
      "PassFile": "/pgpass",
      "Comment": "Every citizen app's schema lives in here."
    }
  }
}
JSON

# A passfile rather than a password in the server definition: pgAdmin refuses to
# store one there, and this keeps it out of the config database too. 0600 is not
# optional — libpq ignores the file otherwise.
printf '%s:%s:*:%s:%s\n' \
  "${DATABASE_HOST}" "${DATABASE_PORT:-5432}" "${DATABASE_USER}" "${DATABASE_PASSWORD}" \
  > "$DATA_DIR/pgpass"
chmod 600 "$DATA_DIR/pgpass"

export PGADMIN_SERVER_JSON_FILE="$DATA_DIR/servers.json"

exec /entrypoint.sh
