# Test utilities for SLYNET
# Provides an in-memory server harness and small helpers for tests.

(import ./slynet/slynk :as slynk)
(import ./slynet/rpc :as rpc)
(import ./test-runner :prefix "tr/")

(defn- ensure-send-handler []
  (when (nil? slynk/*emacs-io*)
    (set slynk/*emacs-io* @{:id "_test" :socket :mem :addr "in-memory" :package slynk/cl-package
                            :rex-handlers @{} :repl-results @{}})))

(defn make-server
  [&opt opts]
  (default opts @{})
  (def pkg (or (opts :package) slynk/cl-package))
  (def timeout (or (opts :timeout) 1.0))

  (ensure-send-handler)

  (def ch (ev/chan 32))
  (var replies @[])

  (def conn @{:id "_test"
              :socket :mem
              :addr "in-memory"
              :package pkg
              :rex-handlers @{}
              :repl-results @{}})

  (def prev-send (rpc/set-send-handler
                   (fn [_ msg]
                     (array/push replies msg)
                     (ev/give ch msg)
                     true)))

  (def prev-resolve (rpc/set-conn-resolver
                      (fn [remote-id]
                        (cond
                          (or (nil? remote-id) (= remote-id :current)) conn
                          (= remote-id (conn :id)) conn
                          true nil))))

  (defn await-one []
    (match (ev/take ch)
      [:return [:ok msg]] msg
      _ nil))

  (defn await-all [&opt idle-ms]
    (default idle-ms 20)
    (while true
      (match (ev/take ch idle-ms)
        [:ok _] nil
        _ (break)))
    (array/slice replies))

  {:conn conn
   :dispose (fn []
              (when prev-send (rpc/set-send-handler prev-send))
              (when prev-resolve (rpc/set-conn-resolver prev-resolve)))
   :chan ch
   :replies replies
   :await-one await-one
   :await-all await-all
   :emacs-rex!
   (fn [form &opt package thread id]
     (default package pkg)
     (default thread nil)
     (default id 1)
     (set replies @[])
     (slynk/process-message conn (rpc/create-emacs-rex-message form package thread id))
     (await-one))
   :send!
   (fn [decoded-msg]
     (set replies @[])
     (slynk/process-message conn decoded-msg)
     (await-all))})

(defmacro with-test-server [binding & body]
  (let [ms make-server
        [name opts] (match binding
                      [n o] [n o]
                      [n] [n {}]
                      _ (error "with-test-server requires [name opts?]"))]
    ~(let [,name (,ms ,opts)]

       ,;body
       (defer ((,name :dispose))))))

(with-test-server [srv]
  (print (= 6 ((srv :emacs-rex!) '(+ 1 2 3) :core nil 42))))
