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

(register-test
  {:name "protocol inventory emits human-readable constraint reasons"
   :tags [:inventory]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (def package-record (record-for text "set-package"))
         (def restart-record (record-for text "invoke-nth-restart"))
         (def clos-record (record-for text "generic-method-specs"))
         (def compile-record (record-for text "compile-file-for-emacs"))
         (def thread-record (record-for text "list-threads"))
         (assert-true (contains package-record "constraint_reason: Janet has modules/environments") "CL package reason emitted")
         (assert-true (contains restart-record "constraint_reason: Janet exceptions/stack traces") "restart reason emitted")
         (assert-true (contains clos-record "constraint_reason: Janet does not provide CLOS/MOP") "CLOS/MOP reason emitted")
         (assert-true (contains compile-record "constraint_reason: Janet diagnostics differ") "compiler-note reason emitted")
         (assert-true (contains thread-record "constraint_reason: Janet execution units/fibers") "thread reason emitted"))})

(register-test
  {:name "protocol inventory audits constraint coverage against tasks"
   :tags [:inventory]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (assert-true (contains text "constraint_coverage_audit:") "audit section emitted")
         (assert-true (contains text "  undocumented_constraints: []") "all used constraints are documented")
         (assert-true (contains text "    - cl_packages") "cl_packages documented in audit")
         (assert-true (contains text "    - conditions_restarts") "conditions_restarts documented in audit")
         (assert-true (contains text "    - clos_mop") "clos_mop documented in audit")
         (assert-true (contains text "    - compiler_notes") "compiler_notes documented in audit")
         (assert-true (contains text "    - threads") "threads documented in audit"))})

(register-test
  {:name "protocol inventory emits precise support fields"
   :tags [:inventory :phase0]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (def ping-record (record-for text "ping"))
         (def restart-record (record-for text "invoke-nth-restart"))
         (def trace-record (record-for text "dialog-trace"))
         (def sticker-record (record-for text "compile-for-stickers"))
         (assert-true (contains text "schema_version: 5") "schema records explicit test and callable-registration evidence")
         (assert-true (contains ping-record "support_class: native") "unconstrained tested implementation is native")
         (assert-true (contains ping-record "state_detail: implemented_native_tested") "tested native implementation has precise state")
         (assert-true (contains ping-record "registration_files:\n      - slynet/slynk.janet") "implemented state requires callable registration evidence")
         (assert-true (contains ping-record "test_evidence_kind: explicit_covers_metadata") "direct test evidence is explicit rather than inferred")
         (assert-true (contains restart-record "support_class: emulated") "restart operations remain explicit Janet emulations")
         (assert-true (contains restart-record "state_detail: implemented_emulated_tested") "direct restart coverage is now recorded")
         (assert-true (contains trace-record "state_detail: implemented_native_unwired") "defined trace-dialog code is not mistaken for a callable RPC")
         (assert-true (contains sticker-record "state_detail: missing_unconstrained") "interface-only sticker declarations are not implementations"))})

(register-test
  {:name "protocol inventory maps operations to frontend surfaces"
   :tags [:inventory :phase0]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (def ping-record (record-for text "ping"))
         (def create-mrepl-record (record-for text "create-mrepl"))
         (def completion-record (record-for text "simple-completions"))
         (def backtrace-record (record-for text "backtrace"))
         (def inspector-record (record-for text "inspector-nth-part"))
         (def xref-record (record-for text "find-definitions-for-emacs"))
         (assert-true (contains ping-record "frontend_surface: transport") "ping maps to transport")
         (assert-true (contains create-mrepl-record "frontend_surface: repl") "create-mrepl maps to repl")
         (assert-true (contains completion-record "frontend_surface: completion") "simple-completions maps to completion")
         (assert-true (contains backtrace-record "frontend_surface: debugger") "backtrace maps to debugger")
         (assert-true (contains inspector-record "frontend_surface: inspector") "inspector-nth-part maps to inspector")
         (assert-true (contains xref-record "frontend_surface: xref") "find-definitions-for-emacs maps to xref"))})

