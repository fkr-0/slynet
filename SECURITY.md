# Security policy

## Supported versions

Security fixes are provided for the latest 1.x release.

## Scope

SLYNET starts a local Janet process and evaluates code sent by an Emacs client.
It is therefore a trusted-local-development tool, not a sandbox or
internet-facing service.

- Keep the listener bound to localhost.
- Do not expose the protocol port to untrusted networks.
- Treat connected clients as able to execute code with the Janet process user's
  permissions.
- Review project code before evaluating or loading it.

## Reporting a vulnerability

Before a public forge is selected, report vulnerabilities privately to the
maintainer through an established private contact channel. Do not include
secrets, personal data, or exploit payloads beyond what is necessary to
reproduce the issue. After publication, this file should be updated with the
forge's private security-advisory route.
