# slynet/contrib/slynet-trace-dialog.janet
# Adapted from slynk-trace-dialog.lisp
# Provides a trace dialog interface for Janet functions

# (declare-source "slynet-trace-dialog")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)

# Module state
(def active-traces @{}) # Symbol -> trace info
(var trace-output @[]) # Vector of trace output entries
(def max-trace-entries 2000) # Maximum number of trace entries to keep
(def show-trace-output-in-repl false) # Whether to show traces in REPL as well
(var current-trace-id 0) # Counter for unique trace IDs
(var current-trace-depth 0) # Track nesting depth of traced calls
(defn trace-format [trace]
  "Format a trace."
  (string/format "%j" trace))

(defn trace-or-lose [id]
  "Trace a part or lose."
  (error "Not implemented"))

(definterface report-partial-tree (id)
  "Report a partial trace tree.")

(definterface report-specs (id)
  "Report trace specs.")

(definterface report-total (id)
  "Report total trace time.")

(definterface clear-trace-tree ()
  "Clear the trace tree.")

(definterface trace-part-or-lose (id)
  "Trace a part or lose.")

(definterface trace-arguments-or-lose (id)
  "Trace arguments or lose.")

(definterface inspect-trace-part (id)
  "Inspect a trace part.")

(definterface pprint-trace-part (id)
  "Pretty-print a trace part.")

(definterface describe-trace-part (id)
  "Describe a trace part.")

(definterface inspect-trace (id)
  "Inspect a trace.")

(definterface trace-location (id)
  "Get the location of a trace.")

(definterface dialog-trace (spec)
  "Trace a function via dialog.")

(definterface dialog-untrace (spec)
  "Untrace a function via dialog.")

(definterface dialog-toggle-trace (spec)
  "Toggle tracing for a function via dialog.")

(definterface dialog-traced-p (spec)
  "Check if a function is traced via dialog.")

(definterface dialog-untrace-all ()
  "Untrace all functions via dialog.")

# Trace entry structure
# {:id unique-id
#  :name function-name
#  :args args-values
#  :depth call-depth
#  :timestamp entry-time
#  :result return-value-or-error
#  :duration time-elapsed}

# RPC Interface definitions are now in slynet/interfaces.janet

# Implementation helpers
(defn- make-trace-wrapper
  "Create a wrapper function that traces calls to the original."
  [fname original-fn]

  (fn [& args]
    # Generate unique trace ID and increment depth
    (def trace-id (++ current-trace-id))
    (def depth current-trace-depth)
    (++ current-trace-depth)

    # Record entry time
    (def start-time (os/clock))
    (def entry-trace
      @{:id trace-id
        :name fname
        :args (try (map slyk-backend/safe-princ-to-string args)
                ([err fib] ["Error capturing args"]))
        :depth depth
        :timestamp (os/time)
        :type :enter})

    # Add entry trace to the buffer
    (array/push trace-output entry-trace)

    # Trim buffer if needed
    (when (> (length trace-output) max-trace-entries)
      (array/remove trace-output 0))

    # Show in REPL if enabled
    (when show-trace-output-in-repl
      (printf "TRACE %s: -> %s" fname (slyk-backend/safe-princ-to-string args)))

    # Call the original function and capture result
    (var result nil)
    (var error nil)
    (try
      (set result (apply original-fn args))
      ([err fib]
        (set error err)))

    # Calculate elapsed time
    (def end-time (os/clock))
    (def duration (- end-time start-time))

    # Create exit trace
    (def exit-trace
      @{:id trace-id
        :name fname
        :result (if (nil? error)
                  (try (slyk-backend/safe-princ-to-string result)
                    ([err fib] "Error capturing result"))
                  (string "ERROR: " error))
        :depth depth
        :timestamp (os/time)
        :duration duration
        :type :exit
        :error (not (nil? error))})

    # Add exit trace to the buffer
    (array/push trace-output exit-trace)

    # Trim buffer if needed
    (when (> (length trace-output) max-trace-entries)
      (array/remove trace-output 0))

    # Show in REPL if enabled
    (when show-trace-output-in-repl
      (printf "TRACE %s: <- %s (%f ms)"
              fname
              (if (nil? error)
                (slyk-backend/safe-princ-to-string result)
                (string "ERROR: " error))
              (* duration 1000)))

    # Decrement depth as we exit
    (-- current-trace-depth)

    # Reraise error or return result
    (if (nil? error)
      result
      (error error))))

