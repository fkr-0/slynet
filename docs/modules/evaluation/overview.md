# Evaluation Overview

The evaluation-facing RPC endpoints bridge Emacs and Janet execution inside the SLYNET backend.

- `interactive-eval-region` accepts raw source text, reads each form with the Gray reader, evaluates it, and returns a property list of the form `[:values @[...]]`. Each entry is rendered with `print-for-emacs/prin1-to-string-for-emacs`, mirroring SLIME's behaviour and satisfying the "interactive-eval-region returns values" test.
- `pprint-eval` shares the same read/eval loop but only returns the final value, again rendered for Emacs consumption. Tests ensure that multi-form inputs report the last result (`"pprint-eval prints last value"`).
- `value-for-editing` and `commit-edited-value` implement the editable value cycle. The former resolves a symbol and serialises its current value, while the latter evaluates the replacement form, rebinds the symbol, and echoes the updated value. The regression test "value editing cycle" keeps the API honest.
- `set-package` (invoked via `set-package-rpc`) updates the global package table, keeps the active connection in sync, and returns both the package plist and the display prompt. This powers prompt updates and keeps `connection-info` outputs aligned with what the user sees in the REPL.

Together these functions cover the day-to-day workflows exercised by the remaining integration tests: setting a REPL package, issuing quick evaluations, pretty-printing results, and editing live bindings.
