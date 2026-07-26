# Inspector, Xref, and Source-Index Contract

## Scope

This file owns inspector object identity, part navigation, source-index-backed xref, source metadata, and source navigation from Emacs buffers.

Owned frontend surfaces:

- `frontend_surface: inspector`
- `frontend_surface: xref`

## Inspector contract

Inspector payloads should include stable object identity and navigation metadata:

- `object-id` for the current inspectee
- `parent-object-id` when a child part is being viewed
- `part-key` for nth-part navigation
- content lines suitable for an Emacs inspector buffer
- part entries with stable index, label, and summary

Interactive inspector controls must use part metadata rather than parsing rendered text. Clicking a part button dispatches `inspector-nth-part` with the recorded index.

## Xref/source-index contract

Xref hits should be source-index records first and runtime reflection records second. A hit should include:

- name
- xref kind
- source index marker
- file path
- line
- column
- optional snippet

Emacs navigation must use file/line/column text properties attached during rendering. Unsupported xref classes should return explicit empty or unsupported metadata rather than unstructured failure.

## Validation stages

| Stage | Owns |
| --- | --- |
| P4_inspector_xref_source_index | Stable object ids, nth-part/pop contracts, and fixture source-index hits. |
| P8_inspector_xref_emacs_ui | Inspector and xref Emacs buffers. |
| P11_interactive_inspector_xref | Clickable inspector parts and xref visit-at-point navigation. |

## Related legacy docs

The older `xref-source-index-contract.md` remains as implementation background. This file is the canonical P10 ownership target referenced by the generated support matrix and protocol inventory.


## P18/P19 implementation notes

P18 adds a SLYNET-owned span-aware Janet source index in `slynet/source_index.janet`.
This is a scanner/indexer layer above Janet, not a Janet runtime source-map API.
It records definition/import/use facts with file, line, column, end-line,
end-column, form kind, module, and snippet fields. Xref definition lookups prefer
`:source-index :slynet-source-index-v2` records before falling back to legacy
synthetic scanner hits.

P19 adds practical inspector paging and navigation metadata:

- `inspector-range` returns a bounded range with `:start`, `:end`, `:total`,
  and part records containing index, label, summary, and support class.
- `inspector-history` returns the active inspection session with stable object ids,
  parent object ids, part keys, and current-entry metadata.
- `inspector-actions` advertises safe native actions and explicitly unsupported
  unsafe actions with reason metadata.

These features are SLYNET workflow affordances. They do not claim Common Lisp
inspector action semantics or a Janet-native object mutation protocol.

## P18 / P19 update: source-index v2 and inspector utility

P18 introduces `slynet/source_index.janet`, a conservative span-aware Janet source index. It records file, line, column, end-line, end-column, module, snippet, and form-kind for project definitions and namespace forms. `find-definitions-for-emacs` now prefers `:slynet-source-index-v2` hits before falling back to legacy synthetic xref behavior.

P19 extends inspector backend utility with `inspector-range`, `inspector-history`, and `inspector-actions`. Large indexed values can be paged without eager full rendering, history entries preserve stable object identity, and actions must state native/safe or unsupported/unsafe metadata explicitly.
