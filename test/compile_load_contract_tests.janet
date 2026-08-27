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

(register-test
  {:name "compile multiple strings aggregates success and diagnostics"
   :tags [:phase5 :compile :diagnostics :compatibility]
   :covers ["compile-multiple-strings-for-emacs"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def good (plist->table
                       ((srv :emacs-rex!)
                         '(compile-multiple-strings-for-emacs @["(+ 1 2)" "(+ 4 5)"] :default)
                         :core nil 3004)))
           (assert= true (good :success))
           (assert= :ok (good :status))
           (assert= 2 (length (good :results)))
           (assert= 0 (length (good :diagnostics)))
           (assert= :emulated (good :support-class))
           (def mixed (plist->table
                        ((srv :emacs-rex!)
                          '(compile-multiple-strings-for-emacs @["(+ 1 2)" "(+ 1"] :default)
                          :core nil 3005)))
           (assert= false (mixed :success))
           (assert= :error (mixed :status))
           (assert= 1 (length (mixed :diagnostics)))))})

(register-test
  {:name "compile file if needed validates and optionally loads existing source"
   :tags [:phase5 :compile :load :compatibility]
   :covers ["compile-file-if-needed"]
   :fn (fn []
         (tt/with-test-server [srv]
           (def path (string (os/cwd) "/test/fixtures/compile_if_needed.janet"))
           (def checked (plist->table
                          ((srv :emacs-rex!) (tuple 'compile-file-if-needed path false)
                           :core nil 3006)))
           (assert= true (checked :success))
           (assert= :ok (checked :status))
           (assert= nil (checked :loaded))
           (assert= :validate-source-each-call (checked :compile-strategy))
           (assert= false (checked :cl-compile-file-cache-equivalent))
           (def loaded (plist->table
                         ((srv :emacs-rex!) (tuple 'compile-file-if-needed path true)
                          :core nil 3007)))
           (assert= true (loaded :success))
           (assert-not-nil (loaded :loaded))
           (assert= :emulated (loaded :support-class))))})
