(import ../mini-test :as runner)

# Load test files so they register with the runner
(import ./project_core_tests)
(import ./channel_dispatch_tests)
(import ./server_integration_tests)
(import ./message-tests)
(import ./suite-slynet)
(import ./contrib_tests)
(import ./runner_self_tests)
(import ./protocol_inventory_tests)
(import ./debugger_facade_tests)
(import ./inspector_xref_contract_tests)
(import ./source_index_v2_tests)
(import ./inspector_ranges_tests)
(import ./compile_load_contract_tests)
(import ./restart_scope_tests)
(import ./runtime_instrumentation_tests)
(import ./phase21_24_tests)
(import ./client_test)

(defn main [& args]
  (apply runner/run-args args))
