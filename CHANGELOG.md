# Changelog

All notable changes to this project are documented here.

The format follows Keep a Changelog, and this project follows Semantic
Versioning.

## [Unreleased]

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
