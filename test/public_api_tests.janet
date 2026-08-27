(import ../mini-test :as t)
(import ../slynet/api :as api)
(import ../slynet/slynet-api :as compat-api)

(def register-test t/register-test)
(def assert= t/assert=)
(def assert-true t/assert-true)
(def assert-not-nil t/assert-not-nil)
(def expect-error t/expect-error)

(register-test
  {:name "stable Janet API initializes and resolves callable RPCs"
   :tags [:public-api :embedding]
   :covers ["ping"]
   :fn (fn []
         (def initialized (api/initialize))
         (assert= :ok (initialized :status))
         (assert= "1" api/api-version)
         (assert= api/version compat-api/version)
         (assert-not-nil (api/rpc-interface 'ping))
         (assert-true (function? (api/rpc-implementation 'ping)))
         (assert= :pong (api/call-rpc 'ping :pong)))})

(register-test
  {:name "stable Janet API exposes explicit embedding capabilities"
   :tags [:public-api :embedding]
   :fn (fn []
         (def caps (api/capabilities))
         (assert= :stable (caps :stability))
         (assert= :denied (caps :remote-bind-default))
         (assert= "127.0.0.1" (caps :default-host))
         (assert= true (caps :in-process-rpc)))})

(register-test
  {:name "stable Janet API refuses accidental remote TCP bind"
   :tags [:public-api :security]
   :fn (fn []
         (expect-error
           (fn []
             (api/start-server {:mode :tcp
                                :host "0.0.0.0"
                                :port 4005
                                :initialize false}))))})
