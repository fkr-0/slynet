# SLYNET roadmap

This is the authoritative project-level roadmap after the public 1.0.7 release.
Operation-level truth is generated into `docs/generated/protocol-inventory.yml`;
current-main interpretation belongs in `docs/DEVELOPMENT_STATUS.md`. Historical
checklists such as `TASKS.md` and `docs/missing_protocol.md` are not release
authority.

## Program target

```yaml
current_release: 1.0.7
next_release: 1.1.0
repository: https://github.com/fkr-0/slynet
release_strategy: capability_first
security_boundary: trusted_localhost_by_default
non_goal: literal_Common_Lisp_runtime_parity
```

The 1.1.0 theme is **truthful capability consolidation**: make coverage evidence
machine-auditable, expose one stable Janet API, turn existing instrumentation
scaffolding into deliberate products, and improve the Emacs daily workflow
without overstating Janet debugger/runtime semantics.

## P0 — Protocol truth and test correspondence

```yaml
priority: P0
status: in_progress
release_blocker: true
```

### Work

- [x] Discover the complete tracked SLY/SLYNK reference corpus, including
  profiler, trace-dialog, stickers, retro, and indentation contrib sources.
- [x] Replace incidental string matching with explicit per-test `:covers`
  metadata.
- [x] Distinguish definition evidence from callable RPC registration evidence.
- [x] Add `implemented_unwired` so translated helper code is not mistaken for a
  usable endpoint.
- [x] Advance generated inventory to schema v5 with `definition_files`,
  `registration_files`, `test_files`, and evidence kind.
- [ ] Add a fifth state/evidence flag for registered implementations that are
  explicit unsupported/error stubs, so registration alone cannot imply product
  functionality.
- [ ] Annotate every release-critical RPC test with `:covers` and eliminate
  ambiguous direct mappings.
- [ ] Add CI thresholds by frontend surface rather than one global percentage.
- [ ] Generate a coverage summary page from the inventory and fail CI when docs
  claim more than the generator proves.

### Current corrected baseline

```yaml
reference_operations: 284
callable_directly_tested: 44
callable_without_direct_mapping: 37
defined_but_unwired: 18
missing: 185
support_classes:
  native: 249
  emulated: 33
  unsupported: 2
```

### Acceptance

- no operation is `implemented` without callable-registration evidence;
- no operation is `implemented_*_tested` without explicit `:covers` evidence;
- every user-facing release claim resolves to at least one implementation,
  direct test, or explicitly documented workflow/E2E proof;
- inventory generation is deterministic and freshness-gated in CI;
- direct coverage for transport, REPL, completion, compile/load, inspector,
  xref, and debugger release-critical operations reaches 100% of the declared
  stable subset, not necessarily 100% of the historical SLYNK corpus.

## P1 — Stable Janet embedding API

```yaml
priority: P0
status: in_progress
release_blocker: true
api_version: 1
```

### Work

- [x] Replace the commented `slynet/slynet-api.janet` scaffold with a
  compatibility shim.
- [x] Add canonical `slynet/api.janet`.
- [x] Expose version/capabilities, initialization, RPC metadata lookup,
  in-process RPC invocation, and server start/stop.
- [x] Refuse accidental non-loopback TCP binding unless the embedding caller
  explicitly opts into a different trust boundary.
- [x] Ensure supported core RPC implementations are registered before
  `initialize` returns.
- [ ] Add a lifecycle object/context helper that owns initialization, server,
  and teardown without requiring callers to understand CLI internals.
- [ ] Add client/session helpers only where semantics can remain transport-
  independent; keep package/channel/session-state RPCs on real connections.
- [ ] Define API-v1 compatibility policy and deprecation rules.
- [ ] Add API examples and package-level documentation to release artifacts.

### Acceptance

- an embedding program imports only `slynet/api` for supported public tasks;
- `initialize` followed by `call-rpc 'ping` returns `:pong`;
- server lifecycle has deterministic teardown;
- no stable API requires direct access to infrastructure registries;
- public API security defaults are loopback-only.

## P2 — Daily-use Emacs workflow

```yaml
priority: P1
status: planned
release_blocker: true
```

### Work

- [ ] Add Janet-aware `eval-last-form`, `eval-region`, `eval-definition`, and
  `eval-buffer` commands.
- [ ] Add `load-current-file` and compile/load-buffer/file workflows with
  structured diagnostics.
- [ ] Add interrupt/cancel commands that target the current request or managed
  execution unit and render the actual outcome.
- [ ] Make project connect/start/reconnect one coherent command path with clear
  ownership of Emacs-started server processes.
- [ ] Add inspector history/back/forward/action commands and discoverable keys.
- [ ] Improve debugger source navigation and capability-aware action buttons.
- [ ] Improve reconnect/session-loss UX so buffers become visibly stale rather
  than silently retaining dead connection state.
- [ ] Add ERT and live E2E coverage for each interactive command.

### Acceptance

A normal Janet editing session can start/connect, evaluate common units, load a
file, navigate a definition, inspect a result, diagnose an error, recover from a
server restart, and quit without manually typing protocol forms.

## P3 — Debugger stepping and resumability

```yaml
priority: P1
status: design_and_substrate
release_blocker: false
semantic_rule: do_not_fake_runtime_continuations
```

### Architecture

SLYNET already owns source maps, execution-unit state, cooperative interruption,
synthetic restart scopes, and a pending `debugger-step-checkpoint`. These are a
useful substrate but **not** a resumable Janet continuation. Full step/next/out
must therefore be split into two capability tiers.

```text
instrumented Janet code
       |
       v
execution unit + source map
       |
       v
cooperative checkpoint --------> paused session record
       |                              |
       |                              +-- continue
       |                              +-- step-into (next checkpoint)
       |                              +-- step-over (same/lower depth)
       |                              +-- step-out  (shallower depth)
       v
completion/error

native runtime continuation support, if Janet exposes it later
       |
       +--> upgrades capability class; never assumed by the facade
```

