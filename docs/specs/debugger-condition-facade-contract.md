# Debugger / condition facade contract

Status: implemented-emulated-tested for the P3 foundation.

This document defines the first stable SLYNET debugger contract. It does not claim
Common Lisp condition/restart/thread equivalence. Instead it gives the Emacs
frontend SLY-shaped data with explicit Janet support metadata, so UI code can
render threads, conditions, frames, locals, and restarts without guessing which
parts are native and which parts are emulated.

## Actors

- FRONTEND: Emacs client or any SLY protocol peer.
- SERVER: the Janet SLYNET runtime.
- EXECUTION-UNIT: a Janet-side unit of work exposed through thread-shaped RPCs.
- CONDITION-RECORD: a structured record produced when evaluation fails.
- RESTART-FACADE: a SLY-shaped restart entry backed by explicit SLYNET behavior.
- FRAME-FACADE: a debugger frame record suitable for backtrace and source jumps.

## Scope

P3 covers the debugger shape needed by the frontend to avoid crashing or assuming
Common Lisp semantics. It is intentionally small:

- list the current server/evaluation unit through `list-threads`;
- turn evaluation failures into a structured condition record;
- expose a debugger-info object with condition text, condition metadata, thread
  metadata, restarts, and frames;
- allow the frontend to invoke the synthetic abort-to-repl restart;
- mark every emulated or non-equivalent field explicitly.

Out of scope for P3:

- true CL condition hierarchy;
- true CL dynamic restart scopes;
- retry, use-value, store-value, or resumable condition semantics;
- stepping, breakpoints, stack mutation, or frame-local mutation;
- mapping arbitrary Janet fibers/threads/workers into stable debugger units;
- precise frame source locations beyond the current facade shape.

## Support classes

The debugger facade uses the global support vocabulary from `phases.yml`:

- `:native` means Janet provides matching runtime semantics.
- `:emulated` means SLYNET provides frontend-compatible behavior without matching
  CL semantics.
- `:unsupported` means the operation or sub-feature is recognized but not
  available.
- `:internal` means a field exists for SLYNET bookkeeping.
- `:pending_design` means the field is reserved for a later contract.

P3 debugger condition and restart support is `:emulated`.

Research note: `docs/research/janet-debugger-condition-system.md` records the upstream Janet debugger/fiber primitives that this contract should wrap before adding any further CL-like emulation.

## Execution-unit contract

`list-threads` returns an array of plist records. Each record is thread-shaped for
SLY compatibility but must declare that it is a SLYNET execution unit, not a CL
thread.

Required plist keys:

| key | type | requirement |
| --- | --- | --- |
| `:id` | string | stable enough for the current server session |
| `:name` | string | human-readable display label |
| `:status` | keyword | currently `:running` for exposed units |
| `:kind` | keyword | legacy/thread-shaped kind; currently `:connection` |
| `:execution-unit` | boolean | must be `true` |
| `:execution-unit-kind` | keyword | e.g. `:connection` |
| `:thread-model` | keyword | must be `:slynet-execution-unit` for P3 |
| `:cl-thread-equivalent` | boolean | must be `false` until native equivalence exists |
| `:current` | boolean | true for the current connection/eval unit when known |
| `:debugging` | boolean | true when the unit is the active debugger unit |

Contract examples:

- A frontend must not treat `:id` as an OS thread id unless a later support field
  explicitly states native thread equivalence.
- A frontend may display these records in SLY thread UI, but should surface the
  `:thread-model` or `:cl-thread-equivalent` distinction in developer/debug views.

Executable evidence:

- `test/debugger_facade_tests.janet`
- test name: `execution units expose Janet thread facade metadata`

## Condition-record contract

When an evaluation error reaches the debugger facade, SLYNET stores a condition
record in debugger state.

Required table keys:

| key | type | requirement |
| --- | --- | --- |
| `:id` | string | unique-ish session-local id, currently `condition-N` |
| `:kind` | keyword | currently `:evaluation-error` |
| `:message` | string | human-readable Janet error text |
| `:support-class` | keyword | currently `:emulated` |
| `:cl-condition-equivalent` | boolean | currently `false` |

The legacy top-level `:condition` string may mirror `condition-record.message` for
frontend compatibility, but new code should prefer `:condition-record`.

Executable evidence:

