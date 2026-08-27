---
layout: page
title: Development status
---

# SLYNET development status

Audited: 2026-08-27  
Applies to: post-1.0.7 `main`

This page describes the current development tree. For the immutable v1.0.7
release snapshot, see `RELEASE_STATUS.md`.

## Current publication state

```yaml
canonical_repository: https://github.com/fkr-0/slynet
latest_release: v1.0.7
next_target: v1.1.0
github_release_published: true
pages: workflow_and_custom_domain_prepared
pages_url: https://slynet.fkr.dev
security_boundary: trusted_localhost_by_default
```

## Corrected protocol inventory

A post-1.0.7 audit found two weaknesses in the old generated inventory:

1. the reference-source scan omitted several SLY contrib files, including
   profiler, trace-dialog, stickers, retro, and indentation;
2. test evidence and implementation evidence were inferred from broad string
   presence rather than explicit test ownership and callable registration.

Inventory schema v5 corrects both. The complete tracked reference corpus now has
**284** operations.

| State | Count | Meaning |
|---|---:|---|
| callable + directly tested | 44 | A callable RPC registration exists and a test explicitly declares the operation in `:covers`. |
| callable, no direct mapping | 37 | A callable RPC registration exists, but no direct `:covers` test is recorded yet. |
| defined but unwired | 18 | Janet helper/function code exists, but no callable RPC registration exists. |
| missing | 185 | No Janet function definition or callable registration is found. |

Support classification currently contains **249 native**, **33 emulated**, and
**2 explicitly unsupported** compatibility operations. Support class answers
"what semantics would be honest if implemented"; state answers "what is actually
wired now".

### By frontend surface

| Surface | Total | Tested callable | Callable / unmapped | Defined / unwired | Missing |
|---|---:|---:|---:|---:|---:|
| backend | 124 | 8 | 12 | 11 | 93 |
| compile/load | 16 | 5 | 6 | 0 | 5 |
| completion | 12 | 5 | 3 | 0 | 4 |
| debugger | 56 | 9 | 4 | 0 | 43 |
| inspector | 24 | 3 | 4 | 0 | 17 |
| namespace | 14 | 5 | 2 | 2 | 5 |
| REPL | 15 | 3 | 4 | 0 | 8 |
| transport | 6 | 4 | 0 | 0 | 2 |
| xref | 17 | 2 | 2 | 5 | 8 |

These numbers are deliberately conservative. An operation can participate in a
broader live E2E workflow without being counted as directly tested until the
responsible test declares `:covers` metadata.

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

### New post-1.0.7 work in progress

- canonical `slynet/api.janet` embedding API v1;
- compatibility `slynet/slynet-api.janet` shim;
- explicit per-test protocol coverage metadata;
- generated distinction between callable registrations and unwired definitions;
- complete contrib reference-source inventory.

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

The post-1.0.7 development tree now contains `slynet/api.janet` API version 1.
It provides:

- version and capabilities;
- initialization that guarantees supported core RPC registration before return;
- RPC interface/implementation lookup;
- in-process RPC invocation for context-free operations;
- server start/stop with loopback-only TCP binding by default.

The API is under 1.1.0 qualification and is not retroactively part of v1.0.7.
See `EMBEDDING_API.md`.

## Remaining product gaps

The highest-value remaining gaps are tracked in `../ROADMAP.md`:

- complete stable-subset operation→test correspondence;
- daily Emacs eval/load/interrupt/recovery commands;
- cooperative debugger sessions and stepping for instrumented code;
- instrumentation consolidation, timing trees and real sticker injection;
- public API lifecycle ownership and compatibility policy;
- GitHub Pages and docs-to-implementation gates;
- Windows and remote/multi-user qualification remain outside the current support
  claim.
