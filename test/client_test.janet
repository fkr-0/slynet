(use ../mini-test)
(use ../test-tools)
(import ../mini-test :prefix "")
(import ../slynet/rpc :as rpc)
(import ../slynet/start :as server)

(deftest
  client-repl-connects-and-evals "client connects to server and shows prompt"
  (with-test-server [srv]
    (let [out-pipe (os/pipe)
          err-pipe (os/pipe)
          proc (os/execute ["janet" "slynet-client.janet" "--port"
                            (string (srv :port))] :p {:out (out-pipe 1)
                                                       :err (err-pipe 1)})]
      (os/proc-close (out-pipe 1))
      (os/proc-close (err-pipe 1))
      (def output (string (file/read (out-pipe 0) 2048)))
      (def err-output (string (file/read (err-pipe 0) 1024)))
      (os/proc-close proc)
      (assert-not-nil (string/find output "Connected to SLYNET server"))
      (assert-not-nil (string/find output "core> "))
      (assert (or (= 0 (length err-output))
                  (string/find err-output "Disconnected"))))))

(register-test
  {:name "client-batch-mode"
   :tags [:integration]
   :fn (fn []
         (with-test-server [srv]
           (let [out-pipe (os/pipe)
                 proc (os/execute ["janet" "slynet-client.janet" "--port"
                                    (string (srv :port)) "--eval" "(+ 1 2)"]
                                   :p {:out (out-pipe 1)})]
             (file/close (out-pipe 1))
             (def output (string (file/read (out-pipe 0) :all)))
             (os/proc-close proc)
             (assert-not-nil (string/find output "Connected to SLYNET server"))
             (assert-not-nil (string/find output "3"))))))})

# (register-test
#   {:name "client-wrong-args"
#    :tags [:integration]
#    :fn (let [err-pipe (os/pipe)
#              p (os/execute ["janet" "slynet-client.janet" "--wrong-arg"] :p {:err (err-pipe 1)})]
#          (os/proc-close (err-pipe 1))
#          (def output (file/read (err-pipe 0) :all))
#          (os/proc-close p)
#          (assert (string/find "Unknown argument" (string output))))})
