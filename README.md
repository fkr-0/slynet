# SLYNET

SLYNET is a Janet development environment for Emacs. It pairs a Janet-native
server with a small Emacs client and uses a SLY/SLYNK-style wire protocol to
provide an interactive REPL, evaluation, completion, source navigation,
inspection, diagnostics, and a practical debugger facade.

SLYNET 1.0.1 is a stable release of the documented Janet workflow, not a claim
of complete Common Lisp SLY compatibility. Features that cannot preserve SLYNK
semantics on Janet are explicitly classified as emulated, experimental, or
unsupported.

## support matrix and contract for 1.0.0

| Component | Supported | Notes |
|---|---|---|
| Emacs | 27.1 through 30.x | CI should exercise 27.1, 28.2, 29.4, and 30.x. |
| Janet | 1.40.x | 1.40.1 is the release-validation baseline. |
| SLY | Protocol-compatible concepts only | SLY itself is not required by the Emacs package. SLYNET ships its own client. |
| OS | GNU/Linux and macOS | Requires local TCP sockets and normal subprocess support. Windows is untested. |

### Stable features

- six-hex-byte length-prefixed protocol transport;
- local server startup, teardown, reconnect, and project-scoped connections;
- MREPL creation, input history, output, successful evaluation, and errors;
- simple and flex completion, namespace-aware completion, and autodoc;
- source-index-backed definitions and xref results;
- inspector navigation and stable object metadata;
- compile/load diagnostics with source locations;
- debugger condition, frame, restart, and execution-unit facades;
- protocol inventory and support-class reporting.

### Experimental features

- debugger stepping/restart behavior beyond the documented Janet facade;
- profiler, stickers, tracing, and Common Lisp package-management compatibility;
- remote, TRAMP, Windows, and multi-user network operation;
- interfaces marked `pending-design`, `workaround`, or `unsupported` in the
  generated protocol inventory.

### Known limitations

- SLYNET is not a drop-in replacement for every SLY contrib module.
- Janet has no Common Lisp package, condition/restart, thread, or MOP model;
  related functionality is intentionally adapted rather than falsely emulated.
- The default server command is relative to the SLYNET checkout. Set
  `slynet-server-directory` when launching it from another project.
- The server listens on localhost by default. Authentication and hostile-network
  exposure are outside the 1.0.0 support contract.

## Prerequisites

- Janet 1.40.x, available as `janet`;
- Emacs 27.1 or newer;
- Git for source installation;
- Eldev 1.11 or newer only for package development and release verification.

Verify the runtime:

```sh
janet --version
emacs --version
```

## Emacs quick start: install from source

Clone the repository to a stable path:

```sh
git clone REPOSITORY-URL ~/src/slynet
```

Add the Emacs package and configure the bundled server location:

```elisp
(add-to-list 'load-path (expand-file-name "~/src/slynet/emacs"))
(require 'slynet)

(setq slynet-server-directory (expand-file-name "~/src/slynet"))
(setq slynet-server-command '("janet" "slynet/cli.janet" "--tcp"))

(slynet-mode 1)
```

After publication to a package archive, installation will use the normal
`M-x package-install RET slynet` flow. Until an archive submission is accepted,
source installation is the supported path.

## First session

1. Open Emacs and evaluate the configuration above.
2. Run `M-x slynet-start-server`.
3. Run `M-x slynet-connect`, accepting `127.0.0.1` and port `4005`.
4. Run `M-x slynet-create-mrepl`.
5. In the REPL buffer, evaluate:

   ```janet
   (+ 20 22)
   ```

6. Confirm that the result is `42`.
7. Evaluate an error to exercise diagnostics/debugger state:

   ```janet
   (error "expected example failure")
   ```

8. Use `C-c C-s b` for debugger information and `C-c C-s q` to disconnect and
   stop the Emacs-owned local server.

## Commands and keybindings

SLYNET uses the prefix `C-c C-s` while `slynet-mode` is enabled.

| Key | Command | Purpose |
|---|---|---|
| `C-c C-s c` | `slynet-connect` | Connect to a running server. |
| `C-c C-s d` | `slynet-disconnect` | Disconnect the current connection. |
| `C-c C-s r` | `slynet-reconnect` | Reconnect to the remembered endpoint. |
| `C-c C-s q` | `slynet-quit` | Disconnect and stop an Emacs-owned server. |
| `C-c C-s s` | `slynet-status` | Show compact connection status. |
| `C-c C-s h` | `slynet-health` | Open the detailed health buffer. |
| `C-c C-s e` | `slynet-eval-string` | Evaluate a Janet string. |
| `C-c C-s m` | `slynet-create-mrepl` | Create or open the MREPL. |
| `C-c C-s i` | `slynet-inspect-value` | Inspect a Janet value. |
| `C-c C-s x` | `slynet-find-definitions` | Find source definitions. |
| `C-c C-s b` | `slynet-debugger-info` | Show debugger state. |
| `C-c C-s D` | `slynet-doc-symbol` | Browse Janet documentation. |

## Troubleshooting decision tree

```text
Server does not start
├─ “executable janet is unavailable”
│  └─ Fix PATH and verify: janet --version
├─ Janet cannot load a shared library
│  └─ Repair the Janet installation or runtime library path
├─ “No such file slynet/cli.janet”
│  └─ Set slynet-server-directory to the repository root
└─ process starts but connection fails
   ├─ inspect *slynet-server*
   ├─ verify port 4005 is free
   └─ run: janet slynet/cli.janet --tcp

Connection drops or reconnect fails
├─ run M-x slynet-health
├─ stop stale processes with M-x slynet-quit
└─ start and connect again

Evaluation succeeds but a SLY feature is missing
├─ inspect docs/generated/protocol-inventory.yml
└─ check whether the operation is native, emulated, workaround, or unsupported
```

## Development

The Makefile is the stable command interface. Eldev is used only where it adds
package-aware Emacs compilation, testing, and packaging.

```sh
make lint              # Janet parse checks + Emacs package lint
make compile           # compile Emacs Lisp in a clean Eldev environment
make test              # Janet test suite
make test-emacs        # Emacs ERT suite
make test-e2e          # repeated lifecycle/E2E verification
make package           # build Janet and Emacs package artifacts
make clean             # remove generated artifacts
make release-verify    # complete local 1.0.1 release gate
```

See `CONTRIBUTING.md` for the contribution workflow and
`docs/COMPATIBILITY.md` for compatibility and deprecation policy.

## Publication

The recommended first publication is a public GitHub repository followed by a
MELPA recipe submission after the repository URL is final. NonGNU ELPA is
possible later, but its copyright-assignment and packaging process is heavier
than this project needs for the initial release. Announce the release in Janet's
official community spaces and Emacs package channels after a public archive and
installable URL exist.

No release tag, remote push, archive upload, or forge release is created by the
release-verification commands.
