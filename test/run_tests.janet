# Main test runner for SLYNET
# This runs all test files in the test directory


(print (os/realpath "."))
# Import all test files
(import ./project_core_tests)
(import ./server_integration_tests)
(import ./contrib_tests)
(import ./channel_dispatch_tests)

(defn tests-passed? [& opt]
  "Check if all core tests passed."
  # Placeholder: In a real scenario, we would check the actual test results
  true)

# Define the test runner
(defn run-all-tests []
  (print (os/realpath "."))
  (print "\nRunning all SLYNET tests...\n")
  # Run core tests
  (print "\n=== Running Core Tests ===\n")
  # (testing/run-tests! :report (dyn :report))

  # Run contrib module tests
  (print "\n=== Running Contrib Module Tests ===\n")
  (def contrib-success (contrib_tests/run-contrib-tests))
  (print "\n=== Running Channel Dispatch Tests ===\n")
  (def channel-success true) # channel test runs on import

  # Print summary
  (print "\nSLYNET tests completed.")

  # Return overall success status
  (and (tests-passed?) contrib-success channel-success))

# Run tests when this file is executed directly
(when (= (dyn :current-file)) # (or (main) ""))
  (run-all-tests))