### Work

- [ ] Define `DebuggerSession` records: stable session id, execution-unit id,
  pause reason, source span, call depth, checkpoint sequence, action state,
  deadline, and terminal state.
- [ ] Define explicit capability classes: `inspection_only`,
  `cooperative_checkpoint`, and future `runtime_resumable`.
- [ ] Build cooperative pause/resume state machine around instrumented
  checkpoints with disconnect/cancel/deadline cleanup.
- [ ] Implement step-into/over/out semantics for instrumented code using
  checkpoint sequence + call-depth invariants.
- [ ] Keep uninstrumented/native-frame stepping reported as unsupported until a
  real Janet substrate exists.
- [ ] Add breakpoints as source-index entries that compile/evaluate into
  checkpoints rather than pretending to patch arbitrary native frames.
- [ ] Render capability-aware Emacs debugger controls.
- [ ] Stress test races: action after completion, double resume, disconnect while
  paused, cancellation while paused, stale session id, nested errors.

### Acceptance

- every accepted debugger action causes one deterministic session-state
  transition;
- no paused session leaks after connection loss or deadline;
- step-over never stops deeper than its origin depth; step-out stops only at a
  shallower depth or terminal completion;
- unsupported native/runtime behavior is surfaced as such, never as success.

## P4 — Profiler, tracing, timing, and stickers

```yaml
priority: P1
status: partial_existing_substrate
release_blocker: false
```

### Current truth

- core `profile`, `profile-reset`, `profile-package`, and `profile-report` are
  callable and directly tested wrapper-based profiling facilities;
- core `slynet-trace-eval`, report, and clear operations produce source-linked
  timing/trace records and are directly tested;
- legacy trace-dialog contains real wrapper/helper code, but several operations
  are currently **defined but unwired**;
- sticker registry/recording scaffolding exists, while compile-time source
  instrumentation such as `compile-for-stickers` is genuinely missing.

### Work

- [ ] Consolidate core and legacy profiler/trace implementations behind one
  instrumentation registry and one record schema.
- [ ] Wire only trace-dialog operations whose behavior is implemented and tested;
  keep incomplete operations missing rather than registering stubs.
- [ ] Add nested timing trees with stable parent/child event ids and bounded
  retention.
- [ ] Add function-call counters, inclusive/self time, source provenance, and
  deterministic reset semantics.
- [ ] Design sticker instrumentation as Janet source/AST rewriting with a source
  map, not as a CL bytecode analogy.
- [ ] Implement compile-for-stickers -> instrumented form -> recording -> inspect
  flow with bounded recording storage.
- [ ] Add Emacs profiler/trace/timing/sticker views after backend semantics are
  stable.
- [ ] Add overhead and bounded-memory tests; instrumentation must be opt-in.

### Acceptance

- tracing/profiling records identify source and instrumented callable exactly;
- timing trees preserve nesting and bounded retention;
- sticker recordings are produced by real injected checkpoints and are
  inspectable end-to-end;
- no legacy contrib endpoint is marked implemented merely because helper code
  exists.

## P5 — Documentation and public site

```yaml
priority: P1
status: in_progress
release_blocker: true
```

### Work

- [x] Publish canonical repository `fkr-0/slynet`.
- [x] Publish immutable GitHub release `v1.0.7` with qualified artifacts and
  release evidence.
- [x] Correct README installation/publication wording for the canonical repo.
- [x] Freeze `docs/RELEASE_STATUS.md` as the historical 1.0.7 snapshot and add a
  current-main development status document.
- [x] Document the stable embedding API.
- [x] Add GitHub Pages landing page generated from `docs/`.
- [x] Add a pinned GitHub Actions Pages workflow and custom-domain declaration
  for `slynet.fkr.dev`.
- [ ] Enable Pages in repository settings and verify the deployed custom-domain
  URL and HTTPS certificate.
- [ ] Add docs-to-implementation checks for public command/API names.
- [ ] Add migration notes for SLY users describing semantic differences rather
  than only command substitutions.

### Acceptance

- every public quickstart command is executable from a fresh clone;
- every documented public Janet symbol exists and has a focused test;
- Pages exposes release, install, support matrix, development status, embedding
  API, security boundary, and roadmap;
- release status and development status cannot be confused.

## P6 — 1.1.0 qualification

```yaml
priority: P0
status: blocked_on_P0_P1_P2_P5
```

### Gate

- [ ] bump all canonical version surfaces to 1.1.0 only after the stable API and
  daily Emacs command set are accepted;
- [ ] run the full Janet + Emacs + fuzz + lifecycle + extracted-artifact gate;
- [ ] run compatibility matrix on Janet 1.40.x/1.41.x and Emacs 27.1-30.x;
- [ ] verify generated protocol inventory and public docs freshness;
- [ ] verify `make publication-verify` against canonical origin;
- [ ] tag immutable `v1.1.0`, publish artifacts/evidence, and verify Pages links.

## Sequencing

```text
P0 truth/mapping ─────┐
                      ├─> P1 stable Janet API ─┐
                      │                         ├─> P6 1.1.0
                      └─> P2 Emacs workflow ───┤
                                                │
P3 debugger sessions/checkpoints ───────────────┤  (may continue after 1.1.0)
P4 instrumentation consolidation ───────────────┤
P5 docs/Pages/publication ──────────────────────┘
```

P0, P1, P2, and P5 define the 1.1.0 product boundary. P3/P4 may land in 1.1.0
when their acceptance gates are met, but they must not delay truthful stable API
and editor improvements by requiring runtime semantics Janet does not expose.
