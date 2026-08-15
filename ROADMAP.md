# SLYNET post-1.0 roadmap

This is the authoritative project-level roadmap. Detailed protocol semantics
remain in `docs/specs/`, while generated operation state belongs in
`docs/generated/protocol-inventory.yml`. Older milestone/task documents are
historical planning inputs and must not override this roadmap or executable
release gates.

## Roadmap policy

- Prefer useful Janet-native editor workflows over literal Common Lisp runtime
  parity.
- Preserve explicit native/emulated/workaround/pending-design/unsupported
  metadata whenever Janet cannot provide SLYNK semantics directly.
- Make release claims from executable evidence, not from source-tree presence.
- Keep publication (remote/tag/push/archive) separate from local release
  verification.

## R0 — Release integrity

```yaml
priority: P0
target: 1.0.7
status: local_complete_publication_gated
```

Work:

- reconcile `improve-slynet-repl-tests` without rolling back newer 1.0.x
  hardening;
- make documented direct CLI invocation executable;
- synchronize package, Janet runtime, bundle, and Emacs version surfaces;
- repair `bundle/info.jdn`;
- require a real repository URL/remote before publication;
- remove insecure `0.0.0.0` quickstarts;
- refresh README, security, setup, and release announcement;
- make the release gate test installed/extracted artifacts.

Acceptance:

- `janet slynet/cli.janet --help` works;
- `janet slynet/cli.janet --version` equals the project version;
- direct TCP startup becomes connectable;
- the extracted Janet package can start a server;
- the extracted Emacs package connects to that server and evaluates a form;
- no stale package version survives `make release-verify`;
- the final release commit has an intentionally clean tracked tree.

Publication note: the current checkout has no canonical `origin`. Local release
integrity does not invent one; `make publication-verify` fails closed until a
real remote is configured and documented.

## R1 — Fail-closed release gate

```yaml
priority: P0
status: complete
```

Work:

- execute `protocol_warning_policy --check` as a real script gate;
- verify generated inventory freshness without mutating the tracked file;
- verify project/runtime/bundle/Emacs versions match;
- reject known release placeholders and stale release-facing text;
- execute the documented direct server command;
- perform extracted artifact install/start/connect/MREPL/eval smoke testing;
- pin or constrain CI dependencies where practical;
- produce checksums and a machine-readable release-evidence manifest.

The gate must fail rather than silently downgrade any of these checks. The full
1.0.7 gate passed on 2026-08-15 with 128 Janet tests / 878 assertions, 81 Emacs
ERT tests, deterministic transport fuzzing, repeated direct-CLI E2E, extracted
artifact start/connect/eval, and release-evidence generation.

## R2 — Public Janet API

```yaml
priority: P1
status: planned
```

Work:

- replace the commented `slynet-api.janet` scaffold;
- introduce one canonical embedding API;
- consolidate duplicated CLI/init initialization;
- define supported `start`, `stop`, `with-server`, `connect`, `eval`,
  `complete`, `inspect`, `xref`, and `diagnostics` entrypoints;
- keep registry plumbing internal.

Exit condition: users embedding SLYNET do not need protocol registry knowledge or
private module state.

## R3 — Daily Emacs workflow

```yaml
priority: P1
status: planned
```

Work:

- reconcile useful MREPL/inspector/debugger E2E coverage from the historical
  side branch onto current mainline semantics;
- polish eval-region, eval-last-expression/form, buffer, and file workflows;
- deepen project-aware server management;
- add richer interactive inspector actions;
- improve debugger navigation UX;
- harden connection/session recovery UX.

## R4 — Janet-native debugging

```yaml
priority: P1/P2
status: planned
```

Focus:

- stable eval source maps;
- richer frame-local metadata;
- resumable debugger control API;
- real step/next/out only when Janet substrate actually permits it;
- persistent source-aware breakpoints;
- structured signal metadata.

Invariant: never claim Common Lisp restart/thread/debugger semantics where Janet
cannot provide them.

## R5 — Introspection and code intelligence

```yaml
priority: P2
status: planned
```

Focus:

- uniform callable metadata;
- macro/function/native signature provenance;
- stronger namespace/module awareness;
- incremental source indexing;
- cross-file dependency graph;
- richer xref categories and ranking;
- better documentation lookup.

## R6 — Instrumentation

```yaml
priority: P2
status: planned
```

Focus:

- low-overhead trace events;
- profiling;
- timing trees;
- source-linked instrumentation;
- optional sticker-like behavior where it has an honest Janet implementation.

## R7 — Architecture cleanup

```yaml
priority: P2
status: planned
```

Work:

- complete the physical runtime/server separation;
- remove dead translated Common Lisp scaffolding;
- eliminate duplicate parsers, initializers, and version constants;
- turn compatibility facades into explicit adapters;
- shrink the large `slynet/slynk.janet` module into capability-oriented units.

This phase should preserve public behavior while clarifying ownership and
reducing cross-layer mutable state.

## R8 — Ecosystem release

```yaml
priority: P2
status: publication_gated
```

Work:

- configure and publish the canonical repository;
- establish the package installation story;
- add the archive recipe;
- provide a migration guide for SLY users;
- automate the compatibility matrix;
- retain reproducible release evidence for every release.

No repository URL, tag, push, package-archive upload, or forge release should be
claimed until the corresponding publication gate is satisfied.

## High-value product enhancements

1. **First-class project sessions.** One command discovers a Janet project,
   starts or reuses its SLYNET server, connects, creates the REPL, and remembers
   the session.
2. **Janet-aware eval commands.** Last form, region, definition/form, buffer, and
   file workflows should feel native in Janet buffers rather than exposing RPC
   primitives.
3. **Source-aware debugger breakpoints.** Persistent breakpoints mapped to Janet
   source forms are the highest-leverage debugger improvement after the existing
   REPL/xref/inspector foundation.
4. **Incremental source index.** Turn the current index into a project
   intelligence service shared by completion, xref, diagnostics, debugger
   locations, and documentation.
5. **Structured capability browser.** Surface protocol-support metadata in a
   searchable Emacs UI instead of leaving it primarily in generated YAML.
6. **Observability mode.** Provide a compact session inspector for RPC latency,
   pending requests, channels, execution units, diagnostics, source-index state,
   and server-process health.

## Sequencing

```text
R0 release integrity
  -> R1 fail-closed gate
     -> local 1.0.x release candidate
        -> R2 public Janet API
        -> R3 daily Emacs workflow
           -> R4/R5 debugging + intelligence
              -> R6 instrumentation
                 -> R7 structural cleanup
                    -> R8 ecosystem publication
```

R4–R7 may overlap when changes are orthogonal, but R0/R1 are release blockers
and R8 remains publication-gated until a real public destination exists.
