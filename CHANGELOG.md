# Changelog

All notable changes to this project are documented here.

The format follows Keep a Changelog, and this project follows Semantic
Versioning.

## [Unreleased]

### Added

- Added a canonical `slynet/api.janet` embedding API v1 with loopback-safe
  server lifecycle, capability reporting, RPC metadata lookup, and in-process
  invocation for context-free RPCs.
- Added explicit per-test protocol `:covers` metadata and protocol inventory
  schema v5, which distinguishes callable registrations, unwired definitions,
  and direct test evidence across the complete tracked SLY/SLYNK corpus.
- Added a GitHub Pages documentation site and pinned deployment workflow for
  `https://slynet.fkr.dev`.

### Changed

- Expanded protocol inventory discovery to include profiler, trace-dialog,
  stickers, retro, and indentation contrib reference sources.
- Updated public installation and release documentation for the canonical
  `fkr-0/slynet` repository and published v1.0.7 release.

## [1.0.7] - 2026-08-27

### Added

- Added fail-closed release-integrity checks for version coherence, stale
  release placeholders, the documented direct CLI, protocol warning policy,
  and generated protocol-inventory freshness.
- Added an extracted-artifact smoke that starts the packaged Janet server and
  drives MREPL evaluation through the packaged Emacs client.
- Added machine-readable `dist/release-evidence.yml` generation with artifact
  sizes and SHA-256 hashes.
- Added a publication-only verification gate that requires a real canonical
  repository remote instead of accepting placeholder clone instructions.
- Added an audited release-status document that separates user-visible workflow
  support from operation-level protocol inventory coverage and records exact
  implemented/tested/missing counts.

### Changed

- Synchronized Janet runtime, Janet bundle, Emacs package, and project release
  metadata on version 1.0.7.
- Made live Emacs/Janet E2E tests start the same `janet slynet/cli.janet --tcp`
  entrypoint documented to users.
- Refreshed setup, security, release, and roadmap documentation around the
  trusted-local protocol boundary and post-1.0 development priorities.
- Constrained CI Emacs setup to a reviewed action revision and Eldev bootstrap
  to the 1.11.2 release, and made the final CI job run the complete release
  gate rather than packaging source alone.
- Made Eldev-backed release commands reuse already-cached package archive
  metadata without forcing a network refresh; fresh environments still fetch
  missing cache entries normally.
- Clarified that `TASKS.md` and `docs/missing_protocol.md` are historical
  planning inputs, while generated inventory and `ROADMAP.md` are release truth.
- Made the Janet source artifact self-contained with the documentation and
  top-level release/security/roadmap files referenced by its bundled README.

### Fixed

- Fixed direct execution of `slynet/cli.janet`, which previously exited without
  invoking the server or rendering CLI help/version output.
- Removed stale 0.0.0 bundle metadata and insecure `0.0.0.0` quickstart
  guidance from release-facing documentation.

## [1.0.6] - 2026-08-01

### Added

- Added defensive argument validation tests for connection endpoints, request
  callbacks and deadlines, request IDs, channel payloads, and MREPL evaluation.

### Changed

- Public client entrypoints now reject invalid arguments before opening a
  socket, allocating request IDs, registering callbacks, or mutating MREPL
  state. Contract violations use `slynet-client-argument-error` with the
  offending argument in the diagnostic.

## [1.0.5] - 2026-08-01

### Added

- Added an eight-cell CI compatibility matrix covering Emacs 27.1, 28.2,
  29.4, and 30.1 with Janet 1.40.1 and 1.41.1.

### Changed

- Extended verified Janet support through 1.41.x.
- Documented Janet 1.39.1 as unsupported after it failed 49 backend tests
  involving fiber/debug APIs and dependent protocol behavior.
- Made CI artifact names revision-specific instead of retaining a stale 1.0.0
  label.

## [1.0.4] - 2026-08-01

### Added

- Added regression coverage for invalid UTF-8 recovery and actionable protocol
  error context.

### Changed

- Protocol violations now report the expected message shape, received value,
  request detail where available, connection state, pending request count,
  buffered byte count, channel ID, and thread ID.

### Fixed

- Rejected non-canonical UTF-8 before Lisp parsing, including overlong,
  truncated, surrogate, and out-of-range encodings.

## [1.0.3] - 2026-08-01

### Added

- Added a 10,000-case deterministic fragmented-frame fuzz gate.
- Added a 1,000-cycle request-lifecycle invariant test covering completion,
  cancellation, timer cleanup, late replies, and pending-request cleanup.
