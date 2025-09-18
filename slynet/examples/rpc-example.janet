# Example of using SLYNET RPC system
# This file demonstrates how to define and implement RPC endpoints

(import ../rpc)
(import ../init)

# Define an RPC interface
(rpc/slynet-definterface slynet/get-version []
                         "Returns the current SLYNET version.")

# Implement the interface
(rpc/slynet-defimplementation slynet/get-version []
                              (comment "Implementation of get-version")
                              "0.1.0")

# Define an RPC interface with arguments
(rpc/slynet-definterface slynet/echo [:message]
                         "Echo back the provided message.")

# Implement the interface
(rpc/slynet-defimplementation slynet/echo [message]
                              (comment "Implementation of echo")
                              (print "Echoing message:" message)
                              message)

# Define a more complex interface
(rpc/slynet-definterface slynet/system-info [:include-env]
                         "Return system information. If include-env is true, includes environment variables.")

# Implement the complex interface
(rpc/slynet-defimplementation slynet/system-info [include-env]
                              (comment "Implementation of system-info")
                              (def result @{:janet-version (dyn :version)
                                            :os (os/which)
                                            :pid (os/getpid)
                                            :cwd (os/cwd)})

                              # Include environment variables if requested
                              (when include-env
                                (put result :env (os/environ)))

                              result)

# Function to test the RPC system
(defn test-rpc []
  (print "Testing SLYNET RPC System")
  (print "-------------------------")

  # Initialize the RPC system
  (init/initialize-rpc)

  # List all interfaces and implementations
  (print "\nRPC Interfaces:")
  (each interface (rpc/list-interfaces)
    (def meta (rpc/get-interface interface))
    (print "  " interface "- args:" (get meta :arglist-spec) "- doc:" (get meta :doc)))

  (print "\nRPC Implementations:")
  (each impl (rpc/list-implementations)
    (print "  " impl))

  # Try dispatching some calls
  (print "\nTest dispatching:")

  (print "  get-version ->" (rpc/dispatch 'slynet/get-version []))
  (print "  echo ->" (rpc/dispatch 'slynet/echo ["Hello, SLYNET!"]))
  (print "  system-info ->" (rpc/dispatch 'slynet/system-info [false]))

  (print "\nRPC validation:")
  (each interface (rpc/list-interfaces)
    (def [valid reason] (rpc/validate-rpc interface))
    (print "  " interface ":" (if valid "Valid" reason)))

  (print "\nDone!"))

# Export the test function
(def export @{:test-rpc test-rpc})

# Run the test if this file is run directly
(when (= (dyn :current-file) # (or (main) "")
)
  (print "Running rpc-example.janet directly...")
  (test-rpc))
