---
layout: page
title: Protocol coverage
---

# Protocol coverage

Generated from `tools/protocol_inventory.janet`. Do not edit by hand.

The release gate requires **100% explicit direct test mapping** for the declared stable subset on every frontend surface below. Historical SLYNK operations outside this subset remain visible in the full inventory without becoming a 1.1 compatibility claim.

| Surface | Stable ops | Functional | Directly tested | Coverage | Gate |
|---|---:|---:|---:|---:|---|
| compile_load | 4 | 4 | 4 | 100% | pass |
| completion | 6 | 6 | 6 | 100% | pass |
| debugger | 7 | 7 | 7 | 100% | pass |
| inspector | 5 | 5 | 5 | 100% | pass |
| repl | 3 | 3 | 3 | 100% | pass |
| transport | 4 | 4 | 4 | 100% | pass |
| xref | 2 | 2 | 2 | 100% | pass |

## Stable subset

### compile_load

- `compile-file-for-emacs`
- `compile-string-for-emacs`
- `load-file`
- `macroexpand-all`

### completion

- `simple-completions`
- `flex-completions`
- `operator-arglist`
- `arglist`
- `describe-function`
- `autodoc`

### debugger

- `debugger-info-for-emacs`
- `backtrace`
- `frame-locals-and-catch-tags`
- `list-threads`
- `debug-nth-thread`
- `kill-nth-thread`
- `invoke-nth-restart`

### inspector

- `inspector-nth-part`
- `inspector-pop`
- `inspector-reinspect`
- `inspector-history`
- `inspector-call-nth-action`

### repl

- `create-mrepl`
- `interactive-eval-region`
- `pprint-eval`

### transport

- `ping`
- `connection-info`
- `flow-control-test`
- `io-speed-test`

### xref

- `find-definitions-for-emacs`
- `frame-source-location`

