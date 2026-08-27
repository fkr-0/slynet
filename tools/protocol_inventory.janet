# Generate a machine-readable SLY/SLYNK-to-SLYNET protocol inventory.
# Extracts SLY defslyfun/definterface names and maps them to Janet/test evidence.

(def source-files [
  "sly_source/slynk/slynk.lisp"
  "sly_source/slynk/slynk-apropos.lisp"
  "sly_source/slynk/slynk-completion.lisp"
  "sly_source/slynk/slynk-backend.lisp"
  "sly_source/slynk/xref.lisp"
  "sly_source/contrib/slynk-arglists.lisp"
  "sly_source/contrib/slynk-fancy-inspector.lisp"
  "sly_source/contrib/slynk-indentation.lisp"
  "sly_source/contrib/slynk-mrepl.lisp"
  "sly_source/contrib/slynk-package-fu.lisp"
  "sly_source/contrib/slynk-profiler.lisp"
  "sly_source/contrib/slynk-retro.lisp"
  "sly_source/contrib/slynk-stickers.lisp"
  "sly_source/contrib/slynk-trace-dialog.lisp"
])

(def janet-files [
  "slynet/slynk.janet"
  "slynet/backend.janet"
  "slynet/completion.janet"
  "slynet/interfaces.janet"
  "slynet/xref.janet"
  "slynet/proto/core.janet"
  "slynet/proto/completion.janet"
  "slynet/contrib/slynet-apropos.janet"
  "slynet/contrib/slynet-arglists.janet"
  "slynet/contrib/slynet-fancy-inspector.janet"
  "slynet/contrib/slynet-indentation.janet"
  "slynet/contrib/slynet-mrepl.janet"
  "slynet/contrib/slynet-package-fu.janet"
  "slynet/contrib/slynet-profiler.janet"
  "slynet/contrib/slynet-retro.janet"
  "slynet/contrib/slynet-stickers.janet"
  "slynet/contrib/slynet-trace-dialog.janet"
])

# The 1.1 stable subset is intentionally smaller than the historical SLYNK
# corpus.  These operations are the release-critical RPC contract that must be
# callable and have explicit operation-level test ownership before release.
(def stable-subset-by-surface
  @{
    "transport" @["ping" "connection-info" "flow-control-test" "io-speed-test"]
    "repl" @["create-mrepl" "interactive-eval-region" "pprint-eval"]
    "completion" @["simple-completions" "flex-completions" "operator-arglist" "arglist" "describe-function" "autodoc"]
    "compile_load" @["compile-file-for-emacs" "compile-string-for-emacs" "load-file" "macroexpand-all"]
    "inspector" @["inspector-nth-part" "inspector-pop" "inspector-reinspect" "inspector-history" "inspector-call-nth-action"]
    "xref" @["find-definitions-for-emacs" "frame-source-location"]
    "debugger" @["debugger-info-for-emacs" "backtrace" "frame-locals-and-catch-tags" "list-threads" "debug-nth-thread" "kill-nth-thread" "invoke-nth-restart"]
  })

(def stale-doc-files [
  "docs/missing_protocol.md"
  "docs/missing_protocol_definterface.md"
])

(defn- slurp-or-empty [path]
  (try (slurp path) ([err fib] "")))

(defn- contains? [text needle]
  (not (nil? (string/find needle text))))

(defn- any-pattern? [text patterns]
  (var ok false)
  (each pattern patterns
    (when (contains? text pattern)
      (set ok true)))
  ok)

(defn- file-matches-patterns? [path patterns]
  (any-pattern? (slurp-or-empty path) patterns))

(defn- evidence-files [files patterns]
  (def out @[])
  (each path files
    (when (file-matches-patterns? path patterns)
      (array/push out path)))
  out)

(defn- last-find-before [text needle limit]
  (var cursor 0)
  (var last nil)
  (var searching true)
  (while searching
    (def pos (string/find needle text cursor))
    (if (or (nil? pos) (>= pos limit))
      (set searching false)
      (do
        (set last pos)
        (set cursor (+ pos 1)))))
  last)

(defn- max-position [positions]
  (var best nil)
  (each pos positions
    (when (and pos (or (nil? best) (> pos best)))
      (set best pos)))
  best)

