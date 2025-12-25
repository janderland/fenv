# fenv

A GitHub Action that sets up a FoundationDB testing environment with Docker.

## Features

- Builds a Docker image with FoundationDB client library and dev tools
- Caches both the build image and FDB server image for fast CI runs
- Supports multiple FDB versions (tested with 7.1.61 and 7.3.43)
- Automatically initializes new FDB databases
- All environment variables prefixed with `FENV_` to avoid collisions

## Usage

```yaml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: janderland/fenv@main
        with:
          fdb_ver: '7.1.61'  # optional, this is the default

      - run: $FENV_PATH/build.sh --exec ./run-tests.sh
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `fdb_ver` | FoundationDB version | No | `7.1.61` |

## Outputs

| Name | Description |
|------|-------------|
| `fenv_docker_tag` | Docker image tag for the build container |

## Environment Variables

The action exports these variables for use in subsequent steps:

| Variable | Description |
|----------|-------------|
| `FENV_PATH` | Path to the fenv action directory |
| `FENV_DOCKER_TAG` | Docker image tag for the build container |
| `FENV_FDB_VER` | FoundationDB version being used |

## Build Container

The build container includes:

- FoundationDB client library
- `fdbcli` command-line tool
- `shellcheck` for shell script linting
- `hadolint` for Dockerfile linting
- `jp` (JMESPath CLI) for JSON processing
- Common build tools (`git`, `curl`, `build-essential`)

## Local Development

Use `build.sh` to work with the environment locally:

```bash
# Build the container image
./build.sh --image

# Run a command in the container
./build.sh --exec fdbcli --exec "status"

# Run a shell
./build.sh --exec bash

# Tear down
./build.sh --down
```

The script can be called from any directory. The calling directory is mounted at `/src` in the container.

Set `FENV_FDB_VER` to use a different FDB version:

```bash
FENV_FDB_VER=7.3.43 ./build.sh --image
```

## Testing Multiple Versions

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

      - uses: janderland/fenv@main
        with:
          fdb_ver: ${{ matrix.fdb_ver }}

      - run: $FENV_PATH/build.sh --exec ./run-tests.sh
```
