(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/rpc :as rpc)
(import ../slynet/infrastructure :as inf)
(import ../slynet/init :as init)
(import ../slynet/slynk :as slynk)
(import ../slynet/cli :as cli)

(defn- reset-all! []
  (inf/reset-interfaces)
  (inf/reset-implementations)
  (init/initialize-backend)
  (init/initialize-rpc))

(register-test
  {:name "test server captures RPC replies"
   :tags [:integration :server]
   :fn (fn []
         (reset-all!)
         (tt/with-test-server [srv]
                              (rpc/register-channel-object {:mock true})
                              (assert= 6 ((srv :emacs-rex!) '(+ 1 2 3) :core nil 7))
                              (def replies (srv :replies))
                              (assert-true (> (length replies) 0))
                              # (assert= replies ((srv :await-all)))
))})

(register-test
  {:name "send! processes decoded messages"
   :tags [:integration :server]
   :fn (fn []
         (reset-all!)
         (tt/with-test-server [srv]
                              (def payload @[:return [:ok 'result]])
                              ((srv :send!) payload)
                              (def replies (srv :replies))
                              (assert= 1 (length replies))
                              (assert= payload (first replies))))})

(register-test
  {:name "server list-connections reflects mock"
   :tags [:unit :server]
   :fn (fn []
         (reset-all!)
         (set slynk/*connections* @{})
         (def conn @{:id "test" :addr "mem" :socket :mem})
         (put slynk/*connections* "test" conn)
         (def entries (slynk/list-connections))
         (assert= 1 (length entries))
         (assert= "test" (first (first entries)))
         (slynk/close-connection conn "testing")
         (assert= 0 (length (slynk/list-connections))))})

(register-test
  {:name "cli rpc initialization handles implementation key listings"
   :tags [:unit :server :cli]
   :fn (fn []
         (assert-true (boolean? (cli/initialize-rpc))))})

(register-test
  {:name "cli contrib initialization loads MREPL module"
   :tags [:unit :server :cli :mrepl]
   :fn (fn []
         (def results (cli/initialize-contrib-modules))
         (assert= :ok (get-in results [:mrepl :status]))
         (assert= :ok (get-in results [:arglists :status])))})
