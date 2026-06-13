(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(deftest p20-restart-scopes-continue-as-nil {:tags [:phase20 :restart-scopes]}
  (tt/with-test-server [srv]
    (def result (plist->table ((srv :emacs-rex!) '(instrumented-eval-with-restarts "(error \"boom\")" :continue-as-nil) :core nil 20001)))
    (def scope (plist->table (result :scope)))
    (assert= :continued (result :status))
    (assert= :continue-as-nil (result :restart))
    (assert= "nil" (result :value))
    (assert= :emulated (result :support-class))
    (assert= false (result :cl-restart-equivalent))
    (assert-true (string? (scope :id)))
    (assert= :synthetic (scope :class))
    (assert= :safe (scope :safety-level))
    (assert= true (scope :callable))
    (assert-true (string? (scope :explanation)))))

(deftest p20-restart-scopes-retry-retained-thunk {:tags [:phase20 :restart-scopes]}
  (tt/with-test-server [srv]
    (def result (plist->table ((srv :emacs-rex!) '(instrumented-eval-with-restarts "(error \"boom\")" :retry "(+ 1 2)") :core nil 20002)))
    (assert= :retried (result :status))
    (assert= :retry (result :restart))
    (assert= :emulated (result :support-class))
    (assert-true (array? (result :values)))
    (assert= "3" ((result :values) 0))))

(deftest p20-unsupported-restart-outside-scope {:tags [:phase20 :restart-scopes]}
  (tt/with-test-server [srv]
    (def result (plist->table ((srv :emacs-rex!) '(invoke-synthetic-restart :retry) :core nil 20003)))
    (assert= :unsupported (result :status))
    (assert= :unsupported (result :support-class))
    (assert= :retry (result :restart))
    (assert= false (result :callable))
    (assert-true (string? (result :unsupported-reason)))))
