# SLYNET documentation

The root `README.md` is the authoritative user quick start. This directory
contains architecture, compatibility, protocol, and development material for
the Janet-native SLYNET backend and its Emacs client.

## Start here

- `../README.md` — supported versions, first session, commands, and release
  verification.
- `COMPATIBILITY.md` — compatibility and deprecation policy.
- `../ROADMAP.md` — authoritative post-1.0 engineering roadmap.
- `generated/protocol-inventory.yml` — generated operation-level SLY/SLYNK to
  SLYNET support inventory.
- `specs/` — executable-design contracts for Janet-specific adaptations.
- `architecture/` — architecture and protocol background; older documents may
  retain historical porting context and should not override current specs.
- `dev-guides/setup.md` — contributor setup and verification workflow.

## Safe local server usage

Run SLYNET from the repository root and keep its listener on loopback:

```sh
export JANET_PATH="${JANET_PATH}:$PWD"
janet slynet/cli.janet --help
janet slynet/cli.janet --tcp --host 127.0.0.1 --port 4005
```

The protocol carries code-evaluation requests and is not an authentication
boundary. Do not expose the development listener directly to an untrusted
network. See `../SECURITY.md` for the trust model and remote-access guidance.

## Development gates

```sh
make test
make test-emacs
make test-e2e
make protocol-inventory-check
make release-integrity
make release-verify
```

`make release-verify` additionally packages SLYNET, extracts both Janet and
Emacs artifacts, starts the extracted Janet CLI, connects with the extracted
Emacs client, evaluates a form, and writes machine-readable release evidence.

## Compatibility rule

SLYNET optimizes for useful Janet editor workflows, not fictional Common Lisp
runtime equivalence. Protocol entries explicitly record whether a behavior is
native, emulated, a workaround, pending design, or unsupported. When a Janet
runtime capability is absent, new code must preserve that distinction rather
than returning a plausible-looking fake success value.
