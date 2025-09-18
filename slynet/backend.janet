(print "Loading backend.janet...")

(import ./types)
(import ./infrastructure :as inf)

(defn eval-in-context [form ctx]
  (eval form))
# SLYNK Backend Interface for Janet
# Translates the Common Lisp slynk-backend.lisp to Janet


## (import ./gray)

(defn test-cd [dir]
  (os/cd dir))
#
# Configuration
#

# Debug flag - when true, don't [err fib]ors and show all frames
(def *debug-slynk-backend* false)

# Maximum length for printed representations of values
(def *max-print-length* 100)

# Maximum level for nested data structure printing
(def *max-print-level* 10)


# Custom error types for the backend
# ---------- small helpers ----------

(defn list-all-modules
  "Return an array of module names (as strings) for all currently loaded modules.
   Notes:
   - Uses (modules) if available (the canonical loader cache).
   - Filters keys to strings; callers can pass them to (require).
   - Stable across early-init (returns [] if registry not yet present)."
  []
  (def out @[])
  (try
    (do
      (def reg module/cache) # (modules) → table: name -> module
      (when (table? reg)
        (eachp [k v] reg
          # Many entries are proper module tables; some can be booleans or sentinels.
          # We don't over-filter: just stringify the key so (require name) works.
          (array/push out (string k)))))
    ([err _] nil))
  out)

# (optional) if you prefer a sorted, deterministic order:
# (array/sort out string/compare) ; then return it
(defmacro if-let
  "([sym expr] then &opt else) – bind, test non-nil, choose branch."
  [[sym expr] then &opt else]
  ~(let [,sym ,expr]
     (if ,sym
       ,then
       ,(if (empty? else) nil ~(do ,else)))))

# ---------- interface & implementation machinery ----------
# == slynet/backend.janet ==
# PATCH 2/4 — fix interface machinery

# ... keep earlier code ...

# Remove all macro-based interface/implementation registration in favor of register-implementation

# Remove definterface/defimplementation macros to avoid duplication/confusion.
# Use only (register-implementation) and plain defn for new backend features.
# == end/backend.janet ==

# (defmacro definterface
#   "Define a backend interface function.

# Example:
#   (definterface my-interface [arg1 arg2] \"Documentation for my interface.\"
#     (default-body ...))
# This macro defines a function that dispatches to the registered implementation,
# or falls back to a default implementation if provided.
#     If no implementation exists and no default is provided, an error is raised.
#     Parameters:
#     - name: The name of the interface function::type: string
#     - arglist: The argument list::type: list
#     - doc: Documentation string::type: string
#     - default-body: Optional default implementation"
#   [name arglist doc & default-body]
#   (var s (symbol name))

#   # bookkeeping --------------------------------------------------------------
#   (array/push *interface-functions* s)
#   (when (empty? default-body) # << correct direction
#     (array/push *unimplemented-interfaces* s))

# (defmacro defimplementation
#   "Register an implementation for an interface."
#   [name arglist & body]
#   (var s (symbol name))
#   # inside your macro expansion (quasiquoted)
#   ~(do
#      (def ,(symbol name) nil) # forward binding
#      (defn ,(symbol name) ,arglist
#        ,;body)
#      (try
#        ((eval 'slynet-register-impl-rt!) ',(symbol name) ,(symbol name) ,doc)
#        ([_ err] nil)))

#   (var idx nil)
#   (for i 0 (dec (length *unimplemented-interfaces*))
#     (when (= (get *unimplemented-interfaces* i) s)
#       (set idx i)
#       (break)))
#   (when idx (array/remove *unimplemented-interfaces* idx))
#   ~(put-in *implementations* [',s :implementation]
#            (fn ,arglist ,;body)))

# == slynet/backend.janet ==
# add to your backend module

# --- Internals ---------------------------------------------------------------

