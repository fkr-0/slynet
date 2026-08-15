# SLYNET development setup

This guide describes the current contributor workflow for SLYNET 1.0.x. The
root `README.md` remains the user-facing quick start and
`docs/COMPATIBILITY.md` defines the supported runtime window.

## Prerequisites

Use:

- Janet 1.40.x or 1.41.x;
- Emacs 27.1 or newer;
- Git;
- Eldev 1.11 or newer for Emacs package development and release checks.

Verify the toolchain:

```sh
janet --version
emacs --version
eldev --version
```

This checkout currently has no canonical public `origin`. Work from the local
repository you were given. Public clone instructions are intentionally withheld
until a real publication remote exists; `make publication-verify` enforces that
boundary.

## Environment

From the repository root:

```sh
export JANET_PATH="${JANET_PATH}:$PWD"
```

The Makefile and `bridge.yml` set this automatically for the canonical Janet
test and release commands where needed.

## Run SLYNET

The supported direct server entrypoint is:

```sh
janet slynet/cli.janet --help
janet slynet/cli.janet --version
janet slynet/cli.janet --tcp --host 127.0.0.1 --port 4005
```

Keep the listener on `127.0.0.1`. SLYNET evaluates code from connected clients;
see `SECURITY.md` before designing any remote workflow.

A separate CLI client is available for protocol smoke work:

```sh
janet slynet-client.janet --help
```

## Repository structure

```text
slynet/                     Janet backend/server implementation
emacs/                      Emacs client package
test/                       Janet and Emacs verification
sly_source/                 tracked Common Lisp SLY/SLYNK reference corpus
docs/specs/                 current semantic/compatibility contracts
docs/generated/             generated protocol inventory
tools/                      inventory and release verification tooling
project.janet               canonical package version
bundle/info.jdn             Janet package metadata
Makefile                    stable build/test/release command surface
```

The older porting documents under `docs/architecture/` are useful historical
context, but executable tests, `docs/specs/`, `docs/COMPATIBILITY.md`, and
`ROADMAP.md` take precedence when they disagree.

## Normal development loop

Use focused tests while editing, then the aggregate gates:

```sh
make lint
make test
make test-emacs
make test-e2e
```

The Janet suite can also be targeted directly:

```sh
JANET_PATH="$PWD" janet test/run_tests.janet :suite source-index :report compact
JANET_PATH="$PWD" janet test/run_tests.janet :suite debugger :report compact
JANET_PATH="$PWD" janet test/run_tests.janet :suite integration :report compact
```

Every new or changed RPC should retain an interface declaration, explicit
support/equivalence metadata where applicable, and executable coverage.

## Release verification

Before a local release candidate is considered valid, run:

```sh
make release-verify
```

That gate checks version coherence, stale placeholders, direct CLI startup,
protocol policy, generated-inventory freshness, Janet/Emacs tests, transport
fuzzing, compilation, repeated live E2E, packaging, and an extracted-artifact
start/connect/eval smoke. It writes `dist/release-evidence.yml` with artifact
hashes.

For public publication, additionally run:

```sh
make publication-verify
```

The publication check intentionally fails until a real `origin` exists and the
README contains that exact canonical repository URL. Neither verification
command creates a tag, pushes, uploads, publishes, or deploys.
