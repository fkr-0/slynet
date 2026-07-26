# Protocol Interface Registry Contract

Status: foundation slice implemented in P17.

## Purpose

SLYNET keeps two related registries:

- declared RPC interfaces, defined through `slynet/interfaces.janet`
- registered Janet implementations, defined through `inf/defimpl`

A supported or staged extension RPC must not exist only as an implementation. The interface declaration is the contract surface used by protocol inventory, warning output, support-matrix ownership, and future generated documentation.

## Contract

Every implementation introduced by a SLYNET phase must have a matching interface declaration unless it is explicitly private/internal and excluded from public RPC dispatch.

The first aligned extension set is:

- `source-aware-eval`
- `list-restart-scopes`
- `interrupt-execution-unit`
- `debugger-step-checkpoint`
- `debugger-frame-details`
- `thread-info`
- `frame-source-location`
- `inspect-for-emacs`
- `macroexpand-1-for-emacs`
- `macroexpand-all-for-emacs`
- `slynet-apropos`

## Validation

P17 validates the contract with `implemented extension RPCs have interface declarations` in `test/project_core_tests.janet`.

That test asserts that representative extension RPCs have both:

- `inf/get-implementation`
- `inf/get-interface`

## Known boundary

P17 does not make every declared historical SLY/SLYNK interface implemented. The project still intentionally carries many declared-but-not-implemented interfaces as inventory signal for future parity work. P17 only closes the opposite gap: implemented extension RPCs without a declared contract.
