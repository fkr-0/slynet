# SLYNET Roadmap to Full Feature Parity

## Goal

Bring SLYNET from a working Janet-native SLY/SLIME-style backend to a feature-complete, dependable, editor-facing development environment with parity on the most important SLY workflows.

This roadmap assumes the current project state is:

- core RPC registry and dispatch working
- connection/handshake working
- completion/eval/edit cycle working
- basic xref, inspector, debugger, compiler, and threading surfaces present
- bridge-based test command present
- integration suite green at the current checkpoint

The remaining work is no longer “make anything work at all”, but “close quality, depth, and protocol parity gaps”.

---

## Parity definition

For this project, “full feature parity” does **not** mean byte-for-byte SLIME/SLY internals.
It means:

1. the Emacs frontend can rely on the same major interaction surfaces,
2. the protocol behavior is stable and predictable,
3. Janet-specific behavior is represented in a first-class way,
4. common editor workflows work without fallback hacks or shallow placeholders.

---

## Current baseline

### Already substantially present

- connection handshake / connection-info / ping
- package switching
- eval / pprint-eval / interactive-eval-region
- value-for-editing / commit-edited-value
- simple and flex completions
- basic arglist / describe-function
- basic xref surface
- basic inspector surface
- minimum debugger loop
- compile-string-for-emacs
- compile-file-for-emacs / load-file / slynk-require surfaces
- basic thread utilities
- bridge.yml command integration
- integration-heavy Janet test suite

### Still below parity quality

- debugger depth and restart/frame semantics
- xref precision and result ranking
- inspector richness and object navigation
- thread model realism
- compiler and file-loading workflow depth
- stream / channel / flow-control behavior
- contrib parity and editor smoke coverage
- packaging / CI / release ergonomics

---

## Milestone plan

## M0 — Stabilized usable baseline

### Goal
Ship a first version that is dependable for normal interactive use.

### Scope

- keep current green suite stable
- remove shallow fallback behavior where it can mislead the editor
- document supported RPCs and unsupported ones explicitly
- add one reproducible editor-session smoke path
- ensure startup / connect / eval / inspect / xref / compile / quit all work in sequence

### Exit criteria

- test suite green
- one documented smoke path from editor startup to interactive session
- no intentionally fake success responses on critical RPCs
- unsupported RPCs fail clearly and consistently

---

## M1 — Debugger parity core

### Goal
Make debugging genuinely useful instead of minimum-loop only.

### Work

#### Condition and restart model

- represent Janet errors with stable debugger payloads
- preserve condition type, message, and triggering context
- support real restart inventory
- ensure restart names/descriptions are stable for editor consumption

#### Frame model

- deepen `backtrace`
- improve `debugger-frame-details`
- improve `frame-source-location`
- improve `frame-locals-and-catch-tags`
- expose meaningful Janet frame data even when direct CL-style frame parity is impossible

#### Debugger commands

- reliable continue/abort behavior
- restart invocation by ordinal and by semantic name
- frame inspection from editor
- condition inspection entrypoint that maps cleanly into inspector

### Exit criteria

- debugger works for eval failures and compile/load failures
- backtrace includes useful frame identity and source hints
- restart operations behave consistently under tests
- dedicated debugger integration tests cover multiple failure classes

---

## M2 — Introspection parity core

### Goal
Make editor-assisted discovery reliable: xref, inspector, arglists, and descriptions should feel trustworthy.

### Work

#### Xref

- replace synthetic fallback ranking with true definition ranking where possible
- improve exact-definition detection
- rank hits by exact definition > exact symbol mention > loose match
- enrich hit payloads with stable kind, snippet, and source location semantics
- add support for Janet-specific definition forms/macros/modules

#### Inspector

- richer rendering for arrays, tuples, tables, buffers, functions, fibers, and Janet-specific values
- stable part navigation
- support nested drill-down without lossy rendering
- add actions for reinspection and parent/child traversal
- improve condition/object inspection integration

#### Callable introspection

- improve arglist extraction quality
- improve `describe-function` details
- expose macro/function distinctions more reliably
- provide Janet-aware metadata when doc/introspection is partial

### Exit criteria

- xref first hit is usually the exact definition for common symbols
- inspector navigation is useful on composite Janet objects
- arglist/describe-function outputs are reliable enough for real editing help
- tests cover exact/near xref ranking and nested inspector traversal

---

## M3 — Threading and concurrency parity core

### Goal
Provide realistic editor-facing concurrency support instead of placeholder thread utilities.

### Work

- define the SLYNET thread model in Janet terms
- stabilize `list-threads`
- improve `thread-info`
- support thread selection, inspection, and debug targeting
- clarify what is a real OS thread, Janet fiber, connection worker, or logical task
- connect debugger state to thread identity consistently
- ensure concurrency-related RPCs do not lie about capabilities

### Exit criteria

- thread listing/selection/debugging semantics are documented and tested
- thread metadata is stable and useful
- thread-directed debugging works on real runnable targets
- unsupported concurrency semantics are clearly surfaced instead of guessed

---

## M4 — Compiler, file, and load workflow parity

### Goal
Make file-based development as strong as string-eval workflows.

### Work

- deepen `compile-string-for-emacs`
- improve `compile-file-for-emacs`
- improve `load-file`
- support compiler notes / warnings / source locations
- preserve location information across load/compile
- handle Janet module loading cleanly
- improve `slynk-require` for contrib/module activation

