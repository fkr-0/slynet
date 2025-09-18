# Entrypoint for starting the SLYNK server in Janet
# Translated from start-slynk.lisp
# Provides a convenient interface for starting the SLYNET server
(print "Loading SLYNET startup module...start\n")
(import ./init)

(import ./slynk)
(import ./backend)
(import ./contrib)

(defn init
  "Initialize the SLY environment.

   Parameters:
   - delete: If true, delete existing compiled files
   - reload: If true, force reload of modules
   - contrib-modules: List of contrib modules to initialize (nil for defaults)"
  [&opt delete reload contrib-modules]
  (default delete false)
  (default reload false)
  (default contrib-modules nil)

  (print "Initializing SLYNET environment...")

  # Initialize the core SLYNET system
  (init/init {:delete delete :reload reload})

  # Initialize contrib modules
  (def contrib-results (contrib/initialize-contrib contrib-modules))

  # Print initialization results
  (print "SLYNET core initialized successfully")
  (print "Contrib modules initialized: "
         (string/join
           (map (fn [item] (string (item 0)))
                (filter (fn [[k v]] (= (v :status) :ok))
                        (pairs contrib-results)))
           ", "))

  # Return success status
  true)

(defn create-server
  # "Create a SLYNK server with the specified options.
  # Returns the server instance (not started in a fiber).

  # Parameters:
  #   - options: Table of server options including:
  #     - :port - Port number (default: 4005)
  #     - :host - Host address (default: 127.0.0.1)
  #     - :dont-close - Keep server running after disconnect
  #     - :debug - Enable debug mode"

  #  Parameters:
  #  - options: Table of server options including:
  #    - :port - Port number (default: 4005)
  #    - :host - Host address (default: 127.0.0.1)
  #    - :dont-close - Keep server running after disconnect
  #    - :debug - Enable debug mode"
  [&opt options]
  (default options @{})

  # Extract options
  (def port (or (options :port) 4005))
  (def host (or (options :host) "127.0.0.1"))
  (def dont-close (or (options :dont-close) true))
  (def debug (or (options :debug) false))

  # Set debug mode if requested
  (when debug
    (print "Starting SLYNET server in debug mode")
    (setdyn :slynet-debug true))

  # Create and start the server
  (def server (slynk/create-server
                port
                host
                dont-close))

  (print "SLYNET server started on " host ":" port)
  server)

# Start the SLYNET server asynchronously in a background fiber.
# Returns the fiber immediately; server runs in background.
(defn start-async
  "Start the SLYNET server asynchronously in a background fiber.
  Returns the fiber immediately; server runs in background.

  Parameters:
    - options: Table of server options (see `create-server`).

  Example:
    (def fiber (start-async {:port 4005}))
    ;; ... do other work ...
    (fiber/join fiber) ; Wait for server to finish if needed
  "
  [&opt options]
  (default options @{})
  (fiber/new
    (fn []
      (def _ (create-server options))
      (while true (os/sleep 60)))))

# Start the SLYNET server synchronously (blocking).
# This is the standard entry point for CLI and main usage.
(defn start
  "Start the SLYNET server synchronously (blocking).
  This function blocks until the server exits.

  Parameters:
    - options: Table of server options (see `create-server`).

  Example:
    (start {:port 4005})
  "
  [&opt options]
  (default options @{})
  (def _ (create-server options))
  (while true (os/sleep 60)))

(defn start-slynk
  "Start the SLYNK server with the specified options.

   Parameters:
   - port: Port number (default: 4005)
   - host: Host address (default: 127.0.0.1)
   - dont-close: Keep server running after disconnect (default: true)
   - debug: Enable debug mode (default: false)
   - contrib-modules: List of contrib modules to initialize (nil for defaults)"
  [&opt port host dont-close debug contrib-modules]
  (default port 4005)
  (default host "127.0.0.1")
  (default dont-close true)
  (default debug false)

  # Initialize the system with requested contrib modules
  (init false false contrib-modules)

  # Create and start the server
  (create-server
    @{:port port
      :host host
      :dont-close dont-close
      :debug debug}))
(def export-api
  @{:init init
    :create-server create-server
    :start-slynk start-slynk})

# If this script is run directly, start the server with command line args
# Usage: janet start.janet [port] [host]