(defn- min-position [positions fallback]
  (var best fallback)
  (each pos positions
    (when (and pos (< pos best))
      (set best pos)))
  best)

(defn- join-path [base name]
  (if (or (= base "") (= base "/"))
    (string base name)
    (string base "/" name)))

(defn- collect-janet-files [root]
  (def out @[])
  (defn walk [dir]
    (each entry (os/dir dir)
      (def path (join-path dir entry))
      (def stat (try (os/stat path) ([_ _] nil)))
      (when stat
        (cond
          (= (stat :mode) :directory) (walk path)
          (and (= (stat :mode) :file) (string/has-suffix? ".janet" path))
          (array/push out path)))))
  (walk root)
  (sorted out))

(def test-files (collect-janet-files "test"))

(defn- explicit-cover-blocks [path]
  # Direct coverage is declared as a flat string array on a test spec, e.g.
  #   :covers ["ping" "connection-info"]
  # The inventory never infers direct coverage from incidental symbol mentions.
  (def text (slurp-or-empty path))
  (def blocks @[])
  (var cursor 0)
  (var searching true)
  (while searching
    (def marker (string/find ":covers" text cursor))
    (if (nil? marker)
      (set searching false)
      (let [open (string/find "[" text marker)]
        (if (nil? open)
          (set searching false)
          (let [close (string/find "]" text (+ open 1))]
            (if (nil? close)
              (set searching false)
              (do
                (array/push blocks (string/slice text (+ open 1) close))
                (set cursor (+ close 1)))))))))
  blocks)

(defn- file-explicitly-covers? [path operation]
  (def needle (string "\"" operation "\""))
  (var covered false)
  (each block (explicit-cover-blocks path)
    (when (contains? block needle)
      (set covered true)))
  covered)

(defn- explicit-test-evidence-files [operation]
  (def out @[])
  (each path test-files
    (when (file-explicitly-covers? path operation)
      (array/push out path)))
  out)

(defn- source-patterns [operation]
  @[(string "(defslyfun " operation)
    (string "(definterface " operation)])

(defn- janet-definition-patterns [operation]
  @[(string "(defn " operation " ")
    (string "(def " operation " ")
    (string "(var " operation " ")])

(defn- janet-registration-patterns [operation]
  @[(string "(inf/defimpl '" operation " ")
    (string "(inf/defimpl \"" operation "\" ")])

(defn- final-registration-position [text operation]
  (max-position
    (map |(last-find-before text $ (length text))
         (janet-registration-patterns operation))))

(defn- definition-body-before-registration [text operation registration-pos]
  (def definition-pos
    (max-position
      (map |(last-find-before text $ registration-pos)
           (janet-definition-patterns operation))))
  (when definition-pos
    (def body-end
      (min-position
        @[(string/find "\n(defn " text (+ definition-pos 1))
          (string/find "\n(def " text (+ definition-pos 1))
          (string/find "\n(var " text (+ definition-pos 1))
          (string/find "\n(defmacro " text (+ definition-pos 1))]
        registration-pos))
    (string/slice text definition-pos body-end)))

(defn- registration-file-semantics [path operation]
  (def text (slurp-or-empty path))
  (def registration-pos (final-registration-position text operation))
  (if (nil? registration-pos)
    nil
    (let [body (definition-body-before-registration text operation registration-pos)]
      (cond
        (and body (contains? body "(error \"Not implemented\")")) "error_stub"
        (and body
             (contains? body ":status :unsupported")
             (not (contains? body ":status :ok"))) "unsupported_stub"
        true "functional"))))

(defn- registration-semantics [operation registration-evidence]
  # A functional registration wins over an obsolete/overridden stub.  This
  # handles files such as backend.janet that preserve historical definitions
  # before a later real implementation.
  (var saw-error false)
  (var saw-unsupported false)
  (var saw-functional false)
  (each path registration-evidence
    (case (registration-file-semantics path operation)
      "functional" (set saw-functional true)
      "error_stub" (set saw-error true)
      "unsupported_stub" (set saw-unsupported true)
      nil))
  (cond
    saw-functional "functional"
    saw-unsupported "unsupported_stub"
    saw-error "error_stub"
    true "functional"))

