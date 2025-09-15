# (declare-source "slynet-mrepl")

(import ../backend :as slyk-backend)
(import ../rpc :as slyk-rpc)
(import ../gray :as slyk-gray)
(import ../completion :as slyk-completion)
(import ../slynk :as slyk)
(defmacro try-catch-finally
  "A macro for try-catch-finally behavior in Janet.
   macro

   (try-catch-finally
     BODY-FORM                # tip: use (do ...) if you need multiple
     ([e fib] CATCH-FORMS...) # you can ignore fib if unused: ([e _] ...)
     FINALLY-FORMS...)        # one form that always run

Example:
(try-catch-finally
    (do
      (print \"Doing work (success path).\")
      :ok)
    ([e fib]
      (do (print \"Caught (should not happen):\" e)
        :caught)) # would be returned on error
    (print \"FINALLY (success): always runs.\"))

"
  [body [errpat & catch-body] & finally-body]
  ~(defer
     (do ,;finally-body) # FINALLY (always runs)
     (try
       ,body # BODY (single form; wrap with (do ...) at call site if needed)
       (,errpat # your catch pattern verbatim, e.g. [e fib] or [e _]
                ,;catch-body))))
# Local printer helper for lisp-style strings
(defn prin1-to-string [x]
  (slyk/slynk-describe-to-string x))

# Module-level state (consider if some should be per-mrepl instance)
(def history @[]) # Stores evaluation history entries
(def saved-objects @[]) # Stores objects saved globally
(def backreference-char "#") # Character for backreferences (Janet REPL might not use this like CL)

# Configuration (could be dynamic or configurable)
(def use-dedicated-output-stream nil) # (slyk/started-from-emacs?))
(def dedicated-output-port
  (if use-dedicated-output-stream
    (slyk-backend/run-implementation 'make-output-stream (fn [string] (slyk/send-to-emacs [:write-string string])))
    nil))
(def dedicated-output-buffering (if (= slyk/*communication-style* :spawn) :line nil))
(def globally-redirect-io (slyk/started-from-emacs?))
(def saved-global-streams {}) # To store original stdio streams

# MREPL Abstract Type
(def MREPL
  "Represents a Multi-REPL instance."
  @{:data [:remote-id # Integer: ID of the remote emacs client
           :mode # Keyword: :eval, :read, :drop, :busy, :teardown
           :pending-errors # Array: Stack of pending errors for the current evaluation
           :thread-id # Thread-ID where this mrepl is primarily active
           :input-stream # Custom input stream for this mrepl
           :history # Array: Per-mrepl history (if desired, else use global)
]
    :init
    (fn [remote-id]
      {:remote-id remote-id
       :mode :eval
       :pending-errors @[]
       :thread-id (fiber/current) # Created in its main thread
       :input-stream nil # Will be set by mrepl-initialize
       :history @[] # Per-mrepl history
})})

# Helper to get mrepl instance from channel-id (assuming channels are used)
(defn find-mrepl [channel-id]
  (let [channel (slyk/find-channel channel-id)]
    (unless (and channel (type channel)) # Or however channels store the mrepl object
      (error (string "No MREPL found for channel ID: " channel-id)))
    channel))

# MREPL methods converted to functions

(defn mrepl-print [mrepl stream]
  (string/format stream "#<MREPL remote-id:%d mode:%s>" (mrepl :remote-id) (mrepl :mode)))

(def mrepl-set-external-mode nil)

(defn mrepl-read-input [mrepl]
  "Handles requests for reading input from Emacs."
  (assert (not= (mrepl :mode) :read) "Cannot pipeline reads")
  (let [current-thread-id (fiber/current)]
    (if (and (= (mrepl :thread-id) current-thread-id) (= (mrepl :mode) :busy))
      # Reading for the current evaluation thread
      (do
        (slyk/flush-listener-streams mrepl)
        (mrepl-set-external-mode mrepl :read)
        (slyk/process-requests false)
        (def v (or (mrepl :pending-input) ""))
        (put mrepl :pending-input nil)
        v) # Process requests until input is received
      # Reading for a different thread (e.g. background)
      (do
        (put mrepl :mode :read) # Set mode to indicate waiting for input
        (let [prompt-string (string "Input for thread " current-thread-id "? \n")]
          (slyk/send-to-remote (mrepl :remote-id) [:read-string (mrepl :thread-id) current-thread-id prompt-string])
          (slyk/process-requests false)
          (def v (or (mrepl :pending-input) ""))
          (put mrepl :pending-input nil)
          v)))))

(defn mrepl-initialize [mrepl]
  "Initializes the MREPL instance, e.g., setting up streams."
  # Provide a read function so gray helpers can fetch input on demand
  (put mrepl :read-input (fn [] (mrepl-read-input mrepl)))
  (put mrepl :input-stream (slyk-gray/make-mrepl-input-stream mrepl))
  mrepl)

(defn mrepl-drop-unprocessed-events [mrepl]
  "Sets the MREPL mode to :drop, processes requests to clear them, then restores mode."
  (let [old-mode (mrepl :mode)]
    (put mrepl :mode :drop)
    (try
      (do
        (slyk/process-requests true) # Assuming this processes events for the current mrepl context
        (put mrepl :mode old-mode))
      ([err fib]
        (put mrepl :mode old-mode)
        (error err)))))

(defn mrepl-get-history-entry [mrepl idx]
  "Retrieves an entry from the MREPL's history by index."
  (let [mrepl-history (mrepl :history)]
    (assert (and (int? idx) (>= idx 0) (< idx (length mrepl-history)))
            (string "Bad history index: " idx))
    (get mrepl-history idx)))

(defn mrepl-get-object-from-history [mrepl hist-idx val-idx]
  "Retrieves a specific object or the whole entry from history."
  (let [entry (mrepl-get-history-entry mrepl hist-idx)]
    (if val-idx
      (do
        (assert (and (int? val-idx) (>= val-idx 0) (< val-idx (length entry)))
                (string "Bad value index: " val-idx " for history entry: " entry))
        (get entry val-idx))
      entry)))

(defn mrepl-make-results [mrepl eval-results]
  "Formats evaluation results for Emacs."
  (let [mrepl-history (mrepl :history)]
    (map (fn [v]
           [(slyk/slynk-pprint-for-emacs v) # Pretty-printed value
            (- (length mrepl-history) 1) # Index of the history entry (current last)
            (match (type v)
              :symbol (prin1-to-string v)
              :keyword (prin1-to-string v)
              :number (string v)
              :string (prin1-to-string v)
              :nil "nil"
              :boolean (if v "t" "nil")
              :array "#<array>"
              :tuple "#<tuple>"
              :struct "#<struct>"
              :table "#<table|struct>"
              :function "#<function>"
              :fiber "#<fiber>"
              :buffer (prin1-to-string (slyk/slynk-buffer-to-string-for-emacs v))
              _ "#<unknown>")])
         eval-results)))


(defn mrepl-send-prompt [mrepl &opt condition]
  "Sends a prompt to Emacs."
  (let [prompt-args
        [(slyk/*package* :name) # Current package name
         (slyk/*package* :nick) # Current package nickname for prompt
         (length (mrepl :pending-errors)) # Number of pending errors
         (length (mrepl :history)) # Current history length
         (if condition (prin1-to-string condition) nil) # Optional condition
]]
    (slyk/send-to-remote (mrepl :remote-id) (array/concat [:prompt] prompt-args)))
  (put mrepl :mode :eval))

(defn mrepl-eval-1 [mrepl string-to-eval]
  "Internal evaluation function for a single string."
  (slyk/with-slyk-interrupts # Handle SLYK interrupts
                             (slyk/with-listener-bindings mrepl # Setup listener context (stdin, stdout, etc.)

                                                          (do (var values @[])
                                                            (var forms (slyk-gray/read-forms-from-string string-to-eval))
                                                            (var i 0)
                                                            (var n (length forms))
                                                            (while (< i n)
                                                              (var form (forms i))
                                                              (try
                                                                (do
                                                                  (var result (eval form)) # EVALUATE THE FORM
                                                                  (array/push values result)
                                                                  (set i (+ i 1)))
                                                                ([err fib]
                                                                  (error (string "Evaluation error: " err)))))
                                                            values))))


(defn mrepl-eval [mrepl string-to-eval]
  "Evaluates a string in the MREPL context."
  (put mrepl :mode :busy)
  (var aborted nil)
  (var results nil)
  (var error-sent false)

  (try-catch-finally
    # Setup debugger hook for this evaluation
    (let [old-debugger-hook slyk/*debugger-hook*
          debugger-hook
          (fn [condition prev-hook]
            (do (set aborted condition) # Mark as aborted with the condition
              (if (and (> (length (mrepl :pending-errors)) 0)
                       (= condition (first (mrepl :pending-errors))))
                # If it's the same error as the one at the top of pending_errors,
                # it means we are unwinding from it, so call the old hook.
                (when old-debugger-hook (old-debugger-hook condition prev-hook))
                (do
                  (array/push (mrepl :pending-errors) condition)
                  (unless error-sent
                    (set error-sent true)
                    (mrepl-send-prompt mrepl condition)) # Send prompt with error
                  # Potentially allow user to handle/debug here via SLYK mechanisms
                  (when old-debugger-hook (old-debugger-hook condition prev-hook))
                  (array/pop (mrepl :pending-errors)) # Remove after handling
))))]
      (do
        (set slyk/*debugger-hook* debugger-hook)
        (set results (mrepl-eval-1 mrepl string-to-eval))
        (set aborted false) # If we reach here, evaluation was not aborted by an error
        (set slyk/*debugger-hook* old-debugger-hook) # Restore old hook
))
    ([err fib]
      # You may want to handle errors here, or just let them propagate
      (error err))

    (when (not= (mrepl :mode) :teardown)
      (slyk/flush-listener-streams mrepl) # Ensure all output is sent
      (slyk/saving-listener-bindings
        mrepl
        (if aborted
          (slyk/send-to-remote (mrepl :remote-id)
                               [:evaluation-aborted (prin1-to-string aborted)])
          (do
            (when results
              (array/push (mrepl :history) results)) # Add results to history
            (slyk/send-to-remote (mrepl :remote-id)
                                 [:write-values (mrepl-make-results mrepl results)])))
        (unless error-sent # if no error was sent during eval, send a normal prompt
          (mrepl-send-prompt mrepl))))))


(defn mrepl-set-external-mode [mrepl new-mode]
  "Sets the read mode for Emacs and updates MREPL's internal mode."
  (unless (= (mrepl :mode) new-mode)
    (slyk/send-to-remote (mrepl :remote-id) [:set-read-mode new-mode (mrepl :thread-id)]))
  (put mrepl :mode new-mode))


# Channel methods (RPC handlers)
# These are typically invoked by slyk-rpc when a message arrives for this mrepl's channel.

(defn mrepl-channel-inspect-object [mrepl hist-idx val-idx]
  "Handles :inspect-object RPC call."
  (slyk/with-listener-bindings mrepl
                               (let [obj (mrepl-get-object-from-history mrepl hist-idx val-idx)
                                     inspection-result (slyk/slynk-inspect obj)]
                                 (slyk/send-to-remote (mrepl :remote-id) [:inspect-object inspection-result]))))

(defn mrepl-channel-process [mrepl string-to-process]
  "Handles :process RPC call (evaluate or provide input)."
  (case (mrepl :mode)
    :eval (mrepl-eval mrepl string-to-process)
    :read (do (put mrepl :pending-input string-to-process) nil) # deliver input
    :drop nil # Do nothing if in :drop mode
    (error (string "Unknown MREPL mode for :process: " (mrepl :mode)))))

(defn mrepl-channel-teardown [mrepl]
  "Handles :teardown RPC call."
  (put mrepl :mode :teardown)
  (slyk-rpc/close-channel (slyk-rpc/find-channel-id-for-object mrepl))) # Assuming a way to get channel ID

(defn mrepl-channel-clear-history [mrepl]
  "Handles :clear-history RPC call."
  (slyk/saving-listener-bindings mrepl
                                 (put mrepl :history @[])
                                 (slyk/send-to-remote (mrepl :remote-id) [:clear-history])
                                 (mrepl-send-prompt mrepl)))

# SLYFUN definitions (functions exposed via RPC, not directly tied to an mrepl instance)

(slyk/defslyfun create-mrepl [remote-id]
                "Creates a new MREPL instance and returns its details."
                (let [mrepl (mrepl-initialize (MREPL remote-id))]
                  # Register mrepl with the channel system, assuming slyk-rpc manages this
                  # The channel ID would be associated with this mrepl instance.
                  # For now, let's assume the mrepl object itself might be stored in the channel.
                  (let [channel-id (slyk-rpc/register-channel-object mrepl)] # Hypothetical registration
                    (slyk/format-output mrepl "# SLYNET MREPL ~a (channel ~a) for remote ~a\n" slyk/*wire-version* channel-id remote-id)
                    (slyk/flush-listener-streams mrepl)
                    (mrepl-send-prompt mrepl)
                    [channel-id (mrepl :thread-id)]))) # Return channel ID and thread ID

(slyk/defslyfun globally-save-object [value]
                "Saves an object globally (accessible via backreferences, perhaps)."
                (array/push saved-objects value)
                (- (length saved-objects) 1)) # Return index of saved object

(slyk/defslyfun copy-to-repl-in-emacs [values &opt blurb pop?]
                "Sends values to Emacs to be copied into the REPL."
                (default blurb "Copied values:")
                (default pop? true)
                (slyk/slynk-eval-in-emacs
                  ~(sly-mrepl--copy-globally-saved-to-repl
                     (unquote (map identity values))
                     :before (unquote blurb)
                     :pop (unquote pop?)))
                true)

# Macro to simplify finding mrepl and setting context
(defmacro with-mrepl-context [[mrepl-sym channel-id-expr] & body]
  ~(let [,mrepl-sym (find-mrepl ,channel-id-expr)]
     (assert (not (nil? ,mrepl-sym)) "MREPL instance not found")
     (slyk/with-listener-bindings ,mrepl-sym
                                  ~;body)))

(let [a 1] (print (+ a 2))) # Example usage of with-mrepl-context

(slyk/defslyfun eval-for-mrepl [channel-id code-string]
                "Evaluates code string in the context of a specific MREPL."
                (with-mrepl-context [mrepl channel-id]
                  (mrepl-eval mrepl code-string))) # This will send results via mrepl-eval's logic

(slyk/defslyfun inspect-entry [channel-id hist-idx val-idx]
                "Inspects a history entry for a given MREPL."
                (with-mrepl-context [mrepl channel-id]
                  (mrepl-channel-inspect-object mrepl hist-idx val-idx)))

(slyk/defslyfun describe-entry [channel-id hist-idx val-idx]
                "Describes a history entry for a given MREPL."
                (with-mrepl-context [mrepl channel-id]
                  (let [obj (mrepl-get-object-from-history mrepl hist-idx val-idx)]
                    (slyk/slynk-describe-to-string obj))))

(slyk/defslyfun pprint-entry [channel-id hist-idx val-idx]
                "Pretty-prints a history entry for a given MREPL."
                (with-mrepl-context [mrepl channel-id]
                  (let [obj (mrepl-get-object-from-history mrepl hist-idx val-idx)]
                    (slyk/slynk-pprint [obj])))) # slynk-pprint likely sends to Emacs

(slyk/defslyfun sync-package-and-default-directory [channel-id package-name directory-name]
                "Synchronizes package and directory with Emacs."
                (with-mrepl-context [mrepl channel-id]
                  (slyk/set-package package-name)
                  (slyk/set-default-directory directory-name)
                  (mrepl-send-prompt mrepl))
                true)

(slyk/defslyfun guess-and-set-package [channel-id string]
                "Guesses and sets the package based on a string."
                (with-mrepl-context [mrepl channel-id]
                  (let [package-name (slyk-completion/guess-package string)]
                    (if package-name
                      (slyk/set-package package-name)
                      (error (string "Could not guess package from: " string))))
                  (mrepl-send-prompt mrepl))
                true)


# IO redirection setup functions (conceptual, adapt from gray.janet)
# These would typically set slyk/*standard-input*, slyk/*standard-output*, etc.
# to streams that communicate with Emacs via the mrepl instance.

(defn setup-mrepl-io-redirection [mrepl]
  "Sets up global IO redirection to the given MREPL's streams."
  (when globally-redirect-io
    (set (saved-global-streams :stdin) slyk/*standard-input*)
    (set (saved-global-streams :stdout) slyk/*standard-output*)
    (set (saved-global-streams :stderr) slyk/*standard-error*)

    (set slyk/*standard-input* (mrepl :input-stream))
    (set slyk/*standard-output* (slyk-gray/make-listener-output-stream mrepl :stdout))
    (set slyk/*standard-error* (slyk-gray/make-listener-output-stream mrepl :stderr))
    (when use-dedicated-output-stream
      (set slyk/*trace-output* dedicated-output-port)
      (set slyk/*debug-io* dedicated-output-port))))

(defn restore-mrepl-io-redirection []
  "Restores global IO to their original streams."
  (when globally-redirect-io
    (set slyk/*standard-input* (saved-global-streams :stdin))
    (set slyk/*standard-output* (saved-global-streams :stdout))
    (set slyk/*standard-error* (saved-global-streams :stderr))
    # Also restore trace/debug if they were changed
))


# Exports (ensure these match the intended public API)
(defn get-public-api [] @{:create-mrepl create-mrepl
                          :globally-save-object globally-save-object
                          :eval-for-mrepl eval-for-mrepl
                          :sync-package-and-default-directory sync-package-and-default-directory
                          :pprint-entry pprint-entry
                          :inspect-entry inspect-entry
                          :guess-and-set-package guess-and-set-package
                          :copy-to-repl-in-emacs copy-to-repl-in-emacs
                          :describe-entry describe-entry
                          # Expose channel methods if they are to be called directly by slyk-rpc dispatcher
                          :mrepl-channel-process mrepl-channel-process
                          :mrepl-channel-inspect-object mrepl-channel-inspect-object
                          :mrepl-channel-teardown mrepl-channel-teardown
                          :mrepl-channel-clear-history mrepl-channel-clear-history})

(def export-api (get-public-api))

# Example of how channel methods might be registered or looked up by slyk-rpc
# This is highly dependent on slyk-rpc's design.
# (slyk-rpc/register-channel-type :mrepl
#   {:process mrepl-channel-process
#    :inspect-object mrepl-channel-inspect-object
#    :teardown mrepl-channel-teardown
#    :clear-history mrepl-channel-clear-history
#    # ... other mrepl-specific RPC calls
#    })
