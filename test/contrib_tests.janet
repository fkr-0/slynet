# Tests for SLYNET contrib modules

(import ../slynet/slynk_janet/contrib :as contrib)
(import ../slynet/slynk_janet/contrib/slynet-apropos :as apropos)
(import ../slynet/slynk_janet/contrib/slynet-arglists :as arglists)
(import ../slynet/slynk_janet/contrib/slynet-trace-dialog :as trace)
(import ../slynet/slynk_janet/contrib/slynet-profiler :as profiler)

# Test utility function
(defn test-module [name test-fn]
  (print "Testing " name "...")
  (try
    (do
      (test-fn)
      (print "  ✓ " name " tests passed")
      true)
    ([err fib]
      (do (print "  ✗ " name " tests failed: " err)
        false))))

# Test contrib module management
(defn test-contrib-module-management []
  # Test list-contrib-modules
  (def modules (contrib/list-contrib-modules))
  (pp modules)
  (assert (array? modules) "list-contrib-modules should return an array")
  (assert (> (length modules) 0) "Should list at least one module")

  # Test initialize-contrib with default modules
  (def init-results (contrib/initialize-contrib))
  (assert (table? init-results) "initialize-contrib should return a table")
  (assert (> (length (keys init-results)) 0) "Should initialize at least one module")

  # Test initialize-contrib with specific modules
  (def specific-modules [:apropos :arglists])
  (def specific-results (contrib/initialize-contrib specific-modules))
  (assert (= (length (keys specific-results)) (length specific-modules))
          "Should initialize exactly the specified modules")

  # Verify each specified module was initialized correctly
  (each module specific-modules
    (assert (= ((specific-results module) :status) :ok)
            (string "Module " module " should initialize correctly"))))

# Test the apropos module
(defn test-apropos-module []
  # Initialize the module
  (assert (apropos/initialize-module) "Should initialize successfully")

  # Test search-symbols with a common term
  (def results (apropos/search-symbols "print" true true 10))
  (assert (array? results) "search-symbols should return an array")
  (assert (>= (length results) 1) "Should find at least one 'print' related symbol")

  # Test list-all-symbols for a core module
  (def core-symbols (apropos/list-all-symbols "core"))
  (assert (array? core-symbols) "list-all-symbols should return an array")
  (assert (> (length core-symbols) 0) "Core module should have symbols")

  # Test describe-symbol-for-emacs
  (def print-desc (apropos/describe-symbol-for-emacs 'print))
  (assert (table? print-desc) "describe-symbol should return a table")
  (assert (print-desc :function-p) "print should be identified as a function"))

# Test the arglists module
(defn test-arglists-module []
  # Initialize the module
  (assert (arglists/initialize-module) "Should initialize successfully")

  # Test clear-arglists-cache
  (assert (nil? (arglists/clear-arglists-cache))
          "clear-arglists-cache should succeed")

  # Define a test function with a known arglist
  (def test-fn (fn [a b &opt c] nil))
  (def test-sym 'test-fn)

  # Test update-arglist
  (arglists/update-arglist test-sym "[a b &opt c]")

  # Test get-arglist-from-cache
  (def cached-arglist (arglists/get-arglist-from-cache test-sym))
  (assert cached-arglist "Should retrieve cached arglist")
  (assert (string/find "[a b &opt c]" cached-arglist)
          "Cached arglist should match what we stored"))

# Test the trace dialog module
(defn test-trace-dialog-module []
  # Initialize the module
  (assert (trace/initialize-module) "Should initialize successfully")

  # Define a test function to trace
  (defn traced-test-function [a b]
    (+ a b))

  # Test dialog-trace
  (def trace-result (trace/dialog-trace 'traced-test-function))
  (assert (= (trace-result :status) :traced)
          "Function should be successfully traced")

  # Call the traced function
  (traced-test-function 1 2)

  # Test report-partial-traces
  (def traces (trace/report-partial-traces 10))
  (assert (>= (length traces) 2)
          "Should have at least entry and exit trace records")

  # Test report-all-traced-functions
  (def traced-fns (trace/report-all-traced-functions))
  (assert (array? traced-fns) "Should return an array of traced function names")
  (assert (>= (length traced-fns) 1) "Should have at least one traced function")

  # Test dialog-untrace-all
  (def untrace-result (trace/dialog-untrace-all))
  (assert (array? untrace-result) "untrace-all should return results array")

  # Verify all traces are cleared
  (assert (= (length (trace/report-all-traced-functions)) 0)
          "All functions should be untraced"))

# Test the profiler module
(defn test-profiler-module []
  # Initialize the module
  (assert (profiler/initialize-module) "Should initialize successfully")

  # Define a test function to profile
  (defn profiled-test-function [n]
    (var sum 0)
    (for i 0 n (set sum (+ sum i)))
    sum)

  # Test start-profiling
  (def profile-result (profiler/start-profiling ['profiled-test-function]))
  (assert (= (profile-result :status) :profiling-started)
          "Profiling should start successfully")

  # Call the profiled function
  (profiled-test-function 1000)

  # Test report
  (def report-result (profiler/report))
  (assert (table? report-result) "report should return a table")
  (assert (report-result :profiling-active) "Profiling should be active")
  (assert (array? (report-result :results)) "Results should be an array")
  (assert (>= (length (report-result :results)) 1)
          "Should have at least one profiled function")

  # Test stop-profiling
  (def stop-result (profiler/stop-profiling))
  (assert (= (stop-result :status) :profiling-stopped)
          "Profiling should stop successfully")
  (assert (not ((profiler/report) :profiling-active))
          "Profiling should no longer be active")

  # Test reset-profiling
  (def reset-result (profiler/reset-profiling))
  (assert (= (reset-result :status) :profiling-reset)
          "Profiling data should be reset"))

# Run all tests
(defn run-contrib-tests []
  (def test-results @{})

  (put test-results :contrib-management
       (test-module "contrib module management" test-contrib-module-management))

  (put test-results :apropos
       (test-module "apropos module" test-apropos-module))

  (put test-results :arglists
       (test-module "arglists module" test-arglists-module))

  (put test-results :trace-dialog
       (test-module "trace dialog module" test-trace-dialog-module))

  (put test-results :profiler
       (test-module "profiler module" test-profiler-module))

  # Print summary
  (def total (length (keys test-results)))
  (def passed (length (filter (fn [x] x) (values test-results))))

  (print "\nTest summary:")
  (print "  " passed "/" total " tests passed")

  # Return overall success/failure
  (= passed total))

# (run-contrib-tests)
