#!/usr/bin/env bash
set -eo pipefail


function print_help {
  cat << 'END'
build.sh is a facade for docker compose. It provides a simple
interface for building and running the fenv container.

FLAGS

  --build  Build the 'build' container image. If --docker is provided,
           builds fenv's image first, then builds the extended image.

  --exec   Execute a command in the 'build' container. All
           arguments after this flag are passed to the container.

  --down   Run 'docker compose down -v' to stop and remove
           containers and volumes.

  --docker FILE
           Path to a custom Dockerfile. Used with --build to
           build an extended image on top of fenv's base image.

  --help   Print this help message.

EXAMPLES

  # Build the fenv image
  ./build.sh --build

  # Build an extended image on top of fenv
  ./build.sh --docker ./docker/Dockerfile --build

  # Run a command in the container
  ./build.sh --exec ./test.sh

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
    --build)
      DO_BUILD="x"
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

    --docker)
      EXT_DOCKERFILE="$2"
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


# derive_project_name determines a unique name for the project.
# It uses FENV_PROJECT_NAME if set, otherwise derives from git remote
# URL or directory name as a fallback.

function derive_project_name {
  # Use explicit project name if provided
  if [[ -n "${FENV_PROJECT_NAME:-}" ]]; then
    echo "${FENV_PROJECT_NAME}"
    return
  fi

  # Try to derive from git remote URL
  if git -C "${CALLING_DIR}" remote get-url origin &>/dev/null; then
    local remote_url
    remote_url="$(git -C "${CALLING_DIR}" remote get-url origin)"
    # Extract repo name from URL (handles both https and ssh formats)
    # e.g., https://github.com/user/repo.git -> repo
    # e.g., git@github.com:user/repo.git -> repo
    local repo_name
    repo_name="$(basename "${remote_url}" .git)"
    echo "${repo_name}"
    return
  fi

  # Fallback to directory name
  basename "${CALLING_DIR}"
}


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

# Derive project name for namespacing extended images
FENV_PROJECT_NAME="$(derive_project_name)"
echo "FENV_PROJECT_NAME=${FENV_PROJECT_NAME}"
export FENV_PROJECT_NAME

# Select which image to use for compose based on whether --docker was provided.
if [[ -n "${EXT_DOCKERFILE:-}" ]]; then
  FENV_IMAGE="fenv-ext-${FENV_PROJECT_NAME}:${FENV_EXT_DOCKER_TAG}"
else
  FENV_IMAGE="fenv:${FENV_DOCKER_TAG}"
fi
echo "FENV_IMAGE=${FENV_IMAGE}"
export FENV_IMAGE


# Run the requested commands.

if [[ -n "${DO_BUILD:-}" ]]; then
  # Always build fenv's base image first.
  (set -x; docker build \
    --platform linux/amd64 \
    --build-arg "FENV_FDB_VER=${FENV_FDB_VER}" \
    --tag "fenv:${FENV_DOCKER_TAG}" \
    "${SCRIPT_DIR}")

  # If an extended Dockerfile is provided, build the extended image.
  if [[ -n "${EXT_DOCKERFILE:-}" ]]; then
    # Convert to absolute path if relative.
    if [[ "$EXT_DOCKERFILE" != /* ]]; then
      EXT_DOCKERFILE="${CALLING_DIR}/${EXT_DOCKERFILE}"
    fi
    echo "EXT_DOCKERFILE=${EXT_DOCKERFILE}"

    # Build extended image from the calling directory context.
    (set -x; docker build \
      --platform linux/amd64 \
      --build-arg "FENV_DOCKER_TAG=${FENV_DOCKER_TAG}" \
      --tag "fenv-ext-${FENV_PROJECT_NAME}:${FENV_EXT_DOCKER_TAG}" \
      --file "${EXT_DOCKERFILE}" \
      "${CALLING_DIR}")
  fi
fi

if [[ -n "${DO_EXEC:-}" ]]; then
  (set -x; docker compose -f compose.yaml run --rm -v "${CALLING_DIR}:/src" fenv "${EXEC_ARGS[@]}")
fi

if [[ -n "${DO_DOWN:-}" ]]; then
  (set -x; docker compose -f compose.yaml down -v)
fi
