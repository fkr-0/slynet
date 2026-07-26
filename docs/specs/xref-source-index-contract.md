# SLYNET Xref and Source-Index Contract

Status: working draft for phase `P4_inspector_xref_source_index` / task `T09_xref_and_source_locations`.

This document is a concrete test oracle for the first xref/source-location slice. It narrows the broader CL ↔ Janet equivalence plan into implementation contracts that can be verified with fixture files before the xref service is wired into richer Emacs UI flows.

## Actors

| tag | actor | role |
| --- | --- | --- |
| `FRONTEND` | Emacs SLYNET client | Requests definitions, xrefs, and source locations, then jumps to files. |
| `SERVER` | Janet SLYNET backend | Accepts RPC calls and normalizes Janet data into SLY-shaped replies. |
| `INDEX` | Janet source index | Parses and caches source facts for fixture/project files. |
| `RUNTIME` | Janet runtime metadata | Supplies source maps where available; never the only source of truth. |
| `FIXTURE` | `test/fixtures/xref/*.janet` | Deterministic input corpus for red/green tests. |

## Scope

### In scope for P4/X1

- Definition lookup for Janet `def`, `var`, `defn`, `defmacro`, and SLYNET `definterface` forms.
- Exact file, line, column, symbol name, kind, and snippet for fixture-backed hits.
- Duplicate suppression for repeated scan paths.
- Stable empty/unsupported replies for xref classes that are not implemented yet.
- Explicit invalidation behavior when fixture files change.
- Source-location reuse by debugger frames and compile diagnostics in later phases.

### Out of scope for P4/X1

- Full semantic Janet analysis.
- Macroexpansion dependency tracking.
- Whole-program call graph correctness.
- Cross-package/import alias resolution beyond direct fixture facts.
- Editor UI rendering beyond consuming returned protocol data.

## Current baseline observed in source

The current `slynet/slynk.janet` path already has a string-scanning `find-definitions-for-emacs` implementation. It scans candidate Janet files, recognizes definition-line patterns, and returns plist-like hit arrays with `:name`, `:file`, `:line`, `:column`, `:kind`, `:match`, and `:snippet` fields.

That baseline is useful, but not sufficient as the final source-index contract because fallback synthetic hits can hide missing index data. P4 must replace fallback-success behavior in fixture tests with deterministic indexed facts.

## Protocol result shapes

### Definition hit

A definition hit returned to `FRONTEND` MUST be a plist-shaped array:

```janet
@[:name "fixture-target"
  :file "/absolute/path/to/test/fixtures/xref/sample_a.janet"
  :line 12
  :column 7
  :kind :function
  :match "fixture-target"
  :snippet "(defn fixture-target [x]"]
```

Required fields:

| field | type | rule |
| --- | --- | --- |
| `:name` | string | Requested display symbol, without synthetic package decoration. |
| `:file` | string | Absolute path for local source jumps. |
| `:line` | number | 1-based line. |
| `:column` | number | 1-based column of the symbol token, not always `1`. |
| `:kind` | keyword | One of `:function`, `:macro`, `:value`, `:var`, `:interface`, or `:unknown`. |
| `:match` | string | Exact token matched in source. |
| `:snippet` | string | Trimmed source line containing the defining form. |

### Xref hit

`xref` and `xrefs` SHOULD return grouped results so the frontend can display section labels without guessing:

```janet
@[:type :calls
  :label "calls"
  :support @{:class :emulated :state :implemented_emulated_tested}
  :hits @[@[:name "fixture-helper"
           :file "/absolute/path/to/test/fixtures/xref/sample_b.janet"
           :line 18
           :column 4
           :kind :call
           :match "fixture-helper"
           :snippet "(fixture-helper x)"]]]
```

For unsupported xref classes the backend MUST return a successful empty section with explicit metadata, not an exception and not a fabricated hit:

```janet
@[:type :specializes
  :label "specializes"
  :support @{:class :unsupported
             :state :missing_constrained
             :reason "Janet has no CLOS generic-function specializer model."}
  :hits @[]]
```

## Index data model

The `INDEX` SHOULD store facts in a normalized table keyed by canonical file path and mtime/content digest:

```janet
@{:schema-version 1
  :files @{"/abs/sample_a.janet"
           @{:mtime 123456789
             :digest "sha256-or-fast-hash"
             :forms @[]}}
  :definitions @{"fixture-target"
                 @[@{:file "/abs/sample_a.janet"
                     :line 12
                     :column 7
                     :kind :function
                     :snippet "(defn fixture-target [x]"}]}
  :references @{:calls @{"fixture-helper" @[@{:file "/abs/sample_b.janet"
                                               :line 18
                                               :column 4}]}}}
```

Minimum P4/X1 fact kinds:

- `:definition/function`
- `:definition/macro`
- `:definition/value`
- `:definition/var`
- `:definition/interface`
- `:reference/call`
- `:reference/symbol`

