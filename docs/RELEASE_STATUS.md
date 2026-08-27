---
layout: page
title: SLYNET 1.1.0 release status
---

# SLYNET 1.1.0 release status

Audited: 2026-08-27

SLYNET 1.1.0 is the capability-consolidation release: it adds a stable Janet
embedding API, expands daily Emacs workflows and recovery behavior, makes
protocol/test correspondence machine-auditable, and repairs the static xref
substrate without pretending Janet provides Common Lisp runtime semantics.

The exact qualified revision, local release-gate results, and artifact hashes are
recorded by `dist/release-evidence.yml`. The immutable v1.1.0 tag is valid only
after the canonical GitHub Actions compatibility matrix and local release gate
both pass.

The frozen v1.0.7 semantic snapshot remains available as
`RELEASE_STATUS_1.0.7.md`.

## Release posture

```yaml
version: 1.1.0
release_kind: qualified_minor_release
canonical_repository: https://github.com/fkr-0/slynet
release_tag: v1.1.0
supported_janet: 1.40.x-1.41.x
supported_emacs: 27.1-30.x
compatibility_matrix:
  janet: [1.40.1, 1.41.1]
  emacs: [27.1, 28.2, 29.4, 30.1]
  cells: 8
supported_os:
  - GNU/Linux
  - macOS
unverified_os:
  - Windows
security_boundary: trusted_localhost_only
publication_gate: local_release_verify_plus_canonical_ci_matrix
```

## Release verification

`make release-verify` is the local release authority. It checks:

- release/version coherence and public-documentation freshness;
- generated schema-6 protocol inventory and stable-surface coverage;
- Janet parse/load and the complete Janet test suite;
- Emacs ERT, lint, byte compilation, and deterministic transport fuzzing;
- repeated live Janet/Emacs lifecycle E2E with server-leak detection;
- packaged Janet and Emacs artifacts through an extracted-artifact
  start/connect/MREPL/eval smoke;
- machine-readable artifact checksums and release evidence.

The canonical `.github/workflows/ci.yml` compatibility job additionally runs the
cross product of Janet 1.40.1/1.41.1 with Emacs 27.1/28.2/29.4/30.1 and executes
`make lint`, `make test-janet`, `make test-emacs`, and `make test-e2e` in each
cell. Tagging is fail-closed on that matrix.

## Stable user workflow

The 1.1 line keeps the trusted-localhost SLYNET model and materially broadens the
daily workflow:

- **Stable Janet embedding API v1** — `slynet/api.janet` exposes version and
  capability discovery, initialization, RPC metadata lookup, context-free
  in-process calls, loopback-safe server lifecycle, owned lifecycle contexts,
  and transport-independent context status. The historical
  `slynet/slynet-api.janet` import is a compatibility shim.
- **Daily Emacs editing commands** — eval last form/region/definition/buffer,
  compile/load the current file, cooperative managed-execution-unit interrupt,
  newest-pending request cancellation, project-aware connect/start/reconnect,
  and deterministic quit/teardown.
- **Recovery and UI state** — inspector back/forward/refresh/actions, source-aware
  debugger controls, stale-buffer marking on connection loss, timeout/late-reply
  recovery, and continued evaluation after recoverable failures.
- **Source navigation and xref** — all top-level Janet forms are parsed, function
  bodies are recursively analyzed, parser sourcemaps provide exact source
  coordinates, caller context is retained, modified-file facts replace old
  facts, deleted-file facts are pruned, and `list-callers` matches the reference
  query signature.
- **Compile/load compatibility** — structured Janet diagnostics retain source
  provenance; compiler-macroexpand compatibility is explicit Janet emulation and
  does not claim Common Lisp lexical-environment/compiler-macro equivalence.
- **Transport, REPL, completion, inspector and debugger facade** — the existing
  release-qualified local TCP/MREPL/completion/autodoc/inspection/debugger flows
  remain part of the stable product contract.

## Protocol inventory: schema 6

The generated inventory tracks **284** historical SLY/SLYNK operations. The
release-critical stable subset is deliberately smaller and is 100% functionally
registered and directly mapped to tests on every declared frontend surface.

| Inventory state | Count | Meaning |
|---|---:|---|
| implemented + directly tested | 70 | Callable functional registration plus explicit operation-level `:covers` evidence. |
| implemented, no direct mapping | 27 | Callable functional registration without direct operation-level test ownership. |
| defined but unwired | 10 | Janet implementation exists but no callable RPC registration exists. |
| registered stub | 5 | Registered endpoint is truthfully an error/unsupported stub. |
| missing | 172 | No Janet implementation or callable registration is present. |

Support classification is **247 native**, **35 emulated**, and **2 explicitly
unsupported** operations.

### Release-critical stable subset

| Surface | Stable operations | Directly tested | Coverage | Gate |
|---|---:|---:|---:|---|
| compile/load | 4 | 4 | 100% | pass |
| completion | 6 | 6 | 100% | pass |
| debugger | 7 | 7 | 100% | pass |
| inspector | 5 | 5 | 100% | pass |
| REPL | 3 | 3 | 100% | pass |
| transport | 4 | 4 | 100% | pass |
| xref | 2 | 2 | 100% | pass |

These numbers remain conservative by design. Historical protocol operations are
not automatically 1.1 product commitments merely because the reference corpus
contains them.

## Deliberate semantic boundaries

SLYNET remains explicit about Janet/Common-Lisp non-equivalence:

- Janet modules/environments are not Common Lisp packages/reader semantics.
- Janet exceptions, fibers and stack traces do not provide CL
  conditions/restarts or resumable debugger continuations.
- Janet execution units do not map one-to-one to implementation threads.
- Janet has no CLOS/MOP substrate; CLOS-specific compatibility operations stay
  unsupported rather than being faked.
- Janet compiler diagnostics and macro expansion differ from CL compiler notes,
  compiler macros and lexical expansion environments.
- `who-references` remains deliberately unwired until static variable-read
  analysis is precise enough to avoid false claims.

Debugger stepping for arbitrary uninstrumented native Janet frames, complete
profiler/trace/sticker UI, Windows qualification, remote/TRAMP, hostile-network,
and multi-user operation are not 1.1.0 release claims.

## Documentation authority

Use these sources in this order:

1. `docs/generated/protocol-inventory.yml` — generated operation-level truth.
2. `docs/generated/protocol-coverage.md` — generated stable-subset coverage.
3. this document — audited 1.1.0 release summary.
4. `ROADMAP.md` — post-release implementation priorities.
5. `docs/RELEASE_STATUS_1.0.7.md` — immutable historical 1.0.7 snapshot.
6. `docs/missing_protocol.md` and `TASKS.md` — historical planning inputs only.
