(import ./interfaces :as i)

# Debug flag
(def *debug-slynk-backend* false)

# Registry for interface definitions and implementations
(def *interface-functions* @[]) # Ordered list of defined interfaces (if needed)
(var *unimplemented-interfaces* @[]) # List of unimplemented interfaces (updated at runtime)
(var *implementations* @{}) # Maps interface names to their implementations

# Register an implementation for an interface
(defn defimpl
  "Register function F as implementation for interface NAME (symbol or string)."
  [name f]
  (put-in *implementations* [(if (symbol? name) name (symbol name)) :implementation] f)
  f)

# SLYNET registry mirrors (for dynamic access)
(def slynet-register-impl-rt! defimpl)
(def *slynet-rpc-implementations-registry* *implementations*)
(def *slynet-rpc-interfaces-registry* @{})
# ??
(def- slynet-rpc-interfaces-dyn-key :slynet.rpc.interfaces)
(def- slynet-rpc-implementations-dyn-key :slynet.rpc.implementations)

########################
# Error helpers
########################
(defn make-backend-error
  "Create a structured backend error."
  [message details]
  @{:type :slynk-backend-error
    :message message
    :details details})

(defn make-implementation-error
  "Create an error for missing or invalid implementations."
  [interface-name reason]
  (eprintf "slynet implementation missing: %s (%s)\n" interface-name reason)
  @{:type :slynk-implementation-error
    :interface interface-name
    :reason reason
    :message "Implementation error"
    :detail @{:interface interface-name :reason reason}})

(defn reset-interfaces []
  "Reset the interfaces registry."
  (table/clear *slynet-rpc-interfaces-registry*))
(defn reset-implementations []
  "Reset the implementations registry."
  (table/clear *slynet-rpc-implementations-registry*))

# Run an implementation, raising a helpful error if missing
(defn run-implementation
  "Run the implementation for interface NAME with ARGS.
   Raises an error if no implementation is registered."
  [name & args]
  (def s (if (symbol? name) name (symbol name)))
  (def impl (get-in *implementations* [s :implementation]))
  (if impl
    (try
      (apply impl args)
      ([err _]
        (if *debug-slynk-backend*
          (error err)
          (error (make-backend-error (string "Error in " s) err)))))
    (error (make-implementation-error s "No implementation provided"))))

# Warn about unimplemented interfaces
(defn warn-unimplemented-interfaces
  "Warn the user about unimplemented backend features."
  []
  (when (not (empty? *unimplemented-interfaces*))
    (eprintf "Warning: These backend interfaces are not implemented: %j\n"
             *unimplemented-interfaces*)))


# Dynamic accessors (safe even if not initialized)
(defn slynet-rpc-interfaces []
  (or (dyn slynet-rpc-interfaces-dyn-key) @{}))
(defn slynet-rpc-implementations []
  (or (dyn slynet-rpc-implementations-dyn-key) @{}))

# Sync compile-time registries into dynamic mirrors
(defn slynet-sync-rpc-registries! []
  (setdyn slynet-rpc-interfaces-dyn-key (table/clone *slynet-rpc-interfaces-registry*))
  (setdyn slynet-rpc-implementations-dyn-key (table/clone *slynet-rpc-implementations-registry*))
  true)

# Register an interface at runtime
(defn slynet-register-interface-rt! [nm arglist-spec doc]
  (put *slynet-rpc-interfaces-registry* nm
       @{:name nm :arglist-spec arglist-spec :doc doc})
  true)

# Register interface via regular function (no macro)
(defn slynet-definterface [rpc-name arglist-spec docstring]
  (unless (symbol? rpc-name)
    (eprintf "slynet-definterface: rpc-name must be symbol, got %s\n" (type rpc-name))
    (error "rpc-name"))
  (unless (or (tuple? arglist-spec) (array? arglist-spec))
    (eprintf "slynet-definterface: arglist-spec must be tuple or array (got %s)\n" (type arglist-spec))
    (error "arglist-spec"))
  (unless (string? docstring)
    (eprintf "slynet-definterface: docstring must be string (got %s)\n" (type docstring))
    (error "docstring"))
  (slynet-register-interface-rt! rpc-name arglist-spec docstring)
  true)

(defn ensure-interfaces-initialized! []
  (when (empty? *slynet-rpc-interfaces-registry*)
    (i/define-core-interfaces slynet-definterface)
    (slynet-sync-rpc-registries!))
  true)

