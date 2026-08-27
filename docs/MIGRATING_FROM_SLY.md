---
layout: page
title: Migrating from SLY
---

# Migrating from Common Lisp SLY to SLYNET

SLYNET deliberately borrows useful SLY/SLYNK workflow and wire concepts, but it
is a Janet development environment rather than a Common Lisp implementation of
SLYNK. Migration therefore means preserving familiar editor habits where Janet
can support them and learning the places where a literal SLY semantic claim
would be false.

## The shortest migration path

1. Install Janet and add SLYNET's `emacs/` directory to Emacs `load-path`.
2. `(require 'slynet)` and enable `(slynet-mode 1)`.
3. Keep the server on loopback and start it with `M-x slynet-start-server`, or
   use `M-x slynet-connect-project` for the ownership-aware project path.
4. Open the MREPL with `M-x slynet-create-mrepl`.
5. Use the normal editor commands for region/form/definition/buffer evaluation,
   file compile/load, source lookup, inspector, diagnostics, and debugger views.
6. When a server disappears, treat buffers marked **stale session** as historical
   output, reconnect, and refresh rather than acting through the dead session.

## Familiar workflow, Janet semantics

| SLY habit | SLYNET equivalent | Important difference |
|---|---|---|
| connect to a Lisp | `slynet-connect` / `slynet-connect-project` | Connects to a Janet process. |
| REPL | `slynet-create-mrepl` | Janet reader/evaluator and Janet values. |
| eval region/form/defun/buffer | `slynet-eval-region`, `slynet-eval-last-form`, `slynet-eval-definition`, `slynet-eval-buffer` | Balanced Janet/Lisp syntax is used; there is no CL package reader model. |
| compile/load file | `slynet-compile-current-file`, `slynet-load-current-file` | Diagnostics are Janet-native, not CL compiler notes. |
| M-. definitions | `slynet-find-definitions` | Backed by SLYNET's Janet source index. |
| inspector | `slynet-inspect-value` | Back/forward/refresh/actions are SLYNET-native inspector operations. |
| debugger | `slynet-debugger-info` | Condition/frame inspection is useful, but not a resumable CL debugger continuation. |
| interrupt | `slynet-interrupt-execution-unit` | Cooperative only for SLYNET-managed execution units. |
| abort pending request | `slynet-cancel-latest-request` | Cancels client bookkeeping; it does not claim to stop arbitrary backend Janet work. |

## Semantics that do not migrate literally

### Packages and reader state

Janet modules/environments are not Common Lisp packages. SLYNET exposes adapted
namespace/package-shaped records where useful, but package-local nicknames and
other CL-only behavior are explicitly unsupported or emulated rather than
invented.

### Conditions and restarts

Janet errors, fibers and debug stacks do not provide the Common Lisp condition
and restart protocol. SLYNET can show structured error state, source-linked
frames and synthetic/cooperative restart-like actions. It does **not** claim CL
restart equivalence.

### Threads and debugger stepping

SLYNET execution units are a managed Janet abstraction. They are not a promise
that every Janet runtime fiber behaves like a CL implementation thread. Native
step/next/out remains unavailable until a real resumable Janet substrate exists;
the UI marks unavailable controls instead of making them clickable.

### CLOS/MOP

Janet has no CLOS/MOP substrate. Operations that require it remain unsupported.
Use Janet data/functions/prototypes directly rather than attempting to port MOP
workflows mechanically.

## Suggested Emacs configuration

```elisp
(add-to-list 'load-path (expand-file-name "~/src/slynet/emacs"))
(require 'slynet)

(setq slynet-server-directory (expand-file-name "~/src/slynet"))
(setq slynet-server-command '("janet" "slynet/cli.janet" "--tcp"))

(slynet-mode 1)
```

The public command prefix is `C-c C-s`; the README contains the current command
and key table.

## Embedding migration

Applications embedding SLYNET should import the API-v1 module instead of CLI,
registry or backend internals:

```janet
(import slynet/api :as slynet)

(def context (slynet/create-context))
(defer (slynet/close-context context))

(slynet/call-rpc 'ping :pong)
(pp (slynet/context-status context))
```

The older `(import slynet/slynet-api ...)` path is an API-v1 compatibility shim.
New code should use `slynet/api`; see the embedding API page for the exact
compatibility and deprecation policy.

An executable example ships in release artifacts as
`examples/embed-server.janet`; `./examples/embed-server.janet --check` verifies
the embedding API without opening a listener.

## Security model

Do not carry over assumptions from a locally trusted Lisp development setup to
an exposed network service. SLYNET evaluates Janet code with the server process
user's authority. API-v1 server helpers and documented defaults bind to
`127.0.0.1`; authentication, authorization, encryption and sandboxing are not
provided by the SLYNET protocol itself.

## Checking whether a SLY feature exists

Use these sources in order:

1. `docs/generated/protocol-inventory.yml` for generated operation-level truth;
2. `docs/generated/protocol-coverage.md` for the release-critical stable subset;
3. `DEVELOPMENT_STATUS.md` for the current development-tree interpretation;
4. `ROADMAP.md` for planned work.

Historical missing-protocol checklists are not release authority.
