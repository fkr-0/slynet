# SLYNET CL ↔ Janet Equivalence Contract Index

This file is the overview and index for staged SLY/SLYNK frontend-behavior equivalence on Janet. Detailed contracts live in the split spec files referenced below and in `docs/specs/support-matrix.yml`.

## Purpose

SLYNET aims to reproduce the SLY/SLYNK frontend experience for Janet where Janet can support it through native behavior, runtime metadata, source indexing, protocol adapters, or explicit emulation layers. The target is not to claim Janet is Common Lisp. The target is frontend-behavior equivalence: Emacs receives stable protocol shapes, source locations, debugger data, inspection trees, completion metadata, diagnostic records, and connection state that make a SLY-like workflow usable and specifiable.

Unsupported behavior must be explicit. When a CL concept has no direct Janet equivalent, the inventory must record `support_class`, `constraint`, `constraint_reason`, `support_rationale`, `validation_stage`, and `owning_spec` instead of silently collapsing the behavior into a generic missing state.

## Canonical split specs

| File | Owns |
| --- | --- |
| `support-matrix.yml` | Machine-readable phase, surface, constraint, and owning-spec matrix. |
| `janet-extension-candidates.md` | Detailed Janet extension candidates and current workaround rules. |
| `slynk-backend-gap-analysis.md` | Full original SLY/SLYNK backend gap analysis, scope decisions, Janet-extension candidates, and workaround rules. |
| `threading-execution-units.md` | Janet execution-unit model, CL thread facade, cooperative interruption, runtime unit metadata. |
| `debugger-condition-restarts.md` | Debugger state, condition records, restart facades, frame metadata, debugger controls. |
| `inspector-xref-source-index.md` | Inspector object identity, part navigation, xref/source-index records, source navigation. |
| `emacs-client-contract.md` | Transport, MREPL, REPL buffer, diagnostics, namespace/package emulation, completion, connection management. |

## Contract vocabulary

- `native`: Janet exposes the behavior directly with small protocol adaptation.
- `emulated`: SLYNET adds metadata, wrappers, source indexes, registries, runtime instrumentation, or side channels to approximate the frontend behavior.
- `unsupported`: Janet currently exposes no safe substrate and no SLYNET shim exists for the operation.
- `internal`: Implementation detail not intended as a user-facing frontend contract.
- `pending_design`: Accepted target whose final staged contract is not yet written.
- `frontend_equivalent`: Emacs behavior and protocol result shape are equivalent enough for normal SLY-like use, even if the internal semantics differ.
- `semantic_equivalent`: The Janet behavior preserves the same language-level semantics as the CL feature. This should be rare and must be justified.

## Generated inventory rule

Every operation in `docs/generated/protocol-inventory.yml` must describe:

- `frontend_surface`: which UI or protocol surface consumes it.
- `support_class`: native, emulated, unsupported, internal, or pending_design.
- `state_detail`: precise implementation/test state.
- `validation_stage`: the phase that owns executable validation.
- `owning_spec`: the split spec file that owns the contract.
- `constraint`: the CL/Janet mismatch, or `none`.
- `constraint_reason`: required for constrained entries.
- `support_rationale`: required for emulated, unsupported, or pending-design entries.

## Canonical staged phase table

