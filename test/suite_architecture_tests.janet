(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/slynk :as slynk)

(defn- contains [haystack needle]
  (not (nil? (string/find needle haystack))))

(defn- run-shell-capture [command output-path]
  (def escaped (string/replace-all "'" "'\\''" command))
  (os/execute ["sh" "-lc" (string "(" command ") > " output-path " 2>&1")] :p))

(defn- slurp-or-empty [path]
  (try (slurp path) ([_ _] "")))

(register-test
  {:name "p29 suite architecture spec exists and records warning policy"
   :tags [:phase29 :suite-architecture :spec]
   :fn (fn []
         (assert-true (= 0 (os/execute ["python3" "-c" "import yaml; yaml.safe_load(open('docs/specs/janet-suite-architecture.yml'))"] :p))
                      "P29 suite architecture spec parses as YAML")
         (def text (slurp "docs/specs/janet-suite-architecture.yml"))
         (each token @["P29_janet_suite_architecture"
                       "suite_selector"
                       "warning_policy"
                       "implemented_without_interface"
                       "declared_but_not_implemented"
                       "isolation"
                       "source-index"]
           (assert-true (contains text token) (string "P29 spec mentions " token))))})

(register-test
  {:name "p29 suite selector runs source index suite without unrelated phase files"
   :tags [:phase29 :suite-architecture :runner]
   :fn (fn []
         (if (= "1" (os/getenv "SLYNET_SUITE_ARCH_CHILD"))
           (assert-true true "child guard avoids recursive suite selector subprocess")
           (do
             (def out "/tmp/slynet-p29-suite-selector.out")
             (def exit-code (run-shell-capture "SLYNET_SUITE_ARCH_CHILD=1 JANET_PATH=$PWD janet test/run_tests.janet :suite source-index :report compact" out))
             (def text (slurp-or-empty out))
             (assert= 0 exit-code "source-index suite exits successfully")
             (assert-true (contains text "Summary: 8 tests") "source-index suite runs exactly its focused source-index and xref compatibility files")
             (assert-false (contains text "phase25") "source-index suite does not import unrelated phase25 tests"))))})

(register-test
  {:name "p29 protocol warning policy fails only unexpected warning classes"
   :tags [:phase29 :suite-architecture :warning-policy]
   :fn (fn []
         (def out "/tmp/slynet-p29-warning-policy.out")
         (def exit-code (run-shell-capture "JANET_PATH=$PWD janet tools/protocol_warning_policy.janet --check" out))
         (def text (slurp-or-empty out))
         (assert= 0 exit-code "current warning policy accepts known declared gaps")
         (assert-true (contains text "implemented_without_interface: 0") "implemented-without-interface class is forbidden and currently absent")
         (assert-true (contains text "declared_but_not_implemented:") "declared-but-not-implemented class is reported explicitly"))})

(register-test
  {:name "p29 test tools reset shared global state"
   :tags [:phase29 :suite-architecture :isolation]
   :fn (fn []
         (set slynk/*slynk-debug-p* false)
         (set slynk/*inspector-stack* @[:dirty])
         (set slynk/*inspector-counter* 999)
         (set slynk/*inspector-object-counter* 999)
         (tt/reset-test-state!)
         (assert= true slynk/*slynk-debug-p* "debug state resets to deterministic enabled default")
         (assert= 0 (length slynk/*inspector-stack*) "inspector stack reset")
         (assert= 0 slynk/*inspector-counter* "inspector counter reset")
         (assert= 0 slynk/*inspector-object-counter* "inspector object counter reset"))})
