# Compatibility and deprecation policy

## 1.0 support window

SLYNET 1.0 supports Emacs 27.1 through 30.x and Janet 1.40.x on GNU/Linux and
macOS. The project may accept fixes for newer compatible patch releases without
changing the minor version.

## Compatibility promises

- Documented Emacs commands, customization variables, keybindings, Janet module
  entrypoints, and stable wire operations will not be removed in a 1.x patch.
- Bug fixes may tighten malformed-input rejection or improve diagnostics.
- Internal functions and names containing a double hyphen are not public API.
- Protocol operations classified as experimental, workaround, pending-design,
  or unsupported are not covered by the stable compatibility promise.

## Deprecation

A stable public API must be documented as deprecated for at least one minor
release before removal. Deprecations include a replacement path and appear in
the changelog. Security or correctness defects may require immediate behavior
changes, but the release notes must explain the break.

## Version policy

- Patch: compatible fixes, diagnostics, tests, and documentation.
- Minor: backward-compatible features and deprecations.
- Major: intentional removal or incompatible public protocol/API changes.

`project.janet` is the canonical version source. Package headers and release
metadata must match it before a tag is created.