(defn- capture-doc-output
  "Return the printed `doc` for SYM as a string, or nil on failure.
   We redirect :out to a buffer so (doc) writes into it."
  [sym]
  (var out nil)
  # (try
  (do
    (set out (buffer/new 1024))
    (with-dyns [:out out]
      (doc* sym))
    (string/trim (string out)))
  # ([_ fib] nil)
)

# (defn sym-type
#   "Return the type of SYM as a keyword, e.g. :function, :macro, :variable, or nil."
#   [sym]
#   (when (symbol? sym)
#     (try
#       (let [val (eval sym)]
#         (cond
#           (function? val) :function
#           (macro? val) :macro
#           (var? val) :variable
#           :else nil))
#       ([err fib] nil))))

(defn sym-type
  "Return the documentation string for SYM of TYPE (:function, :macro, :variable),
   or nil if not found."
  [sym]
  (let [docstr (first (string/split "\n" (capture-doc-output sym)))]
    (cond
      (= docstr "macro") :macro
      (= docstr "function") :function
      (= docstr "variable") :variable
      (= docstr "cfunction") :cfunction
      :else nil)))


(defn- first-signature-line
  "From the full doc text, heuristically pick the first line that looks like
   a signature, e.g. \"(array/push arr x &opt at) -> arr\"."
  [docstr]
  (when (string? docstr)
    (each line (string/split docstr "\n")
      (when (and (string/has-prefix? line "(")
                 (string/find ")" line))
        (break line)))))

(defn- args-from-signature-line
  "Given a signature line like \"(ns/name a b &opt c) -> ret\",
   extract and return just the args as a string, e.g. \"(a b &opt c)\".
   If there are no args, returns \"()\"."
  [sigline]
  (when (string? sigline)
    (let [open (string/find "(" sigline)
          close (string/find ")" sigline (if open (+ open 1) 0))]
      (when (and open close (> close open))
        (let [inside (string/slice sigline (inc open) close)
              sp (string/find " " inside)]
          (if sp
            (let [args (string/trim (string/slice inside (inc sp) (length inside)))]
              (if (empty? args) "()" (string "(" args ")")))
            "()"))))))

# --- Public API --------------------------------------------------------------

