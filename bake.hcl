# Docker Bake configuration for FoundationDB testing environment.
#
# Variables can be overridden via environment variables.
# The CI workflow passes these as env vars from the matrix.

variable "FENV_DOCKER_TAG" {
  default = "latest"
}

variable "FENV_FDB_VER" {
  default = "7.1.61"
}

variable "SHELLCHECK_URL" {
  default = "https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz"
}

variable "HADOLINT_URL" {
  default = "https://github.com/hadolint/hadolint/releases/download/v2.7.0/hadolint-Linux-x86_64"
}

variable "JP_URL" {
  default = "https://github.com/jmespath/jp/releases/download/0.2.1/jp-linux-amd64"
}

# Build arguments used by the target.
function "build_args" {
  params = []
  result = {
    FDB_LIB_URL    = "https://github.com/apple/foundationdb/releases/download/${FENV_FDB_VER}/foundationdb-clients_${FENV_FDB_VER}-1_amd64.deb"
    SHELLCHECK_URL = SHELLCHECK_URL
    HADOLINT_URL   = HADOLINT_URL
    JP_URL         = JP_URL
  }
}

group "default" {
  targets = ["build"]
}

target "build" {
  context    = "."
  dockerfile = "Dockerfile"
  target     = "base"
  tags       = ["docker.io/janderland/fenv:${FENV_DOCKER_TAG}"]
  platforms  = ["linux/amd64"]
  args       = build_args()
}
