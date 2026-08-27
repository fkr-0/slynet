# SLYNET

SLYNET is a Janet development environment for Emacs. It pairs a Janet-native
server with a small Emacs client and a SLY/SLYNK-style wire protocol to provide
an interactive REPL, evaluation, completion, source navigation, inspection,
diagnostics, and a practical debugger facade.

SLYNET 1.0.7 is a stable release of the documented Janet workflow. It is not a
claim of complete Common Lisp SLY compatibility: operations that cannot preserve
SLYNK semantics on Janet are classified explicitly as native, emulated,
workaround, pending-design, or unsupported.

For an audited feature-by-feature release snapshot, including exact generated
protocol coverage counts and known gaps, see `docs/RELEASE_STATUS.md`.

## Support matrix and contract

The support matrix below is the stable 1.0.x compatibility contract.

| Component | Supported | Notes |
|---|---|---|
| Emacs | 27.1 through 30.x | CI covers 27.1, 28.2, 29.4, and 30.1. |
| Janet | 1.40.x through 1.41.x | CI covers 1.40.1 and 1.41.1. |
| SLY | Protocol-compatible concepts only | SLY itself is not required; SLYNET ships its own Emacs client. |
| OS | GNU/Linux and macOS | Local TCP sockets and subprocess support are required. Windows remains unverified. |

### Stable workflow

- six-hex-byte length-prefixed protocol transport;
- direct local server startup, teardown, reconnect, and project-scoped
  connections;
- MREPL creation, history, output, successful evaluation, and error handling;
- simple/flex completion, namespace-aware completion, autodoc, and Janet docs;
- source-index-backed definitions and xref results;
- inspector navigation and stable object metadata;
- compile/load/runtime diagnostics with source locations;
- debugger condition, frame, restart-facade, and execution-unit views;
- protocol inventory and support-class reporting.

### Experimental or deliberately constrained areas

- debugger stepping and resumability beyond SLYNET-owned Janet facades;
- full profiler/trace UI, timing trees, stickers, and Common Lisp
  package-management compatibility;
- remote/TRAMP, Windows, hostile-network, and multi-user operation;
- interfaces classified as pending-design, workaround, or unsupported in
  `docs/generated/protocol-inventory.yml`.

Janet has no Common Lisp package, condition/restart, thread, or CLOS/MOP model.
SLYNET adapts those workflows where useful and does not manufacture semantic
parity where the Janet runtime does not provide it.

## Prerequisites

For normal use:

```sh
janet --version
emacs --version
```

Use Janet 1.40.x or 1.41.x and Emacs 27.1 or newer. Git is needed for source
checkout workflows. Eldev 1.11 or newer is needed only for package development
and release verification.

## Emacs quick start

Clone the canonical public repository and point Emacs at the checkout:

```sh
git clone https://github.com/fkr-0/slynet.git ~/src/slynet
cd ~/src/slynet
make test
```

Then add its Emacs directory to `load-path`:

```elisp
(add-to-list 'load-path (expand-file-name "~/src/slynet/emacs"))
(require 'slynet)

(setq slynet-server-directory (expand-file-name "~/src/slynet"))
(setq slynet-server-command '("janet" "slynet/cli.janet" "--tcp"))

(slynet-mode 1)
```

Project documentation is published at <https://slynet.fkr.dev>, and immutable
release artifacts are available from the
[GitHub Releases page](https://github.com/fkr-0/slynet/releases).

## Verify and start the server directly

The documented server command is itself covered by the release gate:

```sh
janet slynet/cli.janet --help
janet slynet/cli.janet --version
janet slynet/cli.janet --tcp --host 127.0.0.1 --port 4005
```

Keep the server on loopback. The protocol permits code evaluation with the
server process user's permissions and is not an authentication or sandbox
boundary. See `SECURITY.md` before considering remote access.

## First Emacs session

1. Run `M-x slynet-start-server`.
2. Run `M-x slynet-connect`, accepting `127.0.0.1` and port `4005`.
3. Run `M-x slynet-create-mrepl`.
4. Evaluate `(+ 20 22)` in the REPL and confirm the result is `42`.
5. Evaluate `(error "expected example failure")` to exercise diagnostics and
   debugger state.
6. Use `C-c C-s b` for debugger information and `C-c C-s q` to disconnect and
   stop an Emacs-owned local server.

## Commands and keybindings

SLYNET uses the `C-c C-s` prefix while `slynet-mode` is enabled.

| Key | Command | Purpose |
|---|---|---|
| `C-c C-s c` | `slynet-connect` | Connect to a running server. |
| `C-c C-s d` | `slynet-disconnect` | Disconnect the current connection. |
| `C-c C-s r` | `slynet-reconnect` | Reconnect to the remembered endpoint. |
| `C-c C-s q` | `slynet-quit` | Disconnect and stop an Emacs-owned server. |
| `C-c C-s s` | `slynet-status` | Show compact connection status. |
| `C-c C-s h` | `slynet-health` | Open detailed health information. |
| `C-c C-s e` | `slynet-eval-string` | Evaluate a Janet string. |
| `C-c C-s m` | `slynet-create-mrepl` | Create or open the MREPL. |
| `C-c C-s i` | `slynet-inspect-value` | Inspect a Janet value. |
| `C-c C-s x` | `slynet-find-definitions` | Find source definitions. |
| `C-c C-s b` | `slynet-debugger-info` | Show debugger state. |
| `C-c C-s D` | `slynet-doc-symbol` | Browse Janet documentation. |

## Troubleshooting

```text
Server does not start
├─ janet is unavailable
│  └─ verify: janet --version
├─ Janet cannot load a shared library
│  └─ repair the Janet installation/runtime library path
├─ slynet/cli.janet cannot be found
│  └─ set slynet-server-directory to the SLYNET checkout
└─ process starts but connection fails
   ├─ inspect *slynet-server*
   ├─ verify the chosen localhost port is free
   └─ run the direct CLI command manually

Connection drops or reconnect fails
├─ run M-x slynet-health
├─ stop stale processes with M-x slynet-quit
└─ start and connect again

A SLY feature is unavailable
├─ inspect docs/generated/protocol-inventory.yml
└─ check native/emulated/workaround/pending-design/unsupported metadata
```

## Development and release verification

The Makefile is the stable command interface. Eldev is used where it adds
package-aware Emacs compilation, testing, and packaging.

```sh
make lint                     # Janet load checks + Emacs package lint
make compile                  # byte-compile the Emacs package
make test                     # Janet suite
make test-emacs               # Emacs ERT suite
make test-fuzz                # deterministic transport fuzzing
make test-e2e                 # direct CLI + Emacs/Janet lifecycle E2E
make protocol-inventory-check # generated inventory freshness
make release-integrity        # version/docs/direct-start integrity
make package                  # Janet and Emacs release artifacts
make release-artifact-smoke   # extracted artifacts start/connect/eval
make release-verify           # complete local release gate + evidence
make publication-verify       # additionally require real publication remote
```

`make release-verify` does not tag, push, upload, publish, or deploy anything.
It produces `dist/release-evidence.yml` and SHA-256 hashes for the release
artifacts. The artifact smoke starts the Janet server from the extracted Janet
archive and connects/evaluates through the extracted Emacs package, avoiding a
source-tree-only false green.

See `CONTRIBUTING.md`, `docs/COMPATIBILITY.md`, and `ROADMAP.md` for the current
engineering contract and post-1.0 roadmap.
