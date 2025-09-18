# slynet/contrib/slynet-apropos.janet
# Adapted from slynk-apropos.lisp
# Provides symbol search functionality for Janet

# (declare-source "slynet-apropos")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)
(import ../infrastructure :as inf)

# Module constants
(def *max-apropos-matches* 500) # Default limit on results returned

# RPC Interface definitions are now in slynet/interfaces.janet

# (defn list-all-modules []
#   "List all currently loaded modules."
#   (try (do (let ))))
# Implementation helpers
(defn- symbol-to-string [x]
  "Convert a symbol to a string for comparison."
  (cond
    (symbol? x) (string x)
    (keyword? x) (string x)
    :else (string x)))

(defn- string-match? [pattern string case-sensitive]
  "Check if string matches pattern."
  (def p (if case-sensitive pattern (string/ascii-lower pattern)))
  (def s (if case-sensitive string (string/ascii-lower string)))
  (string/find p s))

(defn- match-proto [prototype symbol-name extern-symbols case-sensitive]
  "Match a prototype table against search criteria."
  (when (or extern-symbols (not (prototype :private)))
    (string-match? symbol-name (symbol-to-string (prototype :name)) case-sensitive)))

(defn- search-fiber-env [fiber pattern extern-symbols case-sensitive]
  "Search for symbols in a fiber's environment."
  (def results @[])
  (def env (fiber/getenv fiber))
  (eachp [sym val] env
    (when (symbol? sym)
      # Check if symbol name matches pattern
      (when (string-match? pattern (symbol-to-string sym) case-sensitive)
        (array/push results
                    {:symbol sym
                     :type (type val)
                     :bound true
                     :value-snippet (slyk-backend/safe-princ-to-string val 50)}))))
  results)

(defn- search-module-bindings [module-name pattern extern-symbols case-sensitive]
  "Search for symbols in a module's binding table."
  (def results @[])
  (try
    (do
      (def module (require module-name))
      (eachp [sym val] module
        (when (string-match? pattern (symbol-to-string sym) case-sensitive)
          (array/push results
                      {:symbol (symbol module-name "/" (string sym))
                       :module module-name
                       :type (type val)
                       :bound true
                       :value-snippet (slyk-backend/safe-princ-to-string val 50)}))))
    ([err fib]
      # Module not found or other error
      nil))
  results)

(defn- search-all-modules [pattern extern-symbols case-sensitive]
  "Search all loaded modules for matching symbols."
  (def results @[])
  (def modules (slyk-backend/list-all-modules))
  (each module-name modules
    (array/concat results (search-module-bindings module-name pattern extern-symbols case-sensitive)))
  results)

(defn search-symbols [string-or-pattern extern-symbols case-sensitive limit]
  "Search for symbols matching the given string or pattern."
  (default extern-symbols false)
  (default case-sensitive false)
  (default limit *max-apropos-matches*)

  (def pattern (string string-or-pattern))
  (def results @[])

  # Search current environment
  (array/concat results (search-fiber-env (fiber/current) pattern extern-symbols case-sensitive))

  # Search all loaded modules if extern-symbols is true
  (when extern-symbols
    (array/concat results (search-all-modules pattern extern-symbols case-sensitive)))

  # Limit the number of results
  (if (> (length results) limit)
    (array/slice results 0 limit)
    results))

(defn list-all-symbols [package-name]
  "List all symbols in the specified package/module."
  (def results @[])
  (try
    (do (def module (require package-name))
      (eachp [sym val] module
        (array/push results
                    {:symbol (symbol package-name "/" (string sym))
                     :module package-name
                     :type (type val)
                     :bound true}))) ([err fib]
                                       # Module not found or other error
                                       nil))
  results)

(defn describe-symbol-for-emacs [symbol]
  "Return a property list with documentation about a symbol."
  (def result @{})

  # Try to look up the symbol in available contexts
  (try
    (do (def value (eval symbol))
      (put result :value-p true)
      (put result :value (slyk-backend/safe-princ-to-string value 100))
      (put result :type (type value)))
    ([err fib] nil))

  # If it's a function, get its documentation and arglist
  (try
    (do
      (when (function? (eval symbol))
        (put result :function-p true)
        (put result :arglist (slyk-backend/arglist symbol))

        # Get docstring if available
        (def doc (slyk-backend/documentation symbol :function))
        (when doc
          (put result :documentation doc))))
    ([err fib] nil))

  # If it's a macro, indicate that
  (try
    (when (function? symbol)
      (put result :macro-p true))
    ([err fib] nil))

  # Handle other types of documentation
  (try
    (do (def variable-doc (slyk-backend/documentation symbol :variable))
      (when variable-doc
        (put result :variable-documentation variable-doc)))
    ([err fib] nil))

  result)

(inf/defimpl
  'slynet-apropos/search-symbols
  search-symbols)

(inf/defimpl
  'slynet-apropos/list-all-symbols
  list-all-symbols)

(inf/defimpl
  'slynet-apropos/describe-symbol-for-emacs
  describe-symbol-for-emacs)

# Module initialization
# Check for required backend functions

(defn initialize-module []
  "Initialize the apropos module."
  (print "Initializing SLYNET Apropos module")

  # Check if the backend has the necessary functionality
  (def has-documentation (function? slyk-backend/documentation))
  (def has-arglist (function? slyk-backend/arglist))

  (when (not has-documentation)
    (print "Warning: Backend does not support documentation retrieval"))

  (when (not has-arglist)
    (print "Warning: Backend does not support arglist retrieval"))

  true)

(def export-api
  @{:initialize-module initialize-module
    :search-symbols search-symbols
    :list-all-symbols list-all-symbols
    :describe-symbol-for-emacs describe-symbol-for-emacs})
