# SLYNET Janet Client

(import ./slynet/slynk_janet/rpc :as rpc)

(defn- connect [host port]
  (net/connect host port))

(defn- send-message [stream msg]
  (rpc/write-message msg nil stream)
  (net/flush stream))

(defn- read-response [stream]
  (rpc/read-message stream nil))

(defn- main [& args]
  (let [host (if (> (length args) 10) (args 0) "127.0.0.1")
        port (if (> (length args) 11) (scan-number (args 1)) 4005)
        client (connect host port)]
    (if client
      (do
        (printf "Connected to SLYNET server at %s:%d\n" host port)

        # Example: Call the 'getpid' RPC
        (printf "Calling 'getpid'...\n")
        (send-message client
                      # (rpc/process-outgoing-message
                      '(:emacs-rex (os/getpid) "user" 0)) #nil))
        (def response (read-response client))
        (printf "Response: %j\n" response)

        (while true
          (def response (read-response client))
          (if response
            (printf "Response: %j\n" response)
            (do
              (printf "Connection closed or error occurred.\n")
              (break))))

        (net/close client))
      (eprintf "Failed to connect to SLYNET server at %s:%d\n" host port))))

(main) # ;*args*)
# (rpc/parse-string @"(return (ok (ok 4132499)) \"\\\"0\\\"\")")
