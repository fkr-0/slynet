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


(register-test
  {:name "extension candidates expose concrete workaround facades"
   :tags [:phase16 :janet-extension-candidates]
   :fn (fn []
         (tt/with-test-server [srv]
           (def metadata (plist->table ((srv :emacs-rex!)
                                         '(register-function-metadata "demo-fn" [:x :y] "demo metadata" :user)
                                         :core nil 1610)))
           (assert= "demo-fn" (metadata :name))
           (assert= :workaround (metadata :support-class))
           (assert= false (metadata :native-janet-metadata))
           (def fetched (plist->table ((srv :emacs-rex!) '(function-metadata "demo-fn") :core nil 1611)))
           (assert= [:x :y] (fetched :arglist))
           (assert= :metadata-registry (fetched :source))

           (def source-result ((srv :emacs-rex!)
                                '(source-aware-eval "(+ 40 2)" "/tmp/source-map-demo.janet" 9 4)
                                :core nil 1612))
           (def source-table (plist->table source-result))
           (def context (plist->table (source-table :source-context)))
           (assert-true (string? (context :eval-id)))
           (assert= :source-aware-eval (context :source-map-kind))
           (assert= :workaround (context :support-class))
           (def source-map (plist->table ((srv :emacs-rex!)
                                           @['lookup-eval-source-map (context :eval-id)]
                                           :core nil 1613)))
           (assert= "/tmp/source-map-demo.janet" (source-map :path))
           (assert= false (source-map :stable-native-source-map))

           (def instrumented ((srv :emacs-rex!)
                               '(record-instrumentation-event "demo-fn" :entry [1 2])
                               :core nil 1614))
           (def event (plist->table instrumented))
           (assert= :recorded (event :status))
           (assert= :slynet-wrapper (event :hook-kind))
           (assert= false (event :native-instrumentation-hook))
           (def events ((srv :emacs-rex!) '(list-instrumentation-events) :core nil 1615))
           (assert-true (> (length events) 0))

           (def caps (plist->table ((srv :emacs-rex!) '(debugger-control-capabilities) :core nil 1616)))
           (assert= :pending-design (caps :support-class))
           (assert= false (caps :native-resumable-debugger))
           (assert-true (array? (caps :operations)))
           (def step (plist->table ((srv :emacs-rex!) '(debugger-control-action :step 0) :core nil 1617)))
           (assert= :unsupported (step :status))
           (assert= :pending-design (step :support-class))))})

(register-test
  {:name "debug frame locals expose Janet slot workaround metadata"
   :tags [:phase16 :rich-debug-frame-locals :debugger]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1620)))
           (def info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 1621))
           (def frames (info :frames))
           (var native-frame nil)
           (each frame frames
             (when (and (nil? native-frame)
                        (= :janet-debug-stack ((frame :location) :source-kind)))
               (set native-frame frame)))
           (assert-true (table? native-frame))
           (assert= :workaround (native-frame :locals-support-class))
           (assert= false (native-frame :cl-lexical-locals-equivalent))
           (assert-true (number? (native-frame :janet-slots-count)))
           (assert-true (array? (native-frame :locals)))))})
