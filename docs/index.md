---
layout: home
title: SLYNET
---

# Janet development in Emacs

SLYNET pairs a Janet-native server with an Emacs client and a
SLY/SLYNK-style protocol. The stable 1.1.x line provides local server and
session lifecycle, MREPL evaluation, completion and autodoc, source navigation,
inspection, compile/load diagnostics, and a Janet-aware debugger facade.

The project is intentionally explicit about semantic boundaries: Janet does not
have Common Lisp packages, conditions/restarts, implementation threads, or
CLOS/MOP, so SLYNET adapts useful workflows without claiming runtime parity.

## Start here

- [Install and use SLYNET](https://github.com/fkr-0/slynet#readme)
- [Latest release: v1.1.0](https://github.com/fkr-0/slynet/releases/tag/v1.1.0)
- [1.1.0 release status](RELEASE_STATUS.html)
- [Historical 1.0.7 release status](RELEASE_STATUS_1.0.7.html)
- [Current development status](DEVELOPMENT_STATUS.html)
- [Janet embedding API](EMBEDDING_API.html)
- [Migrating from Common Lisp SLY](MIGRATING_FROM_SLY.html)
- [Compatibility contract](COMPATIBILITY.html)
- [Security boundary](https://github.com/fkr-0/slynet/blob/main/SECURITY.md)
- [Roadmap](https://github.com/fkr-0/slynet/blob/main/ROADMAP.md)
- [Changelog](https://github.com/fkr-0/slynet/blob/main/CHANGELOG.md)

## Current development direction

SLYNET 1.1.0 completes the capability-consolidation tranche. Remaining themes are:

1. stronger operation-to-test correspondence and generated protocol truth;
2. a stable public Janet embedding API;
3. daily-use Emacs evaluation/load/interrupt/recovery commands;
4. cooperative debugger stepping for instrumented Janet code without faking
   native continuations;
5. consolidated profiling, tracing, timing-tree, and sticker instrumentation.

See [development status](DEVELOPMENT_STATUS.html) for the exact current tree and
[release status](RELEASE_STATUS.html) for the audited 1.1.0 release boundary.
