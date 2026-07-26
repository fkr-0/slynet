# Janet Extension Candidates for SLYNET

Status: executable support-spec companion.

This document expands the Janet extension candidates named by the backend gap analysis. These candidates are not 1.0.0 requirements. They record where SLYNET has enough workaround support today and where deeper SLY-like parity would benefit from more Janet runtime, debugger, signal, metadata, or instrumentation substrate.

## Direction rule

SLYNET must prefer truthful Janet facts in this order:

1. native Janet runtime, debugger, signal, and introspection data;
2. SLYNET-owned metadata registries, source indexes, and instrumentation records;
3. explicit synthetic facades, marked as synthetic or emulated;
4. explicit unsupported or pending-design records when no honest fallback exists.

SLYNET must not hide a Janet substrate gap by claiming Common Lisp equivalence.

## Terminology: workaround facade vs runtime extension

A SLYNET workaround facade is code implemented in this project, above the Janet runtime. It may use source indexes, metadata registries, wrapper records, diagnostic envelopes, synthetic restarts, or Emacs-facing compatibility payloads. A workaround facade must be honest about provenance: it must mark support as workaround, emulated, unsupported, or pending-design when the facts do not come from Janet itself. It may improve the user experience, but it must not claim that Janet exposes native VM, debugger, signal, source-map, metadata, or instrumentation support that does not exist.

A Janet runtime extension is a change or stable public API in Janet itself, or in a Janet-native subsystem, that exposes new VM/runtime facts directly. This includes native source maps for evaled forms, named debug-frame locals, resumable debug sessions, structured signal metadata, uniform callable metadata, or low-overhead instrumentation hooks. A runtime extension can later let SLYNET upgrade a candidate from workaround or pending-design to native support, but only after the native API exists and tests prove that SLYNET consumes that native API.

Decision rule: every candidate in this document must name both the current SLYNET workaround facade and the potential Janet runtime extension. Implementing a SLYNET facade is useful release work, but it is not the same thing as extending Janet.

## Candidate matrix

| id | current support class | current workaround | 1.0.0 rule |
| --- | --- | --- | --- |
| stable_eval_source_maps | workaround | source-index fallback and snippets | do not mark dynamic locations native unless native source-map data exists |
| rich_debug_frame_locals | workaround | debug-stack slots, limited locals, printed values | do not invent local names |
| resumable_debugger_control_api | pending-design | wrap current Janet debugger controls where available; otherwise mark unsupported | expose controls only with support metadata |
| structured_signal_metadata | emulated | SLYNET condition records and diagnostic envelopes | keep CL condition/restart equivalence false for facades |
| function_arg_metadata | workaround | arglist cache, overrides, metadata registry | display provenance for inferred or overridden signatures |
| instrumentation_hooks | workaround | SLYNET wrapper and recording layer | state whether records came from wrapper, source transform, debugger control, or native hook |

## stable_eval_source_maps

Problem: dynamically evaluated forms do not yet carry a complete stable source-map object through diagnostics, xref, and debugger frames.

Current workaround: source-index fallback and snippets. SLYNET uses explicit source-kind metadata so source-index locations are not confused with native stack locations.

Potential Janet extension: stable source maps for evaluated forms, including file or buffer identity, line, column, form span, evaluation id, and parent form id. Those facts should be visible to diagnostics and debugger frame metadata.

SLYNET acceptance rule: source-index and synthetic locations must stay explicitly marked. Dynamic or eval locations must not be labeled native unless the facts came from native Janet metadata.

## rich_debug_frame_locals

Problem: the Emacs debugger wants frame locals, values, names, and source context. Janet debug-stack data is useful but may expose limited locals or VM slots rather than stable lexical names.

Current workaround: use Janet debug-stack facts first, then render slots, limited locals, printed values, program counter, status, tail-call marker, and C-frame marker when present.

Potential Janet extension: stable local-variable metadata for debugger frames, including lexical name, slot index, value availability, optimized-away markers, closure capture status, and temporary-slot provenance.

SLYNET acceptance rule: SLYNET may print unknown slots, but must not invent lexical local names. Generated placeholders must be marked as SLYNET-produced or synthetic.

## resumable_debugger_control_api

Problem: original SLY debugger controls include continue, abort, restart selection, step, next, out, frame operations, and selected frame control. Janet exposes some debugger substrate, but SLYNET must not present controls as native when no suspended Janet debug session supports them.

Current workaround: wrap available Janet debugger controls only where a caught or suspended debug fiber can support them. Keep unavailable controls as unsupported or pending-design. Keep abort-to-repl synthetic and emulated.

