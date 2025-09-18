# SLYNK Utility Functions
# Common utility functions for SLYNET modules

(declare-source "slynet-utils")

#
# String utilities
#

(defn safe-string
  "Safely convert any value to a string with a maximum length.
   Handles errors and prevents excessive output."
  [value &opt max-length]
  (default max-length 100)
  (try
    (def result (string/format "%j" value))
    (if (> (length result) max-length)
      (string (string/slice result 0 max-length) "...")
      result)
    ([err fib]
      "[Error printing value]")))

(defn string-match?
  "Check if a substring exists in a string with case sensitivity options."
  [pattern string case-sensitive]
  (def p (if case-sensitive pattern (string/ascii-lower pattern)))
  (def s (if case-sensitive string (string/ascii-lower string)))
  (string/find p s))

#
# Symbol utilities
#

(defn symbol-to-string
  "Convert a symbol or keyword to a string representation."
  [x]
  (cond
    (symbol? x) (string x)
    (keyword? x) (string x)
    :else (string x)))

(defn symbol-package
  "Get the package/namespace part of a symbol."
  [sym]
  (when (symbol? sym)
    (def parts (string/split "/" (string sym)))
    (if (= (length parts) 2)
      (parts 0)
      nil)))

(defn symbol-name
  "Get the name part of a symbol (without the package/namespace)."
  [sym]
  (when (symbol? sym)
    (def parts (string/split "/" (string sym)))
    (if (= (length parts) 2)
      (parts 1)
      (parts 0))))

#
# List/array utilities
#

(defn ensure-array
  "Ensure the value is an array; convert if it's not."
  [value]
  (match (type value)
    :array value
    :tuple (array/slice value)
    # Single element array for other values
    @[value]))

(defn flatten-arrays
  "Flatten nested arrays into a single flat array."
  [arr]
  (var result @[])
  (each item arr
    (if (or (array? item) (tuple? item))
      (array/concat result (flatten-arrays (array/slice item)))
      (array/push result item)))
  result)

#
# Table utilities
#

(defn merge-tables
  "Merge multiple tables into a new table."
  [& tables]
  (def result @{})
  (each t tables
    (when (table? t)
      (eachp [k v] t
        (put result k v))))
  result)

(defn filter-table
  "Filter a table by a predicate function."
  [pred tbl]
  (def result @{})
  (eachp [k v] tbl
    (when (pred k v)
      (put result k v)))
  result)

#
# Error handling utilities
#

(defn make-error
  "Create a standard error object with type and details."
  [type message &opt details]
  (default details @{})
  (merge-tables
    @{:type type
      :message message}
    details))

(defn with-error-handling
  "Execute function with standardized error handling.
   Returns [success result] or [false error-object]."
  [f &opt error-type]
  (default error-type :generic-error)
  (try
    [true (f)]
    ([err fib]
      [false (make-error error-type (string err))])))

#
# Debug utilities
#

(var *debug-enabled* false)

(defn enable-debug
  "Enable debug output."
  []
  (set *debug-enabled* true))

(defn disable-debug
  "Disable debug output."
  []
  (set *debug-enabled* false))

(defn debug-print
  "Print a debug message if debug is enabled."
  [& args]
  (when *debug-enabled*
    (print "[DEBUG] " (string/join (map string args) " "))))