(defn- support-matrix-text []
  (slurp "docs/specs/support-matrix.yml"))

(defn- spec-index-text []
  (slurp "docs/specs/README.md"))

(defn- gap-analysis-text []
  (slurp "docs/specs/slynk-backend-gap-analysis.md"))

(defn- janet-extension-candidates-text []
  (slurp "docs/specs/janet-extension-candidates.md"))

(defn- emacs-client-contract-text []
  (slurp "docs/specs/emacs-client-contract.md"))

(defn- yaml-file-parses? [path]
  (= 0 (os/execute ["python3" "-c" "import sys, yaml; yaml.safe_load(open(sys.argv[1]))" path] :p)))

(defn- all-records [text]
  (def rest-start (string/find "operations:\n" text))
  (if (nil? rest-start)
    @[]
    (let [rest (string/slice text (+ rest-start (length "operations:\n")))]
      (array/slice (string/split "\n  - name: " rest) 1))))

(defn- record-field [record field]
  (def marker (string "    " field ": "))
  (def start (string/find marker record))
  (when start
    (def value-start (+ start (length marker)))
    (def line-end (or (string/find "\n" record value-start) (length record)))
    (string/slice record value-start line-end)))

(register-test
  {:name "support matrix exists parses and indexes current phases"
   :tags [:inventory :phase10 :support-matrix]
   :fn (fn []
         (assert-true (yaml-file-parses? "docs/specs/support-matrix.yml") "support matrix parses as YAML")
         (def text (support-matrix-text))
         (each phase @["P0_inventory_truth"
                       "P1_transport_session_protocol"
                       "P2_eval_mrepl_first_real_e2e"
                       "P3_thread_debugger_condition_facade"
                       "P4_inspector_xref_source_index"
                       "P5_compile_load_diagnostics"
                       "P6_emacs_repl_buffer_ui"
                       "P7_completion_autodoc_capf"
                       "P8_inspector_xref_emacs_ui"
                       "P9_debugger_execution_unit_emacs_ui"
                       "P10_spec_consolidation_support_matrix"
                       "P11_interactive_inspector_xref"
                       "P12_interactive_debugger_controls"
                       "P13_diagnostics_ui"
                       "P14_project_connection_management"
                       "P15_completion_parity_deepening"
                       "P16_runtime_instrumentation"]
           (assert-true (contains text phase) (string "support matrix contains " phase))))})

(register-test
  {:name "equivalence spec index references split specs and phase table"
   :tags [:inventory :phase10 :spec-index]
   :fn (fn []
         (def index (spec-index-text))
         (each spec @["support-matrix.yml"
                      "threading-execution-units.md"
                      "debugger-condition-restarts.md"
                      "inspector-xref-source-index.md"
                      "emacs-client-contract.md"
                      "cl-janet-equivalence-contracts.md"
                      "slynk-backend-gap-analysis.md"]
           (assert-true (contains index spec) (string "spec index references " spec)))
         (def overview (slurp "docs/specs/cl-janet-equivalence-contracts.md"))
         (assert-false (contains overview "Status: working draft") "overview no longer presents itself as draft journal")
         (each phase @["P0" "P1" "P2" "P3" "P4" "P5" "P6" "P7" "P8" "P9" "P10" "P11" "P12" "P13" "P14" "P15" "P16"]
           (assert-true (contains overview (string "| " phase " |")) (string "overview table contains " phase))))})

(register-test
  {:name "slynk backend gap analysis records scope extension and workaround decisions"
   :tags [:inventory :phase10 :spec-index :gap-analysis]
   :fn (fn []
         (def index (spec-index-text))
         (def overview (slurp "docs/specs/cl-janet-equivalence-contracts.md"))
         (def text (gap-analysis-text))
         (assert-true (contains index "slynk-backend-gap-analysis.md") "spec index references backend gap analysis")
         (assert-true (contains overview "slynk-backend-gap-analysis.md") "overview references backend gap analysis")
         (each token @[
                       "native"
                       "emulated"
                       "workaround"
                       "needs-janet-extension"
                       "out-of-scope"
                       "pending-design"
                       "CLOS/MOP"
                       "conditions and restarts"
                       "source-index"
                       "debug/stack"]
           (assert-true (contains text token) (string "gap analysis mentions " token)))
         (assert-true (contains text "The acceptable claim") "gap analysis states release claim boundary")
         (assert-true (contains text "The unacceptable claim") "gap analysis states non-goal boundary"))})


