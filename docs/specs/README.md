# SLYNET Specification Index

This directory is the canonical specification set for staged SLY/SLYNK frontend-behavior equivalence on Janet. The overview explains the vocabulary and phase map; the split files own the executable support contracts used by the protocol inventory.

## Canonical files

- `cl-janet-equivalence-contracts.md`: overview, vocabulary, and canonical P0–P16 phase table.
- `slynk-backend-gap-analysis.md`: full SLY/SLYNK backend gap analysis, scope decisions, Janet-extension candidates, and workaround rules.
- `support-matrix.yml`: machine-readable phase, surface, support-class, and spec-ownership matrix.
- `janet-extension-candidates.md`: detailed Janet extension candidates and current workaround rules.
- `threading-execution-units.md`: execution-unit, thread facade, cooperative interruption, and runtime-instrumentation ownership.
- `debugger-condition-restarts.md`: debugger state, condition records, restart scopes, frame locations, and step/checkpoint ownership.
- `inspector-xref-source-index.md`: inspector object identity, source-index-backed xref, source navigation, and source metadata ownership.
- `emacs-client-contract.md`: transport, MREPL, REPL buffer, diagnostics, connection management, completion, and general Emacs client ownership.
- `protocol-interface-registry.md`: interface declaration and implementation registry alignment for staged extension RPCs.
- `next-implementation-roadmap.yml`: todo roadmap for P18+ implementation phases that should be fixed/implemented with tests.
- `abandoned-cl-semantics.yml`: explicit CL semantic-equivalence boundaries; abandoned literals plus Janet-native keep work that remains planned or implemented.

## Ownership rule

Every generated operation in `docs/generated/protocol-inventory.yml` must include:

- `frontend_surface`
- `support_class`
- `state_detail`
- `validation_stage`
- `owning_spec`

Operations with `support_class: emulated`, `support_class: unsupported`, or `support_class: pending_design` must also include a rationale field explaining why the operation is not direct native Janet support.

## Phase coverage

The support matrix and overview table must represent every staged phase from P0 through the current highest implemented or planned phase. As of this spec split, implemented phases run P0 through P24.
- `janet-suite-architecture.yml` - P29 Janet test-suite architecture, focused suite selector, policy checks, and isolation contract.