- `test/debugger_facade_tests.janet`
- test name: `eval errors create condition records with synthetic abort restart`

## Debugger-info contract

`debugger-info-for-emacs` returns a table-like debugger state. The P3 minimum
shape is:

| key | type | requirement |
| --- | --- | --- |
| `:active` | boolean | true while debugger state is active |
| `:condition` | string or nil | legacy display text |
| `:condition-record` | table or nil | structured condition record |
| `:condition-type` | keyword or nil | currently `:evaluation-error` |
| `:thread` | table or nil | active execution-unit table |
| `:level` | integer | debugger nesting/facade level, currently 1 on error |
| `:restarts` | array | array of restart plist records |
| `:frames` | array | array of frame facade tables |

The returned object is a snapshot/facade. P3 does not guarantee stable identity
across separate debugger entries except through explicit ids such as condition id
and execution-unit id.

## Restart-facade contract

P3 provides synthetic restarts as plist records. The first restart is the stable
minimum frontend affordance.

Required plist keys:

| key | type | requirement |
| --- | --- | --- |
| `:name` | string | frontend-visible restart name |
| `:description` | string | human-readable description |
| `:restart-kind` | keyword | currently `:synthetic` |
| `:support-class` | keyword | currently `:emulated` |
| `:cl-restart-equivalent` | boolean | currently `false` |

Required restarts:

| index | name | behavior |
| --- | --- | --- |
| 0 | `abort-to-repl` | deactivate current debugger state and return `[:ok "abort-to-repl"]` |

Optional P3 restart:

| index | name | behavior |
| --- | --- | --- |
| 1 | `continue` | facade placeholder; no CL resumability is implied |

`invoke-nth-restart` must reject indexes outside the restart array. It must not
pretend that Janet can resume arbitrary failed evaluations unless a later contract
adds a native or instrumented restart scope.

## Frame-facade contract

P3 frames are debugger facade records. On real evaluation errors they should prefer native Janet `debug/stack` facts, then fall back to P4 source-index facts, then to explicitly synthetic facade locations. Each frame table should include:

| key | type | requirement |
| --- | --- | --- |
| `:index` | integer | frame index |
| `:description` | string | display label |
| `:locals` | array | local variable facade records |
| `:location` | table | source location facade; native Janet, source-index backed, or synthetic |
| `:callable` | string or nil | optional callable name from native frame or source-index fallback |
| `:janet-frame` | boolean or nil | true when normalized from Janet `debug/stack` |

Each local record should include at least:

| key | type | requirement |
| --- | --- | --- |
| `:name` | string | local name |
| `:value` | string | printed value |

Each location table should include:

| key | type | requirement |
| --- | --- | --- |
| `:file` | string | path to a source file or best-known facade source |
| `:line` | integer | one-based line number |
| `:column` | integer | one-based column number |
| `:synthetic-location` | boolean | `false` for native Janet or source-index facts, `true` only for synthetic fallback locations |
| `:source-kind` | keyword | `:janet-debug-stack`, `:source-index`, or `:synthetic-facade` |
| `:name` | string or nil | native Janet frame name or source-index symbol name when available |
| `:kind` | keyword or nil | source-index definition kind or normalized native frame kind |
| `:snippet` | string or nil | source line when available |
| `:source-index` | keyword or nil | index identity, currently `:slynet-source-index`, when source-index backed |
| `:janet-pc` | number or nil | Janet program counter from `debug/stack` when native-backed |
| `:janet-status` | keyword or nil | fiber status used for the native stack, usually `:error` or `:debug` |
| `:janet-name` | string or nil | native Janet frame name |
| `:janet-function-present` | boolean or nil | whether `debug/stack` exposed a function object |
| `:janet-slots-count` | integer or nil | number of native frame slots exposed by Janet |
| `:tail-call` | boolean or nil | Janet frame tail-call marker when available |
| `:c-frame` | boolean or nil | Janet C-frame marker when available |

Debugger frame source priority is:

1. `:janet-debug-stack` from the caught error/debug fiber via Janet `debug/stack`;
2. `:source-index` from the P4 xref/source-index contract when a callable name is known;
3. `:synthetic-facade` only when neither native stack nor source-index facts are available.

