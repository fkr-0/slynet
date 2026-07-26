# SLY/SLYNK Backend Gap Analysis for SLYNET

Status: executable support-spec companion.

This document answers the release question: what is still missing from the original SLY/SLYNK backend surface, whether each gap is in scope for SLYNET, and whether the right path is native Janet support, SLYNET workaround/emulation, or a Janet/runtime extension.

It complements:

- `docs/generated/protocol-inventory.yml`, the generated operation-level inventory;
- `docs/specs/support-matrix.yml`, the machine-readable phase/surface matrix;
- `docs/specs/janet-extension-candidates.md`, the detailed extension-candidate contract;
- `docs/specs/cl-janet-equivalence-contracts.md`, the vocabulary and phase overview.

## Classification vocabulary

| class | meaning | release rule |
| --- | --- | --- |
| native | Janet exposes the needed runtime facts directly | Wrap truthfully and test directly. |
| emulated | SLYNET can provide a SLY-shaped facade without claiming CL equivalence | Mark support class, equivalence, constraint reason, and support rationale. |
| workaround | SLYNET can approximate by indexing source, caching metadata, wrapping evaluation, or instrumenting code | Keep fallback explicit; do not hide synthetic data. |
| needs-janet-extension | A correct implementation needs new Janet runtime/debug/introspection support | Keep out of 1.0.0 hard guarantees unless the extension exists. |
| out-of-scope | The CL feature has no Janet concept and no useful SLYNET compatibility story yet | Inventory as unsupported with rationale. |
| pending-design | Useful target, but no stable SLYNET contract yet | Must not be presented as implemented. |

## High-level answer

SLYNET should not try to become a Common Lisp implementation. The target is a truthful SLY-shaped Janet development backend. That means:

- keep transport, MREPL, completion, inspector, xref, diagnostics, and debugger UI compatibility in scope;
- expose Janet fibers, signals, debug stack, modules, environments, and source files as Janet facts;
- emulate CL packages, conditions, restarts, threads, and compiler notes only as explicitly marked facades;
- keep CLOS/MOP and CL method/generic-function operations unsupported unless a separate Janet object system layer is introduced;
- use source indexes, metadata caches, and evaluator instrumentation as workarounds where Janet does not expose enough native runtime data.

## Surface matrix

| SLY/SLYNK surface | SLYNET scope | current strategy | Janet extension needed? | notes |
| --- | --- | --- | --- | --- |
| transport and request/reply protocol | in scope | native sockets plus SLY-shaped RPC messages | no | Protocol compatibility is mostly data-shape work. |
| MREPL and eval loop | in scope | SLYNET connection/session state plus Janet eval | no | Must keep package/module differences explicit. |
| completions and arglists | in scope | native symbol/module scanning plus caches and overrides | maybe later | Native and C functions may not expose rich arglists. |
| autodoc | partial / pending deepening | completion metadata and arglist cache | maybe later | Full CL-style autodoc is not native Janet behavior. |
| compile/load diagnostics | in scope | diagnostic envelopes around Janet parse/eval/load errors | maybe later | Janet does not expose CL compiler-note objects. |
| inspector | in scope | stable SLYNET object ids and Janet data walkers | no | Specialized object renderers can grow incrementally. |
| xref/source locations | in scope | P4 source index plus source snippets | maybe later | Runtime source maps for evaled forms would improve accuracy. |
| debugger frames | in scope | Janet debug/stack first, source-index fallback, synthetic last | maybe later | Native debug frames are real Janet facts, not CL frames. |
| conditions and restarts | in scope as facade | Janet fiber/error signals plus synthetic restart affordances | yes for true CL restarts | Do not claim CL condition/restart equivalence. |
| threads | in scope as execution units | server connections, fibers, tasks, and execution-unit metadata | no for facade; yes for CL parity | Janet has fibers/tasks, not implementation threads like CL. |
| package/namespace ops | in scope as emulation | modules, environments, prompt labels | no for facade | No CL reader-package semantics. |
| source edit/find-definition | in scope | source-index-backed navigation | maybe later | Exact dynamic/eval source locations need richer runtime metadata. |
| tracing/profiling/timing | partial | wrapper/instrumentation layer | no for basic; maybe for VM-level hooks | Prefer explicit instrumentation records. |
| stickers/break-on-stickers | pending design | instrumentation records | maybe | Needs stable instrumentation and frontend contract. |
| CLOS/MOP/generic method metadata | out of scope for 1.0.0 | unsupported with rationale | yes or external object-system library | Janet has no CLOS/MOP equivalent. |
| ASDF/system integration | out of scope for 1.0.0 | project/connection management instead | no | Janet projects do not map to ASDF systems. |
| CL package mutation/export/unintern semantics | constrained | namespace facade only | yes for true parity | Janet symbols/modules are not CL packages. |

## Original SLY/SLYNK gaps by decision

### In scope: native or nearly native

