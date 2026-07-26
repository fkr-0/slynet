# SLYNET 1.0.0 — Janet development in Emacs

SLYNET 1.0.0 is the first stable release of a Janet-native interactive
development environment for Emacs. It provides a local server and lightweight
Emacs client with an MREPL, evaluation, completion and autodoc, source
navigation, inspection, diagnostics, and a practical debugger facade.

The release supports Janet 1.40.x and Emacs 27.1 through 30.x on GNU/Linux and
macOS. It deliberately documents where Janet differs from Common Lisp instead
of claiming complete SLY/SLYNK compatibility.

Highlights:

- first-class Janet REPL and evaluation workflow;
- completion, docs, definitions, xref, and inspector navigation;
- structured compile/runtime diagnostics and debugger information;
- explicit protocol support matrix and known limitations;
- reproducible Janet and Emacs test/release commands.

Install from the public source repository and follow the five-minute first
session in the README. Package-archive availability will follow after the
repository URL is finalized and the MELPA recipe is accepted.