(defn- stub-evidence-files [operation registration-evidence]
  (def out @[])
  (each path registration-evidence
    (def semantics (registration-file-semantics path operation))
    (when (or (= semantics "error_stub") (= semantics "unsupported_stub"))
      (array/push out path)))
  out)

(defn- missing-doc-patterns [operation]
  @[(string "`" operation "`")
    (string "*   `" operation "`")
    (string "(definterface " operation)
    (string "(defslyfun " operation)])

(defn- min2 [a b]
  (if (< a b) a b))

(defn- token-after [prefix line]
  (when (string/has-prefix? prefix line)
    (def rest (string/trim (string/slice line (length prefix))))
    (def end-space (string/find " " rest))
    (def end-paren (string/find ")" rest))
    (def end (cond
               (and end-space end-paren) (min2 end-space end-paren)
               end-space end-space
               end-paren end-paren
               true (length rest)))
    (string/slice rest 0 end)))

(defn- extract-source-ops-from-file [path]
  (def out @[])
  (def lines (string/split "\n" (slurp-or-empty path)))
  (each line lines
    (def trimmed (string/trim line))
    (def maybe-rpc (token-after "(defslyfun " trimmed))
    (when maybe-rpc
      (array/push out {:name maybe-rpc :kind "defslyfun" :source path}))
    (def maybe-interface (token-after "(definterface " trimmed))
    (when maybe-interface
      (array/push out {:name maybe-interface :kind "definterface" :source path})))
  out)

(defn- put-op! [ops rec]
  (def name (rec :name))
  (def existing (get ops name))
  (if existing
    (do
      (when (not (contains? (string (existing :kinds)) (rec :kind)))
        (array/push (existing :kinds) (rec :kind)))
      (when (not (contains? (string (existing :source_files)) (rec :source)))
        (array/push (existing :source_files) (rec :source))))
    (put ops name {:name name :kinds @[(rec :kind)] :source_files @[(rec :source)]})))

(defn- discovered-operations []
  (def ops @{})
  (each path source-files
    (each rec (extract-source-ops-from-file path)
      (put-op! ops rec)))
  ops)

(defn- sorted-names [ops]
  (def names @[])
  (eachp [name _] ops (array/push names name))
  names)

(defn- stale-doc-state [operation]
  (if (> (length (evidence-files stale-doc-files (missing-doc-patterns operation))) 0)
    "stale_doc_lists_as_missing"
    "not_listed_missing"))


(defn- constraint-for [operation]
  (cond
    (or (= operation "set-package")
        (= operation "frame-package-name")
        (= operation "package-local-nicknames")
        (= operation "find-locally-nicknamed-package")
        (= operation "list-all-package-names"))
    "cl_packages"

    (or (= operation "invoke-nth-restart")
        (= operation "invoke-nth-restart-for-emacs")
        (= operation "sly-db-abort")
        (= operation "sly-db-continue")
        (= operation "debugger-info-for-emacs")
        (= operation "backtrace")
        (= operation "frame-locals-and-catch-tags")
        (= operation "return-from-frame")
        (= operation "restart-frame")
        (= operation "sly-db-break-on-return")
        (= operation "sly-db-break-at-start")
        (= operation "sly-db-step-into")
        (= operation "sly-db-step-next")
        (= operation "sly-db-step-out"))
    "conditions_restarts"

    (or (= operation "generic-method-specs")
        (= operation "generic-method-lambda-list")
        (= operation "methods-by-applicability")
        (= operation "method-specializers")
        (= operation "remove-method-by-name"))
    "clos_mop"

    (or (= operation "compile-file-for-emacs")
        (= operation "compile-string-for-emacs")
        (= operation "compile-multiple-strings-for-emacs")
        (= operation "compile-file-if-needed")
        (= operation "slynk-compile-string")
        (= operation "slynk-compile-file"))
    "compiler_notes"

    (or (= operation "list-threads")
        (= operation "thread-name")
        (= operation "thread-status")
        (= operation "thread-id")
        (= operation "kill-thread")
        (= operation "debug-nth-thread")
        (= operation "spawn")
        (= operation "initialize-multiprocessing"))
    "threads"

    true "none"))


