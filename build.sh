#!/usr/bin/env bash
set -eo pipefail


function print_help {
  cat << 'END'
build.sh is a facade for docker compose. It provides a simple
interface for building and running the fenv container.

FLAGS

  --image  Build the 'build' container image.

  --exec   Execute a command in the 'build' container. All
           arguments after this flag are passed to the container.

  --down   Run 'docker compose down -v' to stop and remove
           containers and volumes.

  --help   Print this help message.

EXAMPLES

  # Build the image
  ./build.sh --image

  # Run fdbcli in the container
  ./build.sh --exec fdbcli --exec "status"

  # Run a shell in the container
  ./build.sh --exec bash

  # Tear down the environment
  ./build.sh --down

NOTES

  This script can be called from any directory. The calling
  directory is mounted into the container at /src. 

  The FDB_VER environment variable controls which version of
  FoundationDB is used. It defaults to 7.1.61.
END
}


# fail prints $1 to stderr and exits with code 1.

function fail {
  local RED='\033[0;31m' NO_COLOR='\033[0m'
  echo -e "${RED}ERR! ${1}${NO_COLOR}" >&2
  exit 1
}


# Store the calling directory before changing to script directory.

CALLING_DIR="$(pwd)"

# Change directory to the script's location (repo root).

SCRIPT_DIR="$(cd "${0%/*}" && pwd)"
cd "$SCRIPT_DIR"


# Parse the flags.

if [[ $# -eq 0 ]]; then
  print_help
  echo
  fail "At least one flag must be provided."
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --image)
      DO_IMAGE="x"
      shift 1
      ;;

    --exec)
      DO_EXEC="x"
      shift 1
      EXEC_ARGS=("$@")
      shift $#
      ;;

    --down)
      DO_DOWN="x"
      shift 1
      ;;

    --help)
      print_help
      exit 0
      ;;

    *)
      fail "Invalid flag '$1'"
  esac
done


# Build variables required by docker commands.

DOCKER_TAG="$(./docker_tag.sh)"
echo "DOCKER_TAG=${DOCKER_TAG}"
export DOCKER_TAG

FDB_VER="${FDB_VER:-7.1.61}"
echo "FDB_VER=${FDB_VER}"
export FDB_VER

echo "CALLING_DIR=${CALLING_DIR}"


# Run the requested commands.

if [[ -n "${DO_IMAGE:-}" ]]; then
  (set -x; docker buildx bake -f bake.hcl --load build)
fi

if [[ -n "${DO_EXEC:-}" ]]; then
  (set -x; docker compose run --rm -v "${CALLING_DIR}:/src" build "${EXEC_ARGS[@]}")
fi

if [[ -n "${DO_DOWN:-}" ]]; then
  (set -x; docker compose down -v)
fi
