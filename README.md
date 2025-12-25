# fenv

A Docker-based FoundationDB environment for local development and GitHub Actions CI/CD. Provides a consistent build/test environment with the FDB client library and common dev tools.

## Features

- Builds a Docker image with FoundationDB client library and dev tools
- Caches both the build image and FDB server image for fast CI runs
- Automatically initializes new FDB databases
- Works identically for local development and CI

## Installation

Add fenv as a git submodule in your project:

```bash
git submodule add https://github.com/janderland/fenv.git
```

This allows you to use the same environment locally and in CI.

## Local Development

Use `build.sh` to build and test your project locally:

```bash
# Build the fenv container image
./fenv/build.sh --image

# Run your build/test script inside the container
./fenv/build.sh --exec ./scripts/test.sh

# Or run commands directly
./fenv/build.sh --exec fdbcli --exec "status"

# Interactive shell
./fenv/build.sh --exec bash

# Tear down containers and volumes
./fenv/build.sh --down
```

The script can be called from any directory. Your current working directory is mounted as the working directory in the container.

Set `FENV_FDB_VER` to use a different FDB version:

```bash
FENV_FDB_VER=7.3.43 ./fenv/build.sh --image
```

## GitHub Actions

Reference the action from your submodule path:

```yaml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      - uses: ./fenv
        with:
          fdb_ver: '7.1.61'  # optional, this is the default

      - run: $FENV_PATH/build.sh --exec ./scripts/test.sh
```

### Testing Multiple Versions

Use a matrix strategy to test against multiple FDB versions:

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

      - run: $FENV_PATH/build.sh --exec ./scripts/test.sh
```

## Action Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `fdb_ver` | FoundationDB version | No | `7.1.61` |

## Action Outputs

| Name | Description |
|------|-------------|
| `fenv_docker_tag` | Docker image tag for the build container |

## Environment Variables

The action exports these variables for use in subsequent steps:

| Variable | Description |
|----------|-------------|
| `FENV_PATH` | Path to the fenv directory |
| `FENV_DOCKER_TAG` | Docker image tag for the build container |
| `FENV_FDB_VER` | FoundationDB version being used |

## Build Container Contents

- FoundationDB client library
- `fdbcli` command-line tool
- `shellcheck` for shell script linting
- `hadolint` for Dockerfile linting
- `jp` (JMESPath CLI) for JSON processing
- Common build tools (`git`, `curl`, `build-essential`)