(register-test
  {:name "janet extension candidates record workaround extension and acceptance rules"
   :tags [:inventory :phase10 :spec-index :janet-extension-candidates]
   :fn (fn []
         (def index (spec-index-text))
         (def overview (slurp "docs/specs/cl-janet-equivalence-contracts.md"))
         (def gap (gap-analysis-text))
         (def matrix (support-matrix-text))
         (def text (janet-extension-candidates-text))
         (assert-true (contains index "janet-extension-candidates.md") "spec index references Janet extension candidates")
         (assert-true (contains overview "janet-extension-candidates.md") "overview references Janet extension candidates")
         (assert-true (contains gap "janet-extension-candidates.md") "gap analysis references detailed extension candidate contract")
         (assert-true (contains matrix "janet_extension_candidates:") "support matrix has machine-readable candidate section")
         (each candidate @["stable_eval_source_maps"
                           "rich_debug_frame_locals"
                           "resumable_debugger_control_api"
                           "structured_signal_metadata"
                           "function_arg_metadata"
                           "instrumentation_hooks"]
           (assert-true (contains text candidate) (string "candidate spec mentions " candidate))
           (assert-true (contains matrix candidate) (string "support matrix mentions " candidate)))
         (each token @["Current workaround"
                       "Potential Janet extension"
                       "SLYNET acceptance rule"
                       "source-index fallback and snippets"
                       "debug-stack slots"
                       "condition records and diagnostic envelopes"
                       "arglist cache"
                       "wrapper and recording layer"
                       "pending-design"
                       "SLYNET workaround facade"
                       "Janet runtime extension"
                       "not the same thing as extending Janet"
                       "must mark support as"
                       "must not invent lexical local names"
                       "must not hide a Janet substrate gap"]
           (assert-true (contains text token) (string "candidate spec preserves " token))))})


(register-test
  {:name "emacs client contract documents daily-use package surface"
   :tags [:inventory :phase14 :emacs-client :daily-use]
   :fn (fn []
         (def text (emacs-client-contract-text))
         (def readme (slurp "README.md"))
         (each token @["Daily-use package contract"
                       "slynet-mode"
                       "slynet-command-map"
                       "slynet-menu"
                       "slynet-status"
                       "slynet-health"
                       "slynet-reconnect"
                       "slynet-quit"
                       "live"
                       "stale"
                       "off"]
           (assert-true (contains text token) (string "Emacs client contract mentions " token)))
         (each token @["Emacs quick start"
                       "slynet-mode"
                       "C-c C-s h"
                       "C-c C-s q"
                       "support matrix"]
           (assert-true (contains readme token) (string "README mentions " token))))})

(register-test
  {:name "protocol inventory records validation stage and owning spec"
   :tags [:inventory :phase10]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (each operation @["ping" "create-mrepl" "simple-completions" "list-threads" "debugger-info-for-emacs" "inspector-nth-part" "find-definitions-for-emacs" "compile-string-for-emacs"]
           (def rec (record-for text operation))
           (assert-true rec (string operation " record exists"))
           (assert-true (contains rec "    validation_stage: P") (string operation " has validation stage"))
           (assert-true (contains rec "    owning_spec: docs/specs/") (string operation " has owning spec"))))})

(register-test
  {:name "protocol inventory support rationale required for constrained support"
   :tags [:inventory :phase10]
   :fn (fn []
         (run-inventory-generator)
         (def text (inventory-text))
         (each rec (all-records text)
           (def support (record-field rec "support_class"))
           (when (or (= support "emulated") (= support "unsupported") (= support "pending_design"))
             (assert-true (contains rec "    constraint_reason: ") "constrained record has constraint reason")
             (assert-true (contains rec "    support_rationale: ") "constrained record has support rationale"))))})
