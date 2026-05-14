(use ../mini-test)

(defn- run-inventory-generator []
  (os/execute ["janet" "tools/protocol_inventory.janet"] :p))

(defn- inventory-text []
  (slurp "docs/generated/protocol-inventory.yml"))

(defn- contains [haystack needle]
  (not (nil? (string/find needle haystack))))

(register-test
  {:name "protocol inventory classifies implemented handshake ops"
   :tags [:inventory]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (assert-true (contains text "name: ping") "inventory includes ping")
         (assert-true (contains text "state: implemented") "implemented state recorded")
         (assert-true (contains text "source_files:") "source evidence recorded")
         (assert-true (contains text "janet_files:") "Janet implementation evidence recorded")
         (assert-true (contains text "test_files:") "test evidence recorded")
         (assert-true (contains text "name: simple-completions") "inventory includes simple-completions")
         (assert-true (contains text "missing_protocol_state: stale_doc_lists_as_missing")
                      "stale missing-protocol docs are detected"))})

(register-test
  {:name "protocol inventory discovers source operations beyond curated slice"
   :tags [:inventory]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (assert-true (contains text "  - name: backtrace\n") "defslyfun backtrace discovered")
         (assert-true (contains text "  - name: debugger-info-for-emacs\n") "defslyfun debugger-info-for-emacs discovered")
         (assert-true (contains text "  - name: operator-arglist\n") "defslyfun/operator arglist discovered")
         (assert-true (contains text "kind: definterface") "backend definterface records are emitted"))})

(defn- record-for [text operation]
  (def marker (string "  - name: " operation "\n"))
  (def start (string/find marker text))
  (when start
    (def rest (string/slice text start))
    (def next (string/find "\n  - name: " rest 1))
    (if next
      (string/slice rest 0 next)
      rest)))

(register-test
  {:name "protocol inventory uses definition-aware Janet evidence"
   :tags [:inventory]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (def ping-record (record-for text "ping"))
         (assert-true ping-record "ping record exists")
         (assert-true (contains ping-record "slynet/slynk.janet") "ping implementation file retained")
         (assert-false (contains ping-record "slynet/backend.janet") "unrelated backend mention excluded")
         (assert-false (contains ping-record "slynet/contrib/slynet-fancy-inspector.janet") "unrelated substring mention excluded"))})

(register-test
  {:name "protocol inventory classifies Janet design constraints"
   :tags [:inventory]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (def package-record (record-for text "set-package"))
         (def restart-record (record-for text "invoke-nth-restart"))
         (def clos-record (record-for text "generic-method-specs"))
         (def compile-record (record-for text "compile-file-for-emacs"))
         (def thread-record (record-for text "list-threads"))
         (assert-true package-record "set-package record exists")
         (assert-true (contains package-record "constraint: cl_packages") "set-package marks CL package non-equivalence")
         (assert-true restart-record "invoke-nth-restart record exists")
         (assert-true (contains restart-record "constraint: conditions_restarts") "restart RPC marks Janet restart limitation")
         (assert-true clos-record "generic-method-specs record exists")
         (assert-true (contains clos-record "constraint: clos_mop") "CLOS/MOP RPC marks unsupported Janet model")
         (assert-true compile-record "compile-file-for-emacs record exists")
         (assert-true (contains compile-record "constraint: compiler_notes") "compiler diagnostics mark Janet-native approximation")
         (assert-true thread-record "list-threads record exists")
         (assert-true (contains thread-record "constraint: threads") "thread RPC marks Janet execution-unit limitation"))})
