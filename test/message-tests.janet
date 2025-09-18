(use ../test-runner)
(import ../test-tools :as tt)

(register-test
  {:name "getpid returns numeric pid"
   :tags [:integration :server]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def resp ((srv :emacs-rex!) '(os/getpid) :core nil 1))
                              (assert-true (number? resp))))})
