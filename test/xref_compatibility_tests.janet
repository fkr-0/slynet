(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/xref :as xref)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(def fixture-root (string (os/cwd) "/test/fixtures/xref"))
(def sample-a (string fixture-root "/sample_a.janet"))
(def sample-b (string fixture-root "/sample_b.janet"))
(def sample-set (string fixture-root "/sample_set.janet"))

(defn- first-location [locations]
  (assert-true (> (length locations) 0))
  (locations 0))

(defn- ensure-dir [path]
  (try (os/mkdir path) ([_ _] nil))
  path)

(register-test
  {:name "static xref parses all forms and preserves Janet parser sourcemaps"
   :tags [:phase8 :xref :static-analysis]
   :covers ["who-calls" "who-binds" "who-sets" "list-callers"]
   :fn (fn []
         (xref/clear-xref-database)
         (xref/index-files @[sample-a sample-b sample-set])

         (def target-call (first-location (xref/who-calls 'fixture-target)))
         (assert= sample-b (target-call :file))
         (assert= 5 (target-call :line))
         (assert= 3 (target-call :column))
         (assert= :parser-sourcemap (target-call :location-precision))
         (assert= 'fixture-helper (target-call :context-name))

         (def helper-call (first-location (xref/list-callers 'fixture-helper)))
         (assert= sample-b (helper-call :file))
         (assert= 8 (helper-call :line))
         (assert= 3 (helper-call :column))
         (assert= 'fixture-caller (helper-call :context-name))

         (def caller-binding (first-location (xref/who-binds 'fixture-caller)))
         (assert= sample-b (caller-binding :file))
         (assert= 7 (caller-binding :line))
         (assert= 1 (caller-binding :column))

         (def state-set (first-location (xref/who-sets 'fixture-state)))
         (assert= sample-set (state-set :file))
         (assert= 4 (state-set :line))
         (assert= 3 (state-set :column))
         (assert= 'fixture-update (state-set :context-name)))})

(register-test
  {:name "xref compatibility RPCs return normalized source navigation hits"
   :tags [:phase8 :xref :rpc]
   :covers ["who-calls" "who-binds" "who-sets" "list-callers"]
   :fn (fn []
         (xref/clear-xref-database)
         (tt/with-test-server [srv]
           (def calls ((srv :emacs-rex!) '(who-calls "fixture-target") :core nil 8101))
           (def call (plist->table (first-location calls)))
           (assert= "fixture-helper" (call :name))
           (assert= "fixture-target" (call :query-name))
           (assert= "fixture-helper" (call :context-name))
           (assert= :call (call :xref-kind))
           (assert= :slynet-static-xref (call :source-index))
           (assert= sample-b (call :file))
           (assert= 5 (call :line))
           (assert= 3 (call :column))
           (assert= :parser-sourcemap (call :location-precision))
           (assert= :native (call :support-class))

           (def bindings ((srv :emacs-rex!) '(who-binds "fixture-caller") :core nil 8102))
           (def binding (plist->table (first-location bindings)))
           (assert= :binding (binding :xref-kind))
           (assert= 7 (binding :line))

           (def sets ((srv :emacs-rex!) '(who-sets "fixture-state") :core nil 8103))
           (def set-hit (plist->table (first-location sets)))
           (assert= :set (set-hit :xref-kind))
           (assert= sample-set (set-hit :file))
           (assert= 4 (set-hit :line))

           (def lower ((srv :emacs-rex!) '(list-callers "fixture-helper") :core nil 8104))
           (def lower-hit (plist->table (first-location lower)))
           (assert= :call (lower-hit :xref-kind))
           (assert= "fixture-caller" (lower-hit :name))
           (assert= "fixture-helper" (lower-hit :query-name))
           (assert= 8 (lower-hit :line))))})

(register-test
  {:name "static xref refresh replaces edited facts and prunes deleted files"
   :tags [:phase8 :xref :static-analysis :cache]
   :fn (fn []
         (def root (ensure-dir (string "/tmp/slynet-xref-refresh-" (os/getpid))))
         (def file (string root "/caller.janet"))
         (spit file "(defn caller [] (old-call))\n")
         (xref/clear-xref-database)
         (xref/refresh-project root)
         (assert= 1 (length (xref/who-calls 'old-call)))
         (os/sleep 1.05)
         # old-call/new-call have equal byte length: timestamp, not size, must
         # invalidate the file and prior call facts must be replaced.
         (spit file "(defn caller [] (new-call))\n")
         (xref/refresh-project root)
         (assert= 0 (length (xref/who-calls 'old-call)))
         (assert= 1 (length (xref/who-calls 'new-call)))
         (os/rm file)
         (xref/refresh-project root)
         (assert= 0 (length (xref/who-calls 'new-call))))})

(register-test
  {:name "compiler macroexpand compatibility is explicit Janet emulation"
   :tags [:phase13 :compile :macroexpand :compatibility]
   :covers ["compiler-macroexpand-1" "compiler-macroexpand"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def once (plist->table
                       ((srv :emacs-rex!)
                        '(compiler-macroexpand-1 "(when true 42)")
                        :core nil 8110)))
           (assert= :ok (once :status))
           (assert= :compiler-macroexpand-1 (once :operation))
           (assert= :emulated (once :support-class))
           (assert= false (once :cl-compiler-macroexpand-equivalent))
           (assert= false (once :environment-provided))
           (assert= false (once :environment-supported))
           (assert-true (string? (once :expansion)))

           (def repeated (plist->table
                           ((srv :emacs-rex!)
                            '(compiler-macroexpand "(when true 42)" :fake-env)
                            :core nil 8111)))
           (assert= :ok (repeated :status))
           (assert= :compiler-macroexpand (repeated :operation))
           (assert= true (repeated :environment-provided))
           (assert= false (repeated :environment-supported))
           (assert= false (repeated :cl-macroexpand-equivalent))))})