### Exit criteria

- compile/load results include useful notes and source references
- editor can navigate from compiler output back to source
- compile/load failures enter debugger or error flows predictably
- tests cover success, warnings, and hard failures

---

## M5 — Channel, REPL, and stream behavior parity

### Goal
Make interactive sessions feel like a true SLY development backend.

### Work

- strengthen MREPL/channel behavior
- improve stream handling and flow control
- verify large output behavior
- verify prompt/value/write semantics
- add realistic incremental interaction tests
- ensure async channel behavior does not deadlock or corrupt replies

### Exit criteria

- REPL interactions are stable under long or incremental output
- stream/flow-control probes reflect real behavior
- no protocol corruption under heavy interactive traffic

---

## M6 — Frontend and contrib parity

### Goal
Adapt frontend expectations cleanly for Janet without keeping the editor in a half-supported state.

### Work

- audit frontend assumptions against current backend RPCs
- mark unsupported contribs explicitly
- implement or adapt the highest-value contrib surfaces first
- define Janet-specific UX where CL-specific behavior does not map directly
- document compatibility boundaries per contrib/module

### High-priority contrib/editor surfaces

- inspector-related contribs
- apropos / symbol search
- macroexpand helpers
- REPL helpers
- compilation navigation helpers
- xref/editor navigation helpers

### Exit criteria

- supported frontend features are documented and tested
- unsupported contribs fail clearly, not mysteriously
- one real editor configuration path is documented and reproducible

---

## M7 — Packaging, release, and maintenance parity

### Goal
Turn SLYNET into a project others can install, test, and contribute to reliably.

### Work

- high-level API / public embedding surface
- root-level architecture and protocol docs
- CI for test suite and smoke checks
- release checklist and versioning policy
- changelog discipline
- contribution guide
- compatibility matrix for Janet versions and editor expectations

### Exit criteria

- reproducible CI
- release notes and tagged release process
- setup instructions for developers and users
- roadmap updated after each milestone

---

## Cross-cutting engineering tracks

## A. Protocol correctness

- preserve request/reply correlation
- unify error payload shape
- separate placeholder behavior from supported behavior
- document every RPC surface that exists today

## B. Test architecture

- keep the current integration-heavy suite green
- add targeted suites per subsystem:
  - debugger
  - xref
  - inspector
  - threading
  - compiler/load
  - channel/stream
- add editor-session smoke coverage
- add regression tests for every protocol bug fixed during parity work

## C. Janet-first semantics

- do not force CL semantics where Janet has a better native model
- provide translation layers where the frontend expects CL-ish behavior
- explicitly document every intentional Janet-specific divergence

## D. Documentation

- protocol support matrix
- supported vs partial vs unsupported feature matrix
- debugging/introspection/threading semantics docs
- editor setup and smoke-run instructions

---

## Priority order

If work must be sequenced aggressively, use this order:

1. debugger depth
2. xref precision
3. inspector richness
4. compiler/load workflow depth
5. thread realism
6. REPL/channel/stream behavior
7. contrib/frontend polish
8. packaging/CI/release work

Reasoning:

- debugger/xref/inspector are the highest-leverage “feels real vs feels shallow” surfaces
- compiler/load is necessary for file-based development
- thread realism matters after the main single-session experience is dependable
- packaging/CI is essential, but only after the semantics are worth freezing

---

## Suggested issue breakdown

### Debugger

- [ ] normalize debugger state schema
- [ ] improve restart representation
- [ ] improve frame detail payloads
- [ ] source-location accuracy pass
- [ ] locals rendering pass
- [ ] debugger regression suite

### Xref

- [ ] exact-definition ranking pass
- [ ] support Janet-specific definition forms
- [ ] remove synthetic fallback where real hit discovery is available
- [ ] xref ranking regression suite

### Inspector

- [ ] richer renderers for Janet value kinds
- [ ] nested navigation improvements
- [ ] condition/object integration polish
- [ ] inspector regression suite

### Threading

- [ ] formalize thread/fiber/task semantics
- [ ] improve thread-info payload
- [ ] real debug-nth-thread behavior
- [ ] concurrency regression suite

### Compiler / load

- [ ] compiler notes/warnings model
- [ ] source-linked compile results
- [ ] load-file location behavior
- [ ] failure-mode debugger integration

### Streams / channels

- [ ] large output handling
- [ ] incremental reply safety
- [ ] flow control realism
- [ ] REPL/channel regression suite

### Project / release

- [ ] architecture doc
- [ ] support matrix doc
- [ ] CI pipeline
- [ ] release checklist
- [ ] changelog discipline

---

## Definition of done for full parity

SLYNET can be considered at “full feature parity” when:

- an editor user can connect, inspect, debug, complete, compile, xref, and iterate without hitting shallow placeholders in normal workflows,
- debugger/xref/inspector behavior is dependable enough to trust during real work,
- thread and compiler/file workflows are not merely present but useful,
- supported and unsupported areas are clearly documented,
- CI keeps the protocol/test baseline from regressing.

Until then, the project should prefer:

- explicit partial support,
- sharp failure modes,
- regression tests,
- and documented Janet-specific behavior

over ambiguous “kind of works” parity claims.