(defn- constraint-reason-for [constraint]
  (case constraint
    "cl_packages" "Janet has modules/environments, not CL packages and reader package semantics."
    "conditions_restarts" "Janet exceptions/stack traces do not expose CL condition/restart semantics."
    "clos_mop" "Janet does not provide CLOS/MOP method metadata."
    "compiler_notes" "Janet diagnostics differ from CL compiler note objects and source-note semantics."
    "threads" "Janet execution units/fibers do not map one-to-one to CL implementation thread APIs."
    "none" ""))

(defn- state-for [definition-evidence registration-evidence test-evidence registration-semantics]
  (cond
    (and (> (length registration-evidence) 0)
         (not (= registration-semantics "functional"))) "registered_stub"
    (and (> (length registration-evidence) 0)
         (> (length test-evidence) 0)) "implemented"
    (> (length registration-evidence) 0) "implemented_untested"
    (> (length definition-evidence) 0) "implemented_unwired"
    true "missing"))

(defn- operation-in? [operation names]
  (var found false)
  (each name names
    (when (= operation name)
      (set found true)))
  found)

(defn- stable-subset? [operation frontend-surface]
  (def names (get stable-subset-by-surface frontend-surface @[]))
  (operation-in? operation names))

(defn- operation-has-prefix? [operation prefixes]
  (var found false)
  (each prefix prefixes
    (when (string/has-prefix? prefix operation)
      (set found true)))
  found)

(defn- operation-contains-any? [operation needles]
  (var found false)
  (each needle needles
    (when (contains? operation needle)
      (set found true)))
  found)

(defn- frontend-surface-for [operation]
  (cond
    (operation-in? operation @["ping" "connection-info" "io-speed-test" "flow-control-test" "emacs-connected" "preferred-communication-style"])
    "transport"

    (or (operation-in? operation @["create-mrepl" "eval-for-mrepl" "interactive-eval-region" "pprint-eval" "pprint-entry" "sync-package-and-default-directory"])
        (operation-contains-any? operation @["mrepl" "eval"]))
    "repl"

    (or (operation-contains-any? operation @["completion" "completions" "arglist" "autodoc" "apropos" "documentation-symbol"])
        (operation-in? operation @["describe-function" "describe-symbol" "describe-definition-for-emacs"]))
    "completion"

    (or (operation-has-prefix? operation @["inspector-"])
        (operation-contains-any? operation @["inspect" "inspector"]))
    "inspector"

    (or (operation-has-prefix? operation @["xref" "who-"])
        (operation-contains-any? operation @["definition" "definitions" "source-location" "source-file" "callers" "callees" "references"])
        (operation-in? operation @["find-definitions-for-emacs" "find-source-location-for-emacs"]))
    "xref"

    (or (operation-contains-any? operation @["debug" "backtrace" "restart" "condition" "frame" "thread"])
        (operation-has-prefix? operation @["sly-db-"]))
    "debugger"

    (operation-contains-any? operation @["compile" "load-file" "macroexpand"])
    "compile_load"

    (operation-contains-any? operation @["package" "symbol" "module"])
    "namespace"

    true "backend"))


(defn- owning-spec-for [operation frontend-surface constraint]
  (cond
    (= constraint "threads") "docs/specs/threading-execution-units.md"
    (= constraint "conditions_restarts") "docs/specs/debugger-condition-restarts.md"
    (= frontend-surface "debugger") "docs/specs/debugger-condition-restarts.md"
    (or (= frontend-surface "inspector") (= frontend-surface "xref")) "docs/specs/inspector-xref-source-index.md"
    true "docs/specs/emacs-client-contract.md"))

(defn- validation-stage-for [operation frontend-surface constraint]
  (cond
    (= constraint "threads") "P3_thread_debugger_condition_facade"
    (= constraint "conditions_restarts") "P3_thread_debugger_condition_facade"
    (= frontend-surface "transport") "P1_transport_session_protocol"
    (= operation "create-mrepl") "P2_eval_mrepl_first_real_e2e"
    (= frontend-surface "repl") "P6_emacs_repl_buffer_ui"
    (= frontend-surface "completion") "P7_completion_autodoc_capf"
    (= frontend-surface "inspector") "P8_inspector_xref_emacs_ui"
    (= frontend-surface "xref") "P8_inspector_xref_emacs_ui"
    (= frontend-surface "compile_load") "P13_diagnostics_ui"
    (= frontend-surface "namespace") "P14_project_connection_management"
    true "P0_inventory_truth"))

