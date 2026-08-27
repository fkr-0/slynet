(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/print-for-emacs :as pfe)

(defn- expect-error [thunk]
  (try
    (do (thunk) nil)
    ([e _] e)))




(defn- wait-for-reply-count [srv count]
  (var waited 0)
  (while (and (< (length (srv :replies)) count)
              (< waited 1000))
    (ev/sleep 0.01)
    (set waited (+ waited 10)))
  (>= (length (srv :replies)) count))

(defn- find-message-by-op [messages op]
  (var found nil)
  (each msg messages
    (when (and (nil? found)
               (indexed? msg)
               (> (length msg) 0)
               (= op (msg 0)))
      (set found msg)))
  found)

(defn- find-frame-by-source-kind [frames source-kind]
  (var found nil)
  (each frame frames
    (def location (frame :location))
    (when (and (nil? found)
               (table? location)
               (= source-kind (location :source-kind)))
      (set found frame)))
  found)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(register-test
  {:name "execution units expose Janet thread facade metadata"
   :tags [:phase3 :debugger :threads]
   :covers ["list-threads"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def threads ((srv :emacs-rex!) '(list-threads) :core nil 1001))
           (assert-true (array? threads))
           (assert-true (> (length threads) 0))
           (def unit (plist->table (threads 0)))
           (assert= true (unit :execution-unit))
           (assert= :slynet-execution-unit (unit :thread-model))
           (assert= false (unit :cl-thread-equivalent))
           (assert-true (keyword? (unit :execution-unit-kind)))) )})

(register-test
  {:name "eval errors create condition records with synthetic abort restart"
   :tags [:phase3 :debugger :conditions]
   :covers ["debugger-info-for-emacs" "invoke-nth-restart"]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1002)))
           (def info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 1003))
           (def condition (get info :condition-record))
           (assert-true (table? condition) "condition record is structured")
           (assert-true (string? (condition :id)) "condition record has stable id")
           (assert= :evaluation-error (condition :kind))
           (assert-true (string? (condition :message)))
           (assert= :emulated (get condition :support-class))
           (def restarts (map |(plist->table $) (get info :restarts)))
           (assert-true (> (length restarts) 0))
           (def restart0 (restarts 0))
           (assert= "abort-to-repl" (restart0 :name))
           (assert= :synthetic (get restart0 :restart-kind))
           (assert= :emulated (get restart0 :support-class))
           (def invoked ((srv :emacs-rex!) '(invoke-nth-restart 0) :core nil 1004))
           (assert= :ok (invoked 0))
           (assert= "abort-to-repl" (invoked 1))))})

(register-test
  {:name "debugger frame locations use source index when callable is known"
   :tags [:phase3 :phase4 :debugger :frames :source-index]
   :covers ["debugger-info-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1005)))
           (def info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 1006))
           (def frames (get info :frames))
           (assert-true (array? frames))
           (assert-true (> (length frames) 0))
           (def frame (find-frame-by-source-kind frames :source-index))
           (assert-true (table? frame) "source-index fallback frame exists")
           (def location (frame :location))
           (assert= "trigger-debugger" (frame :callable))
           (assert-true (table? location))
           (assert= false (location :synthetic-location))
           (assert= :source-index (location :source-kind))
           (assert= "trigger-debugger" (location :name))
           (assert= :function (location :kind))
           (assert-true (string/find "slynet/slynk.janet" (location :file)))
           (assert-true (> (location :line) 0))
           (assert-true (> (location :column) 0))
           (assert-true (string/find "(defn trigger-debugger" (location :snippet)))) )})


(register-test
  {:name "debugger frames prefer native Janet debug stack facts"
   :tags [:phase3 :debugger :frames :janet-debug-stack]
   :covers ["debugger-info-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1009)))
           (def info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 1010))
           (def frames (get info :frames))
           (assert-true (array? frames))
           (assert-true (> (length frames) 0))
           (def frame (find-frame-by-source-kind frames :janet-debug-stack))
           (assert-true (table? frame) "native Janet debug stack frame exists")
           (def location (frame :location))
           (assert-true (table? location))
           (assert= :janet-debug-stack (location :source-kind))
           (assert= false (location :synthetic-location))
           (assert-true (or (= :error (location :janet-status))
                            (= :debug (location :janet-status))))
           (assert-true (number? (location :janet-pc)))
           (assert-true (string? (location :file)))
           (assert-true (> (location :line) 0))
           (assert-true (> (location :column) 0))))})


