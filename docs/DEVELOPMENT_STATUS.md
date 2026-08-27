---
layout: page
title: Development status
---

# SLYNET development status

Audited: 2026-08-27  
Applies to: SLYNET 1.1.0 release line

This page describes the current development line. For the current 1.1.0 release
snapshot, see `RELEASE_STATUS.md`; the immutable v1.0.7 snapshot is preserved in
`RELEASE_STATUS_1.0.7.md`.

## Current publication state

```yaml
canonical_repository: https://github.com/fkr-0/slynet
latest_release: v1.1.0
next_target: unplanned
github_release_published: true
pages: deployed_https
pages_url: https://slynet.fkr.dev
pages_https_enforced: true
security_boundary: trusted_localhost_by_default
```

## Corrected protocol inventory

The generated inventory is now **schema 6** over the complete tracked reference
corpus of **284 operations**. Schema 6 separates definition evidence, callable
registration, explicit per-test `:covers` ownership, and registration semantics.
A registered endpoint that only raises `Not implemented` or always reports
unsupported is therefore no longer counted as functional merely because it was
registered.

| State | Count | Meaning |
|---|---:|---|
| implemented + directly tested | 70 | Functional callable registration plus explicit operation-level `:covers` evidence. |
| implemented, no direct mapping | 27 | Functional callable registration without direct `:covers` ownership yet. |
| defined but unwired | 10 | Janet implementation code exists but has no callable RPC registration. |
| registered stub | 5 | Registered, but classified truthfully as an error/unsupported stub. |
| missing | 172 | No Janet function definition or callable registration is found. |

Registration semantics contain **279 functional**, **3 error-stub**, and **2
unsupported-stub** records. Support classification is **247 native**, **35
emulated**, and **2 explicitly unsupported** compatibility operations. Support
class answers what semantics are honest; state answers what is actually wired.

### Release-critical stable subset

The 1.1 release gate declares a finite stable subset instead of pretending that
all historical SLYNK operations are product commitments. Every declared surface
requires **100% functional registration and explicit direct test mapping**:

| Surface | Stable operations | Directly tested | Coverage | Gate |
|---|---:|---:|---:|---|
| compile/load | 4 | 4 | 100% | pass |
| completion | 6 | 6 | 100% | pass |
| debugger | 7 | 7 | 100% | pass |
| inspector | 5 | 5 | 100% | pass |
| REPL | 3 | 3 | 100% | pass |
| transport | 4 | 4 | 100% | pass |
| xref | 2 | 2 | 100% | pass |

`docs/generated/protocol-coverage.md` is generated from the same source of truth
and freshness/threshold checks are part of `make release-verify`.

### Full historical corpus by frontend surface

| Surface | Total | Tested functional | Functional / unmapped | Defined / unwired | Registered stub | Missing |
|---|---:|---:|---:|---:|---:|---:|
| backend | 124 | 8 | 9 | 7 | 3 | 97 |
| compile/load | 16 | 10 | 5 | 0 | 0 | 1 |
| completion | 12 | 6 | 2 | 0 | 0 | 4 |
| debugger | 56 | 11 | 3 | 0 | 0 | 42 |
| inspector | 24 | 14 | 2 | 0 | 0 | 8 |
| namespace | 14 | 3 | 2 | 2 | 2 | 5 |
| REPL | 15 | 6 | 3 | 0 | 0 | 6 |
| transport | 6 | 4 | 0 | 0 | 0 | 2 |
| xref | 17 | 8 | 1 | 1 | 0 | 7 |

These corpus numbers remain deliberately conservative. Historical operations
outside the declared stable subset stay visible without becoming 1.1 compatibility
claims.

## Work that is already real

### Stable development workflows

- local TCP transport, framing, UTF-8 validation, request lifecycle and teardown;
- Emacs connection/project lifecycle and MREPL workflows;
- evaluation, completion/autodoc, source index/xref, inspector, diagnostics;
- Janet debugger inspection facade, execution-unit registry and synthetic
  restart scopes;
