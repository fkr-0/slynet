# Janet debugger / condition-system research note

Status: research note for SLYNET debugger contract work.
Date: 2026-06-13.

## Question

Does Janet already provide debugger or condition-system primitives that SLYNET
should wrap instead of inventing its own Common Lisp-like model?

## Short finding

Janet has a real debugger substrate built around fibers, signals, stack
inspection, breakpoints, stepping, and a built-in REPL debugger. Janet does not
appear to expose a Common Lisp-style condition/restart system with native
condition classes, dynamic restart scopes, or resumable repair semantics.

Therefore SLYNET should not pretend to have CL condition/restart equivalence.
It should expose SLY-shaped protocol data backed by Janet-native debug/fiber
facts, and mark non-equivalent behavior explicitly.

## Upstream primitives worth wrapping

| Primitive | Use for SLYNET | Notes |
| --- | --- | --- |
| `debug` | intentional debug signal / breakpoint-like entry | Emits a `:debug` signal catchable by parent fibers. |
| `debug/stack` | real frame source for `debugger-info-for-emacs` | Returns frame tables with source, line, column, name, function, pc, slots, c/tail flags. |
| `debug/stacktrace` | fallback textual diagnostic | Useful for human-readable logs, not structured UI state. |
| `debug/break`, `debug/unbreak` | future source breakpoints | Source/line/column breakpoint API. |
| `debug/fbreak`, `debug/unfbreak` | future function/pc breakpoints | Function-level bytecode-offset breakpoint API. |
| `debug/step` | future stepping | Runs one VM instruction and returns signal value. |
| `debug/arg-stack` | edge-case introspection | Only useful when signal happens while pushing call args. |
| `debug/lineage` | future fiber/debug signal ownership | Helps identify which child fiber raised a signal. |
| `debugger` | reference behavior, not a direct frontend backend | Built-in REPL debugger for a fiber. |
| `debugger-on-status` | reference hook for run-context integration | Drops into debugger on abnormal signals when env has `:debug`. |
| `fiber/status` | execution-unit state | Includes `:debug`, `:error`, `:pending`, `:alive`, etc. |
| `fiber/last-value` | captured error/signal payload | Last returned/signaled value from a fiber. |
| `fiber/new` with signal mask | error/debug trapping | Errors and debug signals are captured by fibers, not CL conditions. |
| `signal` | low-level user/error/debug signal raising | Supports `:error`, `:debug`, `:yield`, `:interrupt`, `:await`, and user signals. |
| `propagate` | re-raise while preserving stack trace | Useful if SLYNET catches a fiber signal and must preserve original stack context. |
| `run-context :on-status` | possible eval hook | Lets SLYNET observe abnormal eval status without replacing Janet semantics. |

## Implications for SLYNET contracts

### Conditions

SLYNET `condition-record` should be a Janet signal/error facade, not a CL
condition object.

Recommended stable fields:

- `:support-class :emulated`
- `:cl-condition-equivalent false`
- `:janet-signal` when known, for example `:error` or `:debug`
- `:janet-status` when backed by a fiber, for example `(fiber/status fib)`
- `:message` as display text
- `:payload` or `:value` for raw Janet error/signal payload when safe to print

### Restarts

Native CL restarts are not present. SLYNET should keep restart records explicit:

- `:restart-kind :synthetic` for `abort-to-repl`
- `:support-class :emulated`
- `:cl-restart-equivalent false`

Future resumable operations must be designed as SLYNET-specific control actions,
not described as CL restarts unless they really preserve stack and dynamic repair
semantics.

### Frames

`debug/stack` is the right next implementation target. The current P3/P4 source
index fallback is useful, but debugger frames can become much more truthful when
captured from a real errored or debug-suspended fiber.

Recommended frame-location priority:

1. Use `debug/stack` frame table fields `:source`, `:source-line`,
   `:source-column`, `:name`, `:function`, `:pc`, `:slots` when a captured fiber
   is available.
2. Enrich or normalize with P4 source-index facts when symbol/file matching is
   possible.
3. Fall back to `:source-kind :synthetic-facade` only when no native frame source
   exists.

### Threads / execution units

Janet fibers are not CL threads. SLYNET should keep `list-threads` as an
execution-unit facade unless it later maps real OS/event-loop tasks separately.
Use `fiber/status` vocabulary for Janet-backed units.

## Suggested next implementation slice

Add a native-backed debugger frame fixture:

1. Create a function chain that errors inside a fiber created with an error/debug
   trap.
2. Capture the errored fiber.
3. Call `debug/stack` on that fiber.
4. Normalize the top Janet frames into SLYNET frame records.
5. Assert that at least one frame has:
   - `:source-kind :janet-debug-stack`
   - `:synthetic-location false`
   - `:janet-pc` from `debug/stack :pc`
   - `:janet-slots-present true` or an explicit slots count
   - source file/line/column from Janet when provided

This should sit beside the existing source-index-backed frame test, not replace
it. Source-index remains a fallback/enrichment path.

## Sources checked

- Janet official docs, Core API, `debug`, `debug/stack`, `debug/stacktrace`,
  `debug/break`, `debug/fbreak`, `debug/step`, `debugger`,
  `debugger-on-status`.
- Janet official docs, Fibers and Error Handling.
- Local runtime check: Janet 1.40.1 docs for `debug`, `debug/stack`, and
  `debugger-on-status` match the official API shape used here.
