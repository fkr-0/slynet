# slynet

SLYNET is a Janet-oriented SLY/SLYNK-style backend plus Emacs frontend. It provides tested transport, MREPL/REPL, completion, inspector, xref, diagnostics, debugger, and support-matrix/spec tooling while marking Common Lisp semantic gaps explicitly.

## Emacs quick start

```elisp
(add-to-list 'load-path "/path/to/slynet/emacs")
(require 'slynet)
(slynet-mode 1)
```

Useful entry points:

- `M-x slynet-start-server` starts a local Janet SLYNET server using `slynet-server-command`.
- `M-x slynet-connect` connects to `slynet-host` / `slynet-port`.
- `C-c C-s h` opens the SLYNET health buffer.
- `C-c C-s s` echoes structured connection status.
- `C-c C-s m` creates/opens an MREPL.
- `C-c C-s b` opens debugger information when available.
- `C-c C-s q` disconnects and stops the local server process if one was started by Emacs.

SLYNET is Janet-native first. CL/SLYNK compatibility surfaces are implemented as native support, emulated support, workaround facades, pending design, or explicit unsupported records; see `docs/specs/` for the support matrix and gap-analysis contracts.
