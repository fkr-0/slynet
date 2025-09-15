# slynet/slynk_janet/contrib/slynet-package-fu.janet
# Adapted from slynk-package-fu.lisp
# Provides module/package manipulation for Janet

# (declare-source "slynet-package-fu")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)

# RPC Interface definitions are now in slynet/slynk_janet/interfaces.janet

# Implementation helpers
(defn- get-module-info [path]
  "Get information about a module from its path."
  (try
    (do
      (def module (module/cache path))
      (if module
        @{:name path
          :exports (length (keys module))
          :source (try
                    (do
                      (def content (os/stat path))
                      path)
                    ([err _] nil))}
        nil))
    ([err _] nil)))

(defn- get-all-modules []
  "Get information about all available modules."
  (def results @[])
  (each path module/paths
    (def info (get-module-info path))
    (when info
      (array/push results info)))
  results)

(defn- get-module-exports [module-name]
  "Get all exported symbols from a module."
  (try
    (do
      (def mod (require module-name))
      (def exports @[])

      (eachp [k v] mod
        (array/push exports
                    @{:name k
                      :type (type v)
                      :private (string/has-prefix? "_" (string k))}))

      (sort-by (fn [x] (string (x :name))) exports))
    ([err fib]
      @{:error (string "Failed to load module: " err)})))

(defn- get-module-dependencies [module-name]
  "Get all dependencies for a module."
  (def deps @[])

  (try
    # This is difficult without parsing the source code
    # For now, we'll return a placeholder
    @{:message "Dependency tracking requires source code analysis"}
    ([err _]
      @{:error "Failed to analyze module dependencies"})))

(defn metadata [obj]
  "Retrieve metadata from an object if available."
  (if (table? obj)
    (table/getproto obj)
    nil))

(defn meta-mod [obj key]
  "Get metadata key from an object."
  (let [meta (metadata obj)]
    (if meta
      (meta key)
      nil)))

(defn- get-current-imports []
  "Get all modules imported in the current environment."
  (def results @[])
  (def env (fiber/getenv (fiber/current)))

  # Look for module bindings in environment
  # This is a heuristic that looks for tables bound to symbols
  # that might be modules
  (eachp [k v] env
    (when (and (symbol? k) (table? v))
      (try
        (do
          # Check if this is likely a module
          # (has module metadata or several exported functions)
          (def meta-mod (metadata v))
          (when (or (meta-mod :module)
                    (> (length (keys v)) 5)) # Arbitrary threshold
            (array/push results
                        @{:symbol k
                          :bindings (length (keys v))
                          :source (meta-mod :source)})))
        ([err _] nil))))

  results)

(defn- perform-import [module-name prefix exclude rename only]
  "Import a module with the specified options."
  (try
    # Build the import expression based on options
    (do
      (def import-expr
        (cond
          (and prefix (not (empty? prefix)))
          ~(import ,module-name :as ,prefix)

          (and only (not (empty? only)))
          ~(import [,module-name ,;only])

          # Default simple import
          ~(import ,module-name)))

      # Execute the import
      (eval import-expr)

      @{:status :success
        :module module-name
        :expression (string import-expr)})
    ([err fib]
      @{:status :error
        :message (string "Failed to import " module-name ": " err)})))

# Exported functions
(defn list-all-packages []
  "List all available Janet modules."
  (get-all-modules))

(defn list-exported-symbols [package-name]
  "List all exported symbols for a Janet module."
  (get-module-exports package-name))

(defn list-all-imports []
  "List all imported modules in the current environment."
  (get-current-imports))

(defn list-depends [package-name]
  "List all dependencies for a package."
  (get-module-dependencies package-name))

(defn import-module [module-name prefix exclude rename only]
  "Import a module into the current environment."
  (perform-import module-name prefix exclude rename only))

(defn initialize-module []
  "Initialize the package-fu module."
  (print "Initializing SLYNET Package-Fu module")
  true)

(def export-api
  @{:initialize-module initialize-module
    :list-all-packages list-all-packages
    :list-exported-symbols list-exported-symbols
    :list-all-imports list-all-imports
    :list-depends list-depends
    :import-module import-module})
