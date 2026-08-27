# SLYNET 1.1.0 — stable Janet embedding, daily Emacs workflows, and truthful xref

SLYNET 1.1.0 is the capability-consolidation release of the Janet development
environment for Emacs. It keeps the trusted-localhost SLYNET model while adding
a stable Janet embedding API, substantially stronger daily editor workflows,
machine-auditable protocol/test correspondence, and repaired static xref/source
index behavior.

The supported compatibility window remains Janet 1.40.x through 1.41.x and Emacs
27.1 through 30.x on GNU/Linux and macOS. The canonical release matrix exercises
the eight-cell cross product of Janet 1.40.1/1.41.1 with Emacs
27.1/28.2/29.4/30.1 before the immutable tag is published.

## Highlights

- stable `slynet/api.janet` embedding API v1 with initialization, capabilities,
  RPC metadata lookup, context-free in-process calls, loopback-safe server
  lifecycle, lifecycle contexts, and transport-independent context status;
- complete legacy `slynet/slynet-api.janet` API-v1 compatibility shim;
- daily Emacs commands for last-form/region/definition/buffer evaluation,
  current-file compile/load, cooperative managed-unit interruption, request
  cancellation, and project-aware start/connect/reconnect/quit;
- inspector history/actions, capability-aware debugger navigation, stale-session
  marking, timeout/late-reply recovery, and continued evaluation after recoverable
  failures;
- parser-sourcemap-backed static xref with all top-level forms, recursive function
  bodies, caller identity, `who-calls`/`who-binds`/`who-sets`/`list-callers`,
  modified-file fact replacement, and deleted-file pruning;
- Janet-1.40-correct source-index cache invalidation using `os/stat :modified`;
- compiler-macroexpand compatibility that is explicitly Janet-emulated rather
  than presented as Common Lisp compiler-macro/environment equivalence;
- generated schema-6 protocol inventory with definition, registration, direct
  test, support-class, and stable-subset coverage evidence;
- bounded reader-safe debugger payload printing and file-aware compile diagnostic
  provenance;
- live editor E2E coverage for evaluation, compile/load, interrupt/cancel,
  debugger/restart/xref/diagnostic recovery, inspector history/actions, server
  restart, timeout recovery, and reconnect.

## Protocol truth

The generated historical protocol corpus contains 284 operations:

- 70 callable operations have explicit direct operation-level test ownership;
- 27 callable operations are functional but do not yet have direct mapping;
- 10 Janet implementations remain defined but unwired;
- 5 registered endpoints are truthfully classified as stubs;
- 172 historical operations remain missing.

Support classification is 247 native, 35 emulated, and 2 explicitly unsupported.
Every declared release-critical stable frontend surface is 100% functionally
registered and directly tested.

These counts are deliberately conservative and are not a claim of complete
Common Lisp SLY/SLYNK parity.

## Semantic boundaries

SLYNET still does not claim semantics Janet cannot provide. Common Lisp package
reader behavior, conditions/restarts, resumable native debugger continuations,
implementation threads, CLOS/MOP, compiler-note objects, and lexical
compiler-macro environments do not have literal Janet equivalents.

`who-references` also remains deliberately unwired until static variable-read
analysis is precise enough to avoid false positive navigation results.

Debugger stepping for arbitrary native frames, complete profiler/trace/sticker
UI, Windows qualification, remote/TRAMP, hostile-network, and multi-user use are
not 1.1.0 release claims.

## Verification and publication

`make release-verify` validates release metadata, generated inventory/coverage,
public docs, Janet tests, Emacs ERT/lint/byte compilation, 10,000 deterministic
transport fuzz cases, repeated live lifecycle E2E, package creation, and an
extracted Janet+Emacs start/connect/MREPL/eval smoke. The canonical GitHub Actions
compatibility job separately qualifies all eight Janet/Emacs cells before the
tag is created.

See `docs/RELEASE_STATUS.md` for the audited release boundary and
`docs/RELEASE_STATUS_1.0.7.md` for the preserved previous release snapshot.

The immutable release is published at
<https://github.com/fkr-0/slynet/releases/tag/v1.1.0>, and project documentation
is published from `main` through GitHub Pages at <https://slynet.fkr.dev>.