# Register all core interfaces from the interfaces module
(i/define-core-interfaces slynet-definterface)
# (defmacro defimplementation
#   "Define an RPC function and (optionally) register it at runtime.
#    Usage: (slynet-defimplementation name [args] \"doc?\" body...)"
#   [rpc-name args & body]
#   (unless (symbol? rpc-name)
#     (error "slynet-defimplementation: rpc-name must be a symbol"))
#   (unless (tuple? args)
#     (error (string "slynet-defimplementation: args must be a tuple, but got " (type args))))

#   # optional docstring
#   (var doc "")
#   (var forms body)
#   (when (and (> (length forms) 0) (string? (forms 0)))
#     (set doc (forms 0))
#     (set forms (tuple/slice forms 1)))

#   ~(do
#      (def ,rpc-name nil) # forward binding
#      (defn ,rpc-name ,args
#        ,;forms)
#      (try
#        ((eval 'slynet-register-impl-rt!) ',rpc-name ,rpc-name ,doc)
#        ([_ fib] nil))))
# == end/slynet-arglists.janet ==

# == end/slynet-arglists.janet ==

# == end/slynet-arglists.janet ==

# == end/rpc_macros.janet ==



(defn get-interface
  "Get the interface metadata for an RPC endpoint.
  Returns nil if the interface doesn't exist."
  [rpc-name]
  (ensure-interfaces-initialized!)
  (let [dyn-reg (dyn slynet-rpc-interfaces-dyn-key)]
    (or (and (table? dyn-reg) (get dyn-reg rpc-name))
        (get *slynet-rpc-interfaces-registry* rpc-name))))

(defn get-implementation
  "Get the implementation function for an RPC endpoint.
  Returns nil if the implementation doesn't exist."
  [rpc-name]
  (let [dyn-reg (dyn slynet-rpc-implementations-dyn-key)]
    (or (and (table? dyn-reg) (get dyn-reg rpc-name))
        (get *slynet-rpc-implementations-registry* rpc-name))))

(defn list-interfaces
  "List all registered RPC interfaces."
  []
  *slynet-rpc-interfaces-registry*)

(defn list-implementations
  "List all registered RPC implementations."
  []
  (let [dyn-reg (dyn slynet-rpc-implementations-dyn-key)]
    (keys (or (and (table? dyn-reg) dyn-reg)
              *slynet-rpc-implementations-registry*))))
(defn contains? [coll key]
  (not= (get coll key ::not-found) ::not-found))

(defn list-unimplemented-interfaces
  "List all interfaces that do not have an implementation."
  [] (filter |(not (get *implementations* $)) *interface-functions*)
  # (filter (fn [iface] (not (contains? *slynet-rpc-implementations-registry* iface)))
  #         (keys *slynet-rpc-interfaces-registry*))
)
(defn pp-interface-implementations
  "Pretty-print the current interface implementations."
  []
  (each fn-name *interface-functions*
    (def impl (get-in *implementations* [fn-name :implementation]))
    (if impl
      (eprintf "%-30s : implemented\n" (string fn-name))
      (eprintf "%-30s : NOT implemented\n" (string fn-name)))))

(def export-api
  @{:make-backend-error make-backend-error
    :pp-interface-implementations pp-interface-implementations
    :make-implementation-error make-implementation-error
    :run-implementation run-implementation
    :warn-unimplemented-interfaces warn-unimplemented-interfaces
    :defimpl-rt! slynet-register-impl-rt!
    :rpc-interfaces-dyn-key slynet-rpc-interfaces-dyn-key
    :rpc-implementations-dyn-key slynet-rpc-implementations-dyn-key
    :rpc-interfaces slynet-rpc-interfaces
    :rpc-implementations slynet-rpc-implementations
    :sync-rpc-registries! slynet-sync-rpc-registries!
    :register-interface-rt! slynet-register-interface-rt!
    :definterface slynet-definterface
    :defimpl defimpl
    :ensure-interfaces-initialized! ensure-interfaces-initialized!
    :*implementations* *implementations*
    :*debug-slynk-backend* *debug-slynk-backend*
    :interfaces-registry *slynet-rpc-interfaces-registry*
    :implementations-registry *slynet-rpc-implementations-registry*
    :get-interface get-interface
    :get-implementation get-implementation
    :list-interfaces list-interfaces
    :reset-interfaces reset-interfaces
    :reset-implementations reset-implementations
    :list-implementations list-implementations
    :list-unimplemented-interfaces list-unimplemented-interfaces})