- TCP/stdio transport and asynchronous message dispatch.
- MREPL creation, channel send, prompt updates, output/value writes.
- Basic eval, pprint-eval, compile-string/load-file style command paths.
- Completions over Janet-visible symbols and modules.
- Inspector navigation over Janet values.
- Xref for source files known to the source index.
- Debugger frame facts from Janet debug/stack when an error/debug fiber is available.

### In scope: explicit SLYNET emulation

- CL package selection becomes Janet module/environment display and eval environment selection.
- CL condition records become structured Janet error/signal records with `cl-condition-equivalent: false`.
- CL restarts become synthetic restart actions such as `abort-to-repl`, with `cl-restart-equivalent: false`.
- CL threads become SLYNET execution units over server connections/fibers/tasks, with `cl-thread-equivalent: false`.
- CL compiler notes become Janet diagnostic envelopes.
- Source jumps use source-index facts when runtime frame data is insufficient.

### In scope: workaround first, possible Janet extension later

- Precise source locations for dynamically evaluated forms.
- Rich local variable names and slot metadata beyond what Janet debug/stack exposes.
- Step/next/out style debugger control around Janet debug/step, debug/break, and resumable debug fibers.
- Breakpoint management that persists across reloads and maps user source forms to Janet debug locations.
- Full arglists/autodoc for native/C functions and macros without explicit metadata.
- Runtime instrumentation for stickers, trace trees, and profiling with low overhead.

### Out of scope for 1.0.0 unless Janet grows new substrate

- True Common Lisp condition hierarchy and restart scopes.
- CLOS/MOP/generic function and method reflection.
- ASDF system model parity.
- CL package mutation semantics as real reader/package behavior.
- Full compiler-note parity with CL compiler conditions.
- Portable CL-style thread control over independent OS/native threads.

## Janet extension candidates

These are not 1.0.0 requirements, but they are useful upstream/runtime candidates if deeper parity becomes a goal. Detailed per-candidate contracts live in `docs/specs/janet-extension-candidates.md`.

| candidate | why SLYNET wants it | current workaround |
| --- | --- | --- |
| Stable eval source maps | map dynamic eval frames back to buffer regions | source-index fallback and snippets |
| Rich debug frame locals | show named locals reliably in Emacs debugger | debug/stack slots, limited locals, printed values |
| Resumable debugger control API | implement step/next/out/continue honestly | wrap current debug/step/debug/break where available; otherwise mark unsupported |
| Structured signal metadata | distinguish reader/compile/eval/runtime error phases precisely | SLYNET condition records and diagnostic envelopes |
| Function arg metadata | complete autodoc for native/C/macro functions | arglist cache, overrides, metadata registry |
| Instrumentation hooks | efficient tracing/stickers/profiling without invasive wrappers | SLYNET wrapper and recording layer |

## Workaround rules

1. Prefer native Janet facts when available.
2. Use source-index facts only when native facts are absent or incomplete.
3. Use synthetic data only as a last resort.
4. Every synthetic or emulated datum must be marked by support/equivalence metadata.
5. The frontend must display enough metadata to prevent users from mistaking a facade for CL-native behavior.
6. Every unsupported original SLY/SLYNK operation must remain visible in the generated inventory with `support_class: unsupported` and a rationale.

## Release scope decision

The acceptable claim for a 1.0.0 SLYNET release is:

> SLYNET provides a tested Janet development backend with SLY-shaped transport, REPL, completion, inspector, xref, diagnostics, debugger, and Emacs UI surfaces. Where original SLY/SLYNK depends on Common Lisp-only semantics, SLYNET exposes explicit Janet facades or unsupported records instead of claiming Common Lisp equivalence.

The unacceptable claim is:

> SLYNET is a full SLYNK-compatible Common Lisp backend implemented in Janet.

## Enforcement

The executable tests must enforce that:

- this document exists and names native, emulated, workaround, needs-janet-extension, out-of-scope, and pending-design decisions;
- the spec index references this document;
- the generated inventory records support class, owning spec, validation stage, and rationale for constrained entries;
- debugger, thread, condition, package, compiler-note, and CLOS/MOP constraints stay explicit in `support-matrix.yml` and `docs/generated/protocol-inventory.yml`.


## P25-P28 implementation note

P25 through P28 implement useful SLYNET-level development facades for weak SLY/SLYNK surfaces without claiming full Common Lisp backend parity.

- P25 adds source-linked trace/timing records and backend runtime capability records. Historical utilities such as image saving, weak-key hash tables, file descriptor duplication, direct socket creation, stream timeout mutation, and wait-for-input return explicit unsupported metadata unless a safe Janet substrate exists.
- P26 adds a protocol interface browser and wrapper-profile reporting. Profile records are SLYNET wrapper records, not native low-overhead Janet profiler hooks.
- P27 adds SLYNK-shaped compile and macroexpand wrappers around Janet diagnostics/expansion helpers, plus project/session metadata. These records keep CL compiler-note and image equivalence false.
- P28 adds a Janet namespace/module browser and explicit unsupported records for CL package-local nickname lookup.

These phases improve daily-use development workflows while preserving the contract boundary between SLYNET workaround facades and Janet runtime extensions.
