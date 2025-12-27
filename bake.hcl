# Docker Bake configuration for FoundationDB testing environment.

variable "FENV_DOCKER_TAG" {
  default = "latest"
}

variable "FENV_FDB_VER" {
  default = "7.1.61"
}

group "default" {
  targets = ["fenv"]
}

target "fenv" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["fenv:${FENV_DOCKER_TAG}"]
  platforms  = ["linux/amd64"]
  args = {
    FENV_FDB_VER = FENV_FDB_VER
  }
}
