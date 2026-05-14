# SLYNET Agent Operations Guide

## Mission Brief
- Maintain and extend the Janet port of the SLY/SLYNK backend. The goal is feature parity with the Common Lisp implementation while keeping Janet idioms.
- Keep the developer experience smooth: fast feedback loops, reliable tests, and clear runtime separation between protocol/server plumbing and Janet runtime capabilities.
- Handshake endpoints (`ping`, `connection-info`, `list-all-package-names`, `simple-completions`, `flex-completions`) are live—treat regressions here as stop-the-line issues.
- Interactive editing RPCs (`set-package`, `interactive-eval-region`, `pprint-eval`, `value-for-editing`, `commit-edited-value`) now have Janet implementations; any changes here must be backed by tests under `test/project_core_tests.janet`.

## Environment Setup
- **Janet**: Target Janet ≥ 1.28. Export `JANET_PATH="$JANET_PATH:$(pwd)"` when working locally so `import slynet/...` resolves.
- **Dependencies**: Only core Janet + stdlib. Tests embed their own harness; no external packages required.
- **Editor**: Emacs + SLY optional but useful for manual verification.

## Everyday Commands
- `janet test-runner.janet` — run the full suite (after tests are migrated to the unified runner).
- `janet test-runner.janet :match core` — focus on tests whose names contain `core`.
- `janet test-runner.janet :tags slow` — once tagging is in place, target subsets.
- `janet slynet/server/start.janet` — boot the TCP server (defaults to localhost:4005).
- `janet slynet-client.janet :host 127.0.0.1 :port 4005` — CLI smoke-test client.
- `make lint` — optional formatting check when `janet-format` is installed.

## Test Infrastructure
- All tests should register through `test-runner.janet` (mini harness with assertion macros in `test-tools.janet`). Avoid ad-hoc `judge` usage going forward.
- For RPC/server tests prefer the in-memory harness from `test-tools.janet` (`with-test-server` / `test/make-server`). This avoids flaky socket teardown.
- Integration tests that must exercise the real TCP listener should live under `test/server` and be annotated with `:tags [:network]` so they can be skipped in CI.

## Source Layout (target state after refactor)
- `slynet/runtime/` — Janet-facing runtime and interface layer.
  - `interfaces.janet` — declarative RPC interface definitions.
  - `infrastructure.janet` — registries + defimpl helpers.
  - `backend.janet`, `types.janet`, `primitives.janet`, `macros.janet`, `gray.janet`, `utils.janet` — Janet runtime implementations.
- `slynet/server/` — protocol plumbing and network server.
  - `rpc.janet`, `slynk.janet`, `init.janet`, `start.janet`, `completion.janet`, `print-for-emacs.janet`, `xref.janet`.
- `slynet/contrib/` — contrib feature ports (structure unchanged).
- `test/` — spec-style tests using `test-runner.janet`; server fixtures in `test/support/` (create as needed).
- `docs/` — architecture notes, missing protocol coverage, task trackers.

Ensure imports use the new layout, e.g. `(import ./runtime/interfaces :as interfaces)` or `(import ./server/rpc :as rpc)`.

## Coding Guidelines
- Keep modules small and capability-oriented (runtime vs server responsibilities).
- Every new RPC must: declare in `runtime/interfaces.janet`, implement via `runtime/infrastructure.janet` helpers, and register tests.
- Prefer pure functions for protocol transforms; isolate side effects behind clearly named functions.
- Add docstrings and spec comments for non-obvious code paths; avoid noise comments.

## Release Checklist
- Update `TASKS.md` status for any completed SLY parity items.
- `janet test-runner.janet` must pass (include server tests when relevant).
- Verify the CLI smoke test (`slynet-client.janet`) can evaluate an expression against the test server.
- Regenerate or touch `docs/` when interfaces or protocols change.

## Common Pitfalls
- Forgetting to sync the dynamic interface registry after loading modules. Use `runtime/infrastructure.slynet-sync-rpc-registries!` in tests before dispatching.
- Leaving running TCP servers after tests. Always wrap with `with-test-server` or ensure `(srv :dispose)` is deferred.
- Import cycles when moving files; use thin façade modules if two layers need to talk.

Keep this document current—agents rely on it for fast onboarding and consistent operations.