(defn arglist
  "Return a human-readable argument list string for SYM,
   or nil if no function/macro signature can be found.
   Examples:
     (arglist 'array/push)  => \"(arr x &opt at)\"
     (arglist 'clock)       => \"()\" (if no args)
     (arglist 'not-a-fn)    => nil"
  [sym]
  (default sym (error "arglist: expected a symbol"))
  (let [docstr (capture-doc-output sym)
        sigline (first-signature-line docstr)
        args (args-from-signature-line sigline)]
    (or args
        (try
          (when (function? (eval sym)) "(?)")
          ([_ fib] nil)))))

(defn arglist-structured
  "Return a vector of tokens for the arglist, e.g.
     \"(a b &opt c &rest xs)\" → @[\"a\" \"b\" \"&opt\" \"c\" \"&rest\" \"xs\"]
   Useful if you want to post-process or pretty-print differently."
  [sym]
  (let [s (arglist sym)]
    (if (and s (>= (length s) 2))
      (let [body (string/slice s 1 (dec (length s)))]
        (if (empty? (string/trim body)) @[] (string/split body #"\s+")))
                                                          @[]))))))

# (Optional) if you want a single dispatch that returns either string or vector:
# (defn arglist* [sym &named {:structured false}]
#   (if structured (arglist-structured sym) (arglist sym)))


# (defmacro definterface
#   "Define an interface function for the backend to implement.

#    This macro defines a function that dispatches to the registered implementation,
#    or falls back to a default implementation if provided. If no implementation
#    exists and no default is provided, an error is raised.

#    Parameters:
#    - name: The name of the interface function
#    - args: The argument list
#    - doc-string: Documentation string
#    - default-body: Optional default implementation"
#   [name args doc-string & default-body]

#   (def fn-name (symbol name))

#   # Record this function
#   (array/push *interface-functions* fn-name)
#   (unless (empty? default-body)
#     (array/push *unimplemented-interfaces* fn-name))

#   ~(do
#      # Define the metadata
#      (put *implementations* ',fn-name @{:doc ,doc-string
#                                         :args ',args})

#      # Define the function that dispatches to implementation or default
#      (defn ,fn-name ,args
#        (if-let [impl (get-in *implementations* [',fn-name :implementation])]
#          (try
#            (impl ,;args)
#            ([err fib]
#              (if *debug-slynk-backend*
#                (error err)
#                (error (make-backend-error (string "Error in " ',fn-name) err)))))
#          ,(if (empty? default-body)
#             ~(error (make-implementation-error ',fn-name "No implementation provided"))
#             ~(do ,;default-body))))))

# (defmacro defimplementation
#   "Define an implementation for a backend interface function.

#    This registers a function as the implementation for a previously defined
#    interface. The implementation replaces any existing one.

#    Parameters:
#    - name: The name of the interface to implement
#    - args: The argument list (should match the interface)
#    - body: The implementation body"
#   [name args & body]
#   (def fn-name (symbol name))

#   # Remove from unimplemented list if present
#   (array/remove *unimplemented-interfaces* fn-name)

#   ~(put-in *implementations* [',fn-name :implementation]
#     (fn ,args ,;body)))

# Utility function for safe printing
(defn safe-princ-to-string
  "Safely convert a value to a string representation with limits.
   Prevents infinite recursion and excessive output."
  [value &opt max-length]
  (default max-length *max-print-length*)
  (try
    (do (def result (string/format "%j" value))
      (if (> (length result) max-length)
        (string (string/slice result 0 max-length) "...")
        result))
    ([err fib]
      "[Error printing value]")))


# --- Core Backend Interfaces ---



(defn gray-package-name []
  "Return a module name that contains the Gray stream symbols."
  nil)

(inf/defimpl 'gray-package-name gray-package-name)


# UTF-8 helpers
# (deftype octet @[0 255])
# (deftype octets @[octet])

(defn utf8-decode-aux
  "Helper function to decode the next N bytes starting from INDEX.
   Return the decoded char and the new index."
  [buffer index limit byte0 n]
  (var cp (- byte0 (if (= n 1) 0
                     (if (= n 2) 0xC0
                       (if (= n 3) 0xE0 0xF0)))))
  (var i index)

  (for j 1 n
    (when (>= i limit)
      (break))
    (def byte (buffer i))
    (++ i)
    (if (or (< byte 0x80) (>= byte 0xC0))
      (break)
      (set cp (+ (* cp 0x40) (- byte 0x80)))))

  [cp i])
# blshift
# function
# (blshift x & shifts)

# Returns the value of x bit shifted left by the sum of all values in shifts. x and each element in shift must be an integer.
(defn >>
  "Bitwise right shift operator.
   Shifts bits of X to the right by N positions.
   If N is negative, shifts left instead.
Example:
  (>> 8 2) => 2
  (>> 8 -2) => 32"
  [x n]
  (if (>= n 0)
    (blshift x (- n))
    (blshift x (+ n))))
(defn utf8-decode
  "Decode one character in BUFFER starting at INDEX.
   Return 2 values: the character and the new index."
  [buffer index limit]
  (when (>= index limit)
    (break [nil index]))

  (def byte0 (buffer index))
  (def i (+ index 1))

  (cond
    # 1-byte UTF-8 sequence
    (< byte0 0xC0)
    [byte0 i]

    # 2-byte UTF-8 sequence
    (< byte0 0xE0)
    (utf8-decode-aux buffer i limit byte0 2)

    # 3-byte UTF-8 sequence
    (< byte0 0xF0)
    (utf8-decode-aux buffer i limit byte0 3)

    # 4-byte UTF-8 sequence
    (< byte0 0xF8)
    (utf8-decode-aux buffer i limit byte0 4)

    # Invalid UTF-8 lead byte
    [byte0 i]))

(defn string-to-utf8
  "Convert a string to UTF-8 byte array."
  [string]
  (def result @"")
  (loop [i :range [0 (length string)]]
    (def c (string i))
    (cond
      # ASCII
      (< c 0x80)
      (buffer/push result c)

      # 2-byte sequence
      (< c 0x800)
      (do
        (buffer/push result (+ 0xC0 (>> c 6)))
        (buffer/push result (+ 0x80 (band c 0x3F))))

      # 3-byte sequence
      (< c 0x10000)
      (do
        (buffer/push result (+ 0xE0 (>> c 12)))
        (buffer/push result (+ 0x80 (band (>> c 6) 0x3F)))
        (buffer/push result (+ 0x80 (band c 0x3F))))

      # 4-byte sequence
      (do
        (buffer/push result (+ 0xF0 (>> c 18)))
        (buffer/push result (+ 0x80 (band (>> c 12) 0x3F)))
        (buffer/push result (+ 0x80 (band (>> c 6) 0x3F)))
        (buffer/push result (+ 0x80 (band c 0x3F))))))
  result)

(defn utf8-to-string
  "Convert a UTF-8 byte array to a string."
  [buffer]
  (def result @"")
  (var i 0)
  (def limit (length buffer))

  (while (< i limit)
    (def [cp new-i] (utf8-decode buffer i limit))
    (when (nil? cp) (break))
    (set i new-i)
    (buffer/push-string result (string/from-bytes cp)))

  result)

# String encoding/decoding utilities

(defn string-to-bytes
  "Convert a string to bytes in the current encoding."
  [string]
  # For now, just use UTF-8
  (string-to-utf8 string))

(defn bytes-to-string
  "Convert bytes to a string in the current encoding."
  [bytes]
  # For now, just use UTF-8
  (utf8-to-string bytes))

# Utility macros
(defmacro with-struct
  "Extract struct fields for easier access, similar to CL with-slots"
  [[prefix & names] obj & body]
  (def gobj (gensym ()))
  (def bindings
    (reduce (fn [acc name]
              (array/push acc name)
              (array/push acc ~(,prefix ,gobj ',name)))
            @[]
            names))
  ~(let [,gobj ,obj]
     (let ,bindings
       ,;body)))

(defmacro when-let
  "Combine when and let for a common pattern"
  [[var value] & body]
  ~(let [,var ,value]
     (when ,var
       ,;body)))

# --- Stream and IO Interfaces ---

# --- Stream and IO Interfaces ---

(defn stream-line-column [stream]
  "Return the column number at STREAM's position."
  0)
(inf/defimpl 'stream-line-column stream-line-column)

(defn stream-flush-output [stream]
  "Flush output on STREAM."
  nil)
(inf/defimpl 'stream-flush-output stream-flush-output)

(defn make-output-stream [write-string]
  "Return a new character output stream that calls WRITE-STRING.
   WRITE-STRING is called with a string and character position."
  (error "Not implemented"))
(inf/defimpl 'make-output-stream make-output-stream)

(defn make-input-stream [read-string]
  "Return a new character input stream that calls READ-STRING.
   READ-STRING is called with a character count and returns a string."
  (error "Not implemented"))
(inf/defimpl 'make-input-stream make-input-stream)

(defn make-fd-stream [fd external-format]
  "Create a character stream from a file descriptor."
  (error "Not implemented"))
(inf/defimpl 'make-fd-stream make-fd-stream)

# (definterface getpid
#   []
#   "Return the process ID of the running Janet instance"
#   (os/getpid))

(defn default-directory []
  "Return the current default pathname-directory."
  (os/cwd))
(inf/defimpl 'default-directory default-directory)

(defn set-default-directory [directory]
  "Set the current default pathname-directory."
  (os/cd directory))
(inf/defimpl 'set-default-directory set-default-directory)

# --- REPL and Reader Interfaces ---

(defn create-repl
  [opt io-input io-output &options]
  "Create a new REPL, optionally with I/O streams."
  (error "Not implemented"))
(inf/defimpl 'create-repl create-repl)

(defn eval-in-context
  [form context]
  "Evaluate FORM in CONTEXT."
  (eval form))
(inf/defimpl 'eval-in-context eval-in-context)

(defn call-with-compilation-hooks [func]
  "Call FUNC but intercept compiler conditions."
  (func))
(inf/defimpl 'call-with-compilation-hooks call-with-compilation-hooks)

(defn compile-string [string filename line column]
  "Compile STRING as if it appeared in a file."
  (compile string))
(inf/defimpl 'compile-string compile-string)

(defn compile-file [filename output-file load]
  "Compile FILENAME to OUTPUT-FILE and load if LOAD is true."
  (error "Not implemented"))
(inf/defimpl 'compile-file compile-file)

# --- Thread and concurrency interfaces ---

# == slynet/backend.janet ==
# ... your existing code & fixed definterface/defimplementation macros stay ...

# IMPORT the primitives (no gray here!)
(import ./primitives :as prim)

(defn make-lock [name]
  "Create a lock with NAME."
  (prim/make-lock name))
(inf/defimpl 'make-lock make-lock)

(defn with-lock [lock thunk]
  "Invoke (thunk) while holding LOCK."
  (prim/with-lock lock thunk))
(inf/defimpl 'with-lock with-lock)

# Optional: ergonomic macro re-exposed here (expands to primitives version)
(defmacro with-lock/do [lock & body]
  ~(prim/with-lock/do ,lock ,;body))
# (defmacro with-lock/do
#   "Expand to (with-lock lock (fn [] ...body...))."
#   [lock & body]
#   ~(with-lock ,lock (fn [] ,;body)))
# == end/backend.janet ==

# Stream interfaces exist BUT NO import of gray here.
(defn make-output-stream [write-string]
  "Return an output stream that calls WRITE-STRING."
  (error "Not implemented"))
(inf/defimpl 'make-output-stream make-output-stream)

(defn make-input-stream [read-string]
  "Return an input stream that calls READ-STRING."
  (error "Not implemented"))
(inf/defimpl 'make-input-stream make-input-stream)

(defn stream-flush-output [stream]
  "Flush output on STREAM."
  (error "Not implemented"))
(inf/defimpl 'stream-flush-output stream-flush-output)

(defn stream-line-column [stream]
  "Return column at STREAM position."
  0)
(inf/defimpl 'stream-line-column stream-line-column)

# ... rest of backend; keep export-api AT END, after all defs ...
# == end/backend.janet ==

(defn make-thread [name function &args]
  "Create a new thread with NAME that runs FUNCTION with ARGS."
  (error "Not implemented"))
(inf/defimpl 'make-thread make-thread)

# --- Source location interfaces ---

(defn find-source-location [symbol]
  "Return the source location of SYMBOL as (path line column) or nil."
  nil)
(inf/defimpl 'find-source-location find-source-location)

# --- Actual implementations for Janet ---

# == slynet/backend.janet ==
# PATCH A — lock backend: use ev/lock; drop the nonexistent ev/mutex

# BEFORE (causing error):
# (defimplementation "make-lock" [name]
#   @{:type :lock
#     :name name
#     :mutex (ev/mutex)})

# AFTER:
# == slynet/backend.janet ==
# PATCH F — ensure make-lock uses ev/lock and stores :lock

(defn getpid []
  (os/getpid))
(inf/defimpl 'getpid getpid)

(defn default-directory []
  (os/cwd))
(inf/defimpl 'default-directory default-directory)

(defn set-default-directory [directory]
  (os/cd directory))
(inf/defimpl 'set-default-directory set-default-directory)

# (defimplementation make-output-stream [write-string]
#   (gray/sly-output-stream write-string))

# (defimplementation make-input-stream [read-string]
#   (gray/sly-input-stream read-string))

# (defimplementation stream-flush-output [stream]
#   (gray/stream-finish-output stream))

# (defimplementation stream-line-column [stream]
#   (gray/stream-line-column stream))

(defn find-source-location [symbol]
  # Try to find the source location of a symbol
  # This is a challenging task in Janet without additional tooling
  # For now, return nil indicating unknown location
  nil)
(inf/defimpl 'find-source-location find-source-location)

# Additional essential backend implementations

(defn symbol-info
  "Return detailed info for SYM: type, value, docstring."
  [sym]
  (try
    (do
      (def s (if (symbol? sym) sym (symbol sym)))
      (def value (try (eval s) ([_ fib] :undefined)))
      (def type-name (if (not= value :undefined) (type value) :undefined))
      @{:name (string s)
        :type type-name
        :value (if (not= value :undefined) (string/format "%j" value) "undefined")
        :documentation (or (try (doc s) ([_ fib] nil)) "No documentation available")})
    ([err fib] @{:error (string "Error getting symbol info: " err)})))
(inf/defimpl 'symbol-info symbol-info)

(defn eval-for-emacs
  [string buffer-package id]
  "Evaluate STRING in the context of BUFFER-PACKAGE.
   Return a list of the form (:ok RESULT) or (:abort CONDITION)."
  (try
    (do
      (def form (parse string))
      (def result (eval form))
      [:ok result])
    ([err fib]
      [:abort (string "Evaluation error: " err)])))
(inf/defimpl 'eval-for-emacs eval-for-emacs)

(defn eval-in-context
  [form context id]
  "Evaluate FORM in the context of CONTEXT.
   Return a list of the form (:ok RESULT) or (:abort CONDITION)."
  (try
    (do
      (def result (eval form)))

    ([err fib]
      [:abort (string "Evaluation error: " err)])))
(inf/defimpl 'eval-in-context eval-in-context)
(inf/defimpl 'symbol-info symbol-info)

(defn system-info
  "Return basic system/environment info for diagnostics."
  []
  (let [env @{}]
    (eachp [k v] (os/environ)
      (put env k (string v)))
    @{:os (os/which)
      :arch (os/arch)
      :cwd (os/cwd)
      :env env
      :janet-version (string janet/version)}))

(inf/defimpl 'system-info system-info)

(defn list-modules
  "Return a list of loaded module names."
  []
  (try
    (do
      (def modules @[])
      (each name (keys module/cache)
        (when (string? name)
          (array/push modules name)))
      modules)
    ([err fib] [:error (string "Error listing modules: " err)])))

(inf/defimpl 'list-modules list-modules)
# --- Further backend stubs ---

(defn list-directory
  "List files and directories at PATH. Returns array of names."
  [path]
  (try
    (os/dir path)
    ([err fib] [:error (string "Error listing directory: " err)])))

(inf/defimpl 'list-directory list-directory)

(defn file-exists?
  "Return true if PATH exists and is a file."
  [path]
  (try
    (os/stat path)
    ([err fib] false)))

(inf/defimpl 'file-exists? file-exists?)

(defn directory-exists?
  "Return true if PATH exists and is a directory."
  [path]
  (try
    (os/stat path)
    ([err fib] false)))

(inf/defimpl 'directory-exists? directory-exists?)

(defn read-file
  "Read the contents of PATH as a string."
  [path]
  (try
    (file/lines path)
    ([err fib] [:error (string "Error reading file: " err)])))

(inf/defimpl 'read-file read-file)

(defn write-file
  "Write STRING to PATH. Returns true on success."
  [path string]
  (try
    (do (file/write path string) true)
    ([err fib] [:error (string "Error writing file: " err)])))

(inf/defimpl 'write-file write-file)
# [:ok result])

# --- Thread and concurrency interfaces ---

(defn create-repl
  [target &opt create-options]
  "Create a new REPL in TARGET using CREATE-OPTIONS."
  (default create-options @{})
  # Create a basic REPL environment
  @{:target target
    :env (table/clone (fiber/getenv (fiber/current)))
    :history @[]
    :options create-options})
(inf/defimpl 'create-repl create-repl)

(defn current-thread-id []
  "Return the ID of the current thread."
  (identity (fiber/current)))
(inf/defimpl 'current-thread-id current-thread-id)

(defn thread-name [thread]
  "Return the name of THREAD."
  (string "Janet-Thread-" thread))
(inf/defimpl 'thread-name thread-name)

(defn interactive-eval [string]
  "Evaluate STRING interactively."
  (try
    (do (def form (parse string))
      (def result (eval form))
      [:ok result])
    ([err fib]
      [:abort (string "Interactive evaluation error: " err)])))
(inf/defimpl 'interactive-eval interactive-eval)

# (defn interactive-eval
#   [string]
#   (try
#     (do (def form (parse string))
#       (def result (eval form))
#       [:ok result])
#     ([err fib]
#       [:abort (string "Interactive evaluation error: " err)])))

(defn describe-symbol [symbol-name]
  "Return a property list with information about SYMBOL-NAME."
  (try
    (do
      (def sym (if (symbol? symbol-name)
                 symbol-name
                 (symbol symbol-name)))
      (def value (or (try (eval sym) ([_ fib] nil)) :undefined))
      (def type-name (if (not= value :undefined)
                       (type value)
                       :undefined))
      @{:name (string sym)
        :type type-name
        :value (if (not= value :undefined)
                 (string/format "%j" value)
                 "undefined")
        :documentation (or (try (doc sym) ([_ fib] nil)) "No documentation available")})
    ([err fib]
      @{:error (string "Error describing symbol: " err)})))
(inf/defimpl 'describe-symbol describe-symbol)

# (defimplementation describe-symbol
#   [symbol-name]
#   (try
#     (do
#       (def sym (if (symbol? symbol-name)
#                  symbol-name
#                  (symbol symbol-name)))

#       (def value (or (try (eval sym) ([_ fib] nil)) :undefined))
#       (def type-name (if (not= value :undefined)
#                        (type value)
#                        :undefined))

#       # Return a description
#       @{:name (string sym)
#         :type type-name
#         :value (if (not= value :undefined)
#                  (string/format "%j" value)
#                  "undefined")
#         :documentation (or (try (doc sym) ([_ fib] nil)) "No documentation available")})
#     ([err fib]
#       @{:error (string "Error describing symbol: " err)})))

# (defn list-all-modules
#   []
#   (try
#     (do
#       (def modules @[])
#       (each name (os/modules)
#         (when (string? name)
#           (array/push modules name)))
#       modules)
#     ([err fib]
#       [:error (string "Error listing modules: " err)])))

(defn documentation
  [symbol kind]
  "Return the documentation string for SYMBOL of KIND (:function, :variable, etc.), or nil."
  (default kind :function)
  (try
    (do
      (def sym (if (symbol? symbol) symbol (symbol symbol)))
      (def docstr (capture-doc-output sym))
      docstr)
    ([err fib] nil)))

(defn arglist [function-name]
  "Return the argument list of FUNCTION-NAME."
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
            # No metadata available
            ["&" "args"]))
        # Not a function
        [:error (string function-name " is not a function")]))
    ([err fib]
      [:error (string "Error getting arglist: " err)])))
(inf/defimpl 'arglist arglist)

# (defimplementation arglist
#   [function-name]
#   (try
#     (do
#       (def func (if (function? function-name) function-name (eval function-name)))
#       (if (function? func)
#         (let [meta (table/getproto func)]
#           (if meta
#             # Try to get the arglist from the prototype's :arg-list key
#             (if-let [args (meta :arg-list)]
#               args
#               # Otherwise return generic info
#               ["&" "args"])
#             # No metadata available
#             ["&" "args"]))
#         # Not a function
#         [:error (string function-name " is not a function")]))
#     ([err fib]
#       [:error (string "Error getting arglist: " err)])))

(defn frame-locals [index]
  "Return the local variables for the frame at INDEX."
  (try
    (do
      (def fiber (fiber/current))
      (def locals @[])
      (var frame-idx 0)
      # Walk the stacktrace
      (each frame (debug/stacktrace fiber)
        (when (= frame-idx index)
          (each v (debug/stack fiber index)
            (array/push locals v))
          (break))
        (++ frame-idx))
      # Return the locals
      locals)
    ([err fib]
      [:error (string "Error getting frame locals: " err)])))
(inf/defimpl 'frame-locals frame-locals)

# (defimplementation frame-locals
#   [index]
#   (try
#     (do
#       (def fiber (fiber/current))
#       (def locals @[])
#       (var frame-idx 0)

#       # Walk the stacktrace
#       (each frame (debug/stacktrace fiber)
#         (when (= frame-idx index)
#           (each v (debug/stack fiber index)
#             (array/push locals v))
#           (break))
#         (++ frame-idx))

#       # Return the locals
#       locals)
#     ([err fib]
#       [:error (string "Error getting frame locals: " err)])))

# Create a function that implements various interfaces
# == slynet/backend.janet ==
# PATCH E — remove varargs function `fn [& args]`; keep a simple map loader

# BEFORE:
# (defn create-backend-implementation
#   "Create a backend implementation with a set of function implementations."
#   [impl-map]
#   (each key (keys impl-map)
#     (when-let [impl (get impl-map key)]
#       (defimplementation (key) (fn [& args] (apply impl args))))))

# AFTER (no varargs at runtime; just register exact fns you pass in):
# (defn create-backend-implementation
#   "Register exact implementations from a map: {sym -> function}."
#   [impl-map]
#   (each k (keys impl-map)
#     (when-let [impl (get impl-map k)]
#       (put-in *implementations* [k :implementation] impl))))
# == end/backend.janet ==
# == slynet/backend.janet ==
# PATCH D — optional user-facing convenience macro (ok to keep or skip)


# Module documentation
(setdyn :doc "Backend interface definitions for SLYNK Janet")
(defn initialize
  "Initialize the backend environment with optional configuration.
  This resets internal state and loads any necessary resources."
  [&opt options]
  (default options @{})

  # Reset warning tracker
  (let [unimplemented (inf/list-unimplemented-interfaces)]

    # Warn about missing implementations (unless suppressed)
    (unless (or (empty? unimplemented) (options :suppress-warnings))
      (eprintf "Warning: The following backend interfaces are unimplemented:")
      (each iface unimplemented
        (eprintf "  - %s" (string iface)))
      (eprintf "Some features may not work correctly without these implementations.")))

  # Report initialization
  # (unless (options :quiet)
  #   (eprintf "Backend initialized with %d implemented interfaces (of %d total)."
  #            (- (length *interface-functions*) (length *unimplemented-interfaces*))
  #            (length *interface-functions*)))

  true)

# Export public API
(def export-api
  @{:*debug-slynk-backend* *debug-slynk-backend*
    :*max-print-length* *max-print-length*
    :system-info system-info
    :symbol-info symbol-info
    :documentation documentation
    :list-modules list-modules
    :initialize initialize
    :utf8-decode utf8-decode
    :utf8-decode-aux utf8-decode-aux
    :string-to-utf8 string-to-utf8
    :set-default-directory 'set-default-directory
    :utf8-to-string utf8-to-string
    :string-to-bytes string-to-bytes
    :bytes-to-string bytes-to-string
    :make-lock 'make-lock
    :with-lock 'with-lock
    :getpid 'getpid
    :default-directory 'default-directory
    :make-output-stream 'make-output-stream
    :make-input-stream 'make-input-stream
    :stream-flush-output 'stream-flush-output
    :find-source-location 'find-source-location
    :eval-for-emacs 'eval-for-emacs
    :eval-in-context 'eval-in-context
    :create-repl 'create-repl
    :current-thread-id 'current-thread-id
    :thread-name 'thread-name
    :interactive-eval 'interactive-eval
    :describe-symbol 'describe-symbol
    :list-all-modules list-all-modules
    :arglist 'arglist
    :>> >>
    :frame-locals 'frame-locals})
