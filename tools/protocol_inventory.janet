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
  "sly_source/contrib/slynk-mrepl.lisp"
  "sly_source/contrib/slynk-package-fu.lisp"
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
  "slynet/contrib/slynet-mrepl.janet"
  "slynet/contrib/slynet-package-fu.janet"
])

(def test-files [
  "test/project_core_tests.janet"
  "test/server_integration_tests.janet"
  "test/channel_dispatch_tests.janet"
  "test/contrib_tests.janet"
  "test/suite-slynet.janet"
  "test/protocol_inventory_tests.janet"
])

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

(defn- source-patterns [operation]
  @[(string "(defslyfun " operation)
    (string "(definterface " operation)])

(defn- janet-patterns [operation]
  @[(string "(defn " operation)
    (string "(def " operation " ")
    (string "(var " operation " ")
    (string "(inf/defimpl '" operation)
    (string "(inf/defimpl "" operation """)
    (string "(definterface '" operation)
    (string "(definterface " operation " ")
    (string ":" operation " ")
    (string ":" operation "}")])

(defn- test-patterns [operation]
  @[(string "'(" operation " ")
    (string "'" operation)
    (string """ operation """)
    (string "name: " operation)
    (string "  - name: " operation)])

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

(defn- state-for [janet-evidence test-evidence]
  (cond
    (and (> (length janet-evidence) 0)
         (> (length test-evidence) 0)) "implemented"
    (> (length janet-evidence) 0) "implemented_untested"
    true "missing"))

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


(defn- operation-record [rec]
  (def operation (rec :name))
  (def source-evidence (rec :source_files))
  (def janet-evidence (evidence-files janet-files (janet-patterns operation)))
  (def test-evidence (evidence-files test-files (test-patterns operation)))
  (def stale-files (evidence-files stale-doc-files (missing-doc-patterns operation)))
  (def out (buffer/new 0))
  (buffer/push-string out (string "  - name: " operation "\n"))
  (buffer/push-string out (string "    kind: " (string/join (rec :kinds) ",") "\n"))
  (buffer/push-string out (string "    state: " (state-for janet-evidence test-evidence) "\n"))
  (buffer/push-string out (yaml-list 4 "source_files" source-evidence))
  (buffer/push-string out (yaml-list 4 "janet_files" janet-evidence))
  (buffer/push-string out (yaml-list 4 "test_files" test-evidence))
  (def constraint (constraint-for operation))
  (buffer/push-string out (string "    constraint: " constraint "\n"))
  (when (not (= constraint "none"))
    (buffer/push-string out (string "    constraint_reason: " (constraint-reason-for constraint) "\n")))
  (buffer/push-string out (string "    missing_protocol_state: " (stale-doc-state operation) "\n"))
  (buffer/push-string out (yaml-list 4 "missing_protocol_files" stale-files))
  (string out))

(defn generate-inventory []
  (os/execute ["sh" "-c" "mkdir -p docs/generated"] :p)
  (def ops (discovered-operations))
  (def out (buffer/new 0))
  (buffer/push-string out "# Generated by tools/protocol_inventory.janet. Do not edit by hand.\n")
  (buffer/push-string out "project: slynet\n")
  (buffer/push-string out "schema_version: 2\n")
  (buffer/push-string out (string "operation_count: " (length (keys ops)) "\n"))
  (buffer/push-string out (coverage-audit-section ops))
  (buffer/push-string out "operations:\n")
  (each name (sorted-names ops)
    (buffer/push-string out (operation-record (ops name))))
  (spit "docs/generated/protocol-inventory.yml" (string out))
  true)

(generate-inventory)
