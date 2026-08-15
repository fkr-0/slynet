# 1.0.7 reconciliation: `improve-slynet-repl-tests`

## Decision

The historical `improve-slynet-repl-tests` branch must not be merged wholesale
into `main`. Its merge base is `e90c449`; current `main` contains fourteen
unique commits after that point, including the complete 1.0.1–1.0.6 transport,
client, compatibility, release, source-index, diagnostics, and Emacs hardening
line. The side branch contains twelve unique commits from the older
architecture. A normal merge/cherry-pick series would reintroduce obsolete
implementations and large source/test deletions.

For 1.0.7, reconciliation means preserving current mainline semantics and
transplanting only release-relevant behavior that remains valid.

## Disposition

| Side commit | Intent | 1.0.7 disposition |
|---|---|---|
| `dfb8be3` | SLY/MREPL integration and direct CLI execution | direct CLI invocation logic transplanted; current mainline Emacs MREPL E2E retained |
| `1e607ba` | more MREPL E2E | deferred to R3 compatibility/E2E deepening; current repeated direct-CLI lifecycle E2E is release gate |
| `14be7a2`, `2c6caa3`, `1d6a498` | inspector SLY compatibility E2E | deferred to R3; current mainline inspector/source-index contracts are newer |
| `cba1a34` | `eval-and-grab-output` | candidate for R3 Janet-aware eval workflow; not added to a patch-release API surface without dedicated current-main tests |
| `462d26f`, `da6cc05`, `d268c0e` | debugger trigger/default-debugger and SLY E2E | deferred to R3/R4 so current source-aware debugger facade remains authoritative |
| `f476b67`, `3e0989a`, `995699f` | protocol constraint/inventory classification | superseded by current P17–P29 support matrix, generated inventory, and fail-closed inventory/policy checks |

The side worktree also contains pre-existing unstaged changes in
`docs/generated/protocol-inventory.yml`, `slynet/backend.janet`, and
`test/project_core_tests.janet`. They are intentionally not imported into the
1.0.7 release line without an independent review against current main.

## Release evidence

The 1.0.7 release line proves the transplanted direct-start behavior with:

```sh
janet slynet/cli.janet --help
janet slynet/cli.janet --version
make test-e2e
make release-artifact-smoke
```

The last two checks start the direct CLI rather than an import-only `-main`
surrogate; the artifact smoke additionally starts the extracted Janet archive
and evaluates through the extracted Emacs package.

## Follow-up

R3 owns the remaining useful side-branch workflow tests/features. They should be
ported test-first onto current mainline APIs, not recovered by merging the old
branch topology. After those dispositions are complete and the dirty worktree
has been reviewed, the historical worktree/branch may be retired in a separate,
explicit cleanup operation.