Native Janet frames are still normalized into SLYNET facade tables; they do not imply Common Lisp frame semantics. The facade must retain `:synthetic-location false` for native and source-index-backed records, and must mark synthetic fallbacks with `:synthetic-location true` so the frontend can display or de-emphasize them honestly.

## Frontend activation event contract

When an evaluation error creates debugger state, the backend sends the normal
request error reply and then emits an unsolicited event message for frontend UI
activation.

- event operation: :debug-activate
- payload: the same SLYNET debugger facade returned by debugger-info-for-emacs
- frame source priority remains janet-debug-stack, then source-index, then synthetic-facade
- condition records must carry support-class and CL condition equivalence metadata
- restart records must carry restart-kind, support-class, and non-equivalence metadata when available
- Emacs must render these fields visibly instead of implying Common Lisp condition/restart equivalence

Frontend acceptance tests must prove that a decoded activation event opens or
updates the SLYNET debugger buffer and displays condition support, condition
CL-equivalence, restart metadata, and native Janet frame source facts.

## RPC behavior matrix

| RPC | P3 state | notes |
| --- | --- | --- |
| `list-threads` | implemented-emulated-tested | returns execution-unit plist records |
| `thread-info` | implemented-emulated-tested | returns a selected execution-unit plist |
| `debug-nth-thread` | implemented-emulated-tested | creates debugger state for selected execution unit |
| `debugger-info-for-emacs` | implemented-emulated-tested | returns debugger facade state |
| `backtrace` | implemented-emulated-tested | slices facade frames |
| `debugger-frame-details` | implemented-emulated-tested | returns one facade frame |
| `frame-source-location` | implemented-emulated-tested | returns current facade location |
| `frame-locals-and-catch-tags` | implemented-emulated-tested | returns locals plus empty catch tags |
| `invoke-nth-restart` | implemented-emulated-tested | supports synthetic abort-to-repl |
| `sly-db-abort` | implemented-emulated-tested | alias to restart 0 |
| `sly-db-continue` | implemented-emulated-tested | alias to restart 1 placeholder |

## Red/green contract tests

Required focused commands:

- `JANET_PATH=$PWD janet test/run_tests.janet :match 'execution units expose Janet thread facade metadata' :report compact`
- `JANET_PATH=$PWD janet test/run_tests.janet :match 'eval errors create condition records with synthetic abort restart' :report compact`
- `JANET_PATH=$PWD janet test/run_tests.janet :match 'debugger frames prefer native Janet debug stack facts' :report compact`
- `JANET_PATH=$PWD janet test/run_tests.janet :match 'debugger frame locations use source index when callable is known' :report compact`
- `JANET_PATH=$PWD janet test/run_tests.janet :match 'unresolved debugger frame locations keep synthetic facade source kind' :report compact`

Required aggregate command:

- `JANET_PATH=$PWD janet test/run_tests.janet :report compact`
- `eldev test --expect 28` including `slynet-wire-event-renders-buffer`

## Done criteria

P3 is done when:

- `list-threads` records include `:execution-unit true`, `:thread-model
  :slynet-execution-unit`, and `:cl-thread-equivalent false`;
- evaluation errors create a structured `:condition-record` with id, kind,
  message, support class, and CL-equivalence flag;
- `debugger-info-for-emacs` returns condition, thread, restart, and frame facade
  data without requiring Common Lisp condition machinery;
- frame locations use `:source-kind :janet-debug-stack` and `:synthetic-location false`
  when backed by native Janet `debug/stack` facts;
- frame locations use `:source-kind :source-index` and `:synthetic-location false`
  when backed by real source-index facts;
- unresolved frames keep `:source-kind :synthetic-facade` and `:synthetic-location true`;
- the first restart is `abort-to-repl`, marked `:synthetic` and `:emulated`;
- `invoke-nth-restart 0` returns `[:ok "abort-to-repl"]`;
- the aggregate Janet suite passes with the debugger facade tests included.

## Future debugger phases

Suggested follow-up slices:

1. Replace facade frame names with real evaluator/VM frame symbols where Janet
   exposes reliable stack metadata.
2. Split condition records by source phase: reader, compile-string, eval,
   channel-process, transport.
3. Introduce restart scopes for evaluator-owned operations, initially limited to
   abort and continue-as-nil.
4. Add frontend rendering tests that assert Emacs displays the support-class and
   non-equivalence metadata in developer/debug views.
