# Debugger, Conditions, Restarts, and Frames Contract

## Scope

This file owns debugger-facing protocol behavior, condition records, restart facades, backtrace/frame metadata, frame source navigation, and staged runtime checkpoint behavior.

Owned frontend surfaces and constraints:

- `frontend_surface: debugger`
- `constraint: conditions_restarts`
- debugger buffer rendering
- debugger restart controls
- debugger frame source navigation
- runtime checkpoint metadata used by debugger controls

## Contract

SLYNET does not claim Janet has CL conditions or restarts. It provides a frontend-equivalent facade with explicit support metadata.

A condition record should include:

- stable id
- kind or condition type
- message
- support class
- CL-equivalence flag
- optional source context
- raw Janet error information when safe to expose

A restart record should include:

- name or id
- label or description
- restart kind
- support class
- CL-equivalence flag
- scope id when available
- callable or pending status
- rationale for emulated or unsupported behavior

A frame record should include:

- index
- callable or display description
- source location when available
- source kind such as Janet debug stack, source index, or synthetic facade
- local metadata when Janet can expose it safely

## Validation stages

| Stage | Owns |
| --- | --- |
| P3_thread_debugger_condition_facade | Initial condition records, synthetic restart records, and debugger-info payloads. |
| P9_debugger_execution_unit_emacs_ui | Emacs debugger buffer rendering of condition/restart/frame data. |
| P12_interactive_debugger_controls | Restart buttons and frame source navigation. |
| P16_runtime_instrumentation | Restart scopes and pending stepping/checkpoint metadata. |

## Support rationale

Debugger condition/restart behavior is emulated because Janet exceptions and stack traces do not expose CL condition/restart semantics. The facade is still valuable because it gives Emacs a stable interaction model and makes limitations explicit through `support_class`, `constraint_reason`, and `support_rationale` fields.


## P20 instrumented restart scopes

P20 implements synthetic restart behavior only inside SLYNET-owned instrumented
evaluation wrappers. The primary API is `instrumented-eval-with-restarts`.
It can expose `continue-as-nil`, `retry`, and `abort-to-repl` behavior where
SLYNET owns the evaluation scope and can safely retain the requested fallback
or retry expression.

Each restart-scope record includes id, label, restart name, class, safety level,
callable flag, support class, CL-equivalence flag, and explanation. Invoking a
synthetic restart outside an active SLYNET-owned scope returns structured
`:support-class :unsupported` metadata instead of hanging or pretending that
Janet exposes Common Lisp restart scopes.

This is an emulated SLYNET facade. It is not a Janet runtime extension and it is
not CL restart equivalence.

## P20 update: instrumented synthetic restart scopes

P20 adds `instrumented-eval-with-restarts` as the first SLYNET-owned restart scope wrapper. It intentionally does not claim CL restart semantics. Instead, it returns explicit synthetic/emulated metadata for supported wrapper-local actions such as continue-as-nil and retry, while `invoke-synthetic-restart` outside an active SLYNET-owned scope reports structured unsupported metadata.