(register-test
  {:name "eval errors send debugger activation with truthful Janet metadata"
   :tags [:phase3 :debugger :emacs :janet-debug-stack]
   :covers ["debugger-info-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1011)))
           (assert-true (wait-for-reply-count srv 2) "error return plus debugger activation event")
           (def replies (srv :replies))
           (def activation (find-message-by-op replies :debug-activate))
           (assert-true (array? activation) "debug activation message is emitted")
           (def info (get activation 1))
           (assert-true (table? info) "debug activation payload is debugger state")
           (assert= true (get info :active))
           (def condition (get info :condition-record))
           (assert= :emulated (get condition :support-class))
           (assert= false (get condition :cl-condition-equivalent))
           (def restarts (map |(plist->table $) (get info :restarts)))
           (def restart0 (restarts 0))
           (assert= :synthetic (get restart0 :restart-kind))
           (assert= :emulated (get restart0 :support-class))
           (assert= false (get restart0 :cl-restart-equivalent))
           (def native-frame (find-frame-by-source-kind (get info :frames) :janet-debug-stack))
           (assert-true (table? native-frame) "native debug/stack frame is primary available frame")
           (def native-location (get native-frame :location))
           (assert= false (get native-location :synthetic-location))
           (assert= :janet-debug-stack (get native-location :source-kind))
           (assert-true (number? (get native-location :janet-pc)))
           (def synthetic-frame (find-frame-by-source-kind (get info :frames) :synthetic-facade))
           (assert-true (table? synthetic-frame) "synthetic fallback is still explicit")
           (assert= true (get (get synthetic-frame :location) :synthetic-location))))})

(register-test
  {:name "unresolved debugger frame locations keep synthetic facade source kind"
   :tags [:phase3 :debugger :frames]
   :covers ["debugger-info-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1007)))
           (def info ((srv :emacs-rex!) '(debugger-info-for-emacs) :core nil 1008))
           (def frames (get info :frames))
           (assert-true (array? frames))
           (assert-true (> (length frames) 1))
           (def frame (find-frame-by-source-kind frames :synthetic-facade))
           (assert-true (table? frame) "synthetic fallback frame exists")
           (def location (frame :location))
           (assert-true (table? location))
           (assert= true (location :synthetic-location))
           (assert= :synthetic-facade (location :source-kind))))})

(register-test
  {:name "wire printer handles tuple debug metadata without hashing tuple contents"
   :tags [:phase3 :debugger :wire]
   :fn (fn []
         (def payload
           @[(tuple :frame @{:args (tuple (fn [] 1) @{:x 1})})])
         (def printed (pfe/prin1-to-string-for-emacs payload nil))
         (assert-true (string? printed))
         (assert-true (not (nil? (string/find "frame" printed))))
         (assert-true (not (nil? (string/find "#<function>" printed))))
         (def cyclic @[])
         (array/push cyclic cyclic)
         (def cyclic-printed (pfe/prin1-to-string-for-emacs cyclic nil))
         (assert-true (string? cyclic-printed))
         (assert-true (not (nil? (string/find "#<...>" cyclic-printed)))))} )

(register-test
  {:name "debugger compatibility restart and frame package tools remain truthful"
   :tags [:phase3 :debugger :compatibility]
   :covers ["invoke-nth-restart-for-emacs" "frame-package-name"]
   :fn (fn []
         (tt/with-test-server [srv]
           (expect-error (fn [] ((srv :emacs-rex!) '(not-a-real-symbol) :core nil 1012)))
           (def package ((srv :emacs-rex!) '(frame-package-name 0) :core nil 1013))
           (assert= "core" package)
           (def invoked (plist->table
                          ((srv :emacs-rex!) '(invoke-nth-restart-for-emacs 1 0)
                           :core nil 1014)))
           (assert= :ok (invoked :status))
           (assert= 1 (invoked :level))
           (assert= 0 (invoked :restart-index))
           (assert= "abort-to-repl" (invoked :restart-name))
           (assert= :emulated (invoked :support-class))
           (assert= false (invoked :cl-restart-equivalent))))})

