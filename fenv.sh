#!/usr/bin/env bash
set -eo pipefail


function print_help {
  cat << 'END'
build.sh is a facade for docker compose. It provides a simple
interface for building and running the fenv container.

FLAGS

  --image  Build the 'build' container image. If --bake is provided,
           builds fenv's image first, then builds the custom image.

  --exec   Execute a command in the 'build' container. All
           arguments after this flag are passed to the container.

  --down   Run 'docker compose down -v' to stop and remove
           containers and volumes.

  --bake FILE
           Path to a custom bake.hcl file. Used with --image to
           build a custom image on top of fenv's base image.

  --compose FILE
           Path to a custom compose.yaml file. Merges with fenv's
           compose.yaml (custom overrides fenv).

  --help   Print this help message.

EXAMPLES

  # Build the fenv image
  ./build.sh --image

  # Build a custom image extending fenv
  ./build.sh --bake ./bake.hcl --image

  # Run a command with custom compose
  ./build.sh --compose ./compose.yaml --exec ./test.sh

  # Tear down the environment
  ./build.sh --down

NOTES

  This script can be called from any directory. The calling
  directory is mounted into the container at /src.

  The FENV_FDB_VER environment variable controls which version of
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

    --bake)
      CUSTOM_BAKE="$2"
      shift 2
      ;;

    --compose)
      CUSTOM_COMPOSE="$2"
      shift 2
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

FENV_FDB_VER="${FENV_FDB_VER:-7.1.61}"
echo "FENV_FDB_VER=${FENV_FDB_VER}"
export FENV_FDB_VER

FENV_DOCKER_TAG="$(./docker_tag.sh)"
echo "FENV_DOCKER_TAG=${FENV_DOCKER_TAG}"
export FENV_DOCKER_TAG

echo "CALLING_DIR=${CALLING_DIR}"
export CALLING_DIR

# Compute docker tag for extended images if fenv is a submodule.
if [[ -f "${CALLING_DIR}/fenv/docker_tag.sh" ]]; then
  FENV_EXT_DOCKER_TAG="$(cd "$CALLING_DIR" && ./fenv/docker_tag.sh)"
  echo "FENV_EXT_DOCKER_TAG=${FENV_EXT_DOCKER_TAG}"
  export FENV_EXT_DOCKER_TAG
fi


# Build the compose file arguments.

COMPOSE_FILES=(-f compose.yaml)
if [[ -n "${CUSTOM_COMPOSE:-}" ]]; then
  # Convert to absolute path if relative.
  if [[ "$CUSTOM_COMPOSE" != /* ]]; then
    CUSTOM_COMPOSE="${CALLING_DIR}/${CUSTOM_COMPOSE}"
  fi
  COMPOSE_FILES+=(-f "$CUSTOM_COMPOSE")
  echo "CUSTOM_COMPOSE=${CUSTOM_COMPOSE}"
fi


# Run the requested commands.

if [[ -n "${DO_IMAGE:-}" ]]; then
  # Always build fenv's base image first.
  (set -x; docker buildx bake -f bake.hcl --load fenv-base)

  # If a custom bake file is provided, build the custom image.
  if [[ -n "${CUSTOM_BAKE:-}" ]]; then
    # Convert to absolute path if relative.
    if [[ "$CUSTOM_BAKE" != /* ]]; then
      CUSTOM_BAKE="${CALLING_DIR}/${CUSTOM_BAKE}"
    fi
    echo "CUSTOM_BAKE=${CUSTOM_BAKE}"
    (set -x; docker buildx bake -f bake.hcl -f "$CUSTOM_BAKE" --set "fenv.context=$CALLING_DIR" --allow=fs.read=.. --load fenv)
  fi
fi

if [[ -n "${DO_EXEC:-}" ]]; then
  (set -x; docker compose "${COMPOSE_FILES[@]}" run --rm -v "${CALLING_DIR}:/src" fenv "${EXEC_ARGS[@]}")
fi

if [[ -n "${DO_DOWN:-}" ]]; then
  (set -x; docker compose "${COMPOSE_FILES[@]}" down -v)
fi