## Matching rules

1. Match Janet symbols as tokens, not substrings.
   - `target` MUST NOT match `target-extra`.
   - `foo/bar` MUST be matchable as a full Janet symbol.
2. Match definition forms only when the target symbol is the binding name of the form.
3. Preserve first-class symbols with punctuation Janet allows, including `?`, `!`, `*`, `-`, `/`, and `->`.
4. Do not index comments as definitions or calls.
5. Do not index string contents as definitions or calls.
6. For duplicate definitions, return all hits in deterministic order: file path, then line, then column.
7. For changed files, invalidate old facts before inserting new facts.

## Fixture contract

Create fixtures under:

```text
test/fixtures/xref/sample_a.janet
test/fixtures/xref/sample_b.janet
test/fixtures/xref/generated_ignore.janet
```

`sample_a.janet` SHOULD contain at least:

```janet
(def sample-value 10)
(var *sample-state* nil)
(defn fixture-target [x]
  (+ x sample-value))
(defmacro fixture-macro [& body]
  ~(do ,;body))
```

`sample_b.janet` SHOULD contain at least:

```janet
(import ./sample_a)
(defn fixture-caller [x]
  (fixture-target x))
```

`generated_ignore.janet` SHOULD prove that ignored/generated paths can be excluded when tests configure an ignore predicate.

## RPC contracts

### `find-definitions-for-emacs`

Input examples:

```janet
(find-definitions-for-emacs "fixture-target")
(find-definitions-for-emacs 'fixture-target)
```

Required behavior:

- returns at least one fixture-backed hit for `fixture-target`.
- the first hit has `:kind :function`.
- the first hit has a real fixture file path and exact source line/column.
- no synthetic fallback hit is accepted in fixture-mode tests.

### `find-source-location-for-emacs`

Required behavior:

- returns a single source-location plist for a known fixture symbol.
- returns `nil` or an explicit unsupported/missing metadata plist for unknown symbols; it MUST NOT fabricate a source file.

### `xref` / `xrefs`

Required behavior:

- `xref :calls "fixture-caller"` returns call/reference data where implemented.
- unsupported classes such as `:specializes` return explicit support metadata and empty hits.
- `xrefs` returns one section per requested type in requested order.

## Test plan

Add a focused test file:

```text
test/inspector_xref_contract_tests.janet
```

Minimum red tests:

```yaml
red_tests:
  - name: "xref fixture definitions return exact source facts"
    command: "JANET_PATH=$PWD janet test/inspector_xref_contract_tests.janet :match 'xref fixture definitions'"
    initial_failure: "current scanner returns column 1 or synthetic fallback instead of exact fixture column"
  - name: "xref token matching ignores comments strings and substrings"
    command: "JANET_PATH=$PWD janet test/inspector_xref_contract_tests.janet :match 'xref token matching'"
    initial_failure: "current string search accepts substring/comment/string false positives"
  - name: "unsupported xref classes return support metadata"
    command: "JANET_PATH=$PWD janet test/inspector_xref_contract_tests.janet :match 'unsupported xref metadata'"
    initial_failure: "xref/xrefs are interface declarations without contract-shaped implementation"
```

Green commands:

```yaml
green_commands:
  - "JANET_PATH=$PWD janet test/inspector_xref_contract_tests.janet :report compact"
  - "JANET_PATH=$PWD janet test/run_tests.janet :report compact"
```

## Done criteria for P4/X1

P4/X1 is done when:

- fixture-backed definition lookups pass without fallback hits.
- line and column are exact for all fixture definition kinds.
- token matching rejects comment/string/substring false positives.
- unsupported xref classes include support metadata.
- `docs/generated/protocol-inventory.yml` marks `find-definitions-for-emacs`, `find-source-location-for-emacs`, `xref`, and `xrefs` with `frontend_surface: xref` and P4 validation ownership.
- aggregate Janet suite stays green.

## Handoff notes for debugger integration

Debugger phase `P3` should consume source facts from this contract rather than duplicate line-scanning logic. Frame source locations SHOULD be normalized through the same `INDEX` hit shape with an added debugger-specific wrapper:

```janet
@{:frame 0
  :source @[:name "fixture-target"
            :file "/abs/sample_a.janet"
            :line 12
            :column 7
            :kind :function
            :snippet "(defn fixture-target [x]"]
  :confidence :indexed}
```

If no indexed source fact exists, debugger code may return `:confidence :runtime` or `:confidence :unknown`, but it MUST NOT synthesize precise-looking file/line data.


## Source index v2 status

The P18 implementation is `slynet/source_index.janet`. It supersedes the first
fixture scanner for definition xref results by returning
`:source-index :slynet-source-index-v2` plus span fields (`:end-line`,
`:end-column`) and Janet source facts (`:form-kind`, `:module`). The current
implementation is intentionally a SLYNET scanner/indexer workaround; it is not a
stable Janet runtime source-map facility.
