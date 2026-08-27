# SLYNET 1.0.7 release status

Audited: 2026-08-27

The exact qualified revision and artifact hashes are recorded by the release gate
in `dist/release-evidence.yml`.

This document is the human-readable release snapshot for SLYNET 1.0.7. The
generated protocol truth remains `docs/generated/protocol-inventory.yml`; this
page explains what that inventory means for an actual Emacs/Janet user.

## Release posture

```yaml
version: 1.0.7
release_kind: local_semantic_release
public_distribution: blocked
public_distribution_reason: no canonical origin remote is configured
supported_janet: 1.40.x-1.41.x
supported_emacs: 27.1-30.x
supported_os:
  - GNU/Linux
  - macOS
unverified_os:
  - Windows
security_boundary: trusted_localhost_only
```

`make release-verify` is the release authority. It validates source and package
metadata, generated protocol inventory freshness, Janet tests, Emacs tests,
transport fuzzing, byte compilation, repeated live server lifecycle E2E, and an
extracted-artifact start/connect/MREPL/eval smoke. It does not push, upload, or
publish anything.

## What works as a user workflow

The stable 1.0.x workflow is broader than the small set of protocol operations
that have one-to-one inventory test-file mappings. In particular, the Emacs ERT
and live E2E suites exercise composed user workflows across multiple RPCs.

- **Transport and session lifecycle** — six-hex-byte framing, UTF-8 validation,
  request IDs, timeout/cancellation handling, reconnect/disconnect, channel
  lifecycle, and leak-checked local server teardown.
- **Local server startup** — `janet slynet/cli.janet --tcp` is the documented and
  tested server entrypoint; help and version output are release-gated.
- **MREPL and evaluation** — create a REPL, submit forms, receive values/output,
  retain REPL history, and surface evaluation failures.
- **Completion and docs** — simple/flex completion, argument lists,
  namespace-aware completion, autodoc, and Janet symbol documentation.
- **Source navigation and xref** — source-index-backed definitions, frame source
  locations, and xref-style navigation.
- **Inspector** — inspect values and navigate inspector parts/actions through the
  SLYNET-native inspector surface.
- **Compile/load diagnostics** — compile strings/files, load files, and map Janet
  diagnostics into Emacs-visible source locations.
- **Debugger facade** — condition/frame information, frame locals, execution-unit
  views, and limited restart-like/debug actions where Janet can represent them.
- **Project-aware Emacs lifecycle** — start/connect/status/health/reconnect/quit
  commands and project-scoped local server management.

## Protocol inventory: exact current coverage

The generated inventory contains **249** source protocol operations.

| Inventory state | Count | Meaning |
|---|---:|---|
| implemented + directly mapped test | 24 | Implementation and a direct protocol test mapping are recorded. |
| implemented, no direct inventory test mapping | 131 | Code exists; some are exercised indirectly by broader ERT/E2E tests, but the inventory does not claim a direct operation-level test. |
| missing | 94 | No Janet implementation is recorded. |

By frontend surface:

| Surface | Total | Tested impl. | Impl. / no direct mapping | Missing |
|---|---:|---:|---:|---:|
| backend | 94 | 3 | 40 | 51 |
| compile/load | 15 | 4 | 9 | 2 |
| completion | 12 | 5 | 5 | 2 |
| debugger | 56 | 3 | 22 | 31 |
| inspector | 20 | 1 | 19 | 0 |
| namespace | 14 | 1 | 13 | 0 |
| REPL | 15 | 2 | 10 | 3 |
| transport | 6 | 3 | 1 | 2 |
| xref | 17 | 2 | 12 | 3 |

Support classification is **214 native**, **33 emulated**, and **2 explicitly
unsupported** operations. The two unsupported Common Lisp compatibility
operations are `remove-method-by-name` and `generic-method-specs`, because Janet
does not expose a CLOS/MOP equivalent.

The 24 directly mapped tested operations include the release-critical core:
`ping`, `flow-control-test`, `io-speed-test`, `simple-completions`,
`flex-completions`, `operator-arglist`, `arglist`, `describe-function`,
`set-package`, `interactive-eval-region`, `pprint-eval`,
`compile-file-for-emacs`, `compile-string-for-emacs`, `load-file`,
`macroexpand-all`, `find-definitions-for-emacs`, `frame-source-location`,
`inspector-nth-part`, `frame-locals-and-catch-tags`, `debug-nth-thread`,
`kill-nth-thread`, `slynk-require`, `value-for-editing`, and
`commit-edited-value`.

## What is missing or deliberately constrained

### Runtime-semantic gaps

These are not ordinary TODOs where a literal SLYNK port would be honest:

- Janet modules/environments do not provide Common Lisp package/reader
  semantics; package-like behavior is therefore emulated.
- Janet exceptions and stack traces do not provide Common Lisp conditions and
  restart semantics; debugger restart behavior is a facade, not CL parity.
- Janet fibers/execution units do not map one-to-one to implementation threads.
- Janet has no CLOS/MOP substrate; two compatibility operations are explicitly
  unsupported rather than faked.
- Janet compiler diagnostics do not carry Common Lisp compiler-note semantics;
  compile/load diagnostics are adapted to Janet-native data.

Eleven currently missing operations are explicitly constrained by these runtime
differences, including `return-from-frame`, `restart-frame`, debugger step/next/
out primitives, `spawn`, `initialize-multiprocessing`, `thread-status`, and
`kill-thread`.

### Product gaps after 1.0.7

- **No stable public Janet embedding API yet.** `slynet/api.janet` remains a
  roadmap item; registry plumbing is still primarily internal architecture.
- **Debugger stepping is not a production claim.** True step/next/out and
  resumability depend on Janet runtime capabilities that are not yet exposed as
  a stable SLYNET contract.
- **Instrumentation is incomplete.** Profiler, tracing, timing-tree, and
  sticker-like workflows remain roadmap work.
- **Daily editor polish can go further.** Eval-last-form/definition/buffer/file,
  richer inspector interactions, and recovery UX are not yet at SLY's maturity.
- **Remote operation is not a supported security model.** No authentication or
  sandbox boundary is provided; keep the server on loopback. Remote/TRAMP,
  hostile-network, and multi-user operation are not release claims.
- **Windows is unverified.** The current supported OS claim is GNU/Linux and
  macOS.
- **Public installation/distribution is not complete.** There is no canonical
  `origin`, package archive recipe, public clone URL, or published release.
  `make publication-verify` intentionally fails until that is resolved.
- **Migration guidance for Common Lisp SLY users is still missing.** It remains
  a roadmap deliverable for ecosystem publication.

## Documentation authority

Use these sources in this order:

1. `docs/generated/protocol-inventory.yml` — generated operation-level truth.
2. `ROADMAP.md` — current project-level priorities and release policy.
3. this document — audited human release summary.
4. `docs/missing_protocol.md` and `TASKS.md` — historical planning snapshots;
   they may intentionally contain stale entries and are not release authority.

This ordering matters because the historical missing-protocol document still
names many operations that have since been implemented. Release claims must come
from generated inventory plus executable verification, not those old checklists.
