# Completion Overview

SLYNET exposes Emacs-style completion via the `simple-completions` and `flex-completions` RPC interfaces.

- `simple-completions` performs a prefix scan of the active fiber environment, returning `[matches common-prefix]` where each match is a stringified symbol. The optional `:package` argument selects which package to bind during completion; passing `nil` defaults to the server's current package.
- `flex-completions` performs the same environment walk but keeps `[match meta]` entries, where `meta` gives the matched span. A longest-common-prefix is still computed to support minibuffer expansion.
- Both entry points are registered through `infrastructure/defimpl`, so the RPC dispatch goes through `emacs-rex` without requiring the caller to import internal modules.
- The integration tests (`simple completions surface connection-info` / `flex completions surface connection-info`) exercise these paths to ensure backend implementations stay discoverable and include the `connection-info` command in their output.

These helpers only depend on Janet's standard symbol tables, so they work in the in-memory server harness used by the test suite and in external clients such as SLY for Emacs.