(def operation-support-class-overrides
  @{"compiler-macroexpand-1" "emulated"
    "compiler-macroexpand" "emulated"})

(def operation-support-rationale-overrides
  @{"compiler-macroexpand-1"
    "Uses Janet macro expansion as an explicit compatibility emulation; Common Lisp compiler-macro and lexical environment semantics are not available."
    "compiler-macroexpand"
    "Uses Janet macro expansion as an explicit compatibility emulation; Common Lisp compiler-macro and lexical environment semantics are not available."})

(defn- support-rationale-for [operation support-class constraint state-detail]
  (or (get operation-support-rationale-overrides operation)
      (case support-class
        "native" "Supported directly by Janet behavior with protocol adaptation."
        "emulated" (string "Supported through SLYNET emulation because " (constraint-reason-for constraint))
        "unsupported" (string "Not currently supported because " (constraint-reason-for constraint))
        "pending_design" (string "Pending staged design; current state is " state-detail ".")
        (string "Support class " support-class " requires explicit review."))))

(defn- support-class-for [operation constraint]
  (or (get operation-support-class-overrides operation)
      (case constraint
        "none" "native"
        "clos_mop" "unsupported"
        "cl_packages" "emulated"
        "conditions_restarts" "emulated"
        "compiler_notes" "emulated"
        "threads" "emulated"
        "pending_design" "pending_design"
        "emulated")))

(defn- state-detail-for [definition-evidence registration-evidence test-evidence constraint support-class registration-semantics]
  (def has-definition (> (length definition-evidence) 0))
  (def has-registration (> (length registration-evidence) 0))
  (def has-tests (> (length test-evidence) 0))
  (cond
    (and has-registration (= registration-semantics "error_stub")) "registered_error_stub"
    (and has-registration (= registration-semantics "unsupported_stub")) "registered_unsupported_stub"
    (and has-registration has-tests (= support-class "native")) "implemented_native_tested"
    (and has-registration (= support-class "native")) "implemented_native_untested"
    (and has-registration has-tests (= support-class "emulated")) "implemented_emulated_tested"
    (and has-registration (= support-class "emulated")) "implemented_emulated_untested"
    (and has-definition (= support-class "native")) "implemented_native_unwired"
    (and has-definition (= support-class "emulated")) "implemented_emulated_unwired"
    (not has-definition) (if (= constraint "none") "missing_unconstrained" "missing_constrained")
    true "implemented_unwired"))

(defn- yaml-list [indent key values]
  (def prefix (string/repeat " " indent))
  (if (empty? values)
    (string prefix key ": []\n")
    (do
      (def out (buffer/new 0))
      (buffer/push-string out (string prefix key ":\n"))
      (each value values
        (buffer/push-string out (string prefix "  - " value "\n")))
      (string out))))

(defn- documented-constraint-ids []
  (def text (slurp-or-empty "tasks.yml"))
  (def ids @[])
  (each id @["cl_packages" "conditions_restarts" "clos_mop" "compiler_notes" "cl_lambda_lists" "threads"]
    (when (contains? text (string "- id: " id))
      (array/push ids id)))
  ids)

(defn- array-has? [xs value]
  (var found false)
  (each x xs
    (when (= x value)
      (set found true)))
  found)

(defn- push-unique! [xs value]
  (when (not (array-has? xs value))
    (array/push xs value))
  xs)

(defn- used-constraint-ids [ops]
  (def used @[])
  (eachp [name _] ops
    (def constraint (constraint-for name))
    (when (not (= constraint "none"))
      (push-unique! used constraint)))
  used)

(defn- undocumented-constraints [used documented]
  (def missing @[])
  (each id used
    (when (not (array-has? documented id))
      (array/push missing id)))
  missing)

(defn- coverage-audit-section [ops]
  (def documented (documented-constraint-ids))
  (def used (used-constraint-ids ops))
  (def missing (undocumented-constraints used documented))
  (def out (buffer/new 0))
  (buffer/push-string out "constraint_coverage_audit:\n")
  (buffer/push-string out (yaml-list 2 "documented_constraints" documented))
  (buffer/push-string out (yaml-list 2 "used_constraints" used))
  (buffer/push-string out (yaml-list 2 "undocumented_constraints" missing))
  (string out))

