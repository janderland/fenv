#!/usr/bin/env bash
set -euo pipefail

# shim.sh configures the FoundationDB cluster file and
# initializes the database before running a command.
#
# Environment variables:
#   FDB_HOSTNAME       - Hostname of the FDB container (default: fdb)
#   FDB_DESCRIPTION_ID - Cluster description:id (default: docker:docker)
#
# Usage: ./shim.sh <command> [args...]

FDB_HOSTNAME=${FDB_HOSTNAME:-fdb}
FDB_DESCRIPTION_ID=${FDB_DESCRIPTION_ID:-docker:docker}

# Obtain the IP for FDB from the given hostname.
FDB_IP=$(getent hosts "$FDB_HOSTNAME" | awk '{print $1}')

# Create the FDB cluster file.
export FDB_CLUSTER_FILE="/etc/foundationdb/fdb.cluster"
echo "${FDB_DESCRIPTION_ID}@${FDB_IP}:4500" > "$FDB_CLUSTER_FILE"
echo "FDB_CLUSTER_FILE: $(cat "$FDB_CLUSTER_FILE")"

# Check if the database needs initialization by looking for
# the "unreadable_configuration" message in the cluster status.
STATUS_JSON=$(fdbcli --exec 'status json')
UNREADABLE=$(echo "$STATUS_JSON" | jp "cluster.messages[?contains(name, 'unreadable_configuration')]")

# If the result is non-empty, the database needs initialization.
if [[ "$UNREADABLE" != "[]" && "$UNREADABLE" != "null" && -n "$UNREADABLE" ]]; then
  echo "Initializing new database..."
  fdbcli --exec "configure new single memory"
fi

echo

exec "$@"
