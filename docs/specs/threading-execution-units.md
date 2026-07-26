# Threading and Execution-Unit Contract

## Scope

This file owns SLYNET behavior where SLY/SLYNK expects thread-like frontend affordances but Janet exposes fibers, tasks, server connections, and runtime-managed work units instead of CL implementation threads.

Owned frontend surfaces and constraints:

- `constraint: threads`
- execution-unit records consumed by debugger and thread-browser UI
- cooperative interruption metadata
- runtime-instrumentation checkpoints that identify an execution unit

## Contract

SLYNET uses the term **execution unit** for anything that can be named, listed, focused, interrupted cooperatively, or associated with debugger state. A unit can be a server connection, active REPL evaluation, managed fiber, worker, or instrumented evaluator checkpoint.

Every execution-unit record should include:

- stable id
- display name
- status
- kind or execution-unit-kind
- `thread-model: slynet-execution-unit`
- `execution-unit: true`
- `cl-thread-equivalent: false` unless a future backend proves otherwise
- optional source context
- optional debugger association

## Validation stages

| Stage | Owns |
| --- | --- |
| P3_thread_debugger_condition_facade | Current connection and debugger-thread facade records. |
| P9_debugger_execution_unit_emacs_ui | Emacs rendering of execution-unit records. |
| P14_project_connection_management | Multiple named connection identity. |
| P16_runtime_instrumentation | Cooperative interruption request metadata and checkpoint source context. |

## Support rationale

CL thread operations are emulated because Janet execution units do not map one-to-one to CL implementation thread APIs. Hard process- or host-thread control must not be implied by frontend-compatible record shapes. Unsupported hard controls must return structured metadata rather than hang or silently pretend to work.


## P21 implementation notes

P21 adds a SLYNET-owned managed execution-unit registry. It tracks units
registered through `register-execution-unit` or `start-execution-unit`, exposes
them through `list-threads` and `list-execution-units`, and records stable id,
name, status, role/current-role, source path/line/column context, started/ended
timestamps, last output, and cooperative interrupt flags.

`interrupt-execution-unit` does not hard-stop Janet execution. For managed units
it marks `:interrupt-requested true` and transitions the unit to
`:interrupt-requested`; managed wrappers can observe the flag through
`execution-unit-interrupted?`. `complete-execution-unit`/`finish-execution-unit`
record completion or error status and last output. This is explicitly a SLYNET
execution-unit facade, not CL thread control.