- Added a repeated live connect/MREPL/evaluate/disconnect E2E scenario with
  process-leak detection.

### Changed

- Release verification now includes the extended fuzz gate and thirty live
  session lifecycle iterations across three E2E runs.

## [1.0.2] - 2026-08-01

### Added

- Expanded the Emacs regression suite from 54 to 72 tests with focused
  coverage for fragmented Unicode framing, malformed protocol messages,
  request cancellation and timeout races, callback isolation, reconnect and
  disconnect behavior, channel ownership, and teardown reentrancy.
- Added deterministic property-style frame parser coverage and repeated live
  Janet lifecycle checks with process-leak detection.

### Changed

- Hardened RPC request bookkeeping so timers, callbacks, cancellation, late
  replies, synchronous replies, send failures, and connection loss resolve
  exactly once.
- Isolated wire observers, channel hooks, request callbacks, and callback-error
  reporters so one failing extension cannot destabilize transport processing or
  suppress later observers.
- Made malformed `:return`, `:channel-send`, `:channel-close`, `:write-string`,
  and `:prompt` messages fail consistently as protocol errors.
- Invalidated transport and MREPL state before invoking teardown callbacks,
  preventing reentrant work from being submitted onto dead connections or
  closing channels.

### Fixed

- Corrected UTF-8 byte-length framing, including fragmented multibyte payloads,
  valid `nil` messages, trailing payload garbage, invalid prefixes, and the
  six-hex-digit frame-size boundary.
- Prevented stale callbacks, request timers, process references, channel IDs,
  and thread IDs from surviving send failure, channel closure, disconnect,
  reconnect, or unexpected socket loss.
- Prevented overlapping MREPL evaluations, including calls without a completion
  callback, and ignored state-changing events from unrelated channels.
- Ensured explicit disconnect reports `:disconnected`, while unexpected socket
  loss reports `:connection-lost`, including for in-flight RPC and MREPL work.

## [1.0.1] - 2026-07-26

### Added

- Explicit asynchronous RPC cancellation through
  `slynet-client-cancel-request`, with idempotent late-reply handling.
- Configurable request deadlines through `slynet-client-request-timeout` and
  per-request timeout overrides.
- Deterministic property-style transport tests covering 100 generated messages,
  randomized frame fragmentation, Unicode payloads, and malformed prefixes.
- A live TCP integration test proving that an in-flight RPC is aborted when the
  Janet server disappears.

### Changed

- Isolated user callback failures from the process filter and request lifecycle;
  failures are now reported through `slynet-client-callback-error-functions`.
- Pending requests now retain timer and callback state, cancel timers exactly
  once, and ignore replies arriving after cancellation or timeout.
- Connection loss and explicit disconnect now resolve pending RPC and MREPL
  callbacks with structured abort payloads instead of silently dropping them.
- Hardened framing for UTF-8 byte lengths, malformed prefixes and payloads,
  trailing data, and the six-hex-digit maximum frame size.

### Fixed

- Prevented callback leaks after send failures and stale request state after
  remote socket closure.
- Prevented oversized outbound frames from corrupting the protocol stream.

## [1.0.0] - 2026-07-24

### Added

- Janet-native SLYNET server and Emacs client.
- Stable transport, connection lifecycle, MREPL, evaluation, completion,
  autodoc, source navigation, inspector, diagnostics, debugger facade, and
  execution-unit support.
- Source-index and protocol-inventory tooling with explicit support classes for
  Janet adaptations and unavailable Common Lisp semantics.
- Janet unit/integration tests and Eldev-backed Emacs ERT/E2E tests.
- Reproducible lint, compile, test, package, clean, and release-verification
  commands.
- Public compatibility, contribution, security, and release documentation.

### Changed

- Declared Janet 1.40.x and Emacs 27.1–30.x as the 1.0.0 support matrix.
- Hardened local server startup diagnostics and working-directory handling.
- Consolidated release version metadata on `project.janet` as the canonical
  source and synchronized Emacs package headers.

### Removed

- Removed a stale backup implementation file that was excluded by repository
  policy but still tracked.

### Known limitations

- Complete SLY/SLYNK and contrib parity is intentionally out of scope.
- Windows, remote/TRAMP operation, hostile-network exposure, and multi-user
  operation are untested and unsupported for 1.0.0.
- Some declared protocol interfaces remain explicitly unsupported or pending a
  Janet-native design.

## [0.0.0] - 2025-06-09

### Added

- Initial experimental project.
