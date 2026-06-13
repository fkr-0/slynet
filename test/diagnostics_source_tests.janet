(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(defn- first-diagnostic [envelope]
  (def table (plist->table envelope))
  (plist->table ((table :diagnostics) 0)))

(deftest p22-compile-string-diagnostics-include-source-index-location {:tags [:phase22 :diagnostics-source]}
  (tt/with-test-server [srv]
    (def envelope ((srv :emacs-rex!) '(compile-string-for-emacs "(bad" "/tmp/p22/source.janet" 7 4) :core nil 2201))
    (def diag (first-diagnostic envelope))
    (assert= :error (diag :severity))
    (assert= :compile-string (diag :phase))
    (assert= "/tmp/p22/source.janet" (diag :path))
    (assert= 7 (diag :line))
    (assert= 4 (diag :column))
    (assert= :slynet-diagnostic-source (diag :source-index))
    (assert= false (diag :cl-compiler-note-equivalent))))

(deftest p22-runtime-errors-normalize-to-diagnostics {:tags [:phase22 :diagnostics-source :runtime-error]}
  (tt/with-test-server [srv]
    (def envelope ((srv :emacs-rex!) '(runtime-error-diagnostics "(not-a-real-symbol)" "/tmp/p22/runtime.janet" 8 2) :core nil 2202))
    (def table (plist->table envelope))
    (def diag (first-diagnostic envelope))
    (assert= :error (table :status))
    (assert= :runtime-error (diag :phase))
    (assert= "/tmp/p22/runtime.janet" (diag :path))
    (assert= 8 (diag :line))
    (assert= 2 (diag :column))
    (assert= :janet-diagnostics (table :diagnostic-model))
    (assert= false (table :cl-compiler-note-equivalent))))

(deftest p22-test-failures-normalize-to-diagnostics {:tags [:phase22 :diagnostics-source :test-failure]}
  (tt/with-test-server [srv]
    (def envelope ((srv :emacs-rex!) '(test-failure-diagnostic "failing-test" "/tmp/p22/test.janet" 12 1 "expected true") :core nil 2203))
    (def diag (first-diagnostic envelope))
    (assert= :error (diag :severity))
    (assert= :test-failure (diag :phase))
    (assert= "failing-test" (diag :test-name))
    (assert= "/tmp/p22/test.janet" (diag :path))
    (assert= 12 (diag :line))
    (assert= "expected true" (diag :message))))
