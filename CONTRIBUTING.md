# Contributing to SLYNET

Thank you for improving Janet's Emacs development experience.

## Before changing code

1. Read `AGENT.md` and the architecture documentation.
2. Check the generated protocol inventory before assuming a SLY operation maps
   directly to Janet.
3. Keep Janet-native behavior truthful; do not claim Common Lisp semantics that
   Janet cannot provide.

## Development setup

Install Janet 1.40.x, Emacs 27.1 or newer, and Eldev 1.11 or newer. Then run:

```sh
make release-verify
```

## Pull requests

- Keep changes focused and preserve unrelated behavior.
- Add tests for fixes and public features.
- Update README, compatibility policy, protocol inventory, or changelog when the
  public contract changes.
- Include exact validation commands and results in the pull request.
- Do not commit logs, `.eldev`, binaries, local worktrees, or scratch backups.

## Code style

- Prefer small capability-oriented Janet modules.
- Declare RPC interfaces before registering implementations.
- Keep protocol transforms pure where possible and isolate process/network I/O.
- Use structured, actionable diagnostics containing the failing operation and
  relevant path, executable, endpoint, or protocol detail.

## Reporting bugs

Include Emacs and Janet versions, operating system, minimal configuration,
reproduction steps, the `*slynet-server*` buffer when relevant, and whether a
repeated run leaves a process listening on port 4005.
