# slynet/contrib/slynet-profiler.janet
# Adapted from slynk-profiler.lisp
# Provides a basic profiling interface for Janet functions

# (declare-source "slynet-profiler")

(import ../slynk :as slyk)
(import ../rpc :as slyk-rpc)
(import ../backend :as slyk-backend)

# Module state
(def profiled-functions @{}) # Symbol -> profile info
(def profile-results @{}) # Symbol -> results
(var is-profiling false) # Whether profiling is active
(var profile-start-time nil) # When profiling was started
(var profile-end-time nil) # When profiling was stopped

# Profile info structure
# {:symbol symbol-name
#  :original original-fn
#  :wrapper profiling-wrapper
#  :calls count
#  :time total-time
#  :min-time min-time
#  :max-time max-time}

# RPC Interface definitions are now in slynet/interfaces.janet
(definterface time-spec (spec)
  "Time a spec.")

(definterface untime-spec (spec)
  "Untime a spec.")

(definterface toggle-timing (spec)
  "Toggle timing for a spec.")

(definterface timed-spec-p (spec)
  "Check if a spec is timed.")

(definterface untime-all ()
  "Untime all specs.")

(definterface report-latest-timings ()
  "Report the latest timings.")

(definterface clear-timing-tree ()
  "Clear the timing tree.")

# Implementation helpers
(defn- make-profile-wrapper
  "Create a profiling wrapper function for the original."
  [func symbol-name]
  (fn [& args]
    # Only record timings if profiling is active
    (if is-profiling
      (do
        # Get profile info
        (def info (get profiled-functions symbol-name))

        # Increment call count
        (put info :calls (+ 1 (or (info :calls) 0)))

        # Record start time
        (def start-time (os/clock))

        # Call original function
        (def result (apply func args))

        # Record elapsed time
        (def end-time (os/clock))
        (def elapsed (- end-time start-time))

        # Update timing stats
        (put info :time (+ elapsed (or (info :time) 0)))
        (put info :min-time (min elapsed (or (info :min-time) elapsed)))
        (put info :max-time (max elapsed (or (info :max-time) elapsed)))

        # Return original result
        result)
      # If not profiling, just call the original function
      (apply func args))))

(defn- resolve-function [fname]
  "Resolve a function by name from a symbol or string."
  (def sym (if (string? fname) (symbol fname) fname))
  (try
    (do
      (def val (eval sym))
      (if (function? val)
        [true val sym]
        [false nil sym]))
    ([err fib]
      [false nil sym])))

(defn- instrument-function [fname]
  "Set up profiling for a function."
  (def [resolved-ok resolved-fn sym] (resolve-function fname))
  (def sym-str (string sym))

  # Skip if already profiled
  (when (get profiled-functions sym-str)
    {:status :already-profiled :function sym-str})

  # Check if function exists
  (when (not resolved-ok)
    {:status :error :message (string "Cannot profile " sym-str ": not a function") :function sym-str})

  # Create profiling wrapper
  (def wrapper (make-profile-wrapper resolved-fn sym-str))

  # Store function info
  (put profiled-functions sym-str
       @{:symbol sym-str
         :original resolved-fn
         :wrapper wrapper
         :calls 0
         :time 0
         :min-time nil
         :max-time nil})

  # Replace function with wrapper
  (try
    (do
      (eval ~(def ,sym ,wrapper))
      {:status :profiling :function sym-str})
    ([err fib]
      (put profiled-functions sym-str nil)
      {:status :error :message (string err) :function sym-str})))

(defn- uninstrument-function [fname]
  "Remove profiling from a function."
  (def [_ _ sym] (resolve-function fname))
  (def sym-str (string sym))

  # Check if function is profiled
  (def profile-info (get profiled-functions sym-str))
  (when (nil? profile-info)
    {:status :not-profiled :function sym-str})

  # Save profile results
  (put profile-results sym-str profile-info)

  # Restore original function
  (try
    (do
      (eval ~(def ,sym ,(profile-info :original)))
      (put profiled-functions sym-str nil)
      {:status :unprofiled :function sym-str})
    ([err fib]
      {:status :error :message (string err) :function sym-str})))

