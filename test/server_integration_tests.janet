(import ../slynet/slynk_janet/slynk :prefix "slynk/")
(import ../slynet/slynk_janet/rpc :prefix "rpc/")
(import ../slynet/slynk_janet/init :prefix "init/")
(import ../slynet/slynk_janet/backend :prefix "backend/")
(import judge :as j)
(use ./deftest-macros)


(defn setup-test-env []
  (init/initialize-backend)
  (init/initialize-rpc))

(defn cleanup-test-env []
  (when (slynk/*server*)
    (slynk/stop-server)))

(deftest-group "SLYNET Server Basic Integration"
  (setup [_] (setup-test-env))
  (teardown [_] (cleanup-test-env))

  (deftest "SLYNET RPC Interface Registration"
    # Define a test interface and implementation
    (rpc/slynet-definterface test/get-server-info [] "Get server information")
    (rpc/slynet-defimplementation test/get-server-info []
                                  (if slynk/*server*
                                    {:status "running" :port (slynk/*server* :port)}
                                    {:status "stopped"}))

    # Test that the interface is registered
    (assert (get (dyn rpc/slynet-rpc-interfaces-registry) 'test/get-server-info)
            "Interface should be registered")

    # Test that the implementation is registered
    (assert (get (dyn rpc/slynet-rpc-implementations-registry) 'test/get-server-info)
            "Implementation should be registered")

    # Test dispatching the RPC call
    (def result (rpc/dispatch 'test/get-server-info []))
    (assert (= (result :status) "stopped") "Server should be stopped initially"))

  (deftest "SLYNET Server Start/Stop"
    # Skip actual network operations for this test
    (def original-listen net/listen)
    (def original-accept net/accept)
    (def original-close net/close)
    (def original-spawn-thread ev/spawn-thread)

    (set net/listen (fn [host port] {:mock true :host host :port port}))
    (set net/accept (fn [socket] nil)) # Return nil to avoid connection processing
    (set net/close (fn [socket] true))
    (set ev/spawn-thread (fn [f] {:mock true :fn f}))

    # Start the server
    (def port (slynk/create-server :port 4006))
    (assert port "Server should return a port")
    (assert slynk/*server* "Server should be created")

    # Test our RPC again now that server is "running"
    (def result (rpc/dispatch 'test/get-server-info []))
    (assert (= (result :status) "running") "Server should be running")

    # Stop the server
    (def result (slynk/stop-server))
    (assert result "Server should be stopped")
    (assert (nil? slynk/*server*) "Server should be nil after stopping")

    # Restore original network functions
    (set net/listen original-listen)
    (set net/accept original-accept)
    (set net/close original-close)
    (set ev/spawn-thread original-spawn-thread)))