(defn- stable-surface-facts [ops surface names]
  (var functional 0)
  (var tested 0)
  (def missing @[])
  (def untested @[])
  (def stubbed @[])
  (each name names
    (def rec (get ops name))
    (if (nil? rec)
      (array/push missing name)
      (let [definition-evidence (evidence-files janet-files (janet-definition-patterns name))
            registration-evidence (evidence-files janet-files (janet-registration-patterns name))
            test-evidence (explicit-test-evidence-files name)
            semantics (registration-semantics name registration-evidence)]
        (cond
          (or (= semantics "error_stub") (= semantics "unsupported_stub"))
          (array/push stubbed name)
          (> (length registration-evidence) 0)
          (do
            (++ functional)
            (if (> (length test-evidence) 0)
              (++ tested)
              (array/push untested name)))
          true (array/push missing name)))))
  (def total (length names))
  (def percent (if (= total 0) 100 (math/floor (* 100 (/ tested total)))))
  @{:surface surface
    :total total
    :functional functional
    :tested tested
    :coverage-percent percent
    :missing missing
    :untested untested
    :stubbed stubbed
    :gate (if (and (= tested total) (= functional total)) "pass" "fail")})

(defn- stable-subset-facts [ops]
  (def facts @[])
  (each surface (sorted (keys stable-subset-by-surface))
    (array/push facts
                (stable-surface-facts ops surface (stable-subset-by-surface surface))))
  facts)

(defn- stable-subset-audit-section [ops]
  (def facts (stable-subset-facts ops))
  (var all-pass true)
  (def out (buffer/new 0))
  (buffer/push-string out "stable_subset_coverage:\n")
  (buffer/push-string out "  threshold_policy: direct_tested_percent_by_surface\n")
  (buffer/push-string out "  required_percent: 100\n")
  (buffer/push-string out "  surfaces:\n")
  (each fact facts
    (when (= "fail" (fact :gate)) (set all-pass false))
    (buffer/push-string out (string "    " (fact :surface) ":\n"))
    (buffer/push-string out (string "      total: " (fact :total) "\n"))
    (buffer/push-string out (string "      functional_registered: " (fact :functional) "\n"))
    (buffer/push-string out (string "      directly_tested: " (fact :tested) "\n"))
    (buffer/push-string out (string "      coverage_percent: " (fact :coverage-percent) "\n"))
    (buffer/push-string out (string "      gate: " (fact :gate) "\n"))
    (buffer/push-string out (yaml-list 6 "missing" (fact :missing)))
    (buffer/push-string out (yaml-list 6 "untested" (fact :untested)))
    (buffer/push-string out (yaml-list 6 "stubbed" (fact :stubbed))))
  (buffer/push-string out (string "  gate: " (if all-pass "pass" "fail") "\n"))
  (string out))

(defn- write-coverage-summary [ops output-path]
  (def facts (stable-subset-facts ops))
  (def out (buffer/new 0))
  (buffer/push-string out "---\nlayout: page\ntitle: Protocol coverage\n---\n\n")
  (buffer/push-string out "# Protocol coverage\n\n")
  (buffer/push-string out "Generated from `tools/protocol_inventory.janet`. Do not edit by hand.\n\n")
  (buffer/push-string out "The release gate requires **100% explicit direct test mapping** for the declared stable subset on every frontend surface below. Historical SLYNK operations outside this subset remain visible in the full inventory without becoming a 1.1 compatibility claim.\n\n")
  (buffer/push-string out "| Surface | Stable ops | Functional | Directly tested | Coverage | Gate |\n")
  (buffer/push-string out "|---|---:|---:|---:|---:|---|\n")
  (each fact facts
    (buffer/push-string out
      (string "| " (fact :surface) " | " (fact :total) " | " (fact :functional)
              " | " (fact :tested) " | " (fact :coverage-percent) "% | " (fact :gate) " |\n")))
  (buffer/push-string out "\n## Stable subset\n\n")
  (each surface (sorted (keys stable-subset-by-surface))
    (buffer/push-string out (string "### " surface "\n\n"))
    (each name (stable-subset-by-surface surface)
      (buffer/push-string out (string "- `" name "`\n")))
    (buffer/push-string out "\n"))
  (spit output-path (string out)))


