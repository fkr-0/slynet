(use ../test-runner)
(import ../slynet/slynk :as slynk)
(import ../slynet/rpc :as rpc)

(register-test
  {:name "process-channel-send dispatches actions"
   :tags [:unit :server]
   :fn (fn []
         (def handled @{:process 0 :inspect 0 :teardown 0 :clear 0 :arg nil})
         (def channel
           @{:mrepl-channel-process (fn [arg]
                                      (put handled :process (+ 1 (handled :process)))
                                      (put handled :arg arg))
             :mrepl-channel-inspect-object (fn [_ _]
                                             (put handled :inspect (+ 1 (handled :inspect))))
             :mrepl-channel-teardown (fn [] (put handled :teardown (+ 1 (handled :teardown))))
             :mrepl-channel-clear-history (fn [] (put handled :clear (+ 1 (handled :clear))))})
         (def cid (rpc/register-channel-object channel))
         (slynk/process-channel-send nil cid [:process "(print :ok)"])
         (assert= 1 (handled :process))
         (assert= "(print :ok)" (handled :arg))
         (slynk/process-channel-send nil cid [:inspect-object 0 0])
         (assert= 1 (handled :inspect))
         (slynk/process-channel-send nil cid [:clear-history])
         (assert= 1 (handled :clear))
         (slynk/process-channel-send nil cid [:teardown])
         (assert= 1 (handled :teardown)))})
