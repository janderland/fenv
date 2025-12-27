# fenv

A FoundationDB development environment that provides a Docker-based environment for building and testing code that depends on FoundationDB. Works identically on your local machine and in GitHub Actions.

## Features

- Provides a base container with the FoundationDB client library
- The base container may be extended by providing a custom Dockerfile
- Automatically starts an FDB container for integration testing
- Configures the client container with the appropriate cluster file
- Supports both local development and GitHub Actions workflows
- Caches Docker images in CI to prevent rebuilds on every workflow run
- Provides a `/cache` directory that persists between container runs for build and test caches

## Installation

Add fenv as a git submodule in your project:

```bash
git submodule add https://github.com/janderland/fenv.git
```

## Quick Start

**Local development:**
```bash
./fenv/fenv.sh --build --exec fdbcli --exec "status"
```

**GitHub Actions:**
```yaml
- uses: actions/checkout@v4
  with:
    submodules: true
- uses: ./fenv
- run: ./fenv/fenv.sh --exec fdbcli --exec "status"
```

## Extending the Client Container

You can extend the base fenv image with your own build tools and dependencies by providing a custom Dockerfile.

Create a Dockerfile that uses the fenv base image:

```dockerfile
ARG FENV_DOCKER_TAG
FROM fenv:${FENV_DOCKER_TAG}

# Install Go
RUN curl -fsSL https://go.dev/dl/go1.23.4.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOCACHE="/cache/gocache"
ENV GOMODCACHE="/cache/gomod"

# Install golangci-lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | \
    sh -s -- -b /usr/local/bin v1.62.2
ENV GOLANGCI_LINT_CACHE="/cache/golangci-lint"
```

The `FENV_DOCKER_TAG` argument is automatically provided and ensures your extended image is based on the correct version of fenv.

### Cache Directory

The `/cache` directory is backed by a Docker volume that persists between container runs. This makes it an ideal location for build and test caches (as shown in the example above with Go's module cache and golangci-lint cache). Using `/cache` significantly speeds up subsequent builds and test runs.

## Local Development

Use the `fenv.sh` script to manage your development environment:

```bash
# Build the fenv container (and optionally an extended image)
./fenv/fenv.sh --build
./fenv/fenv.sh --docker ./Dockerfile --build

# Execute commands in the container
./fenv/fenv.sh --exec fdbcli --exec "status"

# Interactive shell
./fenv/fenv.sh --exec bash

# Tear down containers and volumes
./fenv/fenv.sh --down

# Show help
./fenv/fenv.sh --help
```

The script can be called from any directory. Your current working directory is automatically mounted as the container's working directory at `/src`.

### Example: ci.sh Script

A common pattern is to create a `ci.sh` script that invokes fenv with your build and test commands:

```bash
#!/bin/bash
set -eo pipefail
cd "$(dirname "$0")"

./fenv/fenv.sh \
    --docker ./Dockerfile \
    --build \
    --exec sh -c '
        shellcheck ci.sh
        hadolint Dockerfile
        go build ./...
        golangci-lint run ./...
        go test ./... -timeout 5s
    '
```

This script can be run both locally and in CI, ensuring identical behavior.

### FDB Version Selection

Set the `FENV_FDB_VER` environment variable to use a different FoundationDB version:

```bash
FENV_FDB_VER=7.3.43 ./fenv/fenv.sh --build
```

## GitHub Actions

Use the fenv action in your workflows:

```yaml
name: test
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      - uses: ./fenv
        with:
          ext_dockerfile: './Dockerfile'

      - run: ./ci.sh
```

The action automatically:
- Sets up Docker Buildx
- Caches the FDB server image
- Builds and caches your extended image (if provided)
- Exports environment variables for subsequent steps

### Testing Multiple FDB Versions

Use a matrix strategy to test against multiple FoundationDB versions:

```yaml
jobs:
  test:
    strategy:
      matrix:
        fdb_ver: ['7.1.61', '7.3.43']

    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      - uses: ./fenv
        with:
          fdb_ver: ${{ matrix.fdb_ver }}
          ext_dockerfile: './Dockerfile'

      - run: ./ci.sh
```

## Configuration Reference

### Environment Variables

**User-configurable:**
- `FENV_FDB_VER`: FoundationDB version (default: `7.1.61`)
- `FENV_CACHE_VOLUME`: Custom cache volume name (optional)

**Auto-computed (available after running fenv):**
- `FENV_DOCKER_TAG`: Docker tag for the base fenv image
- `FENV_EXT_DOCKER_TAG`: Docker tag for the extended image (if built)
- `FENV_IMAGE`: Selected image name used by docker compose

**Container-internal (used by shim.sh entrypoint):**
- `FENV_FDB_HOSTNAME`: FDB server hostname (default: `fdb`)
- `FENV_FDB_DESCRIPTION_ID`: Cluster description:id (default: `docker:docker`)

### GitHub Action Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `fdb_ver` | FoundationDB version | No | `7.1.61` |
| `ext_dockerfile` | Path to custom Dockerfile for extending fenv image | No | - |

### GitHub Action Outputs

| Name | Description |
|------|-------------|
| `fenv_docker_tag` | Docker tag for base fenv image |
| `fenv_ext_docker_tag` | Docker tag for extended image (if built) |
| `fenv_ext_image_built` | Whether extended image was built (`true`/`false`) |

## Base Image Contents

The base fenv image includes:

- **OS**: Debian 12
- **FoundationDB**: Client library and `fdbcli` command-line tool
- **Linters**: `shellcheck` (v0.10.0), `hadolint` (v2.7.0)
- **Utilities**: `jp` (JMESPath CLI v0.2.1) for JSON processing
- **Build Tools**: `git`, `curl`, `build-essential`

## Example Repository

See [fdb-mutex](https://github.com/janderland/fdb-mutex) for a complete example showing:
- Custom Dockerfile extending fenv with Go toolchain
- ci.sh script for build and test
- GitHub Actions workflow integration