Potential Janet extension: public resumable debug session API with explicit fiber status, stepping mode, resume result, control capability discovery, source location, and failure reason.

SLYNET acceptance rule: no step, next, out, or continue control may claim native support unless it operates on a real Janet debug fiber or session. Unsupported controls must carry support rationale.

## structured_signal_metadata

Problem: original SLY condition handling has condition classes, restarts, condition printing, and debugger entry semantics. Janet error signaling is fiber and signal based and does not expose a CL condition hierarchy.

Current workaround: SLYNET condition records and diagnostic envelopes carry support class, CL equivalence flags, source phase, message, and source evidence when available.

Potential Janet extension: structured signal metadata with signal kind, source phase, originating fiber, nested causes, stack identity, source-map identity, and user-facing message.

SLYNET acceptance rule: condition records must keep cl-condition-equivalent false unless a documented Janet condition object is introduced. Restart records must keep cl-restart-equivalent false for synthetic restart affordances.

## function_arg_metadata

Problem: SLY autodoc and arglist features expect callable signatures and documentation. Janet functions, macros, native functions, and dynamic callables may not expose uniform metadata.

Current workaround: arglist cache, overrides, source scanning, and metadata registry entries. Unknown or inferred arglists remain marked as inferred or unknown.

Potential Janet extension: stable callable metadata for user functions, macros, native functions, and callable abstract types. Useful fields include required, optional, and rest parameters, macro status, docstring, source location, and provenance.

SLYNET acceptance rule: autodoc must display provenance or support class when a signature is inferred, cached, or overridden. Native functions without metadata must not be presented as fully introspected.

## instrumentation_hooks

Problem: original SLY contrib surfaces include tracing, stickers, profiling, timing, and recording views. SLYNET can wrap functions or instrument selected call sites, but low-overhead runtime-level instrumentation is not guaranteed.

Current workaround: SLYNET wrapper and recording layer. Trace, sticker, profiling, and timing records carry support class and instrumentation source.

Potential Janet extension: stable low-overhead instrumentation for function entry and exit, call-site recording, evaluation-region identity, timing samples, profiling samples, debugger events, and sticker events.

SLYNET acceptance rule: instrumentation records must state whether they came from wrapper instrumentation, source transformation, debugger control, or native runtime support. Missing runtime-level support must be pending-design or workaround, not native.

## Cross-spec ownership

| candidate id | primary specs |
| --- | --- |
| stable_eval_source_maps | inspector-xref-source-index.md; emacs-client-contract.md |
| rich_debug_frame_locals | debugger-condition-restarts.md |
| resumable_debugger_control_api | debugger-condition-restarts.md |
| structured_signal_metadata | debugger-condition-restarts.md; emacs-client-contract.md |
| function_arg_metadata | emacs-client-contract.md |
| instrumentation_hooks | threading-execution-units.md; debugger-condition-restarts.md |


## Implemented SLYNET workaround APIs

The five requested candidates now have concrete SLYNET-level facade APIs. These
APIs are deliberately marked as workaround, emulated, unsupported, or
pending-design where Janet does not expose native VM facts.

| candidate id | implemented API surface | support boundary |
| --- | --- | --- |
| stable_eval_source_maps | source-aware-eval; lookup-eval-source-map | records eval-id, path, line, column, snippet, and stable-native-source-map=false |
| rich_debug_frame_locals | debugger-info-for-emacs; debugger-frame-details; frame-locals-and-catch-tags | exposes Janet debug-stack locals/slots with locals-support-class=workaround and cl-lexical-locals-equivalent=false |
| resumable_debugger_control_api | debugger-control-capabilities; debugger-control-action | capability discovery is available; step/next/out/continue actions return unsupported/pending-design until a native resumable debug session exists |
| function_arg_metadata | register-function-metadata; function-metadata; list-function-metadata | metadata registry records arglist, documentation, source, support-class=workaround, and native-janet-metadata=false |
| instrumentation_hooks | record-instrumentation-event; list-instrumentation-events; clear-instrumentation-events | wrapper/recording events carry hook-kind=slynet-wrapper and native-instrumentation-hook=false |

Required verification command:

- JANET_PATH=$PWD janet test/run_tests.janet :match 'extension candidates expose concrete workaround facades' :report compact

## Enforcement

Executable tests must enforce that this document, the spec index, the overview, and support-matrix.yml name all six candidate ids and preserve each candidate's workaround, potential Janet extension, and SLYNET acceptance rule.
