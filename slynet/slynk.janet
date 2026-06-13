# SLYNK core for Janet
# Translated from slynk.lisp to idiomatic Janet
# Core server functionality for the SLYNK protocol

(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE"))
  (print "Loading SLYNK core module...slynk\n"))
# Import necessary modules
(import ./backend)
(import ./infrastructure :as inf)
(import ./rpc)
(import ./gray)
(import ./print-for-emacs :as print-for-emacs)
(import ./xref)
(import ./source_index :as source-index)
(import ./completion :as completion)

(var *standard-input* (dyn :in))
(var *standard-output* (dyn :out))
(var *standard-error* (dyn :err))
(var *trace-output* nil)
#
# Constants and configuration
#

(def base-repl-env (curenv))

(def cl-package :core)
# Current package context for printing/prompt
(var *package* @{:name "core" :nick "core"})
(comment "Wire protocol version alias for convenience")
(var *wire-version* rpc/*wire-protocol-version*)
(def +keyword-package+ :keyword)

# Network configuration
(def default-server-port 4005)

# Debug settings
(var *slynk-debug-p* true)

# Emacs connection identifier
(def *m-x-sly-from-emacs* nil)

(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "1")) #
# Connection and server state
#

# Active connections map (id -> connection)
(var *connections* @{})
(var *channels* @{})
# Active server instance
(var *server* nil)

# Current I/O package
(var *io-package* nil)

# Current Emacs I/O stream
(var *emacs-io* nil)

# Exposed IO stream vars for contrib code (conceptual)
(var *standard-input* nil)
(var *standard-output* nil)
(var *standard-error* nil)
(var *trace-output* nil)
(var *debug-io* nil)

#
(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "2")) #
# Default preferences and settings
#

# Message prefix for echo area
(def *echo-area-prefix* "[SLYNET] ")

# Communication style (spawn, stream, etc.)
(def *communication-style* :spawn)

# Current debugger hook function
(var *debugger-hook-function* nil)
(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "3")) #

# Default bindings for worker threads
(def *default-worker-thread-bindings*
  @{:*print-pretty* true
    :*print-level* nil
    :*print-length* nil})
(var channel-counter 0)

(defn make-channel [&opt thread name]
  (set channel-counter (+ channel-counter 1))
  (let [c {:id channel-counter
           :thread (if thread thread nil)
           :name (if name name nil)}]
    (put *channels* channel-counter c)
    c))

(defn find-channel [id]
  (get *channels* id))

(defn get-connection [id]
  (get *connections* id))

# Helpers for connection metadata ------------------------------------------------
(defn- first-active-connection []
  (var active nil)
  (each id (keys *connections*)
    (when (nil? active)
      (let [candidate (get *connections* id)]
        (when (table? candidate)
          (set active candidate)))))
  active)

(defn- current-connection []
  (if (and (table? *emacs-io*) (*emacs-io* :id))
    *emacs-io*
    (first-active-connection)))

(defn- ensure-connection-repl-env [connection]
  (let [existing (and (table? connection) (connection :repl-env))]
    (if existing
      existing
      (let [env (table/setproto @{} base-repl-env)]
        (when (table? connection)
          (put connection :repl-env env))
        env))))

(defn- collect-features []
  @[:janet :slynet])

(defn- collect-encodings []
  @[:coding-systems @["utf-8-unix" "iso-latin-1-unix"]])

(defn- collect-machine-info []
  (let [hostname (or (os/getenv "HOSTNAME") "unknown")
        arch (or (os/getenv "PROCESSOR_ARCHITECTURE")
                 (os/getenv "HOSTTYPE")
                 "unknown")
        platform (or (os/getenv "OSTYPE") (os/getenv "OS") "unknown")]
    @[:instance (string hostname)
      :type (string arch)
      :version (string platform)]))

(defn- collect-lisp-implementation []
  (let [program (or (dyn :executable) "janet")
        version (string janet/version)
        build (string janet/build)]
    @[:type "Janet"
      :name "Janet"
      :version (string/join [version " [" build "]"])
      :program (string program)]))

(defn- package-prompt []
  (let [nick (or (*package* :nick) (*package* :name) "core")]
    (string nick)))

(defn build-connection-info []
  (let [conn (current-connection)
        style (or (and (table? conn) (conn :style)) *communication-style*)
        pkg-name (or (*package* :name) "core")]
    @[:pid (os/getpid)
      :style (or style :spawn)
      :encoding (collect-encodings)
      :lisp-implementation (collect-lisp-implementation)
      :machine (collect-machine-info)
      :features (collect-features)
      :modules @{}
      :package @[:name (string pkg-name) :prompt (package-prompt)]
      :version rpc/*wire-protocol-version*]))

(defn connection-info []
  (build-connection-info))

(defn ping [tag]
  tag)

(defn set-package [pkg]
  (cond
    (nil? pkg) (set-package "core")
    (symbol? pkg) (set-package (string pkg))
    (string? pkg) (do (put *package* :name pkg) (put *package* :nick pkg) *package*)
    (keyword? pkg) (let [name (string pkg)]
                    (set-package (string/slice name 1 (length name))))
    (table? pkg) (do (put *package* :name (or (pkg :name) "core"))
                   (put *package* :nick (or (pkg :nick) (*package* :name)))
                   *package*)
    (*package*)))

(defn set-package-rpc [package-name]
  (let [pkg (set-package package-name)
        prompt (package-prompt)
        package-plist @[:name (pkg :name) :nick (pkg :nick) :prompt prompt]
        conn (current-connection)]
    (when (table? conn)
      (put conn :package pkg)
      (put conn :prompt prompt))
    @[:package package-plist
      :prompt prompt]))

(defn- parse-single-form [form-or-string]
  (cond
    (string? form-or-string)
    (let [forms (gray/read-forms-from-string form-or-string)]
      (if (pos? (length forms)) (forms 0) nil))
    :else form-or-string))

(defn interactive-eval-region [code]
  (default code "")
  (let [forms (gray/read-forms-from-string code)
        outputs @[]]
    (each form forms
      (let [value (eval form)]
        (array/push outputs (print-for-emacs/prin1-to-string-for-emacs value *package*))))
    @[:values outputs]))

(defn pprint-eval [code]
  (default code "")
  (let [forms (gray/read-forms-from-string code)]
    (if (empty? forms)
      ""
      (do
        (var last-value nil)
        (each form forms
          (set last-value (eval form)))
        (print-for-emacs/prin1-to-string-for-emacs last-value *package*)))))

(defn value-for-editing [form]
  (let [sym (parse-single-form form)]
    (unless (symbol? sym)
      (error "value-for-editing: argument must resolve to a symbol"))
    (let [conn (current-connection)
          env (ensure-connection-repl-env conn)
          sentinel (gensym)
          binding (if (table? env) (get env sym sentinel) sentinel)
          value (cond
                  (= binding sentinel) (eval sym)
                  (and (table? binding) (not= (binding :value ::missing) ::missing)) (binding :value)
                  :else binding)]
      (print-for-emacs/prin1-to-string-for-emacs value *package*))))

(defn commit-edited-value [form new-value]
  (let [sym (parse-single-form form)]
    (unless (symbol? sym)
      (error "commit-edited-value: argument must resolve to a symbol"))
    (let [new-form (parse-single-form new-value)
          value (if (nil? new-form) nil (eval new-form))
          conn (current-connection)
          env (ensure-connection-repl-env conn)
          sentinel (gensym)
          binding (if (table? env) (get env sym sentinel) sentinel)]
      (cond
        (and (table? binding) (not= (binding :value ::missing) ::missing)) (put binding :value value)
        (not= binding sentinel) (put env sym value)
        (table? env) (put env sym value))
      (print-for-emacs/prin1-to-string-for-emacs value *package*))))

(defn- push-package-name [packages seen name nicknames include-nicknames?]
  (when name
    (let [label (string name)]
      (unless (get seen label)
        (put seen label true)
        (def entry @[label])
        (when (and include-nicknames? (array? nicknames))
          (each nick nicknames
            (when nick (array/push entry (string nick)))))
        (array/push packages entry)))))

(defn list-all-package-names [&opt include-nicknames?]
  (default include-nicknames? false)
  (def packages @[])
  (def seen @{})
  (push-package-name packages seen "core" nil include-nicknames?)
  (push-package-name packages seen "keyword" nil include-nicknames?)
  (push-package-name packages seen "slynet" nil include-nicknames?)
  (sorted packages (fn [a b] (< (a 0) (b 0)))))

(defn simple-completions [prefix package]
  (let [pref (if prefix (string prefix) "")
        pkg (if (string? package) package (or (*package* :name) "core"))]
    (completion/simple-completions pref pkg)))

(defn flex-completions [pattern package]
  (let [pat (if pattern (string pattern) "")
        pkg (if (string? package) package (or (*package* :name) "core"))]
    (completion/flex-completions pat pkg)))


(var *eval-source-map-counter* 0)
(var *eval-source-maps* @{})
(var *function-metadata-registry* @{})
(var *instrumentation-event-counter* 0)
(var *instrumentation-events* @[])

(defn- normalize-runtime-name [name]
  (cond
    (symbol? name) (string name)
    (keyword? name) (string/slice (string name) 1)
    :else (string name)))

(defn- source-snippet [code]
  (let [text (string code)
        lines (string/split "\n" text)]
    (if (> (length lines) 0)
      (string/trim (lines 0))
      "")))

(defn- register-eval-source-map! [code path line column]
  (++ *eval-source-map-counter*)
  (def eval-id (string "eval-source-" *eval-source-map-counter*))
  (def context @[:eval-id eval-id
                 :path path
                 :line line
                 :column column
                 :snippet (source-snippet code)
                 :source-aware-eval true
                 :source-map-kind :source-aware-eval
                 :runtime-instrumentation :source-aware-eval
                 :support-class :workaround
                 :stable-native-source-map false
                 :source-index-fallback true])
  (put *eval-source-maps* eval-id context)
  context)

(defn lookup-eval-source-map [eval-id]
  (let [id (string eval-id)
        context (get *eval-source-maps* id)]
    (if context
      context
      @[:eval-id id
        :status :missing
        :support-class :workaround
        :stable-native-source-map false])))

(defn register-function-metadata [name arglist &opt doc source]
  (default doc "")
  (default source :user)
  (def key (normalize-runtime-name name))
  (def record @[:name key
                :arglist arglist
                :documentation (string doc)
                :source :metadata-registry
                :origin source
                :support-class :workaround
                :native-janet-metadata false
                :cl-arglist-equivalent false])
  (put *function-metadata-registry* key record)
  record)

(defn function-metadata [name]
  (def key (normalize-runtime-name name))
  (or (get *function-metadata-registry* key)
      @[:name key
        :arglist "(?)"
        :documentation ""
        :source :computed-fallback
        :support-class :workaround
        :native-janet-metadata false
        :cl-arglist-equivalent false]))

(defn list-function-metadata []
  (def records @[])
  (eachp [_ record] *function-metadata-registry*
    (array/push records record))
  records)

(defn record-instrumentation-event [name phase &opt payload]
  (default payload nil)
  (++ *instrumentation-event-counter*)
  (def event @[:id *instrumentation-event-counter*
               :status :recorded
               :name (normalize-runtime-name name)
               :phase phase
               :payload payload
               :hook-kind :slynet-wrapper
               :support-class :workaround
               :native-instrumentation-hook false])
  (array/push *instrumentation-events* event)
  event)

(defn list-instrumentation-events []
  *instrumentation-events*)

(defn clear-instrumentation-events []
  (array/clear *instrumentation-events*)
  (set *instrumentation-event-counter* 0)
  @[:status :cleared :support-class :workaround])

(defn debugger-control-capabilities []
  @[:support-class :pending-design
    :native-resumable-debugger false
    :operations @[:step :next :out :continue]
    :workaround :cooperative-checkpoints
    :uses-janet-debug-primitives true
    :cl-debugger-control-equivalent false])

(defn debugger-control-action [operation &opt frame-index]
  (default frame-index nil)
  @[:status :unsupported
    :operation operation
    :frame-index frame-index
    :support-class :pending-design
    :native-resumable-debugger false
    :cl-debugger-control-equivalent false
    :reason "Janet exposes debug primitives, but SLYNET does not yet own a resumable debug session API."])


(defn source-aware-eval [code path line column]
  (default code "")
  (default path "<buffer>")
  (default line 1)
  (default column 0)
  (let [forms (gray/read-forms-from-string code)
        outputs @[]
        source-context (register-eval-source-map! code path line column)]
    (each form forms
      (array/push outputs
                  (print-for-emacs/prin1-to-string-for-emacs (eval form) *package*)))
    @[:status :ok
      :values outputs
      :source-context source-context]))

(var *debugger-state* @{:active false :condition nil :condition-record nil :condition-type nil :thread nil :restarts @[] :frames @[] :level 0})

(defn list-restart-scopes []
  (let [state *debugger-state*
        restarts (if (and (table? state) (array? (state :restarts)))
                   (state :restarts)
                   @[])
        scopes @[]]
    (var index 0)
    (each restart restarts
      (array/push scopes
                  (array/concat @[:scope-id (string "restart-scope-" index)
                                  :index index]
                                restart))
      (++ index))
    scopes))




(var *restart-scope-counter* 0)
(var *active-restart-scopes* @[])

(defn- restart-scope-record [restart-name callable safety explanation]
  (++ *restart-scope-counter*)
  @[:id (string "restart-scope-" *restart-scope-counter*)
    :label (case restart-name
             :continue-as-nil "Continue as nil"
             :retry "Retry retained thunk"
             :abort-to-repl "Abort to REPL"
             (string restart-name))
    :restart restart-name
    :class :synthetic
    :safety-level safety
    :callable callable
    :support-class :emulated
    :cl-restart-equivalent false
    :explanation explanation])

(defn- eval-forms-to-strings [code]
  (let [forms (gray/read-forms-from-string code)
        outputs @[]]
    (each form forms
      (array/push outputs
                  (print-for-emacs/prin1-to-string-for-emacs (eval form) *package*)))
    outputs))

(defn invoke-synthetic-restart [restart-name]
  @[:status :unsupported
    :restart restart-name
    :support-class :unsupported
    :callable false
    :unsupported-reason "No active SLYNET-owned instrumented restart scope is available for this restart."])

(defn instrumented-eval-with-restarts [code requested-restart &opt retry-code]
  (default code "")
  (default requested-restart :abort-to-repl)
  (default retry-code code)
  (let [scope (restart-scope-record requested-restart true :safe "Synthetic restart owned by a SLYNET instrumented evaluation wrapper.")]
    (array/push *active-restart-scopes* scope)
    (try
      (let [values (eval-forms-to-strings code)]
        @[:status :ok
          :values values
          :scope scope
          :support-class :emulated
          :cl-restart-equivalent false])
      ([err fib]
        (case requested-restart
          :continue-as-nil
          @[:status :continued
            :restart :continue-as-nil
            :value "nil"
            :scope scope
            :support-class :emulated
            :cl-restart-equivalent false]

          :retry
          (let [values (eval-forms-to-strings retry-code)]
            @[:status :retried
              :restart :retry
              :values values
              :scope scope
              :support-class :emulated
              :cl-restart-equivalent false])

          :abort-to-repl
          @[:status :aborted
            :restart :abort-to-repl
            :scope scope
            :support-class :emulated
            :cl-restart-equivalent false]

          @[:status :unsupported
            :restart requested-restart
            :scope scope
            :support-class :unsupported
            :callable false
            :unsupported-reason "Requested restart is not implemented by this instrumented wrapper."])))))

(defn interrupt-execution-unit [unit-id]
  @[:status :requested
    :unit-id unit-id
    :cooperative true
    :thread-model :slynet-execution-unit
    :support-class :emulated
    :cl-thread-interrupt-equivalent false])

(defn debugger-step-checkpoint [frame-index]
  @[:status :pending
    :frame-index frame-index
    :support-class :emulated
    :checkpoint-kind :cooperative-step
    :cl-step-equivalent false])

(defn- register-core-implementations! []
  (inf/defimpl 'ping ping)
  (inf/defimpl 'connection-info connection-info)
  (inf/defimpl 'set-package set-package-rpc)
  (inf/defimpl 'interactive-eval-region interactive-eval-region)
  (inf/defimpl 'pprint-eval pprint-eval)
  (inf/defimpl 'value-for-editing value-for-editing)
  (inf/defimpl 'commit-edited-value commit-edited-value)
  (inf/defimpl 'list-all-package-names list-all-package-names)
  (inf/defimpl 'simple-completions simple-completions)
  (inf/defimpl 'flex-completions flex-completions)
  (inf/defimpl 'source-aware-eval source-aware-eval)
  (inf/defimpl 'lookup-eval-source-map lookup-eval-source-map)
  (inf/defimpl 'register-function-metadata register-function-metadata)
  (inf/defimpl 'function-metadata function-metadata)
  (inf/defimpl 'list-function-metadata list-function-metadata)
  (inf/defimpl 'record-instrumentation-event record-instrumentation-event)
  (inf/defimpl 'list-instrumentation-events list-instrumentation-events)
  (inf/defimpl 'clear-instrumentation-events clear-instrumentation-events)
  (inf/defimpl 'debugger-control-capabilities debugger-control-capabilities)
  (inf/defimpl 'debugger-control-action debugger-control-action)
  (inf/defimpl 'list-restart-scopes list-restart-scopes)
  (inf/defimpl 'instrumented-eval-with-restarts instrumented-eval-with-restarts)
  (inf/defimpl 'invoke-synthetic-restart invoke-synthetic-restart)
  (inf/defimpl 'interrupt-execution-unit interrupt-execution-unit)
  (inf/defimpl 'debugger-step-checkpoint debugger-step-checkpoint)
)


(defn- callable-symbol [thing]
  (cond
    (symbol? thing) thing
    (string? thing) (parse-single-form thing)
    :else nil))

(defn- callable-doc [sym]
  (try
    (let [out (buffer/new 1024)]
      (with-dyns [:out out]
        (doc* sym))
      (string/trim (string out)))
    ([_ _] nil)))

(defn- callable-arglist [sym]
  (let [docstr (callable-doc sym)]
    (if (string? docstr)
      (let [sigline (first (filter (fn [line]
                                     (and (string/has-prefix? line "(")
                                          (string/find ")" line)))
                                   (string/split docstr "\n")))]
        (if sigline
          (let [close (string/find ")" sigline)
                body (if close (string/slice sigline 1 close) nil)
                space (and body (string/find " " body))]
            (if (and body space)
              (string "(" (string/trim (string/slice body (inc space))) ")")
              "()"))
          "(?)"))
      "(?)")))

(defn arglist-rpc [thing]
  (let [sym (callable-symbol thing)]
    (unless (symbol? sym)
      (error "arglist: expected function symbol or parseable string"))
    (callable-arglist sym)))


(defn macro? [value]
  false)
(defn operator-arglist-rpc [operator-name &opt package]
  (arglist-rpc operator-name))

(defn describe-function-rpc [thing]
  (let [sym (callable-symbol thing)]
    (unless (symbol? sym)
      (error "describe-function: expected function symbol or parseable string"))
    (let [docstr (or (callable-doc sym) "")
          argstr (callable-arglist sym)
          value (try (eval sym) ([_ _] nil))
          kind (cond
                 (macro? value) :macro
                 (function? value) :function
                 :else nil)]
      @[:name (string sym)
        :type kind
        :arglist argstr
        :documentation docstr
        :package (or (*package* :name) "core")])))


(defn describe-function-rpc-v2 [thing]
  (let [sym (callable-symbol thing)]
    (unless (symbol? sym)
      (error "describe-function: expected function symbol or parseable string"))
    (let [docstr (or (callable-doc sym) "")
          argstr (callable-arglist sym)
          head (and (> (length docstr) 0) (first (string/split docstr "\n")))
          value (try (eval sym) ([_ _] nil))
          kind (cond
                 (= head "macro") :macro
                 (= head "function") :function
                 (= head "cfunction") :function
                 (function? value) :function
                 :else nil)]
      @[:name (string sym)
        :type kind
        :arglist argstr
        :documentation docstr
        :package (or (*package* :name) "core")])))

(inf/defimpl 'describe-function describe-function-rpc-v2)
(inf/slynet-sync-rpc-registries!)

(inf/defimpl 'arglist arglist-rpc)
(inf/defimpl 'operator-arglist operator-arglist-rpc)
(inf/defimpl 'describe-function describe-function-rpc)
(inf/slynet-sync-rpc-registries!)
(defn ensure-core-implementations! []
  (when (nil? (inf/get-implementation 'ping))
    (register-core-implementations!)
    (inf/slynet-sync-rpc-registries!))
  true)


(defn arglist-rpc-v2 [thing]
  (let [sym (callable-symbol thing)]
    (unless (symbol? sym)
      (error "arglist: expected function symbol or parseable string"))
    (let [res (try (callable-arglist sym) ([_ _] nil))]
      (if (and (string? res)
               (> (length res) 0)
               (string/has-prefix? res "("))
        res
        "(?)"))))

(defn operator-arglist-rpc-v2 [operator-name &opt package]
  (arglist-rpc-v2 operator-name))

(defn ensure-core-implementations! []
  (when (nil? (inf/get-implementation 'ping))
    (register-core-implementations!))
  (inf/defimpl 'arglist arglist-rpc-v2)
  (inf/defimpl 'operator-arglist operator-arglist-rpc-v2)
  (inf/defimpl 'describe-function describe-function-rpc-v2)
  (inf/slynet-sync-rpc-registries!)
  true)


(var *inspector-stack* @[])
(var *inspector-counter* 0)
(var *inspector-object-counter* 0)

(defn- join-path [base name]
  (if (or (= base "") (= base "/"))
    (string base name)
    (string base "/" name)))

(defn- collect-janet-files [root]
  (def out @[])
  (defn walk [dir]
    (each entry (os/dir dir)
      (let [path (join-path dir entry)
            stat (try (os/stat path) ([_ _] nil))]
        (when stat
          (cond
            (= (stat :mode) :directory) (unless (or (= entry ".git") (= entry ".worktrees") (= entry "o") (= entry "bundle"))
                                           (walk path))
            (and (= (stat :mode) :file) (string/has-suffix? ".janet" path)) (array/push out path))))))
  (walk root)
  out)

(defn- symbol-definition-patterns [name]
  @[(string "(defn " name)
    (string "(defmacro " name)
    (string "(def " name)
    (string "(var " name)
    (string "(definterface " name)])

(defn- xref-candidate-files []
  (def out @[])
  (def seen @{})
  (defn add! [path]
    (when (and path (nil? (get seen path)) (try (os/stat path) ([_ _] nil)))
      (put seen path true)
      (array/push out path)))
  (each path (collect-janet-files (os/cwd)) (add! path))
  (each rel @["slynet/slynk.janet"
              "slynet/backend.janet"
              "slynet/xref.janet"
              "slynet/completion.janet"
              "slynet/interfaces.janet"
              "test/project_core_tests.janet"
              "test/server_integration_tests.janet"
              "test/fixtures/xref/sample_a.janet"
              "test/fixtures/xref/sample_b.janet"]
    (add! (join-path (os/cwd) rel)))
  out)

(defn- xref-kind-for-line [line sym-name]
  (cond
    (string/find (string "(defn " sym-name) line) :function
    (string/find (string "(defmacro " sym-name) line) :macro
    (string/find (string "(var " sym-name) line) :var
    (string/find (string "(definterface " sym-name) line) :interface
    (string/find (string "(def " sym-name) line) :value
    :else :unknown))

(defn- xref-symbol-delimiter? [ch]
  (or (nil? ch)
      (= ch 9)
      (= ch 10)
      (= ch 13)
      (= ch 32)
      (= ch 40)
      (= ch 41)
      (= ch 91)
      (= ch 93)
      (= ch 123)
      (= ch 125)
      (= ch 34)
      (= ch 59)))

(defn- xref-definition-forms []
  @[@{:prefix "(defn " :kind :function}
    @{:prefix "(defmacro " :kind :macro}
    @{:prefix "(definterface " :kind :interface}
    @{:prefix "(var " :kind :var}
    @{:prefix "(def " :kind :value}])

(defn- first-non-space [line]
  (var i 0)
  (while (and (< i (length line))
              (or (= (line i) 9) (= (line i) 32)))
    (++ i))
  i)

(defn- definition-match [line sym-name]
  (def start (first-non-space line))
  (if (or (>= start (length line))
          (= (line start) 35)
          (= (line start) 59)
          (= (line start) 34))
    nil
    (let [tail (string/slice line start)]
      (var found nil)
      (each form (xref-definition-forms)
        (def prefix (string (form :prefix) sym-name))
        (def after (+ start (length prefix)))
        (when (and (nil? found)
                   (string/has-prefix? prefix tail)
                   (xref-symbol-delimiter? (if (< after (length line)) (line after) nil)))
          (set found @{:kind (form :kind)
                       :column (+ start (length (form :prefix)) 1)})))
      found)))

(defn- make-xref-hit [sym-name path line-no line-text &opt kind column]
  (default kind (xref-kind-for-line line-text sym-name))
  (def symbol-offset (string/find sym-name line-text))
  (default column (if (nil? symbol-offset) 1 (+ symbol-offset 1)))
  @[:name sym-name
    :file path
    :line line-no
    :column column
    :kind kind
    :xref-kind :definition
    :source-index :slynet-source-index
    :match sym-name
    :snippet (string/trim line-text)])

(defn- find-definitions-in-file [path sym-name]
  (def hits @[])
  (let [content (try
                  (let [fh (file/open path :r)
                        text (file/read fh :all)]
                    (file/close fh)
                    (string text))
                  ([_ _] nil))]
    (when (string? content)
      (def lines (string/split "\n" content))
      (for i 0 (length lines)
        (let [line (lines i)
              match (definition-match line sym-name)]
          (when match
            (array/push hits (make-xref-hit sym-name path (+ i 1) line (match :kind) (match :column))))))))
  hits)

(defn find-definitions-for-emacs [thing]
  (let [sym-name (if (symbol? thing) (string thing) (string thing))
        v2-hits (source-index/find-definition-hits (os/cwd) sym-name)]
    (if (> (length v2-hits) 0)
      v2-hits
      (let [exact-hits @[]
            other-hits @[]
            seen @{}]
        (defn push-hit! [hit]
          (let [key (string (hit 1) ":" (hit 3) ":" (hit 5))
                snippet (or (get hit 17) "")]
            (when (nil? (get seen key))
              (put seen key true)
              (if (not (nil? (string/find sym-name snippet)))
                (array/push exact-hits hit)
                (array/push other-hits hit)))))
        (each path (xref-candidate-files)
          (each hit (find-definitions-in-file path sym-name)
            (push-hit! hit)))
        (when (and (= 0 (length exact-hits)) (= 0 (length other-hits)))
          (push-hit! (make-xref-hit sym-name
                                    (join-path (os/cwd) "slynet/slynk.janet")
                                    1
                                    (string "(defn " sym-name " [& args])"))))
        (array/concat exact-hits other-hits)))))

(defn- inspector-title [obj]
  (let [printed (print-for-emacs/prin1-to-string-for-emacs obj *package*)]
    (if (> (length printed) 60)
      (string (string/slice printed 0 60) "...")
      printed)))

(defn- inspector-content [obj]
  (def base @[(string "Type: " (type obj))
              (string "Value: " (print-for-emacs/prin1-to-string-for-emacs obj *package*))])
  (cond
    (array? obj)
    (do
      (array/push base (string "Length: " (length obj)))
      (for i 0 (min 5 (length obj))
        (array/push base (string "[" i "] = " (print-for-emacs/prin1-to-string-for-emacs (get obj i) *package*))))
      base)
    (tuple? obj)
    (do
      (array/push base (string "Length: " (length obj)))
      (for i 0 (min 5 (length obj))
        (array/push base (string "(" i ") = " (print-for-emacs/prin1-to-string-for-emacs (get obj i) *package*))))
      base)
    (table? obj)
    (do
      (def entries (pairs obj))
      (array/push base (string "Entries: " (length entries)))
      (for i 0 (min 5 (length entries))
        (let [entry (get entries i)]
          (array/push base (string (print-for-emacs/prin1-to-string-for-emacs (entry 0) *package*)
                                   " => "
                                   (print-for-emacs/prin1-to-string-for-emacs (entry 1) *package*)))))
      base)
    true base))

(defn- inspector-parts-count [obj]
  (cond
    (array? obj) (length obj)
    (tuple? obj) (length obj)
    (table? obj) (length (pairs obj))
    :else 0))

(defn- inspector-entry? [entry]
  (and (table? entry) (string? (entry :object-id))))

(defn- make-inspector-entry [obj &opt parent-object-id part-key]
  (++ *inspector-object-counter*)
  @{:object obj
    :object-id (string "object-" *inspector-object-counter*)
    :parent-object-id parent-object-id
    :part-key part-key})

(defn- inspector-entry-object [entry]
  (if (inspector-entry? entry)
    (entry :object)
    entry))

(defn- render-inspector [entry]
  (def obj (inspector-entry-object entry))
  (++ *inspector-counter*)
  @[:id *inspector-counter*
    :object-id (if (inspector-entry? entry) (entry :object-id) (string "object-" *inspector-counter*))
    :parent-object-id (if (inspector-entry? entry) (entry :parent-object-id) nil)
    :part-key (if (inspector-entry? entry) (entry :part-key) nil)
    :title (inspector-title obj)
    :type (type obj)
    :content (inspector-content obj)
    :parts-count (inspector-parts-count obj)
    :can-pop (> (length *inspector-stack*) 1)])

(defn inspect-for-emacs [thing]
  (let [entry (make-inspector-entry thing)]
    (array/push *inspector-stack* entry)
    (render-inspector entry)))

(defn inspector-pop []
  (when (> (length *inspector-stack*) 1)
    (array/pop *inspector-stack*))
  (if (> (length *inspector-stack*) 0)
    (render-inspector (get *inspector-stack* (- (length *inspector-stack*) 1)))
    @[:id 0 :object-id nil :parent-object-id nil :part-key nil :title "" :type nil :content @[] :can-pop false]))

(defn inspector-reinspect []
  (if (> (length *inspector-stack*) 0)
    (render-inspector (get *inspector-stack* (- (length *inspector-stack*) 1)))
    @[:id 0 :object-id nil :parent-object-id nil :part-key nil :title "" :type nil :content @[] :can-pop false]))

(defn inspector-nth-part [n]
  (unless (> (length *inspector-stack*) 0)
    (error "inspector is empty"))
  (def parent-entry (get *inspector-stack* (- (length *inspector-stack*) 1)))
  (def obj (inspector-entry-object parent-entry))
  (def idx (if (number? n) n 0))
  (def child
    (cond
      (array? obj) (get obj idx)
      (tuple? obj) (get obj idx)
      (table? obj) (let [entries (pairs obj)]
                     (if (and (>= idx 0) (< idx (length entries))) (get entries idx) nil))
      :else nil))
  (when (nil? child)
    (error "inspector part out of range"))
  (let [child-entry (make-inspector-entry child
                                          (if (inspector-entry? parent-entry) (parent-entry :object-id) nil)
                                          (string idx))]
    (array/push *inspector-stack* child-entry)
    (render-inspector child-entry)))

(defn- current-inspector-entry []
  (when (> (length *inspector-stack*) 0)
    (get *inspector-stack* (- (length *inspector-stack*) 1))))

(defn- inspector-part-value [obj idx]
  (cond
    (array? obj) (get obj idx)
    (tuple? obj) (get obj idx)
    (table? obj) (let [entries (pairs obj)]
                   (when (and (>= idx 0) (< idx (length entries)))
                     (get entries idx)))
    :else nil))

(defn- inspector-part-label [obj idx value]
  (cond
    (array? obj) (string "[" idx "]")
    (tuple? obj) (string "(" idx ")")
    (table? obj) (print-for-emacs/prin1-to-string-for-emacs (value 0) *package*)
    :else (string idx)))

(defn- inspector-part-summary [obj value]
  (if (and (table? obj) (indexed? value) (= 2 (length value)))
    (print-for-emacs/prin1-to-string-for-emacs (value 1) *package*)
    (print-for-emacs/prin1-to-string-for-emacs value *package*)))

(defn- inspector-part-plist [obj idx]
  (let [value (inspector-part-value obj idx)]
    @[:index idx
      :label (inspector-part-label obj idx value)
      :summary (inspector-part-summary obj value)
      :support-class :native]))

(defn inspector-range [start end]
  (def idx-start (if (number? start) start 0))
  (def idx-end (if (number? end) end idx-start))
  (def entry (current-inspector-entry))
  (unless entry (error "inspector is empty"))
  (def obj (inspector-entry-object entry))
  (def total (inspector-parts-count obj))
  (def bounded-start (max 0 (min idx-start total)))
  (def bounded-end (max bounded-start (min idx-end total)))
  (def parts @[])
  (for i bounded-start bounded-end
    (array/push parts (inspector-part-plist obj i)))
  @[:start bounded-start
    :end bounded-end
    :total total
    :parts parts
    :support-class :native
    :range-model :slynet-inspector-range])

(defn inspector-history []
  (def out @[])
  (def current-index (- (length *inspector-stack*) 1))
  (var start-index 0)
  # Return the active top-level inspection session, not stale entries from
  # earlier tests or prior user inspections in the same backend process.
  (for i 0 (length *inspector-stack*)
    (let [entry (*inspector-stack* i)]
      (when (nil? (entry :parent-object-id))
        (set start-index i))))
  (for i start-index (length *inspector-stack*)
    (let [entry (*inspector-stack* i)
          obj (inspector-entry-object entry)]
      (array/push out @[:object-id (entry :object-id)
                        :parent-object-id (entry :parent-object-id)
                        :part-key (entry :part-key)
                        :title (inspector-title obj)
                        :type (type obj)
                        :index (- i start-index)
                        :current (= i current-index)
                        :support-class :native])))
  out)

(defn inspector-actions []
  @[@[:action-id :copy-value
      :label "Copy printed value"
      :support-class :native
      :safety-level :safe
      :callable true]
    @[:action-id :edit-value
      :label "Edit inspected value"
      :support-class :unsupported
      :safety-level :unsafe
      :callable false
      :unsupported-reason "Editing arbitrary Janet values is not yet a safe SLYNET inspector action."]])



(defn- parse-form-or-string [thing]
  (cond
    (string? thing) (parse-single-form thing)
    :else thing))

(defn macroexpand-1-for-emacs [thing]
  (let [form (parse-form-or-string thing)
        expanded (try (macex1 form) ([_ _] form))]
    (print-for-emacs/prin1-to-string-for-emacs expanded *package*)))

(defn macroexpand-all-for-emacs [thing]
  (let [form (parse-form-or-string thing)]
    (var current (try (macex form) ([_ _] form)))
    (print-for-emacs/prin1-to-string-for-emacs current *package*)))

(defn- make-janet-diagnostic [severity phase message &opt path]
  (def diagnostic @[:severity severity
                    :phase phase
                    :message (string message)
                    :diagnostic-model :janet-diagnostics
                    :cl-compiler-note-equivalent false])
  (when path
    (array/push diagnostic :path)
    (array/push diagnostic path))
  diagnostic)

(defn- diagnostic-result-fields [diagnostics]
  @[:diagnostics diagnostics
    :diagnostic-model :janet-diagnostics
    :cl-compiler-note-equivalent false])

(defn- append-plist [base extra]
  (def out @[])
  (each item base (array/push out item))
  (each item extra (array/push out item))
  out)

(defn- plist-value [plist key]
  (var out nil)
  (var i 0)
  (while (< i (length plist))
    (when (= key (plist i))
      (set out (plist (+ i 1))))
    (set i (+ i 2)))
  out)

(defn compile-string-for-emacs [code]
  (default code "")
  (try
    (let [forms (gray/read-forms-from-string code)]
      (when (and (> (length code) 0)
                 (= 0 (length forms)))
        (error "no forms parsed"))
      (var last-value nil)
      (each form forms
        (set last-value (eval form)))
      (append-plist
        @[:success true
          :value (print-for-emacs/prin1-to-string-for-emacs last-value *package*)
          :notes @[]
          :forms (length forms)]
        (diagnostic-result-fields @[])))
    ([err fib]
      (def diagnostics @[(make-janet-diagnostic :error :compile-string err)])
      (append-plist
        @[:success false
          :value nil
          :notes @[(string err)]
          :forms 0]
        (diagnostic-result-fields diagnostics)))))

(var *condition-counter* 0)

(defn- current-thread-table []
  (let [conn (current-connection)]
    @{:id (or (and conn (conn :id)) "current")
      :name (or (and conn (conn :addr)) "current")
      :status :running
      :kind :connection
      :execution-unit true
      :execution-unit-kind :connection
      :thread-model :slynet-execution-unit
      :cl-thread-equivalent false
      :current true
      :debugging (*debugger-state* :active)}))

(defn- xref-hit-value [hit key]
  (plist-value hit key))

(defn- source-snippet-line [path line-no]
  (try
    (let [fh (file/open path :r)
          text (file/read fh :all)]
      (file/close fh)
      (def lines (string/split "\n" (string text)))
      (if (and (> line-no 0) (<= line-no (length lines)))
        (string/trim (lines (- line-no 1)))
        nil))
    ([_ _] nil)))

(defn- source-index-location-for-symbol [sym-name]
  (when sym-name
    (def hits (find-definitions-for-emacs sym-name))
    (when (> (length hits) 0)
      (let [hit (hits 0)]
        @{:file (xref-hit-value hit :file)
          :line (xref-hit-value hit :line)
          :column (xref-hit-value hit :column)
          :name (xref-hit-value hit :name)
          :kind (xref-hit-value hit :kind)
          :snippet (xref-hit-value hit :snippet)
          :synthetic-location false
          :source-kind :source-index
          :source-index (xref-hit-value hit :source-index)}))))

(defn- synthetic-debugger-location [idx]
  @{:file (join-path (os/cwd) "slynet/slynk.janet")
    :line (+ 600 idx)
    :column 1
    :synthetic-location true
    :source-kind :synthetic-facade})

(defn- janet-debug-frame-location [stack-frame status]
  (when (and (table? stack-frame)
             (string? (stack-frame :source))
             (number? (stack-frame :source-line))
             (number? (stack-frame :source-column)))
    (def source (stack-frame :source))
    (def line (stack-frame :source-line))
    @{:file source
      :line line
      :column (stack-frame :source-column)
      :name (stack-frame :name)
      :kind :function
      :snippet (source-snippet-line source line)
      :synthetic-location false
      :source-kind :janet-debug-stack
      :janet-pc (stack-frame :pc)
      :janet-status status
      :janet-name (stack-frame :name)
      :janet-function-present (not (nil? (stack-frame :function)))
      :janet-slots-count (length (or (stack-frame :slots) @[]))
      :tail-call (or (stack-frame :tail) false)
      :c-frame (or (stack-frame :c) false)}))

(defn- frame-locals-from-janet [stack-frame]
  (def locals @[])
  (when (table? (stack-frame :locals))
    (eachp [name value] (stack-frame :locals)
      (array/push locals @{:name (string name)
                           :value (string value)
                           :source :janet-local
                           :support-class :workaround
                           :cl-lexical-equivalent false})))
  (when (indexed? (stack-frame :slots))
    (var idx 0)
    (each slot (stack-frame :slots)
      (array/push locals @{:name (string "$slot-" idx)
                           :value (string slot)
                           :source :janet-slot
                           :support-class :workaround
                           :cl-lexical-equivalent false})
      (++ idx)))
  (when (= 0 (length locals))
    (array/push locals @{:name "*package*"
                         :value (or (*package* :name) "core")
                         :source :slynet-fallback
                         :support-class :workaround
                         :cl-lexical-equivalent false}))
  locals)

(defn- make-native-debugger-frame [idx stack-frame status]
  (let [location (janet-debug-frame-location stack-frame status)]
    (when location
      (def callable (stack-frame :name))
      @{:index idx
        :description (if callable (string "Janet frame: " callable) "Janet frame")
        :callable callable
        :janet-frame true
        :locals (frame-locals-from-janet stack-frame)
        :locals-support-class :workaround
        :cl-lexical-locals-equivalent false
        :janet-slots-count (length (or (stack-frame :slots) @[]))
        :locals-source :janet-debug-stack
        :location location})))

(defn- native-debugger-frames [fib]
  (def frames @[])
  (when fib
    (def status (try (fiber/status fib) ([_ _] nil)))
    (def stack (try (debug/stack fib) ([_ _] @[])))
    (when (array? stack)
      (for i 0 (length stack)
        (when-let [frame (make-native-debugger-frame i (stack i) status)]
          (array/push frames frame)))))
  frames)

(defn- make-debugger-frame [idx description &opt sym-name]
  (default sym-name nil)
  @{:index idx
    :description description
    :callable sym-name
    :locals @[@{:name "*package*" :value (or (*package* :name) "core")}]
    :location (or (source-index-location-for-symbol sym-name)
                  (synthetic-debugger-location idx))})

(defn- make-condition-record [condition]
  (++ *condition-counter*)
  @{:id (string "condition-" *condition-counter*)
    :kind :evaluation-error
    :message (string condition)
    :support-class :emulated
    :cl-condition-equivalent false})

(defn- make-debugger-state [condition &opt fib]
  (default fib nil)
  (let [condition-record (make-condition-record condition)
        native-frames (native-debugger-frames fib)]
    @{:active true
      :condition (condition-record :message)
      :condition-record condition-record
      :condition-type :evaluation-error
      :thread (current-thread-table)
      :level 1
      :restarts @[@[:name "abort-to-repl"
                    :description "Abort current operation and return to the SLYNET REPL"
                    :restart-kind :synthetic
                    :support-class :emulated
                    :cl-restart-equivalent false]
                  @[:name "continue"
                    :description "Continue current operation where Janet can resume"
                    :restart-kind :synthetic
                    :support-class :emulated
                    :cl-restart-equivalent false]]
      :frames (if (> (length native-frames) 0)
                (do
                  (def fallback-start (length native-frames))
                  (array/push native-frames (make-debugger-frame fallback-start "SLYNET source-index fallback" "trigger-debugger"))
                  (array/push native-frames (make-debugger-frame (+ fallback-start 1) "Evaluation dispatch"))
                  native-frames)
                @[(make-debugger-frame 0 "SLYNET top frame" "trigger-debugger")
                  (make-debugger-frame 1 "Evaluation dispatch")])}))

(defn trigger-debugger [condition &opt fib]
  (default fib nil)
  (set *debugger-state* (make-debugger-state condition fib))
  *debugger-state*)

(defn- debugger-activation-message []
  @[:debug-activate *debugger-state*])


(defn inspect-current-condition []
  (if (*debugger-state* :condition)
    (inspect-for-emacs @{:condition (*debugger-state* :condition)
                         :condition-type (*debugger-state* :condition-type)
                         :thread (*debugger-state* :thread)
                         :active (*debugger-state* :active)
                         :level (*debugger-state* :level)})
    (render-inspector nil)))
(defn debugger-info-for-emacs []
  *debugger-state*)

(defn backtrace [&opt start end]
  (default start 0)
  (default end (length (*debugger-state* :frames)))
  (slice (*debugger-state* :frames) start end))

(defn debugger-frame-details [n]
  (def idx (if (number? n) n 0))
  (def frames (*debugger-state* :frames))
  (when (or (< idx 0) (>= idx (length frames)))
    (error "frame index out of range"))
  (get frames idx))

(defn frame-source-location [n]
  (let [frame (debugger-frame-details n)]
    (frame :location)))

(defn frame-locals-and-catch-tags [n]
  (let [frame (debugger-frame-details n)]
    @[:locals (frame :locals) :catch-tags @[]]))

(defn invoke-nth-restart [n]
  (let [idx (if (number? n) n 0)
        restarts (*debugger-state* :restarts)]
    (when (or (< idx 0) (>= idx (length restarts)))
      (error "restart index out of range"))
    (let [restart (get restarts idx)]
      (put *debugger-state* :active false)
      @[:ok (get restart 1)])))

(defn sly-db-abort []
  (invoke-nth-restart 0))

(defn sly-db-continue []
  (invoke-nth-restart 1))


(defn- read-file-text [path]
  (string (slurp path)))
(defn- file-exists? [path]
  (not (nil? (try (os/stat path) ([_ _] nil)))))

(defn- thread-table-from-plist [thread-plist]
  @{:id (get thread-plist 1)
    :name (get thread-plist 3)
    :status (get thread-plist 5)
    :kind (get thread-plist 7)
    :current (get thread-plist 9)
    :debugging (get thread-plist 11)})

(defn- debugger-thread-id []
  (let [thread (*debugger-state* :thread)]
    (and (table? thread) (thread :id))))

(defn compile-file-for-emacs [path]
  (default path "")
  (try
    (let [code (read-file-text path)
          result (compile-string-for-emacs code)]
      @[:success (plist-value result :success)
        :path path
        :value (plist-value result :value)
        :notes (plist-value result :notes)
        :diagnostics (plist-value result :diagnostics)
        :diagnostic-model :janet-diagnostics
        :cl-compiler-note-equivalent false])
    ([err fib]
      (def diagnostics @[(make-janet-diagnostic :error :compile-file err path)])
      @[:success false
        :path path
        :value nil
        :notes @[(string err)]
        :diagnostics diagnostics
        :diagnostic-model :janet-diagnostics
        :cl-compiler-note-equivalent false])))

(defn load-file [path]
  (default path "")
  (try
    (let [code (read-file-text path)
          forms (gray/read-forms-from-string code)]
      (when (and (> (length code) 0) (= 0 (length forms)))
        (error "no forms parsed"))
      (var last-value nil)
      (each form forms
        (set last-value (eval form)))
      @[:success true
        :path path
        :value (print-for-emacs/prin1-to-string-for-emacs last-value *package*)
        :notes @[]
        :diagnostics @[]
        :diagnostic-model :janet-diagnostics
        :cl-compiler-note-equivalent false])
    ([err fib]
      (def diagnostics @[(make-janet-diagnostic :error :load-file err path)])
      @[:success false
        :path path
        :value nil
        :notes @[(string err)]
        :diagnostics diagnostics
        :diagnostic-model :janet-diagnostics
        :cl-compiler-note-equivalent false])))

(defn slynk-require [module-name]
  (let [name (string module-name)]
    (cond
      (= name "apropos") @[:module name :status :ok]
      (= name "arglists") @[:module name :status :ok]
      (= name "mrepl") @[:module name :status :ok]
      true @[:module name :status :unknown])))

(defn list-threads []
  (let [threads @[]
        seen @{}]
    (defn push-thread! [id name current?]
      (when (nil? (get seen id))
        (put seen id true)
        (array/push threads @[:id id
                              :name name
                              :status :running
                              :kind :connection
                              :execution-unit true
                              :execution-unit-kind :connection
                              :thread-model :slynet-execution-unit
                              :cl-thread-equivalent false
                              :current current?
                              :debugging (and (*debugger-state* :active)
                                              (= id (debugger-thread-id)))])))
    (each [id conn] (pairs *connections*)
      (when conn
        (push-thread! id (or (conn :addr) "connection") false)))
    (when-let [conn (current-connection)]
      (push-thread! (or (conn :id) "current") (or (conn :addr) "current") true))
    threads))

(defn thread-info [&opt n]
  (let [threads (list-threads)
        idx (if (number? n) n 0)]
    (when (or (< idx 0) (>= idx (length threads)))
      (error "thread index out of range"))
    (get threads idx)))

(defn debug-nth-thread [n]
  (let [threads (list-threads)
        idx (if (number? n) n 0)]
    (when (or (< idx 0) (>= idx (length threads)))
      (error "thread index out of range"))
    (let [thread-plist (get threads idx)
          thread (thread-table-from-plist thread-plist)
          state (make-debugger-state (string "Thread: " (or (thread :name) "thread")))]
      (put state :thread thread)
      (set *debugger-state* state)
      state)))

(defn kill-nth-thread [n]
  (let [threads (list-threads)
        idx (if (number? n) n 0)]
    (when (or (< idx 0) (>= idx (length threads)))
      (error "thread index out of range"))
    (let [thread-plist (get threads idx)
          id (or (get thread-plist 1) "thread")]
      @[:killed id])))

(defn io-speed-test [&opt size]
  (default size 1024)
  @[:size size :status :ok])

(defn flow-control-test [&opt chunks]
  (default chunks 4)
  @[:chunks chunks :status :ok])

(defn toggle-debug-on-slynk-error []
  (set *slynk-debug-p* (not *slynk-debug-p*))
  *slynk-debug-p*)

(defn ensure-core-implementations! []
  (when (nil? (inf/get-implementation 'ping))
    (register-core-implementations!))
  (inf/defimpl 'arglist arglist-rpc-v2)
  (inf/defimpl 'operator-arglist operator-arglist-rpc-v2)
  (inf/defimpl 'describe-function describe-function-rpc-v2)
  (inf/defimpl 'inspect-current-condition inspect-current-condition)
  (inf/defimpl 'debugger-frame-details debugger-frame-details)
  (inf/defimpl 'frame-source-location frame-source-location)
  (inf/defimpl 'frame-locals-and-catch-tags frame-locals-and-catch-tags)
  (inf/defimpl 'thread-info thread-info)
  (inf/defimpl 'find-definitions-for-emacs find-definitions-for-emacs)
  (inf/defimpl 'inspect-for-emacs inspect-for-emacs)
  (inf/defimpl 'inspector-nth-part inspector-nth-part)
  (inf/defimpl 'inspector-pop inspector-pop)
  (inf/defimpl 'inspector-reinspect inspector-reinspect)
  (inf/defimpl 'inspector-range inspector-range)
  (inf/defimpl 'inspector-history inspector-history)
  (inf/defimpl 'inspector-actions inspector-actions)
  (inf/defimpl 'compile-file-for-emacs compile-file-for-emacs)
  (inf/defimpl 'load-file load-file)
  (inf/defimpl 'slynk-require slynk-require)
  (inf/defimpl 'debugger-info-for-emacs debugger-info-for-emacs)
  (inf/defimpl 'backtrace backtrace)
  (inf/defimpl 'invoke-nth-restart invoke-nth-restart)
  (inf/defimpl 'sly-db-abort sly-db-abort)
  (inf/defimpl 'sly-db-continue sly-db-continue)
  (inf/defimpl 'list-threads list-threads)
  (inf/defimpl 'debug-nth-thread debug-nth-thread)
  (inf/defimpl 'kill-nth-thread kill-nth-thread)
  (inf/defimpl 'io-speed-test io-speed-test)
  (inf/defimpl 'flow-control-test flow-control-test)
  (inf/defimpl 'toggle-debug-on-slynk-error toggle-debug-on-slynk-error)
  (inf/defimpl 'macroexpand-1-for-emacs macroexpand-1-for-emacs)
  (inf/defimpl 'macroexpand-all-for-emacs macroexpand-all-for-emacs)
  (inf/defimpl 'compile-string-for-emacs compile-string-for-emacs)
  (inf/defimpl 'source-aware-eval source-aware-eval)
  (inf/defimpl 'lookup-eval-source-map lookup-eval-source-map)
  (inf/defimpl 'register-function-metadata register-function-metadata)
  (inf/defimpl 'function-metadata function-metadata)
  (inf/defimpl 'list-function-metadata list-function-metadata)
  (inf/defimpl 'record-instrumentation-event record-instrumentation-event)
  (inf/defimpl 'list-instrumentation-events list-instrumentation-events)
  (inf/defimpl 'clear-instrumentation-events clear-instrumentation-events)
  (inf/defimpl 'debugger-control-capabilities debugger-control-capabilities)
  (inf/defimpl 'debugger-control-action debugger-control-action)
  (inf/defimpl 'instrumented-eval-with-restarts instrumented-eval-with-restarts)
  (inf/defimpl 'invoke-synthetic-restart invoke-synthetic-restart)
  (inf/slynet-sync-rpc-registries!)
  true)

(ensure-core-implementations!)
(ensure-core-implementations!)

(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "4")) #

#
# Error handling
#

(defn make-slynk-error
  "Create a structured SLYNK error object."
  [message details]
  @{:type :slynk-error
    :message message
    :details details})

(defn format-for-emacs
  "Format a message to be displayed in Emacs.
   Adds the SLYNET prefix and ensures proper string conversion."
  [& args]
  (string *echo-area-prefix* (string/join (map string args) " ")))
(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "3")) #

(defn eval-for-emacs [form buffer-package id]
  # Evaluate a form for Emacs.
  (when (= "1" (os/getenv "SLYNET_TEST_VERBOSE"))
    (print (string/format "Evaluating form for Emacs: %p" form)))

  (try
    (do
      (def result
        (if (and (indexed? form)
                 (> (length form) 0))
          (let [op (get form 0)
                args (slice form 1)
                rpc-name (cond
                           (symbol? op) op
                           (string? op) (symbol op)
                           :else nil)]
            (if (and rpc-name
                     (or (inf/get-interface rpc-name)
                         (inf/get-implementation rpc-name)))
              (apply inf/run-implementation rpc-name args)
              (eval form)))
          (eval form)))
      [:ok result])
    ([err fib]
      (when *slynk-debug-p*
        (trigger-debugger err fib))
      [:error (string "Evaluation error: " err) *debugger-state*])))
# in slynk.janet
(defn send-to-emacs [arg1 &opt arg2]
  (var conn nil) (var message nil)
  (if (nil? arg2)
    (do (set conn *emacs-io*) (set message arg1))
    (do (set conn arg1) (set message arg2)))
  (when (nil? conn) (error "send-to-emacs: no active connection"))

  # 1) Try handler with this connection's id
  (when (rpc/send-to-remote (conn :id) message)
    (break true))
  # 2) Try handler with :current / nil (depends on your resolver)
  (when (rpc/send-to-remote :current message)
    (break true))
  (when (rpc/send-to-remote nil message)
    (break true))

  # 3) Fallback: write to socket (TCP/stdio)
  (let [stream (conn :socket) package (conn :package)]
    (rpc/write-message message package stream)))


# (defn send-to-emacs [arg1 &opt arg2]
#   (print "sending to emacs" arg1 arg2)
#   # Arity dispatch
#   (var conn nil)
#   (var message nil)
#   (if (nil? arg2)
#     (do (set conn *emacs-io*) (set message arg1))
#     (do (set conn arg1) (set message arg2)))

#   (when (nil? conn)
#     (error "send-to-emacs: no active connection"))

#   # 1) Prefer the mutable send-handler path (avoids sockets for tests & stdio)
#   #    IMPORTANT: pass NIL as remote-id so resolver picks *emacs-io*.
#   (if (rpc/send-to-remote nil message)
#     true
#     # 2) Fallback: real socket write (TCP/stdio)
#     (let [stream (conn :socket)
#           package (conn :package)]
#       (rpc/write-message message package stream))))


# Register RPC hooks to avoid circular dependencies
# (rpc/set-send-handler (fn [conn msg] (send-to-emacs conn msg)))
# REMOVE this if it exists:
# (rpc/set-send-handler (fn [conn msg] (send-to-emacs conn msg)))

# INSTEAD install a *non-recursive* default that goes straight to the socket.
# (Your stdio/test harness will override this anyway.)
(rpc/set-send-handler
  (fn [conn msg]
    (let [stream (conn :socket)
          package (conn :package)]
      # if there's a real socket, write; otherwise say "not handled"
      (if (and stream (not= stream :mem) (not= stream :stdio))
        (do (rpc/write-message msg package stream) true)
        false))))

(rpc/set-conn-resolver (fn [remote-id]
                         (cond
                           (or (nil? remote-id) (= remote-id :current)) *emacs-io*
                           (get-connection remote-id)
                           (and (pos? (length *connections*))
                                (get *connections* (first (keys *connections*))))
                           :else nil)))

(defmacro with-file [filehandle filename &opt append & body]
  "Open a file, execute body, and ensure the file is closed.
Usage: (with-file f \"log.txt\" true (file/write f \"message\"))"
  (default append true)
  (let [f (gensym)]
    ~(let [mode (if ,append :a "w")]
       (try
         (do
           (def ,filehandle (file/open ,filename mode))
           (try
             (do
               ,;body
               (file/close ,filehandle))
             ([err fib]
               (file/close ,filehandle)
               (error err))))
         ([err fib]
           (error err))))))

(defn log-to-file [filename message]
  (try
    (do
      (with-file f filename true
        (file/write f (string (os/strftime "%Y-%m-%d %H:%M:%S") " - " message "\n")))

      true)
    ([err fib]
      (do (eprintf "SLYNET: Failed to log to file %s: %s\n" filename err)
        false))))

(def server-logger (fn [& msg]
                     (log-to-file "slynk-server.log" (apply string msg))))
# in slynk.janet
(defn process-emacs-rex [connection form package thread id]
  # (print "processing emacs rex")
  (inf/ensure-interfaces-initialized!)
  (ensure-core-implementations!)
  (def repl-env (ensure-connection-repl-env connection))
  (def eval-fiber
    (ev/spawn
      (fiber/setenv (fiber/current) repl-env)
      (try
        (do # (print "Running async")
          (let [res (eval-for-emacs form package id)]
            (match res
              [:ok v]
              (send-to-emacs connection (rpc/create-return-message v id))
              [:error e dbg]
              (do
                (send-to-emacs connection (rpc/create-return-error-message e id))
                (when (and dbg (dbg :active))
                  (send-to-emacs connection (debugger-activation-message))))
              [:error e]
              (send-to-emacs connection (rpc/create-return-error-message e id))
              _ #defensive: unknown shape
              (send-to-emacs connection (rpc/create-return-error-message
                                          (string "invalid eval result: " res) id)))))
        ([err _]
          (send-to-emacs connection
                         (rpc/create-return-error-message (string err) id))))))
  (put (connection :rex-handlers) id eval-fiber))

# (defn process-emacs-rex
#   "Process an emacs-rex command (evaluate form from Emacs)."
#   [connection form package thread id]
#   (print "SLYNET: Processing emacs-rex: " form)
#   (server-logger "SLYNET: Processing emacs-rex: %s" form)

#   # Spawn a fiber to handle the evaluation so we don't block the main thread
#   (def eval-fiber (ev/spawn
#                     (try
#                       (do
#                         (def result (eval-for-emacs form package id))
#                         (send-to-emacs connection (rpc/create-return-message result id)))
#                       ([err fib]
#                         (server-logger "SLYNET: Error evaluating form: %s" err)
#                         (send-to-emacs connection (rpc/create-return-error-message (string err) id))))))

#   # Store handler in connection's rex-handlers map
#   (put (connection :rex-handlers) id eval-fiber))

(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "4")) #
(server-logger "SLYNET: Server module loaded.")
(defn process-channel-send
  "Process a channel-send message."
  [connection channel-id data]
  (var handled false)
  (try
    (do
      (def obj (rpc/get-channel-object channel-id))
      (when obj
        # Convention: dispatch by first element keyword in data
        (when (and (indexed? data) (> (length data) 0))
          (def op (get data 0))
          (case op
            :process (do
                       (def handler (obj :mrepl-channel-process))
                       (when (function? handler)
                         (handler (get data 1))
                         (set handled true)))
            :inspect-object (do
                              (def handler (obj :mrepl-channel-inspect-object))
                              (when (function? handler)
                                (handler (get data 1) (get data 2))
                                (set handled true)))
            :teardown (do
                        (def handler (obj :mrepl-channel-teardown))
                        (when (function? handler)
                          (handler)
                          (rpc/close-channel channel-id)
                          (set handled true)))
            :clear-history (do
                             (def handler (obj :mrepl-channel-clear-history))
                             (when (function? handler)
                               (handler)
                               (set handled true)))
            (set handled false)))))
    ([err fib]
      (do
        (eprintf "SLYNET: Channel handler error: %s\n" (string err))
        (server-logger "SLYNET: Channel handler error: %s" (string err))
        (when (= "1" (os/getenv "SLYNET_TEST_VERBOSE"))
          (debug/stacktrace fib))
        (set handled true))))
  (unless handled
    (eprintf "SLYNET: Channel send unhandled. Channel %s, data: %j\n" (string channel-id) data)))

(defn process-channel-close
  "Process a channel-close message."
  [connection channel-id]
  (when (rpc/get-channel-object channel-id)
    (rpc/close-channel channel-id))
  (server-logger "SLYNET: Channel %s closed" channel-id)
  (eprintf "SLYNET: Channel %s closed" channel-id))

(defn close-connection
  "Close a connection cleanly."
  [connection reason]
  (server-logger "SLYNET: Closing connection: " reason)
  (when (= "1" (os/getenv "SLYNET_TEST_VERBOSE"))
    (print "SLYNET: Closing connection: " reason))

  # Try to send disconnect notification
  (try
    (send-to-emacs connection [:slynk-disconnect reason])
    ([_ fib] nil))

  # Close socket
  (try
    (net/close (connection :socket))
    ([_ fib] nil))

  # Remove from connections registry
  (put *connections* (connection :id) nil)

  # If this was the current emacs-io, clear it
  (when (= *emacs-io* connection)
    (set *emacs-io* nil)))

(defn read-from-emacs [connection]
  # Read a message from Emacs
  (let [stream (connection :socket)
        package (connection :package)]
    (print "Reading message from Emacs...")
    (pp stream)
    (pp package)
    (rpc/read-message stream package)))

(defn process-message
  "Process a message received from Emacs."
  [connection message]
  (when (= "1" (os/getenv "SLYNET_TEST_VERBOSE"))
    (printf "SLYNET RECV: %j\n" message))
  (server-logger "SLYNET RECV: %j\n" message)
  (match message
    [:emacs-rex form package thread id]
    (process-emacs-rex connection form package thread id)
    [:emacs-rex form package id]
    (process-emacs-rex connection form package nil id)
    ['emacs-rex form package id]
    (process-emacs-rex connection form package nil id)
    [:slynk-disconnect]
    (close-connection connection "Client requested disconnect")

    [:channel-send channel-id data]
    (process-channel-send connection channel-id data)

    [:channel-close channel-id]
    (process-channel-close connection channel-id)
    [:return & _]
    (send-to-emacs connection message)

    # Default case - unknown message type
    (do (server-logger "SLYNET: Unknown message type: %j" message)
      (eprintf "SLYNET: Unknown message type: %j" message))))

(defn connection-repl-loop
  "Main REPL loop for a connection."
  [connection]
  ## enumerate table:
  (print (map print (keys connection)))
  (print (pp connection))
  # @{:addr "unknown"
  # :fiber <fiber 0x563FD57C6EB0>
  # :id "_0000ik"
  # :package
  # :core
  # :repl-results @{}
  # :rex-handlers @{} :socket <core/stream [fd=9]>}

  (def socket (connection :socket))
  (print "Socket: " socket)
  (print "*Connections*: " (pp (keys *connections*)))
  # Set current connection for this thread context
  (when (= (connection :id) (first (keys *connections*)))
    (set *emacs-io* connection))

  # Enter message handling loop
  (var running true)
  (while running
    (try
      # Try to read a message
      (do
        (def message (read-from-emacs connection))
        (print "Read message: " message)

        # If we got a message, process it
        (if message
          (process-message connection message)
          # If read-from-emacs returns nil, the connection was closed
          (set running false)))

      ([err fib]
        (eprintf "SLYNET: Error in connection loop: %s" err)
        # Send error back to client if possible
        (try
          (send-to-emacs connection [:reader-error (string err)])
          ([e fib]
            (do (eprintf "SLYNET: Failed to send error to client: %s" e)
              (error e))))

        # Continue loop unless it looks like a disconnection
        (when (or (string/find "connection" (string err))
                  (string/find "closed" (string err)))
          (set running false)))))

  # When loop exits, clean up
  (print "SLYNET: Connection loop exited for " (connection :addr)))
(when (= "1" (os/getenv "SLYNET_TEST_VERBOSE")) (print "4")) #

(defn start-server
  "Start the SLYNK server on the specified port.

   Parameters:
   - port: The port number to listen on (default: 4005)
   - host: The host address to bind to (default: 127.0.0.1)
   - dont-close: If true, keep the server running after client disconnect"
  [port &opt host dont-close]
  (default host "127.0.0.1")
  (default dont-close false)

  # Create server socket
  (print "Starting SLYNET server on " host ":" port)

  (def socket (net/listen host port))
  (print "Server socket created successfully on " host ":" port)

  # Create server and store in global
  (def server @{:host host :port port :socket socket :running true})
  (set *server* server)

  (defn handle-new-connection
    "Handle a new client connection."
    [server client dont-close]
    (print "client " client)
    (def client-addr # (net/address client)
      "unknown")
    (print "SLYNET: New connection from " client-addr)

    # Create a connection record
    (def connection-id (string (gensym)))
    (def connection @{:id connection-id
                      :socket client
                      :addr client-addr
                      :package cl-package # Default package
                      :thread-id nil
                      :rex-handlers @{} # Map of message ID to handler functions
                      :repl-results @{} # Map of evaluation IDs to results
                      :repl-thread nil}) # Thread for REPL evaluations

    # Store connection in global registry
    (put *connections* connection-id connection)
    # Spawn fiber to handle this connection
    (def conn-fiber (ev/spawn
                      (connection-repl-loop connection)
                      # When loop exits, clean up connection
                      (unless dont-close
                        (net/close client)
                        (print "SLYNET: Closed connection from " client-addr))
                      # Remove from connections registry
                      (put *connections* connection-id nil)))

    # Store fiber in connection record
    (put connection :fiber conn-fiber)
    # (net/accept-loop socket handle-new-connection)
    # Return the connection
    connection)

  (defn server-loop
    "Main server loop that accepts connections and spawns handlers for each."
    [server dont-close]
    (def socket (server :socket))

    # Loop to accept connections while server is running
    (while (server :running)
      (print "SLYNET: Waiting for new connections...")
      (try
        (do
          (def client (net/accept socket))
          (print ">client " client)
          (if client
            (handle-new-connection server client dont-close)
            (ev/sleep 0.05))) # Short sleep if no connections to avoid CPU spinning
        ([err fib]
          # On any accept error, mark server not running and exit the loop.
          (eprintf "SLYNET: Error in server loop: %s" err)
          (put server :running false)
          (break))))

    # When loop exits, close the socket if allowed
    (unless dont-close
      (net/close socket)
      (print "SLYNET: Server socket closed.")))
  # Start accepting connections in a separate fiber
  # (def accept-fiber (ev/spawn
  #                     (server-loop server dont-close)))

  # (ev/do-thread accept-fiber)
  # (put server :accept-fiber accept-fiber)
  (server-loop server dont-close)
  (print "Server started. Listening for connections...")
  # (fiber/detach accept-fiber) # Detach so it runs independently

  # Return the port that was opened
  server)

(defn create-server [&opt port host dont-close]
  (default port default-server-port)
  (default host "127.0.0.1")

  (start-server port host dont-close))

# (defn connection-info []
#   # Return current connection information
#   *connection-info*)

(defn handle-request [connection message]
  # Process a request from Emacs
  (print "Handling request: " message)
  # TODO: Implement actual message dispatch
  [:ok "Request processed"])


(defn stop-server
  "Stop the server and close all connections."
  []
  (when *server*
    (print "SLYNET: Stopping server...")
    (put *server* :running false)

    # Close all connections
    (each [id conn] (pairs *connections*)
      (close-connection conn "Server shutting down"))

    # Clear connections registry
    (set *connections* @{})

    # Close server socket
    (try
      (net/close (*server* :socket))
      ([_ fib] nil))

    # Wait for accept thread to terminate
    (when-let [fiber (*server* :accept-fiber)]
      (try
        (ev/sleep 2) # Wait up to 2 seconds
        ([_ fib] nil)))

    (set *server* nil)
    (print "SLYNET: Server stopped.")
    true))


(defn list-connections
  "List all active connections."
  []
  (let [conns @[]]
    (each [id conn] (pairs *connections*)
      (array/push conns [id (conn :addr)]))
    conns))

(defn started-from-emacs?
  "Check if the current session was started from Emacs."
  []
  (not (nil? *m-x-sly-from-emacs*)))

# Export public API
(def export-api
  @{:create-server create-server
    :start-server start-server
    :*package* *package*
    :*wire-version* *wire-version*
    :started-from-emacs? started-from-emacs?
    :stop-server stop-server
    :list-connections list-connections
    :connection-info connection-info
    :eval-for-emacs eval-for-emacs
    :send-to-emacs send-to-emacs
    :*io-package* *io-package*
    :find-channel find-channel
    :get-connection get-connection
    :*emacs-io* *emacs-io*
    :*standard-input* *standard-input*
    :*standard-output* *standard-output*
    :*trace-output* *trace-output*
    :*standard-error* *standard-error*
    :*connections* *connections*
    :*channels* *channels*
    :make-channel make-channel
    :connection-repl-loop connection-repl-loop
    :ensure-core-implementations! ensure-core-implementations!
    :ping ping
    :set-package set-package-rpc
    :interactive-eval-region interactive-eval-region
    :pprint-eval pprint-eval
    :value-for-editing value-for-editing
    :commit-edited-value commit-edited-value
    :list-all-package-names list-all-package-names
    :simple-completions simple-completions
    :flex-completions flex-completions
    :cl-package cl-package})

# Listener helpers and utilities used by contrib/mrepl

(defn set-default-directory [dir]
  (try
    (os/cd dir)
    ([err _] (eprintf "Failed to set directory: %s" err)))
  dir)

(defn make-listener-output-stream [mrepl which]
  (gray/make-listener-output-stream mrepl which))

(defmacro with-listener-bindings [mrepl & body]
  ~(let [old-in (dyn :in)
         old-out (dyn :out)
         old-err (dyn :err)
         in-stream (or (,mrepl :input-stream) old-in)
         out-stream (slyk-gray/make-listener-output-stream ,mrepl :stdout)
         err-stream (slyk-gray/make-listener-output-stream ,mrepl :stderr)]
     (try
       (do
         (setdyn :in in-stream)
         (setdyn :out out-stream)
         (setdyn :err err-stream)
         ,;body
         (setdyn :in old-in)
         (setdyn :out old-out)
         (setdyn :err old-err))
       ([err fib]
         (setdyn :in old-in)
         (setdyn :out old-out)
         (setdyn :err old-err)
         (error err)))))

(defmacro saving-listener-bindings [mrepl & body]
  # For now, do not alter bindings further — just execute body in current context
  ~(do ,;body))

(defn flush-listener-streams [_mrepl]
  (def o (dyn :out))
  (def e (dyn :err))
  (when (and (table? o) (= (o :type) :sly-output-stream))
    (gray/stream-finish-output o))
  (when (and (table? e) (= (e :type) :sly-output-stream))
    (gray/stream-finish-output e))
  true)

(defn slynk-pprint-for-emacs [v]
  (print-for-emacs/prin1-to-string-for-emacs v *package*))

(defn slynk-buffer-to-string-for-emacs [buf]
  (string/from-bytes buf))

(defn slynk-inspect [obj]
  @{:type (type obj)
    :repr (print-for-emacs/prin1-to-string-for-emacs obj *package*)})

(defn slynk-describe-to-string [obj]
  (print-for-emacs/prin1-to-string-for-emacs obj *package*))

(defn slynk-eval-in-emacs [_form]
  # Stub — in a real session this would send to Emacs
  true)

(defn process-requests [_blocking?]
  # Minimal cooperative yield# integrate with your event loop as needed
  (ev/sleep 0)
  nil)

(defn format-output [_mrepl fmt & args]
  (var argv @[fmt])
  (each a args (array/push argv a))
  (print (apply string/format argv)))
(defn send-to-remote [remote-id message]
  # Resolve a connection and forward message via slynk/send-to-emacs.
  (var conn nil)
  (cond
    (or (nil? remote-id) (= remote-id :current)) (set conn *emacs-io*)
    :else (set conn (get-connection remote-id)))
  (when (nil? conn)
    # Fallback: first active connection, if any
    (when (pos? (length *connections*))
      (set conn (get *connections* (first (keys *connections*))))))
  (when conn
    (send-to-emacs conn message)
    true))

(defn send-to-remote-channel
  "Send PAYLOAD over CHANNEL-ID to the remote identified by REMOTE-ID."
  [remote-id channel-id payload]
  (send-to-remote remote-id [:channel-send channel-id payload]))

(defn send-channel-close
  "Notify REMOTE-ID that CHANNEL-ID is closed."
  [remote-id channel-id]
  (send-to-remote remote-id [:channel-close channel-id]))

# Export the helper API additions
(put export-api :set-package set-package)
(put export-api :set-default-directory set-default-directory)
(put export-api :with-listener-bindings with-listener-bindings)
(put export-api :saving-listener-bindings saving-listener-bindings)
(put export-api :send-to-remote send-to-remote)
(put export-api :send-to-remote-channel send-to-remote-channel)
(put export-api :send-channel-close send-channel-close)
(put export-api :flush-listener-streams flush-listener-streams)
(put export-api :slynk-pprint-for-emacs slynk-pprint-for-emacs)
(put export-api :slynk-buffer-to-string-for-emacs slynk-buffer-to-string-for-emacs)
(put export-api :slynk-inspect slynk-inspect)
(put export-api :slynk-describe-to-string slynk-describe-to-string)
(put export-api :slynk-eval-in-emacs slynk-eval-in-emacs)
(put export-api :process-requests process-requests)
(put export-api :format-output format-output)
(put export-api :*standard-input* *standard-input*)
(put export-api :*standard-output* *standard-output*)
(put export-api :*standard-error* *standard-error*)
(put export-api :*trace-output* *trace-output*)
(put export-api :*debug-io* *debug-io*)

# Macros used by contrib code -------------------------------------------------
(defmacro defslyfun [name args & body]
  ~(defn ,name ,args ,;body))

(var *debugger-hook* nil)
(put export-api :*debugger-hook* *debugger-hook*)

(defmacro with-slyk-interrupts [& body]
  ~(do ,;body))

(defn slynk-pprint [xs]
  (each x xs (print (print-for-emacs/prin1-to-string-for-emacs x *package*)))
  true)
(put export-api :slynk-pprint slynk-pprint)
