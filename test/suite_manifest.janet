# Suite manifest for the project-level Janet test runner.
# Keep this manifest declarative so focused runs can avoid importing unrelated
# phase files.

(def all-files
  @[
    "test/project_core_tests.janet"
    "test/channel_dispatch_tests.janet"
    "test/server_integration_tests.janet"
    "test/message-tests.janet"
    "test/suite-slynet.janet"
    "test/contrib_tests.janet"
    "test/runner_self_tests.janet"
    "test/suite_architecture_tests.janet"
    "test/protocol_inventory_tests.janet"
    "test/debugger_facade_tests.janet"
    "test/inspector_xref_contract_tests.janet"
    "test/source_index_v2_tests.janet"
    "test/inspector_ranges_tests.janet"
    "test/compile_load_contract_tests.janet"
    "test/restart_scope_tests.janet"
    "test/runtime_instrumentation_tests.janet"
    "test/phase21_24_tests.janet"
    "test/phase25_28_tests.janet"
    "test/execution_unit_registry_tests.janet"
    "test/diagnostics_source_tests.janet"
    "test/completion_namespace_tests.janet"
    "test/phase25_27_tests.janet"
    "test/phase29_doc_browser_tests.janet"
    "test/public_api_tests.janet"
    "test/xref_compatibility_tests.janet"
    "test/client_test.janet"])

(def suites
  @{
    :all all-files
    :unit @["test/runner_self_tests.janet" "test/suite_architecture_tests.janet"]
    :contract all-files
    :protocol-inventory @["test/protocol_inventory_tests.janet"]
    :source-index @["test/source_index_v2_tests.janet" "test/xref_compatibility_tests.janet"]
    :debugger @["test/debugger_facade_tests.janet" "test/restart_scope_tests.janet"]
    :inspector @["test/inspector_xref_contract_tests.janet" "test/inspector_ranges_tests.janet"]
    :diagnostics @["test/compile_load_contract_tests.janet" "test/diagnostics_source_tests.janet"]
    :completion @["test/completion_namespace_tests.janet"]
    :execution-units @["test/execution_unit_registry_tests.janet" "test/phase21_24_tests.janet"]
    :public-api @["test/public_api_tests.janet"]
    :integration @["test/server_integration_tests.janet" "test/client_test.janet"]
    :compatibility-boundaries @["test/phase25_28_tests.janet"]})

(defn suite-key [suite]
  (cond
    (nil? suite) :all
    (keyword? suite) suite
    (string? suite) (keyword suite)
    true (keyword (string suite))))

(defn files-for-suite [&opt suite]
  (def key (suite-key suite))
  (def files (get suites key))
  (unless files
    (error (string "Unknown test suite: " key)))
  files)

(defn suite-names []
  (keys suites))

(defn load-test-files! [files]
  (each file files
    (dofile file))
  true)

(def export-api
  @{:suites suites
    :all-files all-files
    :files-for-suite files-for-suite
    :suite-names suite-names
    :load-test-files! load-test-files!})
