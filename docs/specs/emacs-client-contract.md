# Emacs Client Contract

## Scope

This file owns frontend surfaces where the Emacs client consumes SLYNET protocol data and turns it into user-facing editor behavior outside the specialized debugger/inspector/xref files.

Owned frontend surfaces:

- `transport`
- `repl`
- `completion`
- `compile_load`
- `namespace`
- `backend` fallback ownership for inventory-only operations

Owned constraints:

- `cl_packages`
- `compiler_notes`

## Transport and session contract

Transport messages use six-byte hexadecimal length prefixes over S-expression payloads. The client must decode fragmented and batched messages deterministically and must not lose data when multiple frames arrive in one chunk.

## MREPL and REPL buffer contract

The Emacs client owns the live MREPL flow from connection through `create-mrepl`, channel eval, prompt rendering, write-string/write-values rendering, input history, and clean disconnect. REPL buffers are per connection and must not hide the underlying channel state.


## Daily-use package contract

The Emacs package must expose a sane default user surface, not just transport helpers.
At minimum it owns:

- `slynet-mode`: a global minor mode with the `C-c C-s` prefix map;
- `slynet-command-map`: key bindings for connect, disconnect, reconnect, quit, status, health, eval, MREPL, inspector, xref, and debugger commands;
- `slynet-menu`: menu-bar access to the same daily-use commands;
- `slynet-status`: a command returning a structured connection-status plist and echoing a compact status label;
- `slynet-health`: a readable health buffer showing live/stale/off state, endpoint, package, pending requests, and last error;
- `slynet-reconnect`: reconnects through the current endpoint or the last remembered endpoint;
- `slynet-quit`: disconnects and stops a local SLYNET server process when present.

The daily-use UI must stay honest: it may report `live`, `stale`, or `off`, but it must not hide stale/dead process state behind a successful connection object. It should be usable without starting a server automatically, because project-specific server lifecycle policy belongs above this package layer.

## Completion and autodoc contract

Completion candidates preserve source/support metadata as text properties. Flex completion adds cacheable pattern lookups and candidate documentation metadata. Unsupported autodoc subfeatures should be represented as structured pending/unsupported metadata rather than hanging the UI.

## Diagnostics contract

Janet compile/load diagnostics are rendered through `:janet-diagnostics` envelopes. They are not CL compiler-note semantic equivalents, but they carry enough path/line/column/message metadata for Emacs to display and navigate them.

## Namespace and package contract

CL package-facing operations are emulated over Janet modules/environments where possible. The client must preserve prompt/default-directory/package display state while keeping CL-equivalence limitations explicit through generated inventory rationale fields.

## Validation stages

| Stage | Owns |
| --- | --- |
| P1_transport_session_protocol | Deterministic wire framing and message helpers. |
| P2_eval_mrepl_first_real_e2e | Live Emacs to Janet MREPL connection and eval. |
| P5_compile_load_diagnostics | Structured Janet diagnostic envelopes. |
| P6_emacs_repl_buffer_ui | User-facing REPL buffer rendering. |
| P7_completion_autodoc_capf | CAPF and initial autodoc metadata. |
| P13_diagnostics_ui | Clickable diagnostics buffer UI. |
| P14_project_connection_management | Named connections, project root discovery, reconnect seams. |
| P15_completion_parity_deepening | Flex completion, candidate docs, and cache invalidation. |


## P22/P23/P24 implementation notes

P22 unifies compile, runtime, and test failure diagnostics behind Janet
diagnostic envelopes. `compile-string-for-emacs` accepts optional path, line, and
column metadata; `runtime-error-diagnostics` and `test-failure-diagnostic` return
clickable diagnostic records with `:diagnostic-model :janet-diagnostics`,
`:source-index :slynet-diagnostic-source`, and `:cl-compiler-note-equivalent
false`. These records are source-aware UI facts, not CL compiler notes.

P23 adds `namespace-completions`, backed by `slynet/source_index.janet`, so local
project definitions can be completed with file/line/column, module, form kind,
doc summary, support class, and source-index metadata. The source-index cache is
invalidated by file mtime/size changes, which is enough for the current fixture
contract and daily editing loop.

P24 adds project lifecycle status helpers: `ensure-project-server-ready`,
`project-server-status`, `project-server-reconnect`, and
`project-server-note-stale`. They expose observable readiness, reconnect identity
preservation, stale status, reason strings, and status-buffer metadata for the
Emacs side. This is currently an in-process lifecycle/status facade, not a full
external daemon supervisor.

## P29 docs/autodoc/complete-form

The Emacs client provides a scrollable `*slynet-doc*` buffer for Janet docs/autodoc payloads.

- `autodoc` returns operator, arglist, doc text, source locations, `support-class`, and `cl-autodoc-equivalent=false`.
- `complete-form` returns prefix, common prefix, candidates, doc summaries, source-index facts, `support-class`, and `cl-complete-form-equivalent=false`.
- `slynet-doc-symbol` renders autodoc payloads in `slynet-doc-mode`; the buffer uses ordinary Emacs scrolling.

This is not a Common Lisp documentation/autodoc semantic clone. It is a SYYNET docs loop using Janet doc output when available and source-index snippets/locations as enrichment.
