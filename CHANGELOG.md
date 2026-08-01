# Changelog

All notable changes to this project are documented here.

The format follows Keep a Changelog, and this project follows Semantic
Versioning.

## [Unreleased]

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