(defn- collect-profile-results []
  "Collect and organize profiling results."
  (def results @[])
  # First add still-profiled functions
  (eachp [sym info] profiled-functions
    (array/push results
                @{:name sym
                  :inclusive-time (or (info :time) 0)
                  :exclusive-time (or (info :time) 0) # No subcall tracking yet
                  :call-count (or (info :calls) 0)
                  :min-time (or (info :min-time) 0)
                  :max-time (or (info :max-time) 0)}))

  # Then add previously profiled functions
  (eachp [sym info] profile-results
    # Skip if already included above
    (when (not (get profiled-functions sym))
      (array/push results
                  @{:name sym
                    :inclusive-time (or (info :time) 0)
                    :exclusive-time (or (info :time) 0) # No subcall tracking yet
                    :call-count (or (info :calls) 0)
                    :min-time (or (info :min-time) 0)
                    :max-time (or (info :max-time) 0)})))

  # Sort by inclusive time (descending)
  (sort-by (fn [x] (- 0 (x :inclusive-time))) results))

(defn start-profiling [function-names]
  "Start profiling the named functions."
  (def results @[])
  (each fname function-names
    (array/push results (instrument-function fname)))

  # Start profiling timer
  (set is-profiling true)
  (set profile-start-time (os/time))
  (set profile-end-time nil)

  @{:status :profiling-started
    :timestamp profile-start-time
    :results results})

(defn stop-profiling []
  "Stop profiling and return the profiling results."
  # Stop profiling timer
  (set profile-end-time (os/time))
  (set is-profiling false)

  # Collect results but don't uninstrument
  (def results (collect-profile-results))

  @{:status :profiling-stopped
    :start-time profile-start-time
    :end-time profile-end-time
    :duration (if profile-start-time
                (- profile-end-time profile-start-time)
                0)
    :results results})

(defn reset-profiling []
  "Reset profiling data."
  # Uninstrument all functions
  (def uninstrument-results @[])
  (eachp [sym _] profiled-functions
    (array/push uninstrument-results (uninstrument-function sym)))

  # Clear results
  (table/clear profile-results)
  (set is-profiling false)
  (set profile-start-time nil)
  (set profile-end-time nil)

  @{:status :profiling-reset
    :uninstall-results uninstrument-results})

(defn report []
  "Return the current profiling report."
  @{:profiling-active is-profiling
    :start-time profile-start-time
    :end-time profile-end-time
    :duration (if (and profile-start-time profile-end-time)
                (- profile-end-time profile-start-time)
                (if profile-start-time
                  (- (os/time) profile-start-time)
                  0))
    :results (collect-profile-results)})

(defn profile-package [package]
  "Profile all functions in a package/module."
  (try
    (do
      (def mod (require package))
      (def results @[])
      (def functions @[])

      # Collect functions to profile
      (eachp [k v] mod
        (when (function? v)
          (array/push functions (symbol package "/" (string k)))))

      # Start profiling them
      (start-profiling functions)

      @{:status :profiling-package
        :package package
        :function-count (length functions)})
    ([err fib]
      @{:status :error
        :message (string "Error profiling package " package ": " err)})))

(defn initialize-module []
  "Initialize the profiler module."
  (print "Initializing SLYNET Profiler module")

  # Reset any previous state
  (table/clear profiled-functions)
  (table/clear profile-results)
  (set is-profiling false)
  (set profile-start-time nil)
  (set profile-end-time nil)

  true)

(def export-api
  @{:initialize-module initialize-module
    :start-profiling start-profiling
    :stop-profiling stop-profiling
    :reset-profiling reset-profiling
    :report report
    :profile-package profile-package})
