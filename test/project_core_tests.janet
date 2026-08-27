(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/infrastructure :as inf)
(import ../slynet/init :as init)
(import ../slynet/slynk :as slynk)
(import ../slynet/rpc :as rpc)
(import ../slynet/backend :as backend)

(defn- wipe-registries! []
  (inf/reset-interfaces)
  (inf/reset-implementations)
  true)

(defn- expect-error [thunk]
  (try
    (do (thunk) nil)
    ([e _] e)))

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(register-test
  {:name "definterface registers metadata"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'test/example [:arg] "doc")
         (def meta (get (inf/list-interfaces) 'test/example))
         (assert-true meta "interface metadata stored")
         (assert= 'test/example (meta :name))
         (assert= [:arg] (meta :arglist-spec))
         (assert= "doc" (meta :doc)))})

(register-test
  {:name "definterface validates input"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (def err1 (expect-error (fn [] (inf/slynet-definterface "bad" [] "doc"))))
         (assert-true (string/find (string err1) "rpc-name") "rpc-name must be symbol")
         (def err2 (expect-error (fn [] (inf/slynet-definterface 'test/bad :oops "doc"))))
         (assert-true (string/find (string err2) "arglist-spec") "arglist-spec must be collection")
         (def err3 (expect-error (fn [] (inf/slynet-definterface 'test/bad [] :oops))))
         (assert-true (string/find (string err3) "docstring") "docstring must be string"))})

(register-test
  {:name "defimplementation registers function"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'test/double [:x] "doc")
         (def impl-fn (fn [x] (* 2 x)))
         (inf/defimpl 'test/double impl-fn)
         (assert= 10 (inf/run-implementation 'test/double 5)))})

(register-test
  {:name "initialize-backend clears registries"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'foo [] "doc")
         (inf/defimpl 'foo (fn [] :ok))
         (assert-true (get (inf/list-interfaces) 'foo))
         (assert= :ok (inf/run-implementation 'foo))
         (init/initialize-backend)
         (assert-true (empty? (inf/list-interfaces)))
         (assert-throws (inf/run-implementation 'foo)))})

(register-test
  {:name "missing implementation flagged"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'needs-impl [] "doc")
         (def ok? (init/initialize-rpc))
         (assert-false ok?)
         (inf/defimpl 'needs-impl (fn [] :ok))
         (assert-true (init/initialize-rpc)))})

(register-test
  {:name "implemented extension RPCs have interface declarations"
   :tags [:unit :phase17 :rpc-contract]
   :fn (fn []
         (inf/ensure-interfaces-initialized!)
         (slynk/ensure-core-implementations!)
         (each rpc ['source-aware-eval
                    'list-restart-scopes
                    'interrupt-execution-unit
                    'debugger-step-checkpoint
                    'debugger-frame-details
                    'thread-info
                    'inspect-for-emacs
                    'macroexpand-1-for-emacs
                    'macroexpand-all-for-emacs]
           (assert-true (inf/get-implementation rpc) (string rpc " has an implementation"))
           (assert-true (inf/get-interface rpc) (string rpc " has a declared interface")))
         (assert-true (inf/get-interface 'slynet-apropos)
                      "slynet-apropos contrib implementation has a declared interface"))})

(register-test
  {:name "ping roundtrip"
   :tags [:integration :server]
   :covers ["ping"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (assert= :pong ((srv :emacs-rex!) '(ping :pong) :core nil 11))))})

(register-test
  {:name "connection-info exposes basics"
   :tags [:integration :server]
   :covers ["connection-info"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def info ((srv :emacs-rex!) '(connection-info) :core nil 12))
                              (def table (plist->table info))
                              (assert-true (table? table))
                              (assert-true (number? (table :pid)))
                              (assert= :spawn (table :style))
                              (def encoding (plist->table (table :encoding)))
                              (assert-true (some |(= $ "utf-8-unix") (encoding :coding-systems)))
                              (def pkg-info (plist->table (table :package)))
                              (assert= "core" (pkg-info :name))
                              (assert-true (string? (pkg-info :prompt)))
                              (assert-true (array? (table :features)))
                              (assert= rpc/*wire-protocol-version* (table :version))))})

(register-test
  {:name "list-all-package-names includes core"
   :tags [:integration :server]
   :covers ["list-all-package-names"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def pkgs ((srv :emacs-rex!) '(list-all-package-names) :core nil 13))
                              (assert-true (array? pkgs))
                              (assert-true (some (fn [entry] (and (array? entry)
                                                                  (> (length entry) 0)
                                                                  (= "core" (entry 0)))) pkgs))))})

(register-test
  {:name "simple completions surface connection-info"
   :tags [:integration :server]
   :covers ["simple-completions"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def result ((srv :emacs-rex!) '(simple-completions "connection" "core") :core nil 14))
                              (def matches (result 0))
                              (assert-true (array? matches))
                              (assert-true (some |(= $ "connection-info") matches))
                              (assert-true (string? (result 1)))))})

(register-test
  {:name "flex completions surface connection-info"
   :tags [:integration :server]
   :covers ["flex-completions"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def result ((srv :emacs-rex!) '(flex-completions "conninfo" "core") :core nil 15))
                              (def matches (result 0))
                              (assert-true (array? matches))
                              (assert-true (some (fn [entry]
                                                   (and (array? entry)
                                                        (= "connection-info" (entry 0))))
                                                 matches))
                              (assert-true (string? (result 1)))))})

(register-test
  {:name "set-package updates prompt"
   :tags [:integration :server]
   :covers ["set-package"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def result ((srv :emacs-rex!) '(set-package "core") :core nil 16))
                              (def table (plist->table result))
                              (def pkg (plist->table (table :package)))
                              (assert= "core" (pkg :name))
                              (assert= "core" (table :prompt))))})

(register-test
  {:name "interactive-eval-region returns values"
   :tags [:integration :server]
   :covers ["interactive-eval-region"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def res ((srv :emacs-rex!) '(interactive-eval-region "(+ 1 2)\n(+ 2 3)") :core nil 17))
                              (def table (plist->table res))
                              (def values (table :values))
                              (assert= @["3" "5"] values)))})


(register-test
  {:name "backend interactive-eval reports aborts without shadowing string"
   :tags [:unit :backend :eval]
   :covers ["interactive-eval"]
   :fn (fn []
         (def result (backend/interactive-eval "(definitely-missing-function 1)"))
         (assert= :abort (result 0))
         (assert-true (string? (result 1)))
         (assert-true (not (nil? (string/find "Interactive evaluation error" (result 1))))))})

(register-test
  {:name "pprint-eval prints last value"
   :tags [:integration :server]
   :covers ["pprint-eval"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def res ((srv :emacs-rex!) '(pprint-eval "(def tmp-eval 10)\n(+ tmp-eval 5)") :core nil 18))
                              (assert= "15" res)))})

(register-test
  {:name "arglist rpc returns callable signature"
   :tags [:integration :server]
   :covers ["arglist"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def res ((srv :emacs-rex!) '(arglist array/push) :core nil 23))
                              (assert-true (string? res))))})

(register-test
  {:name "operator-arglist rpc mirrors arglist"
   :tags [:integration :server]
   :covers ["operator-arglist"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def res ((srv :emacs-rex!) '(operator-arglist array/push "core") :core nil 24))
                              (assert-true (string? res))))})

(register-test
  {:name "xref returns precise snippets for debugger symbol"
   :tags [:integration :server :xref]
   :covers ["find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def res ((srv :emacs-rex!) '(find-definitions-for-emacs "debugger-info-for-emacs") :core nil 54))
           (assert-true (array? res))
           (assert-true (> (length res) 0))
           (var function-hit nil)
           (each hit res
             (def table (plist->table hit))
             (when (and (nil? function-hit) (= :function (table :kind)))
               (set function-hit table)))
           (assert-not-nil function-hit)
           (assert-true (string? (function-hit :snippet)))
           (assert= "(defn debugger-info-for-emacs []" (function-hit :snippet))))})

(register-test
  {:name "find-definitions-for-emacs finds repo symbol"
   :tags [:integration :server :xref]
   :covers ["find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def res ((srv :emacs-rex!) '(find-definitions-for-emacs "connection-info") :core nil 26))
                              (assert-true (array? res))
                              (assert-true (> (length res) 0))
                              (def first-hit (plist->table (res 0)))
                              (assert-true (string? (first-hit :file)))
                              (assert-true (number? (first-hit :line)))
                              (assert-true (string? (first-hit :snippet)))))})

(register-test
  {:name "inspector push and pop roundtrip"
   :tags [:integration :server :inspector]
   :covers ["inspect-for-emacs" "inspector-pop"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def a (plist->table ((srv :emacs-rex!) '(inspect-for-emacs 42) :core nil 27)))
                              (def b (plist->table ((srv :emacs-rex!) '(inspect-for-emacs @[1 2 3]) :core nil 28)))
                              (def popped (plist->table ((srv :emacs-rex!) '(inspector-pop) :core nil 29)))
                              (assert-true (string? (a :title)))
                              (assert-true (array? (a :content)))
                              (assert-true (string? (b :title)))
                              (assert= (a :title) (popped :title))))})

(register-test
  {:name "inspector nth part drills into arrays"
   :tags [:integration :server :inspector]
   :covers ["inspect-for-emacs" "inspector-nth-part"]
   :fn (fn []
         (tt/with-test-server [srv]
                              ((srv :emacs-rex!) '(inspect-for-emacs @[10 20 30]) :core nil 33)
                              (def child (plist->table ((srv :emacs-rex!) '(inspector-nth-part 1) :core nil 34)))
                              (assert= "20" (child :title))
                              (assert-true (child :can-pop))))})

(register-test
  {:name "inspect current condition exposes debugger payload"
   :tags [:integration :server :inspector :debugger]
   :covers ["inspect-current-condition"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 55)))
                              (def inspected (plist->table ((srv :emacs-rex!) '(inspect-current-condition) :core nil 56)))
                              (assert-true (string? (inspected :title)))
                              (assert-true (array? (inspected :content)))
                              (assert= 5 (inspected :parts-count))))})

(register-test
  {:name "macroexpand and compile-string for emacs"
   :tags [:integration :server :compiler]
   :covers ["interactive-eval-region" "macroexpand-all" "macroexpand-1-for-emacs" "compile-string-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
                              ((srv :emacs-rex!) '(interactive-eval-region "(defmacro plus2 [x] (tuple '+ x 2))") :core nil 30)
                              (def expanded ((srv :emacs-rex!) '(macroexpand-1-for-emacs "(plus2 3)") :core nil 31))
                              (def expanded-all ((srv :emacs-rex!) '(macroexpand-all "(plus2 3)") :core nil 63))
                              (def compiled (plist->table ((srv :emacs-rex!) '(compile-string-for-emacs "(def compiled-target 9)\n(+ compiled-target 1)") :core nil 32)))
                              (assert-true (string? expanded))
                              (assert-true (string? expanded-all))
                              (assert= true (compiled :success))
                              (assert= "10" (compiled :value))))})

(register-test
  {:name "compile-string for emacs reports failures"
   :tags [:integration :server :compiler]
   :covers ["compile-string-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def compiled (plist->table ((srv :emacs-rex!) '(compile-string-for-emacs "(this-will-fail") :core nil 35)))
                              (assert= false (compiled :success))
                              (assert-true (array? (compiled :notes)))) )})

(register-test
  {:name "compile-file and load-file for emacs"
   :tags [:integration :server :compiler]
   :covers ["compile-file-for-emacs" "load-file"]
   :fn (fn []
         (def path "/home/user/code/slynet/tmp-slynet-load.janet")
         (def f (file/open path :w))
         (file/write f "(def tmp-load-target 10)\n(+ tmp-load-target 1)\n")
         (file/close f)
         (tt/with-test-server [srv]
                              (def compiled (plist->table ((srv :emacs-rex!) (tuple 'compile-file-for-emacs path) :core nil 36)))
                              (def loaded (plist->table ((srv :emacs-rex!) (tuple 'load-file path) :core nil 37)))
                              (assert= true (compiled :success))
                              (assert= true (loaded :success))
                              (assert= "11" (loaded :value))))})

(register-test
  {:name "debugger minimum loop surfaces state"
   :tags [:integration :server :debugger]
   :covers ["debugger-info-for-emacs" "backtrace" "frame-source-location" "frame-locals-and-catch-tags" "sly-db-continue"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 38)))
                              (def info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 39))
                              (def bt ((srv :emacs-rex!) '(backtrace) :core nil 40))
                              (def frame0 ((srv :emacs-rex!) '(debugger-frame-details 0) :core nil 57))
                              (def frame0-loc ((srv :emacs-rex!) '(frame-source-location 0) :core nil 58))
                              (def frame0-locals (plist->table ((srv :emacs-rex!) '(frame-locals-and-catch-tags 0) :core nil 59)))
                              (assert-true (or (= (info :active) true) (= (info :active) false)))
                              (assert-true (string? (info :condition)))
                              (assert-true (or (array? bt) (tuple? bt)))
                              (assert-true (table? frame0))
                              (assert-true (table? frame0-loc))
                              (assert-true (array? (frame0-locals :locals)))
                              (def cont ((srv :emacs-rex!) '(sly-db-continue) :core nil 41))
                              (assert= :ok (cont 0))))})

(register-test
  {:name "thread ops and utility probes respond"
   :tags [:integration :server :threads]
   :covers ["list-threads" "debug-nth-thread" "kill-nth-thread" "io-speed-test" "flow-control-test"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def threads ((srv :emacs-rex!) '(list-threads) :core nil 42))
                              (def t0 (plist->table ((srv :emacs-rex!) '(thread-info 0) :core nil 60)))
                              (assert-true (string? (t0 :name)))
                              (assert-true (or (= (t0 :current) true) (= (t0 :current) false)))
                              (def dbg ((srv :emacs-rex!) '(debug-nth-thread 0) :core nil 43))
                              (def t0-debug (plist->table ((srv :emacs-rex!) '(thread-info 0) :core nil 61)))
                              (def dbg-info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 62))
                              (def killed (plist->table ((srv :emacs-rex!) '(kill-nth-thread 0) :core nil 44)))
                              (def io (plist->table ((srv :emacs-rex!) '(io-speed-test 64) :core nil 45)))
                              (def flow (plist->table ((srv :emacs-rex!) '(flow-control-test 3) :core nil 46)))
                              (assert-true (array? threads))
                              (assert-true (> (length threads) 0))
                              (assert= true (dbg :active))
                              (assert= true (t0-debug :debugging))
                              (assert= (t0 :name) ((dbg-info :thread) :name))
                              (assert-true (string? (killed :killed)))
                              (assert= :ok (io :status))
                              (assert= :ok (flow :status))))})

(register-test
  {:name "slynk require and debug toggle work"
   :tags [:integration :server]
   :covers ["slynk-require" "toggle-debug-on-slynk-error"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def req (plist->table ((srv :emacs-rex!) '(slynk-require "apropos") :core nil 47)))
                              (def toggled ((srv :emacs-rex!) '(toggle-debug-on-slynk-error) :core nil 48))
                              (assert= :ok (req :status))
                              (assert-true (or (= toggled true) (= toggled false)))) )})

(register-test
  {:name "editor session smoke path"
   :tags [:integration :server :smoke]
   :covers ["ping" "connection-info" "compile-string-for-emacs" "find-definitions-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (assert= :pong ((srv :emacs-rex!) '(ping :pong) :core nil 49))
                              (def ci (plist->table ((srv :emacs-rex!) '(connection-info) :core nil 50)))
                              (def compile-res (plist->table ((srv :emacs-rex!) '(compile-string-for-emacs "(def smoke-value 5)\n(+ smoke-value 2)") :core nil 51)))
                              (def insp (plist->table ((srv :emacs-rex!) '(inspect-for-emacs @[7 8 9]) :core nil 52)))
                              (def xrefs ((srv :emacs-rex!) '(find-definitions-for-emacs "connection-info") :core nil 53))
                              (assert-true (number? (ci :pid)))
                              (assert= true (compile-res :success))
                              (assert= "7" (compile-res :value))
                              (assert-true (string? (insp :title)))
                              (assert-true (> (length xrefs) 0))))})

(register-test
  {:name "describe-function exposes metadata"
   :tags [:integration :server]
   :covers ["describe-function"]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def res ((srv :emacs-rex!) '(describe-function +) :core nil 25))
                              (def table (plist->table res))
                              (assert= "+" (table :name))
                              (assert-true (string? (table :arglist)))
                              (assert-true (or (= :function (table :type))
                                               (= :macro (table :type))))))})
(register-test
  {:name "value editing cycle"
   :tags [:integration :server]
   :covers ["value-for-editing" "commit-edited-value"]
   :fn (fn []
         (tt/with-test-server [srv]
                              ((srv :emacs-rex!) '(def editable-target 21) :core nil 19)
                              (assert= "21" ((srv :emacs-rex!) '(value-for-editing "editable-target") :core nil 20))
                              (assert= "42" ((srv :emacs-rex!) '(commit-edited-value "editable-target" "(* 6 7)") :core nil 21))
                              (assert= "42" ((srv :emacs-rex!) '(value-for-editing "editable-target") :core nil 22))))})

(register-test
  {:name "emacs-rex via test server"
   :tags [:integration :server]
   :fn (fn []
         (tt/with-test-server [srv]
                              (assert= 6 ((srv :emacs-rex!) '(+ 1 2 3) :core nil 42))))})
