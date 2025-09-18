# SLYNK Janet Implementation
# Main module that brings everything together
# Translated from slynk-loader.lisp
(print "Loading SLYNK module...init")
# Import all submodules
(import ./backend)
(import ./rpc)
(import ./infrastructure :as inf)
(import ./slynk)
(import ./gray)
(import ./completion)
(import ./xref)
# (import ./start)
(import ./contrib)

# Version information
(def version "0.2.0")
(def compatible-versions ["0.1.0" "0.2.0"])
(def required-modules @["backend" "rpc" "slynk" "gray" "completion" "xref" "start"])
(def optional-modules @["contrib"])

# Module registry
(def modules @{})
(def contrib-modules @{})

# User configuration
(def *user-init-file* "~/.slynk.janet")
(var *loaded-user-init-file* false)
(def *load-path* @["./" "./slynet/" "./slynet/" "./"])
(var *slynk-hooks* @{:init @[]})

# Core functions
(defn load-module
  "Load a SLYNK module by name."
  [name]
  (def module-name (string name))
  (def full-name (string (os/cwd) "/slynet/" module-name ".janet"))

  # Try to load the module
  (try
    (do
      (print "Loading module: " full-name "\n")
      (dofile full-name))
    ([err fib]
      (eprintf "Error loading module %s: %s\n" module-name err))))

(defn initialize-backend
  "Initialize the backend environment and reset any state needed."
  [&opt options]
  (default options @{})
  (backend/initialize options)
  true)

(defn load-user-init
  "Load the user initialization file."
  []
  (try
    (do (dofile *user-init-file*)
      (set *loaded-user-init-file* true))
    ([err fib]
      (eprintf "Error loading user init file: %s\n" err))))
(defn initialize-rpc
  "Initialize the RPC system: reset registries and validate RPC interfaces and implementations.
  Returns true if all interfaces have implementations, false otherwise."
  [&opt options]
  (default options @{})

  # Get access to the registries managed by infrastructure
  (def interfaces inf/*slynet-rpc-interfaces-registry*)
  (def implementations inf/*slynet-rpc-implementations-registry*)

  # Reset registries if requested
  (when (options :reset-registries)
    (eprintf "Resetting RPC registries...\n")
    (inf/reset-interfaces)
    (inf/reset-implementations))

  # Validate that all interfaces have implementations
  (var all-implementations-found true)

  # Validate the registry tables exist
  (unless (and (table? interfaces) (table? implementations))
    (eprintf "Error: SLYNET RPC registries are not properly initialized (not tables). Backend initialization might have failed or rpc.janet not loaded.\n")
    (set all-implementations-found false)
    (return false))

  # Check for interfaces without implementations
  (eachp [rpc-name interface-meta] interfaces
    (unless (get implementations rpc-name)
      (eprintf "Warning: SLYNET RPC interface '%s' (Doc: \"%s\") is declared but not implemented."
               rpc-name (get interface-meta :doc "no docstring"))
      (set all-implementations-found false)))

  # Check for implementations without interfaces
  (eachp [rpc-name impl] implementations
    (unless (get interfaces rpc-name)
      (eprintf "Warning: SLYNET RPC implementation for '%s' has no corresponding interface declaration."
               rpc-name)
      (set all-implementations-found false)))

  # Return validation status
  all-implementations-found)

(defn initialize-contrib-modules
  "Initialize contrib modules. If modules is nil, use default modules."
  [&opt modules]
  (default modules nil)

  # Call the contrib initializer if available
  (if (and (module/cache "./contrib") contrib/export-api)
    (do
      (def results (contrib/initialize-contrib modules))
      (print "SLYNET: Contrib modules initialized:")
      (eachp [name result] results
        (if (= (result :status) :ok)
          (print "  - " name ": OK")
          (print "  - " name ": ERROR - " (result :message))))
      results)
    (do
      (print "SLYNET: Contrib system not available")
      @{})))

(defn init
  "Initialize the SLYNK environment."
  [&opt options]
  (default options @{})

  # Extract options
  (def delete (options :delete))
  (def reload (options :reload))

  # Check if SLYNK is already loaded
  (when (get modules :slynk)
    (cond
      delete (each name (keys modules)
               (put modules name nil))
      (not reload) (do
                     (print "SLYNK already loaded. Use :reload true to reload.")
                     (return nil))))

  # Load required modules
  (each module required-modules
    (load-module module))

  # Register the main modules
  (put modules :backend backend/export-api)
  (put modules :rpc rpc/export-api)
  (put modules :slynk slynk/export-api)
  (put modules :gray gray/export-api)
  (put modules :completion completion/export-api)
  (put modules :xref xref/export-api)

  # Initialize backend and RPC
  (initialize-backend options)
  (initialize-rpc options)

  # Load user init file
  (when (and (not *loaded-user-init-file*)
             (os/stat *user-init-file*))
    (load-user-init))

  # Run init hooks
  (each hook (get *slynk-hooks* :init)
    (hook))

  # Initialize contrib modules if requested
  (when (or (options :enable-contrib) true)
    (def contrib-modules (options :contrib-modules))
    (initialize-contrib-modules contrib-modules)
    (put modules :contrib contrib/export-api))

  # Return success
  true)


(defn add-hook
  "Add a function to a SLYNK hook."
  [hook-name func]
  (unless (get *slynk-hooks* hook-name)
    (put *slynk-hooks* hook-name @[]))
  (array/push (get *slynk-hooks* hook-name) func))

(defn remove-hook
  "Remove a function from a SLYNK hook."
  [hook-name func]
  (when-let [hooks (get *slynk-hooks* hook-name)]
    (array/remove hooks func)))

(defn slynk-version
  "Returns the current SLYNK version string."
  []
  version)

# Re-export key functionality from other modules
(def create-server slynk/create-server)

# Module documentation
(setdyn :doc "SLYNK implementation for Janet - A backend for the Superior Lisp Interaction Mode for Emacs (SLY)")

# Export public API
(def export-api
  @{:init init
    :version version
    :slynk-version slynk-version
    :create-server create-server
    # :start-slynk start-slynk
    :add-hook add-hook
    :remove-hook remove-hook
    :initialize-backend initialize-backend
    :initialize-rpc initialize-rpc
    :initialize-contrib-modules initialize-contrib-modules
    :modules modules
    :required-modules required-modules
    :optional-modules optional-modules
    :*user-init-file* *user-init-file*})
