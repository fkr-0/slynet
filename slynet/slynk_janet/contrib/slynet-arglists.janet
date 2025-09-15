# slynet/slynk_janet/contrib/slynet-arglists.janet
# Adapted from slynk-arglists.lisp
# Provides enhanced arglist functionality for Janet functions
# == slynet/slynk_janet/contrib/slynet-arglists.janet ==
# PATCH — add a tiny stub so (declare-source ...) compiles.
# If later you want to track file/line origins, replace this with a registry.

# (defmacro declare-source [& _]
#   nil)

# # ... rest of the file ...
# # == end/slynet-arglists.janet ==

# (declare-source "slynet-arglists")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)

# Module state
(var debug-arglist-cache false)
(var arglist-cache @{})
(var cache-last-access @{})
(var cache-access-count @{})
(var arglist-update-hooks @[])
(var cache-size 0)
(var cache-limit 700)

# RPC Interface definitions are now in slynet/slynk_janet/interfaces.janet

# Implementation
(defn- record-cache-access [symbol]
  "Record that SYMBOL was accessed in the arglist cache."
  (def now (os/time))
  (put cache-last-access symbol now)
  (put cache-access-count symbol (+ 1 (or (cache-access-count symbol) 0))))

(defn- remove-symbol-from-cache [symbol]
  "Remove a symbol from the cache."
  (put arglist-cache symbol nil)
  (put cache-last-access symbol nil)
  (put cache-access-count symbol nil)
  (-- cache-size))

(defn- trim-cache []
  "Trim the cache to the limit by removing least recently used entries."
  (when (> cache-size cache-limit)
    (def entries @[])
    (eachp [sym timestamp] cache-last-access
      (array/push entries [sym timestamp]))

    # Sort by timestamp (oldest first)
    (sort entries (fn [a b] (< (a 1) (b 1))))

    # Remove oldest entries until we're under the limit
    (def count-to-remove (- cache-size cache-limit))
    (for i 0 count-to-remove
      (if (< i (length entries))
        (remove-symbol-from-cache ((entries i) 0))))))

(defn compute-arglist [function-name]
  "Compute the arglist for a function."
  (try
    (do
      (def func (if (function? function-name) function-name (eval function-name)))
      (if (function? func)
        (let [meta (table/getproto func)]
          (if meta
            # Try to get the arglist from the prototype's :arg-list key
            (if-let [args (meta :arg-list)]
              args
              # Otherwise return generic info
              ["&" "args"])
            ["&" "args"]))
        nil) # Not a function, return nil
)
    ([err fib]
      (eprintf "Error computing arglist for %s: %s" function-name err)
      nil))) # Error, return nil

(defn
  slynet-arglists/update-arglist [symbol new-arglist]
  "Update the arglist for a function in the cache."
  (when (and (symbol? symbol) new-arglist)
    (put arglist-cache symbol new-arglist)
    (when (not (cache-last-access symbol))
      (set cache-size (inc cache-size)))
    (record-cache-access symbol)

    # Run the hooks
    (each hook arglist-update-hooks
      (try (hook symbol new-arglist) ([_ fib] nil)))

    # Trim if needed
    (trim-cache))
  symbol)

(slyk-backend/register-implementation
  'slynet-arglists/update-arglist
  slynet-arglists/update-arglist)

(defn
  slynet-arglists/clear-arglists-cache []
  "Clear the arglist cache."
  (set arglist-cache @{})
  (set cache-last-access @{})
  (set cache-access-count @{})
  (set cache-size 0)
  true)

(slyk-backend/register-implementation
  'slynet-arglists/clear-arglists-cache
  slynet-arglists/clear-arglists-cache)

(defn get-argl-fc [symbol] (when (symbol? symbol)
                             (if-let [cached (get arglist-cache symbol)]
                               (do
                                 (record-cache-access symbol)
                                 cached)
                               (let [computed (compute-arglist symbol)]
                                 (when computed
                                   (put arglist-cache symbol computed)
                                   (++ cache-size)
                                   (record-cache-access symbol)
                                   (trim-cache))
                                 computed))))
(defn slynet-arglists/get-arglist-from-cache [symbol]
  "Get the cached arglist for a symbol, or compute and cache it."
  (when (symbol? symbol)
    (if-let [cached (get arglist-cache symbol)]
      (do
        (record-cache-access symbol)
        cached)
      (let [computed (compute-arglist symbol)]
        (when computed
          (put arglist-cache symbol computed)
          (++ cache-size)
          (record-cache-access symbol)
          (trim-cache))
        computed))))
(slyk-backend/register-implementation
  'slynet-arglists/get-arglist-from-cache
  slynet-arglists/get-arglist-from-cache)

(defn slynet-arglists/show-arglist [symbol]
  "Show the arglist for a function in the minibuffer."
  (def arglist (get-argl-fc symbol))
  (if arglist
    (string/format "%s: %j" symbol arglist)
    (string "No arglist available for " symbol)))

(slyk-backend/register-implementation
  'slynet-arglists/show-arglist
  slynet-arglists/show-arglist)

# Add a hook to refresh arglists when a function is redefined
(defn hook-into-eval []
  "Add hooks into the Janet eval system to update arglists when functions are defined."
  # In Janet, we might need to hook into the compiler or use other approaches
  # This is a simplified version and might need enhancement
  (def orig-defn (dyn 'defn))
  (defmacro new-defn [name args & body]
    ~(print "Defining function " name " with args " args)
    ~(do
       (,orig-defn ,name ,args ,;body)
       # Update the arglist cache
       (when-let [f (,name)]
         (slynet-arglists/update-arglist ',name ,args))
       ,name))
  (setdyn 'defnn new-defn))

# Module initialization
(defn initialize-module []
  "Initialize the arglists module."
  (hook-into-eval)
  (print "SLYNET: Arglists module initialized.")
  true)
(print "SLYNET: Arglists module loaded.")

# Module exports
(def export-api
  @{:initialize-module initialize-module
    :arglist-cache arglist-cache
    :show-arglist slynet-arglists/show-arglist
    :get-arglist-from-cache slynet-arglists/get-arglist-from-cache
    :clear-arglists-cache slynet-arglists/clear-arglists-cache
    :update-arglist slynet-arglists/update-arglist
    :compute-arglist compute-arglist
    :debug-arglist-cache debug-arglist-cache
    :arglist-update-hooks arglist-update-hooks})
# Janet module-level aliases for public API (for import :as arglists)
(def clear-arglists-cache slynet-arglists/clear-arglists-cache)
(def initialize-module initialize-module)
(def arglist-cache arglist-cache)
(def show-arglist slynet-arglists/show-arglist)
(def get-arglist-from-cache slynet-arglists/get-arglist-from-cache)
(def update-arglist slynet-arglists/update-arglist)
(def compute-arglist compute-arglist)
(def debug-arglist-cache debug-arglist-cache)
(def arglist-update-hooks arglist-update-hooks)
# All public API functions are defined at the module top level for Janet import.
# (provide ...) is not valid Janet. Export symbols via export-api map only.