(defn- resolve-function
  "Resolve a function by name from a symbol or string."
  [fname]
  (def sym (if (string? fname) (symbol fname) fname))
  (try
    (do
      (def val (eval sym))
      (if (function? val)
        [true val]
        [false nil]))
    ([err fib]
      [false nil])))

(defn- start-tracing
  "Start tracing a function."
  [fname]
  (def sym (if (string? fname) (symbol fname) fname))
  (def sym-str (string sym))

  # Return early if already traced
  (when (get active-traces sym-str)
    {:status :already-traced :function sym-str})

  # Resolve the function
  (def [resolved-ok resolved-fn] (resolve-function sym))
  (when (not resolved-ok)
    (error (string "Cannot trace " sym-str ": not a function")))

  # Create a trace wrapper
  (def wrapper (make-trace-wrapper sym-str resolved-fn))

  # Store the original and wrapper
  (put active-traces sym-str
       @{:name sym-str
         :original resolved-fn
         :wrapper wrapper})

  # Replace the function with the wrapper
  (try
    (do
      (eval ~(def ,sym ,wrapper))
      {:status :traced :function sym-str})
    ([err fib]
      (put active-traces sym-str nil)
      {:status :error :message (string err) :function sym-str})))

(defn- stop-tracing
  "Stop tracing a function."
  [fname]
  (def sym (if (string? fname) (symbol fname) fname))
  (def sym-str (string sym))

  # Return early if not traced
  (def trace-info (get active-traces sym-str))
  (when (nil? trace-info)
    {:status :not-traced :function sym-str})

  # Restore the original function
  (try
    (do
      (eval ~(def ,sym ,(trace-info :original)))
      (put active-traces sym-str nil)
      {:status :untraced :function sym-str})
    ([err fib]
      {:status :error :message (string err) :function sym-str})))

(defn dialog-trace [fname]
  "Enable tracing for a function."
  (start-tracing fname))

(defn dialog-untrace [fname]
  "Disable tracing for a function."
  (stop-tracing fname))

(defn dialog-toggle-trace [fname]
  "Toggle tracing for a function."
  (def sym (if (string? fname) (symbol fname) fname))
  (def sym-str (string sym))

  (if (get active-traces sym-str)
    (stop-tracing fname)
    (start-tracing fname)))

(defn dialog-untrace-all []
  "Disable all active traces."
  (def results @[])
  (eachp [sym trace-info] active-traces
    (array/push results (stop-tracing sym)))
  results)

(defn clear-trace-buffer []
  "Clear the trace output buffer."
  (array/clear trace-output)
  (set current-trace-id 0)
  true)

(defn report-partial-traces [limit]
  "Return the latest trace entries from the buffer, up to LIMIT entries."
  (default limit (length trace-output))

  (def start-idx (max 0 (- (length trace-output) limit)))
  (array/slice trace-output start-idx))

(defn report-all-traced-functions []
  "Return a list of all currently traced functions."
  (def result @[])
  (eachp [sym trace-info] active-traces
    (array/push result sym))
  result)

(defn initialize-module []
  "Initialize the trace dialog module."
  (print "Initializing SLYNET Trace Dialog module")

  # Clear any previous state
  (clear-trace-buffer)
  (table/clear active-traces)
  (set current-trace-depth 0)

  true)

(def export-api
  @{:initialize-module initialize-module
    :dialog-toggle-trace dialog-toggle-trace
    :dialog-trace dialog-trace
    :dialog-untrace dialog-untrace
    :dialog-untrace-all dialog-untrace-all
    :clear-trace-buffer clear-trace-buffer
    :report-partial-traces report-partial-traces
    :report-all-traced-functions report-all-traced-functions
    :trace-format trace-format
    :trace-or-lose trace-or-lose})
