# Roadmap to a SLY-Equivalent Janet Backend

> **Historical planning snapshot.** This checklist is retained for provenance,
> but it is not current release authority. Use `ROADMAP.md` for current project
> priorities, `docs/generated/protocol-inventory.yml` for protocol truth, and
> `docs/RELEASE_STATUS.md` for the audited 1.0.7 works/missing summary.

This document captured the work originally expected for practical parity with
the Common Lisp SLY/SLYNK stack. Some unchecked entries have since been
implemented or deliberately reclassified, so do not derive release claims from
the checkboxes below.

## 1. Foundational Infrastructure
- [x] **Runtime separation** — complete the runtime/server split described in `AGENT.md` (file moves, imports, façade modules).
- [x] **Interface registry audit** — ensure every exported RPC goes through `runtime/interfaces.janet` and `runtime/infrastructure.janet` helpers; remove ad-hoc registration code.
- [x] **Dynamic registry sync** — implement a single entry point to initialize runtime state (`runtime/init.janet` or similar) and call it from the public API.

## 2. Core Protocol Coverage
Track completion status in [`docs/missing_protocol.md`](docs/missing_protocol.md).
- [x] Implement handshake essentials: `ping`, `connection-info`, `list-all-package-names`, `simple-completions`, `flex-completions` (see `slynk.janet` + tests in `test/project_core_tests.janet`).
- [ ] Debugger loop: `backtrace`, `debugger-info-for-emacs`, `invoke-nth-restart`, `sly-db-abort/continue`, frame inspectors.
- [ ] Eval/edit RPCs: `interactive-eval-region`, `pprint-eval`, `set-package`, `value-for-editing`, `commit-edited-value` (**implemented**; extend with inspector/debugger features next).
- [ ] Compiler services: `compile-file-for-emacs`, `compile-string-for-emacs`, macroexpand family, `load-file`, `slynk-require`.
- [ ] Inspector & xref: inspector RPC suite, `find-definitions-for-emacs`, `xref/xrefs`.
- [ ] Thread ops: `list-threads`, `debug-nth-thread`, `kill-nth-thread`.
- [ ] Stream utilities: `io-speed-test`, `flow-control-test`.

## 3. Contrib Parity
- [x] Audit every contrib module in `slynet/contrib/` for interface coverage vs the Lisp originals.
- [x] Implement missing RPCs listed under the Contrib section of `docs/missing_protocol.md`.
- [x] Add focused tests per contrib module using the shared test harness.

## 4. Runtime Services
- [x] Provide working implementations for filesystem interfaces (`list-directory`, `read-file`, `write-file`, etc.) with sandbox awareness.
- [x] Flesh out REPL support: implement `interactive-eval`, `eval-for-emacs`, package management hooks (`set-package`, `guess-and-set-package`).
- [ ] Implement arglist/signature introspection that mirrors SLY expectations (`arglist`, `operator-arglist`, `describe-function`).
- [ ] Add persistent session state (history, bookmarks) surfaced via interfaces.

## 5. Server & Transport Layer
- [x] Harden TCP listener lifecycle (graceful shutdown, restart, error handling).
- [x] Channel support (`process-channel-send/close`, MREPL channels) with exhaustive tests using the in-memory harness.
- [ ] Implement structured logging with verbosity levels and timestamps; expose toggles via RPC (`toggle-debug-on-slynk-error`).
- [ ] Provide TLS or SSH tunnel guidance for remote connections.

## 6. Tooling & Testing
- [x] Migrate all legacy `judge` tests to `test-runner.janet`; ensure determinism.
- [x] Build fixture utilities under `test/support/` for fake module caches, network sockets, and filesystem sandboxes.
- [x] Add smoke tests for the CLI client (`slynet-client.janet`) using the in-memory server (updated to exercise the MREPL handshake/results path).
- [ ] Integrate a CI script (GitHub Actions or similar) running lint + tests.
- [x] Capture coverage on interface implementations—insist every RPC has at least one test.

## 7. Developer Experience
- [ ] Expose a high-level Janet API (`slynet/api.janet`) that hides registry plumbing and offers `start`, `stop`, `with-server` helpers.
- [ ] Document extension points for third-party contribs (`docs/dev-guides/`).
- [ ] Provide examples in `examples/` demonstrating eval, inspector, and breakpoints.

## 8. Release Readiness
- [ ] Write migration notes for Common Lisp SLY users switching to Janet.
- [ ] Tag semantic versions once core protocol parity is achieved.
- [ ] Package scripts for `janet -m slynet/server/start` usage (respecting Janet module loader conventions).

Keep the checklist synchronized with actual work. When tasks are completed, link to the implementing commit or PR for traceability.
