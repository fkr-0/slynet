(import ../slynet/slynk_janet/rpc :prefix "rpc/")
(import ../slynet/slynk_janet/init :prefix "init/")
(import judge :as j)

(defn- reset-env []
  "Helper to reset the environment for each test group."
  (init/initialize-backend))

# (j/deftest-group "SLYNET Core RPC Macros & Registries"
#   (setup [_] (reset-env))

(j/deftest "slynet-definterface: successful registration"
           (rpc/slynet-register-interface-rt! 'test/iface1 [:arg1] "Test interface 1")
           (assert (get rpc/*slynet-rpc-interfaces-registry* 'test/iface1) "Interface 'test/iface1 should be registered")
           (assert (= (get-in rpc/*slynet-rpc-interfaces-registry* ['test/iface1 :name]) 'test/iface1))
           (assert (= (get-in rpc/*slynet-rpc-interfaces-registry* ['test/iface1 :arglist-spec]) [:arg1]))
           (assert (= (get-in rpc/*slynet-rpc-interfaces-registry* ['test/iface1 :doc]) "Test interface 1")))

(j/deftest "slynet-definterface: argument validation errors"
           (assert-error "rpc-name must be symbol" (rpc/slynet-definterface "iface-string" [] "doc"))
           (assert-error "arglist-spec must be tuple, array, or keyword" (rpc/slynet-definterface test/iface-err-argspec "not-array" "doc"))
           (assert-error "docstring must be string" (rpc/slynet-definterface test/iface-err-doc [] :not-string)))

(j/deftest "slynet-definterface: re-declaration overwrites"
           (rpc/slynet-register-interface-rt! "test/iface-overwrite" [] "Original doc")
           (rpc/slynet-register-interface-rt! "test/iface-overwrite" [:new-arg] "New doc")
           (assert (= (get-in rpc/*slynet-rpc-interfaces-registry* ['test/iface-overwrite :arglist-spec]) [:new-arg]))
           (assert (= (get-in rpc/*slynet-rpc-interfaces-registry* ['test/iface-overwrite :doc]) "New doc")))

(j/deftest "slynet-defimplementation: successful definition and registration"
           (rpc/slynet-register-interface-rt! "test/impl1" [] "Interface for impl1")
           (rpc/slynet-defimplementation test/impl1 [x] (* x 2))
           (assert (get rpc/*slynet-rpc-interfaces-registry* 'test/impl1) "Implementation 'test/impl1 should be registered")
           (def my-fn (get rpc/slynet-rpc-implementations-registry 'test/impl1))
           (assert (function? my-fn) "Registered item should be a function")
           (assert (= (my-fn 5) 10) "Function should be callable and work as expected")
           # Test if the function is defined in the current scope by its name
           (assert (= (test/impl1 3) 6) "Function test/impl1 should be directly callable"))

(j/deftest "slynet-defimplementation: argument validation errors"
           (assert-error "rpc-name must be symbol" (rpc/slynet-defimplementation "impl-string" [] ()))
           (assert-error "janet-arglist must be tuple" (rpc/slynet-defimplementation test/impl-err-arglist :not-tuple ())))

(j/deftest "slynet-defimplementation: warning for implementation without interface (manual check)"
           (testing/set-print-test true) # Enable capturing prints for this test if testing lib supports
           (rpc/slynet-defimplementation test/impl-no-iface [] (print "hello"))
           # This test primarily ensures the macro doesn't fail.
           # Capturing eprintf output is non-trivial in standard Janet testing.
           # We expect a warning to stderr: "Warning: SLYNET RPC implementation for 'test/impl-no-iface' has no corresponding..."
           (assert (get rpc/slynet-rpc-implementations-registry 'test/impl-no-iface) "Implementation should still be registered")
           (testing/set-print-test false))

(j/deftest "slynet-defimplementation: re-definition overwrites"
           (rpc/slynet-definterface test/impl-overwrite [] "doc")
           (rpc/slynet-defimplementation test/impl-overwrite [] 1)
           (assert (= ((get rpc/slynet-rpc-implementations-registry 'test/impl-overwrite)) 1))
           (rpc/slynet-defimplementation test/impl-overwrite [] 2)
           (assert (= ((get rpc/slynet-rpc-implementations-registry 'test/impl-overwrite)) 2))
           (assert (= (test/impl-overwrite) 2))) # )

# (j/deftest-group "SLYNET Core Initialization Functions"
#   (setup [_] (reset-env)) # Ensure clean state for each init test

(j/deftest "slynet/initialize-backend: clears registries"
           (rpc/slynet-definterface test/iface-before-init [] "doc")
           (rpc/slynet-defimplementation test/impl-before-init [] 1)
           (assert (not (empty? rpc/*slynet-rpc-interfaces-registry*)))
           (assert (not (empty? rpc/slynet-rpc-implementations-registry)))

           (init/slynet/initialize-backend) # This is the action under test

           (assert (empty? rpc/*slynet-rpc-interfaces-registry*) "Interfaces registry should be empty after init-backend")
           (assert (empty? rpc/slynet-rpc-implementations-registry) "Implementations registry should be empty after init-backend"))

(j/deftest "slynet/initialize-rpc: all interfaces implemented"
           (reset-env) # Start fresh
           (rpc/slynet-definterface test/rpc-init-iface1 [] "doc1")
           (rpc/slynet-defimplementation test/rpc-init-iface1 [] "impl1")
           (rpc/slynet-definterface test/rpc-init-iface2 [:a] "doc2")
           (rpc/slynet-defimplementation test/rpc-init-iface2 [x] x)
           (assert (init/slynet/initialize-rpc) "initialize-rpc should return true when all interfaces are implemented"))

(j/deftest "slynet/initialize-rpc: some interfaces not implemented"
           (reset-env) # Start fresh
           (rpc/slynet-definterface test/rpc-init-iface-ok [] "doc-ok")
           (rpc/slynet-defimplementation test/rpc-init-iface-ok [] "impl-ok")
           (rpc/slynet-definterface test/rpc-init-iface-missing [] "doc-missing")
           # test/rpc-init-iface-missing is not implemented
           (testing/set-print-test true)
           (assert (not (init/slynet/initialize-rpc)) "initialize-rpc should return false when an interface is missing implementation")
           # Expect eprintf warning for 'test/rpc-init-iface-missing'
           (testing/set-print-test false))

(j/deftest "slynet/initialize-rpc: no interfaces declared"
           (reset-env) # Start fresh
           (assert (init/slynet/initialize-rpc) "initialize-rpc should return true if no interfaces are declared"))

(j/deftest "slynet/initialize-rpc: registries not tables (simulated error)"
           # Simulate a bad state where registries are not tables
           (setdyn rpc/*slynet-rpc-interfaces-registry* nil)
           (setdyn rpc/slynet-rpc-implementations-registry nil)
           (assert-error "RPC registries not tables" (init/slynet/initialize-rpc))
           # Restore for other tests if any run after this group without setup
           (setdyn rpc/*slynet-rpc-interfaces-registry* @{})
           (setdyn rpc/slynet-rpc-implementations-registry @{}))
# )

# (j/deftest-group "SLYNET RPC Protocol Encoding/Decoding"
#   (setup [_] (reset-env))

(j/deftest "parse-sexp: basic types"
           (assert (= (rpc/parse-sexp "42") 42) "Number parsing")
           (assert (= (rpc/parse-sexp "\"hello\"") "hello") "String parsing")
           (assert (= (rpc/parse-sexp "nil") nil) "nil parsing")
           (assert (= (rpc/parse-sexp "t") true) "t for true parsing"))

(j/deftest "parse-sexp: composite types"
           (assert (deep= (rpc/parse-sexp "(1 2 3)") [1 2 3]) "List parsing")
           (assert (deep= (rpc/parse-sexp "(\"hello\" \"world\")") ["hello" "world"]) "List of strings")
           (assert (deep= (rpc/parse-sexp "(:a 1 :b 2)") [:a 1 :b 2]) "Property list"))

(j/deftest "process-incoming-message: RPC formats"
           (def rex-msg (rpc/process-incoming-message "(:emacs-rex (slynet/connection-info) \"COMMON-LISP\" t 1)"))
           (assert (= (first rex-msg) :emacs-rex) "Should recognize :emacs-rex message")
           (assert (= (last rex-msg) 1) "Message ID should be preserved"))

(j/deftest "RPC message creation"
           (def rex (rpc/create-emacs-rex-message '(slynet/connection-info) :core 't 1))
           (assert (= (first rex) :emacs-rex) "Should create :emacs-rex message")
           (assert (= (get rex 3) 1) "Message ID should be set correctly"))
# )

# (j/deftest-group "SLYNET Connection Management"
#   (setup [_] (reset-env))

# These tests would ideally use mock sockets
# For now, we'll test the basic functionality without actual network connections

(j/deftest "create-server: basic structure"
           (def port 4444)
           (def host "127.0.0.1")

           # Temporarily redefine net/listen to avoid actual socket binding
           (def original-listen net/listen)
           (set net/listen (fn [host port] {:mock-socket true :host host :port port}))

           # Temporarily redefine ev/spawn-thread to avoid actual thread creation
           (def original-spawn-thread ev/spawn-thread)
           (set ev/spawn-thread (fn [f] {:mock-fiber true :fn f}))

           # Create the server
           (def server-port (slynk/create-server :port port :host host :dont-close true))

           # Restore original functions
           (set net/listen original-listen)
           (set ev/spawn-thread original-spawn-thread)

           # Verify server created correctly
           (assert (= server-port port) "Should return the port number")
           (assert slynk/*server* "Server should be stored in global var")
           (assert (= (slynk/*server* :host) host) "Host should be stored in server")
           (assert (= (slynk/*server* :port) port) "Port should be stored in server")
           (assert (slynk/*server* :socket) "Socket should be created"))

(j/deftest "connection management: basic operations"
           # Set up an empty connections registry
           (set slynk/*connections* @{})

           # Create a mock connection
           (def conn @{:id "test-conn" :addr "127.0.0.1:1234" :socket {:mock true}})
           (put slynk/*connections* "test-conn" conn)

           # Test connection listing
           (def conns (slynk/list-connections))
           (assert (= (length conns) 1) "Should have one connection")
           (assert (= (first (first conns)) "test-conn") "Connection ID should match")

           # Simulate closing a connection
           # Temporarily redefine net/close to avoid actual socket closing
           (def original-close net/close)
           (set net/close (fn [sock] true))

           (slynk/close-connection conn "Test closing")
           (set net/close original-close)

           # Verify connection was removed
           (assert (= (length (slynk/list-connections)) 0) "Connection should be removed"))
# )

# Ensure to run tests if this file is executed directly
# (testing/run-tests)
# Or rely on Makefile