| Phase | Status | Owning spec | Primary contract |
| --- | --- | --- | --- |
| P0 | done | `cl-janet-equivalence-contracts.md` | Inventory truth: support fields, surfaces, constraints, and generated evidence. |
| P1 | done | `emacs-client-contract.md` | Deterministic transport/session framing and message helpers. |
| P2 | done | `emacs-client-contract.md` | Live Emacs to Janet MREPL connection, eval, values, prompts, and cleanup. |
| P3 | done | `threading-execution-units.md`; `debugger-condition-restarts.md` | Execution-unit facade plus condition/restart/debugger payload foundation. |
| P4 | done | `inspector-xref-source-index.md` | Stable inspector identity and source-index-backed xref foundation. |
| P5 | done | `emacs-client-contract.md` | Janet compile/load diagnostic envelopes. |
| P6 | done | `emacs-client-contract.md` | User-facing Emacs REPL buffer. |
| P7 | done | `emacs-client-contract.md` | CAPF completion and arglist/autodoc metadata. |
| P8 | done | `inspector-xref-source-index.md` | Emacs inspector and xref buffers. |
| P9 | done | `debugger-condition-restarts.md`; `threading-execution-units.md` | Emacs debugger and execution-unit buffers. |
| P10 | done | `cl-janet-equivalence-contracts.md`; `support-matrix.yml` | Spec split, support matrix, owning-spec inventory fields, and rationale checks. |
| P11 | done | `inspector-xref-source-index.md` | Interactive inspector part buttons and xref source navigation. |
| P12 | done | `debugger-condition-restarts.md` | Interactive debugger restart buttons and frame source navigation. |
| P13 | done | `emacs-client-contract.md` | Diagnostics UI with source navigation. |
| P14 | done | `emacs-client-contract.md` | Named connections, project-root detection, server/reconnect seams. |
| P15 | done | `emacs-client-contract.md` | Flex completion caching, candidate docs, cache invalidation. |
| P16 | done | `threading-execution-units.md`; `debugger-condition-restarts.md` | Source-aware eval, restart scopes, cooperative interruption metadata, checkpoints. |

## Maintenance rules

1. Add new conceptual contracts to a split spec file, not to this overview.
2. Update `support-matrix.yml` when a new phase, frontend surface, constraint, or owning spec appears.
3. Regenerate `docs/generated/protocol-inventory.yml` after changing inventory ownership logic.
4. Add or update protocol inventory tests before changing generator behavior.
5. Keep `phases.yml` as status and verification history; keep long conceptual explanations in split specs.

## Phase 17: Protocol interface registry alignment

P17 closes the implementation-without-interface gap for staged extension RPCs. The registry contract is now explicit: every implemented extension RPC introduced by a phase must have a matching `slynet/interfaces.janet` declaration unless it is deliberately private/internal and excluded from public RPC dispatch.

The first aligned set covers runtime instrumentation, debugger frame helpers, inspector rendering, macroexpand helpers, thread metadata, and `slynet-apropos`. The detailed contract lives in `protocol-interface-registry.md`.

## Phase 18-20 implementation notes

P18 makes source-index v2 the preferred xref backing model. P19 turns inspector ranges/history/actions into backend contracts. P20 implements the first instrumented synthetic restart scope substrate. These keep the project aligned with the core rule: prefer frontend workflow equivalence with explicit Janet-native metadata over unsupported or misleading CL semantic claims.

| P21 | done | `threading-execution-units.md` | Managed execution-unit registry, cooperative interrupt flags, and lifecycle status. |
| P22 | done | `emacs-client-contract.md` | Source-aware compile/runtime/test diagnostics with explicit Janet diagnostic provenance. |
| P23 | done | `emacs-client-contract.md` | Source-index-backed namespace completions, doc metadata, and cache invalidation. |
| P24 | done | `emacs-client-contract.md` | Project server lifecycle readiness, reconnect identity, and stale status surface. |

| P25 | done | `next-implementation-roadmap.yml` | Backend utility capability records and source-linked SLYNET trace/timing, with unsupported records for non-Janet CL runtime utilities. |
| P26 | done | `protocol-interface-registry.md` | Protocol interface browser plus SLYNET wrapper profile/report facade. |
| P27 | done | `next-implementation-roadmap.yml` | SLYNK-shaped compile/macroexpand wrappers and Janet project/session metadata, with CL compiler/image equivalence false. |
| P28 | done | `emacs-client-contract.md` | Janet namespace browser plus explicit CL package-local nickname non-support. |

## Phase 29: Janet suite architecture and checks

P29 makes the growing Janet contract suite maintainable. It introduces `docs/specs/janet-suite-architecture.yml`, a project-level suite manifest, focused `:suite` execution, a protocol-check script, and a shared test-state reset helper. The goal is not new product behavior; it is faster, stricter, and less noisy verification for future backend phases.
| P29 | done | `emacs-client-contract.md` | Scrollable Janet docs/autodoc/complete-form buffer backed by Janet docs and source-index metadata, with CL documentation/autodoc/complete-form equivalence false. |\n