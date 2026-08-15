# SLYNET 1.0.7 — release integrity and Janet development in Emacs

SLYNET 1.0.7 is a patch release of the Janet-native development environment for
Emacs. It keeps the existing REPL, evaluation, completion/autodoc, source
navigation, inspection, diagnostics, and debugger-facade workflows while
hardening the path by which those capabilities are actually packaged and
started.

The release supports Janet 1.40.x through 1.41.x and Emacs 27.1 through 30.x on
GNU/Linux and macOS. It deliberately distinguishes Janet-native behavior from
emulated, workaround, pending-design, and unsupported Common Lisp semantics.

Highlights:

- fixes direct `janet slynet/cli.janet` invocation so the documented server
  command is executable and covered by live E2E tests;
- synchronizes package, Janet runtime, bundle, and Emacs version metadata;
- makes protocol-warning and generated-inventory checks fail closed in the
  release gate;
- verifies the extracted Janet and Emacs artifacts together with a real
  start/connect/MREPL/eval smoke;
- produces machine-readable release evidence and SHA-256 artifact hashes;
- refreshes security and setup guidance and constrains moving CI tooling inputs.

This source checkout does not yet have a canonical public repository remote, so
1.0.7 release preparation remains local. `make publication-verify` is the
explicit publication gate and will fail until the real repository URL is
configured and documented. No release-verification command tags, pushes,
uploads, or publishes the project.
