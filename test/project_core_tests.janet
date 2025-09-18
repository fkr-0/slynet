(use ../test-runner)
(import ../test-tools :as tt)
(import ../slynet/infrastructure :as inf)
(import ../slynet/init :as init)
(import ../slynet/slynk :as slynk)

(defn- wipe-registries! []
  (inf/reset-interfaces)
  (inf/reset-implementations)
  true)

(defn- expect-error [thunk]
  (try
    (do (thunk) nil)
    ([e _] e)))

(register-test
  {:name "definterface registers metadata"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'test/example [:arg] "doc")
         (def meta (get (inf/list-interfaces) 'test/example))
         (assert-true meta "interface metadata stored")
         (assert= 'test/example (meta :name))
         (assert= [:arg] (meta :arglist-spec))
         (assert= "doc" (meta :doc)))})

(register-test
  {:name "definterface validates input"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (def err1 (expect-error (fn [] (inf/slynet-definterface "bad" [] "doc"))))
         (assert-true (string/find err1 "rpc-name") "rpc-name must be symbol")
         (def err2 (expect-error (fn [] (inf/slynet-definterface 'test/bad :oops "doc"))))
         (assert-true (string/find err2 "arglist-spec") "arglist-spec must be collection")
         (def err3 (expect-error (fn [] (inf/slynet-definterface 'test/bad [] :oops))))
         (assert-true (string/find err3 "docstring") "docstring must be string"))})

(register-test
  {:name "defimplementation registers function"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'test/double [:x] "doc")
         (def impl-fn (fn [x] (* 2 x)))
         (inf/defimpl 'test/double impl-fn)
         (assert= 10 (inf/run-implementation 'test/double 5)))})

(register-test
  {:name "initialize-backend clears registries"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'foo [] "doc")
         (inf/defimpl 'foo (fn [] :ok))
         (assert-true (get (inf/list-interfaces) 'foo))
         (assert= :ok (inf/run-implementation 'foo))
         (init/initialize-backend)
         (assert-true (empty? (inf/list-interfaces)))
         (assert-throws (inf/run-implementation 'foo)))})

(register-test
  {:name "missing implementation flagged"
   :tags [:unit]
   :fn (fn []
         (wipe-registries!)
         (inf/slynet-register-interface-rt! 'needs-impl [] "doc")
         (def ok? (init/initialize-rpc))
         (assert-false ok?)
         (inf/defimpl 'needs-impl (fn [] :ok))
         (assert-true (init/initialize-rpc)))})

(register-test
  {:name "emacs-rex via test server"
   :tags [:integration :server]
   :fn (fn []
         (wipe-registries!)
         (tt/with-test-server [srv]
           (assert= 6 ((srv :emacs-rex!) '(+ 1 2 3) :core nil 42))))})
