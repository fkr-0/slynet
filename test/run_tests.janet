(import ../mini-test :as runner)

# Load test files so they register with the runner
(import ./project_core_tests)
(import ./channel_dispatch_tests)
(import ./server_integration_tests)
(import ./message-tests)
(import ./suite-slynet)
(import ./contrib_tests)

(defn main [& args]
  (apply runner/run-args args))
