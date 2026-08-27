# SLYNET 1.0.7 — a release-qualified Janet development environment for Emacs

SLYNET 1.0.7 is the first release in this repository whose local release path is
designed to prove the packaged workflow rather than infer readiness from source
files. It provides a Janet-native server, a small Emacs client, and a
SLY/SLYNK-style protocol for interactive Janet development.

The supported matrix is Janet 1.40.x through 1.41.x and Emacs 27.1 through 30.x
on GNU/Linux and macOS. The server is a trusted-localhost development tool; it is
not an authenticated or sandboxed remote execution service.

## What works

- direct local server start/stop/reconnect and project-aware Emacs lifecycle;
- MREPL creation, history, output, evaluation results, and error handling;
- hardened length-prefixed UTF-8 transport with timeout/cancellation cleanup;
- simple/flex and namespace-aware completion, arglists, autodoc, and docs;
- source-index-backed definitions and xref navigation;
- value inspection and inspector navigation;
- compile/load/runtime diagnostics with source locations;
- a practical Janet debugger facade with frame/condition/execution-unit views;
- extracted-artifact start/connect/MREPL/eval smoke testing, not only source-tree
  tests;
- deterministic transport fuzzing, repeated live lifecycle E2E, and
  machine-readable release evidence with artifact SHA-256 hashes.

## What is not claimed

SLYNET is not complete Common Lisp SLY parity. The generated inventory currently
tracks 249 source protocol operations: 24 are implemented with a direct
operation-level test mapping, 131 are implemented without such a direct mapping,
and 94 are still missing. Broader Emacs ERT/E2E tests exercise composed workflows,
so those inventory numbers are deliberately more conservative than the user-level
feature list above.

The largest remaining gaps are debugger stepping/resumability, thread/restart
semantics that Janet cannot represent directly, profiler/tracing instrumentation,
a stable public Janet embedding API, further daily-editor polish, Windows
qualification, remote/TRAMP and multi-user operation, and a public package/
repository installation story. Two CLOS/MOP compatibility operations are
explicitly unsupported rather than pretending Janet has equivalent semantics.

See `docs/RELEASE_STATUS.md` for the exact coverage table and semantic caveats.

## Publication status

The qualified v1.0.7 tag and its original release artifacts are published at
<https://github.com/fkr-0/slynet/releases/tag/v1.0.7>. Publication happened
after local qualification and did not move the tag or rebuild the artifacts.
Project documentation is published from `main` through GitHub Pages at
<https://slynet.fkr.dev>.
