(use ../mini-test)
(import ../test-tools :as tt)

(defn- plist->table [plist]
  (def out @{})
  (var i 0)
  (while (< i (length plist))
    (put out (plist i) (plist (+ i 1)))
    (set i (+ i 2)))
  out)

(register-test
  {:name "compile-string success exposes empty Janet diagnostic envelope"
   :tags [:phase5 :compile :diagnostics]
   :covers ["compile-string-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def res (plist->table ((srv :emacs-rex!) '(compile-string-for-emacs "(+ 1 2)") :core nil 3001)))
             (assert= true (res :success))
             (assert= "3" (res :value))
             (assert= 1 (res :forms))
             (assert-true (array? (res :notes)))
             (assert= 0 (length (res :notes)))
             (assert-true (array? (res :diagnostics)))
             (assert= 0 (length (res :diagnostics)))
             (assert= :janet-diagnostics (res :diagnostic-model))
             (assert= false (res :cl-compiler-note-equivalent)))))})

(register-test
  {:name "compile-string failure exposes structured Janet diagnostic"
   :tags [:phase5 :compile :diagnostics]
   :covers ["compile-string-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def res (plist->table ((srv :emacs-rex!) '(compile-string-for-emacs "(+ 1") :core nil 3002)))
             (assert= false (res :success))
             (assert-true (array? (res :notes)))
             (assert-true (> (length (res :notes)) 0))
             (assert-true (array? (res :diagnostics)))
             (assert= 1 (length (res :diagnostics)))
             (def diagnostic (plist->table ((res :diagnostics) 0)))
             (assert= :error (diagnostic :severity))
             (assert= :compile-string (diagnostic :phase))
             (assert= :janet-diagnostics (diagnostic :diagnostic-model))
             (assert= false (diagnostic :cl-compiler-note-equivalent))
             (assert-true (string? (diagnostic :message))))))})

(register-test
  {:name "load-file failure exposes path-aware structured diagnostic"
   :tags [:phase5 :load :diagnostics]
   :covers ["load-file"]
   :fn (fn []
         (tt/with-test-server [srv]
           (do
             (def missing-path (string (os/cwd) "/test/fixtures/compile/does-not-exist.janet"))
             (def res (plist->table ((srv :emacs-rex!) (tuple 'load-file missing-path) :core nil 3003)))
             (assert= false (res :success))
             (assert= missing-path (res :path))
             (assert-true (array? (res :notes)))
             (assert-true (> (length (res :notes)) 0))
             (assert-true (array? (res :diagnostics)))
             (assert= 1 (length (res :diagnostics)))
             (def diagnostic (plist->table ((res :diagnostics) 0)))
             (assert= :error (diagnostic :severity))
             (assert= :load-file (diagnostic :phase))
             (assert= missing-path (diagnostic :path))
             (assert= :janet-diagnostics (diagnostic :diagnostic-model))
             (assert= false (diagnostic :cl-compiler-note-equivalent)))))})
