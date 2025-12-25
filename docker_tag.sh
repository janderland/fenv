#!/usr/bin/env bash
set -eo pipefail

# docker_tag.sh outputs the Docker image tag based on
# the git version and FDB version. This script is used
# by build scripts and CI workflows to ensure consistent tags.
#
# Environment variables:
#   FDB_VER - FDB version (defaults to 7.1.61)

function code_version {
  git rev-parse --short HEAD
}

function fdb_version {
  echo "${FDB_VER:-7.1.61}"
}

echo "$(code_version)_fdb.$(fdb_version)"
