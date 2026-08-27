(use ../mini-test)
(import ../slynet/api :as api)
(import ../slynet/slynet-api :as compat-api)

(defn expect-error [thunk]
  (try
    (do (thunk) nil)
    ([e _] e)))

(register-test
  {:name "stable Janet API initializes and resolves callable RPCs"
   :tags [:public-api :embedding]
   :covers ["ping"]
   :fn (fn []
         (def initialized (api/initialize))
         (assert= :ok (initialized :status))
         (assert= "1" api/api-version)
         (assert= api/version compat-api/version)
         (assert= api/create-context compat-api/create-context)
         (assert= api/context-start-server compat-api/context-start-server)
         (assert= api/context-stop-server compat-api/context-stop-server)
         (assert= api/close-context compat-api/close-context)
         (assert= api/context-status compat-api/context-status)
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
         (def err
           (expect-error
             (fn []
               (api/start-server {:mode :tcp
                                  :host "0.0.0.0"
                                  :port 4005
                                  :initialize false}))))
         (assert-not-nil err))})

(register-test
  {:name "stable Janet API context status stays transport independent"
   :tags [:public-api :embedding :lifecycle]
   :fn (fn []
         (def context (api/create-context))
         (def ready (api/context-status context))
         (assert= :slynet-context-status (ready :kind))
         (assert= :ready (ready :status))
         (assert= false (ready :closed))
         (assert= false (ready :owns-server))
         (assert= :transport-dependent (ready :session-state))
         (put context :server
              {:mode :tcp
               :host "127.0.0.1"
               :port 4555
               :transport {:close! (fn [] true)}})
         (put context :status :serving)
         (def serving (api/context-status context))
         (assert= true (serving :owns-server))
         (assert= :tcp (serving :server-mode))
         (assert= "127.0.0.1" (serving :server-host))
         (assert= 4555 (serving :server-port))
         (api/close-context context)
         (def closed (api/context-status context))
         (assert= :closed (closed :status))
         (assert= true (closed :closed)))})

(register-test
  {:name "stable Janet API lifecycle context owns deterministic teardown"
   :tags [:public-api :embedding :lifecycle]
   :fn (fn []
         (def context (api/create-context))
         (assert= :slynet-context (context :kind))
         (assert= :ready (context :status))
         (assert= false (context :closed))
         (var stopped false)
         # Inject the same public server-record shape returned by start-server;
         # this proves close-context owns teardown without binding a test port.
         (put context :server
              {:transport {:close! (fn [] (set stopped true) true)}})
         (put context :status :serving)
         (assert= true (api/close-context context))
         (assert= true stopped)
         (assert= nil (context :server))
         (assert= :closed (context :status))
         (assert= true (context :closed))
         (assert= true (api/close-context context))
         (def err
           (expect-error
             (fn [] (api/context-start-server context {:initialize false}))))
         (assert-not-nil err))})
