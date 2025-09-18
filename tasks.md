# SLYNET Translation Gaps and Missing Features vs SLYNK

> ⚠️  This backlog is kept for historical context. The authoritative roadmap now lives in `TASKS.md`.

This document tracks the current gaps and missing features in the Janet SLYNET port compared to the original SLYNK (Common Lisp) backend.

---

## 1. Protocol Coverage

- [ ] Not all SLYNK protocol messages are implemented (see `sly_source/` for full list).
- [ ] Channel handling (`process-channel-send`, `process-channel-close`) is stubbed.
- [ ] Advanced REPL features (multithreaded eval, remote threads) are not fully ported.
- [ ] Inspector, apropos, xref, and contrib modules are only partially implemented or stubbed.

## 2. Error Handling

- [ ] Error reporting to Emacs is basic; lacks full SLYNK error protocol fidelity.
- [ ] Disconnection and reconnection logic is minimal.
- [ ] No robust handling for malformed or partial protocol messages.

## 3. Backend Features

- [ ] Many backend interfaces are stubbed or incomplete.
- [ ] No support for project-wide symbol indexing or cross-referencing.
- [ ] No persistent history or session management.

## 4. Testing

- [x] Unit tests for error constructors and macros exist.
- [x] Integration tests for server startup, connection, and protocol roundtrip added.
- [ ] No tests for advanced protocol features, error recovery, or contrib modules.

## 5. Documentation

- [ ] API documentation is incomplete.
- [ ] No user-facing migration or usage guide for SLYNET vs SLYNK.

---

**See also:**  
- [`sly_source/`](sly_source/) for reference SLYNK implementation  
- [`docs/`](docs/) for project documentation standards

_Last updated: 2025-09-05_