- compile/load operations with structured diagnostics;
- wrapper-based profiling and source-linked trace/timing records in the core
  implementation.

### Qualified 1.1.0 work

- canonical `slynet/api.janet` embedding API v1 with owned lifecycle contexts;
- complete API-v1 compatibility shim at `slynet/slynet-api.janet`;
- transport-independent `context-status` without invented client-session claims;
- executable release-artifact embedding example;
- schema-6 protocol inventory with registration-stub truth and per-surface stable
  coverage gates;
- daily editor eval/compile/load/interrupt/cancel workflows and live TCP E2E;
- inspector back/forward/refresh/actions, wire-record normalization, and
  stale-session provenance/recovery;
- live timeout/late-reply recovery plus debugger -> restart -> xref -> compile
  diagnostics -> continued-eval E2E coverage;
- 21 additional editor-adjacent compatibility RPCs promoted only where SLYNET
  already has native or explicitly emulated Janet semantics; the generated
  inventory moved from 49 to 70 directly tested functional operations, while
  missing operations fell from 189 to 172 and unwired definitions from 14 to 10;
- parser-sourcemap-backed static xref compatibility for `who-calls`, `who-binds`,
  `who-sets`, and `list-callers`, with caller identity plus exact source
  coordinates; modified-file refresh replaces prior facts and project refresh
  prunes deleted-file facts; `who-references` remains deliberately unwired until
  variable-read analysis is precise;
- Janet-1.40-correct source-index cache signatures use `os/stat :modified`; a
  same-size rewrite regression proves cache invalidation does not accidentally
  depend on file-size changes;
- explicit Janet-emulated `compiler-macroexpand-1` and `compiler-macroexpand`
  compatibility records that report unsupported CL environment semantics;
- bounded Emacs-readable wire serialization for rich Janet debugger payloads and
  file-aware compile diagnostics that preserve source provenance.

## Debugger truth

SLYNET can inspect Janet errors, stack/frame data, execution-unit state, source
maps, and synthetic restart scopes. It can also cooperatively interrupt managed
execution units. This is **not** equivalent to a resumable Common Lisp debugger
continuation.

The next implementation layer is an explicit debugger-session/checkpoint state
machine for instrumented Janet code. Step-into/over/out will only be claimed for
that cooperative capability tier. Native uninstrumented frame resumability stays
unsupported until Janet exposes a substrate that can provide it.

## Instrumentation truth

The instrumentation estate is mixed and must not be described as all-or-none:

- `profile`, `profile-reset`, `profile-package`, and `profile-report` are callable
  and directly tested wrapper-based profiling operations;
- `slynet-trace-eval`, `slynet-trace-report`, and
  `slynet-clear-trace-report` are directly tested source-linked trace/timing
  operations;
- legacy trace-dialog includes concrete helper/wrapper implementations such as
  `dialog-trace`, but several are not registered as RPCs and therefore appear as
  `implemented_unwired`;
- sticker registries/record structures exist, but compile-time Janet source
  instrumentation (`compile-for-stickers` and the complete record/inspect flow)
  is still missing.

## Public API truth

SLYNET 1.1.0 contains `slynet/api.janet` API version 1.
It provides:

- version and capabilities;
- initialization that guarantees supported core RPC registration before return;
- RPC interface/implementation lookup;
- in-process RPC invocation for context-free operations;
- server start/stop with loopback-only TCP binding by default;
- owned lifecycle contexts and transport-independent context status;
- an explicit API-v1 compatibility/deprecation policy and legacy import shim.

The API is part of the 1.1.0 stable release surface and is not retroactively
part of v1.0.7. See `EMBEDDING_API.md` and `MIGRATING_FROM_SLY.md`.

## Remaining product gaps

The highest-value remaining gaps are tracked in `../ROADMAP.md`:

- cooperative debugger sessions and stepping for instrumented code;
- instrumentation consolidation, timing trees and real sticker injection;
- expansion of directly mapped tests beyond the declared release-critical subset;
- Windows and remote/multi-user qualification remain outside the current support
  claim.
