# Security policy

## Supported versions

Security fixes are provided for the latest 1.x release.

## Trust boundary

SLYNET starts a Janet process and evaluates code sent by its Emacs client. A
connected client must therefore be treated as able to execute code with the
permissions of the Janet server process. SLYNET is a trusted local development
tool, not a sandbox, authentication service, or hostile-network protocol.

- Keep the TCP listener on `127.0.0.1` (the default).
- Do not bind the development server to `0.0.0.0` or otherwise expose its port
  directly to an untrusted network.
- Review project code before evaluating or loading it.
- Keep server processes scoped to the user/project that owns the development
  session.

For a future remote workflow, keep SLYNET bound to loopback and place the
connection behind an authenticated transport such as an SSH tunnel. Remote and
TRAMP operation are not part of the current stable support contract, so such a
setup needs its own validation rather than weakening the server bind address.

## Reporting a vulnerability

This checkout does not yet have a canonical public forge remote. Until one is
configured, report vulnerabilities privately to the maintainer through an
established private contact channel and disclose only the material needed to
reproduce the issue. Publication is gated by `make publication-verify`; once a
real forge is configured, this section must name its private security-advisory
route before public release.
