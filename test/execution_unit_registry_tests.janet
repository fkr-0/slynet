(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(defn- find-thread [threads id]
  (var found nil)
  (each thread threads
    (let [entry (plist->table thread)]
      (when (and (nil? found) (= id (entry :id)))
        (set found entry))))
  found)

(deftest p21-registers-and-transitions-execution-units {:tags [:phase21 :execution-unit-registry] :covers ["list-threads"]}
  (tt/with-test-server [srv]
    (def unit (plist->table ((srv :emacs-rex!) '(register-execution-unit "unit-p21" "Long eval" :eval "/tmp/unit.janet" 3 2) :core nil 2101)))
    (assert= "unit-p21" (unit :id))
    (assert= :running (unit :status))
    (assert= :eval (unit :current-role))
    (assert= "/tmp/unit.janet" (unit :source-path))
    (def threads ((srv :emacs-rex!) '(list-threads) :core nil 2102))
    (def listed (find-thread threads "unit-p21"))
    (assert-not-nil listed)
    (assert= :running (listed :status))
    (assert= :managed (listed :execution-unit-kind))
    (def interrupted (plist->table ((srv :emacs-rex!) '(interrupt-execution-unit "unit-p21") :core nil 2103)))
    (assert= :requested (interrupted :status))
    (assert= true (interrupted :interrupt-requested))
    (def after-interrupt (plist->table ((srv :emacs-rex!) '(execution-unit-status "unit-p21") :core nil 2104)))
    (assert= true (after-interrupt :interrupt-requested))
    (assert= :interrupt-requested (after-interrupt :status))
    (def completed (plist->table ((srv :emacs-rex!) '(complete-execution-unit "unit-p21" :completed "done") :core nil 2105)))
    (assert= :completed (completed :status))
    (assert= "done" (completed :last-output))))

(deftest p21-execution-unit-errors-are-visible {:tags [:phase21 :execution-unit-registry] :covers ["execution-unit-status"]}
  (tt/with-test-server [srv]
    ((srv :emacs-rex!) '(register-execution-unit "unit-p21-error" "Broken eval" :eval "/tmp/unit-error.janet" 5 1) :core nil 2111)
    (def errored (plist->table ((srv :emacs-rex!) '(complete-execution-unit "unit-p21-error" :error "boom") :core nil 2112)))
    (assert= :error (errored :status))
    (assert= "boom" (errored :last-output))
    (def status (plist->table ((srv :emacs-rex!) '(execution-unit-status "unit-p21-error") :core nil 2113)))
    (assert= :error (status :status))
    (assert= "boom" (status :last-output))))