(defn- operation-record [rec]
  (def operation (rec :name))
  (def source-evidence (rec :source_files))
  (def definition-evidence (evidence-files janet-files (janet-definition-patterns operation)))
  (def registration-evidence (evidence-files janet-files (janet-registration-patterns operation)))
  (def registration-status (registration-semantics operation registration-evidence))
  (def stub-files (stub-evidence-files operation registration-evidence))
  (def janet-evidence (sorted (array/concat @[] definition-evidence registration-evidence)))
  (def test-evidence (explicit-test-evidence-files operation))
  (def stale-files (evidence-files stale-doc-files (missing-doc-patterns operation)))
  (def out (buffer/new 0))
  (buffer/push-string out (string "  - name: " operation "\n"))
  (buffer/push-string out (string "    kind: " (string/join (rec :kinds) ",") "\n"))
  (def frontend-surface (frontend-surface-for operation))
  (buffer/push-string out (string "    frontend_surface: " frontend-surface "\n"))
  (buffer/push-string out (string "    stable_subset: " (if (stable-subset? operation frontend-surface) "true" "false") "\n"))
  (def constraint (constraint-for operation))
  (def support-class (support-class-for operation constraint))
  (def state-detail (state-detail-for definition-evidence registration-evidence test-evidence constraint support-class registration-status))
  (buffer/push-string out (string "    support_class: " support-class "\n"))
  (buffer/push-string out (string "    state: " (state-for definition-evidence registration-evidence test-evidence registration-status) "\n"))
  (buffer/push-string out (string "    state_detail: " state-detail "\n"))
  (buffer/push-string out (string "    registration_semantics: " registration-status "\n"))
  (buffer/push-string out (string "    validation_stage: " (validation-stage-for operation frontend-surface constraint) "\n"))
  (buffer/push-string out (string "    owning_spec: " (owning-spec-for operation frontend-surface constraint) "\n"))
  (buffer/push-string out (yaml-list 4 "source_files" source-evidence))
  (buffer/push-string out (yaml-list 4 "janet_files" janet-evidence))
  (buffer/push-string out (yaml-list 4 "definition_files" definition-evidence))
  (buffer/push-string out (yaml-list 4 "registration_files" registration-evidence))
  (buffer/push-string out (yaml-list 4 "stub_files" stub-files))
  (buffer/push-string out (yaml-list 4 "test_files" test-evidence))
  (buffer/push-string out "    test_evidence_kind: explicit_covers_metadata\n")
  (buffer/push-string out (string "    constraint: " constraint "\n"))
  (when (not (= constraint "none"))
    (buffer/push-string out (string "    constraint_reason: " (constraint-reason-for constraint) "\n")))
  (when (not (= support-class "native"))
    (buffer/push-string out (string "    support_rationale: " (support-rationale-for operation support-class constraint state-detail) "\n")))
  (buffer/push-string out (string "    missing_protocol_state: " (stale-doc-state operation) "\n"))
  (buffer/push-string out (yaml-list 4 "missing_protocol_files" stale-files))
  (string out))

(defn generate-inventory []
  (def output-path (or (os/getenv "SLYNET_PROTOCOL_INVENTORY_OUTPUT")
                       "docs/generated/protocol-inventory.yml"))
  (def coverage-output-path (or (os/getenv "SLYNET_PROTOCOL_COVERAGE_OUTPUT")
                                "docs/generated/protocol-coverage.md"))
  (when (= output-path "docs/generated/protocol-inventory.yml")
    (os/execute ["sh" "-c" "mkdir -p docs/generated"] :p))
  (def ops (discovered-operations))
  (def out (buffer/new 0))
  (buffer/push-string out "# Generated by tools/protocol_inventory.janet. Do not edit by hand.\n")
  (buffer/push-string out "project: slynet\n")
  (buffer/push-string out "schema_version: 6\n")
  (buffer/push-string out (string "operation_count: " (length (keys ops)) "\n"))
  (buffer/push-string out (coverage-audit-section ops))
  (buffer/push-string out (stable-subset-audit-section ops))
  (buffer/push-string out "operations:\n")
  (each name (sorted-names ops)
    (buffer/push-string out (operation-record (ops name))))
  (spit output-path (string out))
  (write-coverage-summary ops coverage-output-path)
  true)

(generate-inventory)
