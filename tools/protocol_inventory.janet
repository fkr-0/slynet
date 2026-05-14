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

(defn- file-mentions? [path needle]
  (contains? (slurp-or-empty path) needle))

(defn- matching-files [files needle]
  (def out @[])
  (each path files
    (when (file-mentions? path needle)
      (array/push out path)))
  out)

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
  (if (> (length (matching-files stale-doc-files operation)) 0)
    "stale_doc_lists_as_missing"
    "not_listed_missing"))

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

(defn- operation-record [rec]
  (def operation (rec :name))
  (def source-evidence (rec :source_files))
  (def janet-evidence (matching-files janet-files operation))
  (def test-evidence (matching-files test-files operation))
  (def stale-files (matching-files stale-doc-files operation))
  (def out (buffer/new 0))
  (buffer/push-string out (string "  - name: " operation "\n"))
  (buffer/push-string out (string "    kind: " (string/join (rec :kinds) ",") "\n"))
  (buffer/push-string out (string "    state: " (state-for janet-evidence test-evidence) "\n"))
  (buffer/push-string out (yaml-list 4 "source_files" source-evidence))
  (buffer/push-string out (yaml-list 4 "janet_files" janet-evidence))
  (buffer/push-string out (yaml-list 4 "test_files" test-evidence))
  (buffer/push-string out "    constraint: null\n")
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
  (buffer/push-string out "operations:\n")
  (each name (sorted-names ops)
    (buffer/push-string out (operation-record (ops name))))
  (spit "docs/generated/protocol-inventory.yml" (string out))
  true)

(generate-inventory)
