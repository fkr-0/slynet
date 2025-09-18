# slynet/contrib/slynet-indentation.janet
# Adapted from slynk-indentation.lisp
# Provides indentation rules for Janet code in Emacs

# (declare-source "slynet-indentation")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)
(import ../infrastructure :as inf)


(def slynet-indentation/load-default-rules nil)
# Module state
(var *indentation-rules* @{}) # Symbol -> indentation spec

# (def *default-indentation-rules* @{})
# Default indentation rules for Janet special forms and common macros
(def *default-indentation-rules*
  @{# Core special forms
    'def [1]
    'var [1]
    'do [0]
    'fn [1 :body]
    'defn [2 :body]
    'defmacro [2 :body]
    'while [1 :body]
    'for [1 :body]
    'if [1]
    'when [1 :body]
    'unless [1 :body]
    'cond [0]
    'case [1]
    'match [1]
    'let [1 :body]
    'try [0 :body]
    'catch [2 :body]

    # Common macros
    'each [1 :body]
    'eachp [1 :body]
    'eachk [1 :body]
    'loop [1 :body]
    'with [1 :body]
    'with-dyns [1 :body]
    'deftest [1 :body]
    'deftest-skip [1 :body]
    'deftest-assert [1 :body]
    'comment [0]

    # Special Janet forms
    'import [0]
    'use [0]})

# RPC Interface definitions are now in slynet/interfaces.janet

# Implementation
(defn- valid-indentation-spec? [spec]
  "Check if an indentation spec is valid."
  (or (number? spec)
      (and (indexed? spec)
           (every? (map (fn [item]
                          (or (number? item)
                              (= item :body)
                              (= item :rest)))
                        spec)))))

(defn slynet-indentation/update-indentation-rule [symbol spec]
  "Update the indentation rule for a symbol."
  (if (and (symbol? symbol) (valid-indentation-spec? spec))
    (do
      (put *indentation-rules* symbol spec)
      [true (string "Updated indentation rule for " symbol)])
    [false "Invalid symbol or indentation spec"]))

(inf/defimpl
  'slynet-indentation/update-indentation-rule
  slynet-indentation/update-indentation-rule)

(defn slynet-indentation/get-indentation-rule [symbol]
  "Get the indentation rule for a symbol."
  (if (symbol? symbol)
    (or (get *indentation-rules* symbol)
        (get *default-indentation-rules* symbol)
        nil)
    nil))

(inf/defimpl
  'slynet-indentation/get-indentation-rule
  slynet-indentation/get-indentation-rule)

(defn slynet-indentation/get-all-indentation-rules []
  "Get all defined indentation rules."
  (def rules @{})

  # First add defaults
  (eachp [sym spec] *default-indentation-rules*
    (put rules sym spec))

  # Then override with custom rules
  (eachp [sym spec] *indentation-rules*
    (put rules sym spec))

  rules)

(inf/defimpl
  'slynet-indentation/update-indentation-rule
  slynet-indentation/update-indentation-rule)

(defn slynet-indentation/load-default-rules []
  "Load the default indentation rules."
  (set *indentation-rules* (table/clone *default-indentation-rules*))
  (length *indentation-rules*))


(inf/defimpl
  'slynet-indentation/load-default-rules
  slynet-indentation/load-default-rules)
# Auto-detection of indentation rules
# (defn- extract-defmacro-indentation [macro-def]
#   "Try to automatically determine indentation for a macro definition."
#   # This is a simplified implementation
#   # In a real implementation, we might parse the macro to analyze its structure
#   # For now, we'll just use a default conservative indentation
#   [1])

# (defn scan-for-macros [env]
#   "Scan the environment for macro definitions and extract their indentation."
#   (def rules @{})
#   (eachp [k v] env
#     (when (and (symbol? k) (function? v) (v :macro))
#       (put rules k (extract-defmacro-indentation v))))
#   rules)

(defn scan-current-env []
  "Scan the current environment for macro definitions."
  (def rules # (scan-for-macros (fiber/getenv (fiber/current)))
    *default-indentation-rules*)
  (eachp [sym rule] rules
    (put *indentation-rules* sym rule))
  (length rules))

# Module initialization
(defn initialize-module []
  "Initialize the indentation module."
  (slynet-indentation/load-default-rules)
  (scan-current-env)
  (print "SLYNET: Indentation module initialized with " (length *indentation-rules*) " rules.")
  true)

# Module exports
(def export-api
  @{:initialize-module initialize-module
    :*indentation-rules* *indentation-rules*
    :*default-indentation-rules* *default-indentation-rules*
    # :slynet-indentation/update-indentation-rule slynet-indentation/update-indentation-rule
    # :slynet-indentation/get-indentation-rule slynet-indentation/get-indentation-rule
    # :slynet-indentation/get-all-indentation-rules slynet-indentation/get-all-indentation-rules
    # :slynet-indentation/load-default-rules slynet-indentation/load-default-rules
    :scan-current-env scan-current-env})
