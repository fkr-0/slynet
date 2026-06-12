(use ../mini-test)
(import ../test-tools :as tt)

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
  {:name "source-aware eval returns source context and values"
   :tags [:phase16 :runtime-instrumentation]
   :fn (fn []
         (tt/with-test-server [srv]
           (def result ((srv :emacs-rex!) '(source-aware-eval "(+ 1 2)" "/tmp/source.janet" 4 2) :core nil 1601))
           (def table (plist->table result))
           (def context (plist->table (table :source-context)))
           (assert= :ok (table :status))
           (assert= "/tmp/source.janet" (context :path))
           (assert= 4 (context :line))
           (assert= 2 (context :column))
           (assert= true (context :source-aware-eval))
           (assert-true (array? (table :values)))
           (assert= "3" ((table :values) 0))))})

(register-test
  {:name "runtime instrumentation exposes restart scopes and cooperative interruption"
   :tags [:phase16 :runtime-instrumentation :restart-scopes]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1602)))
           (def scopes ((srv :emacs-rex!) '(list-restart-scopes) :core nil 1603))
           (assert-true (array? scopes))
           (assert-true (> (length scopes) 0))
           (def scope0 (plist->table (scopes 0)))
           (assert= :emulated (scope0 :support-class))
           (assert= false (scope0 :cl-restart-equivalent))
           (def interrupt (plist->table ((srv :emacs-rex!) '(interrupt-execution-unit "_test") :core nil 1604)))
           (assert= :requested (interrupt :status))
           (assert= true (interrupt :cooperative))
           (assert= :slynet-execution-unit (interrupt :thread-model))
           (def checkpoint (plist->table ((srv :emacs-rex!) '(debugger-step-checkpoint 0) :core nil 1605)))
           (assert= :pending (checkpoint :status))
           (assert= :emulated (checkpoint :support-class))))})
