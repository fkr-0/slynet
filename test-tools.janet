# Test utilities for SLYNET
# Provides an in-memory server harness and small helpers for tests.

(import ./slynet/slynk :as slynk)
(import ./slynet/rpc :as rpc)
(import ./slynet/infrastructure :as inf)
(import ./test-runner :prefix "tr/")

(defn- ensure-send-handler []
  (when (nil? slynk/*emacs-io*)
    (set slynk/*emacs-io* @{:id "_test" :socket :mem :addr "in-memory" :package slynk/cl-package
                            :rex-handlers @{} :repl-results @{}})))

(defn reset-test-state! []
  (set slynk/*slynk-debug-p* true)
  (set slynk/*inspector-stack* @[])
  (set slynk/*inspector-counter* 0)
  (set slynk/*inspector-object-counter* 0)
  (inf/ensure-interfaces-initialized!)
  (slynk/ensure-core-implementations!)
  (inf/slynet-sync-rpc-registries!)
  true)

(defn make-server
  [&opt opts]
  (default opts @{})
  (def pkg (or (opts :package) slynk/cl-package))
  (def timeout (or (opts :timeout) 1.0))

  (ensure-send-handler)
  (def prev-debug slynk/*slynk-debug-p*)
  (def prev-inspector-stack slynk/*inspector-stack*)
  (def prev-inspector-counter slynk/*inspector-counter*)
  (def prev-inspector-object-counter slynk/*inspector-object-counter*)
  (set slynk/*slynk-debug-p* true)
  (set slynk/*inspector-stack* @[])
  (set slynk/*inspector-counter* 0)
  (set slynk/*inspector-object-counter* 0)

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

  (defn wait-for-replies [&opt timeout-ms]
    (default timeout-ms 1000)
    (var waited 0)
    (while (and (= (length replies) 0)
                (< waited timeout-ms))
      (ev/sleep 0.01)
      (set waited (+ waited 10)))
    (> (length replies) 0))

  (defn await-one [&opt timeout-ms]
    (default timeout-ms 1000)
    (when (not (wait-for-replies timeout-ms))
      (error "timeout waiting for reply"))
    (match (first replies)
      [:return [:ok value] & _] value
      [:return [:abort reason] & _] (error reason)
      msg msg))

  (defn await-all [&opt timeout-ms]
    (default timeout-ms 1000)
    (wait-for-replies timeout-ms)
    (array/slice replies))

  {:conn conn
   :dispose (fn []
              (set slynk/*slynk-debug-p* prev-debug)
              (set slynk/*inspector-stack* prev-inspector-stack)
              (set slynk/*inspector-counter* prev-inspector-counter)
              (set slynk/*inspector-object-counter* prev-inspector-object-counter)
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
     (array/clear replies)
     (slynk/process-message conn (rpc/create-emacs-rex-message form package thread id))
     (await-one))
   :send!
   (fn [decoded-msg]
     (array/clear replies)
     (slynk/process-message conn decoded-msg)
     (await-one))})

(defmacro with-test-server [binding & body]
  (let [ms make-server
        [name opts] (match binding
                      [n o] [n o]
                      [n] [n {}]
                      _ (error "with-test-server requires [name opts?]"))]
    ~(let [,name (,ms ,opts)]

       ,;body
       (defer ((,name :dispose))))))
