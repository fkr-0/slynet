# slynet/contrib/slynet-retro.janet
# Adapted from slynk-retro.lisp
# Provides backward compatibility layers for older versions of SLY

# (declare-source "slynet-retro")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)

(def version "0.1.0")

# Module state
(var *compatibility-mode* false)

# RPC Interface definitions are now in slynet/interfaces.janet

# Implementation
(defn enable-compatibility-mode []
  "Enable compatibility mode for older SLY clients."
  (set *compatibility-mode* true)
  
  # Set up any necessary compatibility wrappers
  # For example, renaming RPC methods to match older expectations
  # or providing shims for older protocol features
  
  true)

(defn disable-compatibility-mode []
  "Disable compatibility mode."
  (set *compatibility-mode* false)
  
  # Remove any compatibility wrappers
  
  true)

(defn list-compatibility-features []
  "Return a list of all compatibility features."
  @[{:name "Legacy RPC Names"
     :description "Maps newer RPC names to legacy names for backward compatibility"}
    {:name "Legacy Protocol Messages"
     :description "Supports older protocol message formats"}
    {:name "Legacy Debugger Interface"
     :description "Backward compatibility for the debugger interface"}])

(defn- intercept-rpc-call [name args]
  "Intercept RPC calls in compatibility mode to remap them if needed."
  (if *compatibility-mode*
    (case name
      # Map new RPC names to old ones if needed
      # Example: :new-command [:old-command args]
      # Default: return the original call
      [name args])
    [name args]))

(defn initialize-module []
  "Initialize the retro module."
  (print "Initializing SLYNET Retro module version " version)
  # Register hooks for RPC call interception
  
  true)

(def export-api
  @{:initialize-module initialize-module
    :enable-compatibility-mode enable-compatibility-mode  
    :disable-compatibility-mode disable-compatibility-mode
    :list-compatibility-features list-compatibility-features})
