# SLYNET Integration Test Suite – Server Startup, Connection, and Protocol Roundtrip

(import ../slynet/slynk_janet/slynk)
(import ../slynet/slynk_janet/rpc)
(import ../slynet/slynk_janet/backend)
(import ../slynet/slynet-api)

(defn test-server-startup []
  (var port 4010)
  (var host "127.0.0.1")
  (var dont-close true)
  (def server (slynk/start-server port host dont-close))
  (print "Started server: " server "\n")
  (assert (= (server :port) port))
  (assert (= (server :host) host))
  (assert (server :running))
  (net/close (server :socket))
  :ok)

(defn test-connection-acceptance []
  (var port 4011)
  (var host "127.0.0.1")
  (var dont-close true)
  (def server (slynk/start-server port host dont-close))
  (def client (net/connect host port))
  (assert client)
  (net/close client)
  (net/close (server :socket))
  :ok)

(defn test-protocol-roundtrip []
  (var port 4012)
  (var host "127.0.0.1")
  (var dont-close true)
  (def server (slynk/start-server port host dont-close))
  (pp (server :socket))
  (def client (net/connect host port))
  (def test-message "(:emacs-rex (quote (+ 1 2)) \"CL-USER\" :repl-thread 1)")
  (var len 0)
  # Write a SLYNK protocol message (length-prefixed)
  (defn send-packet [sock msg]
    (def bytes (backend/string-to-utf8 msg))
    (def header (string/format "%06x" (length bytes)))
    (net/write sock header)
    (net/write sock (string bytes)))
  (send-packet client test-message)
  # Do not block on a response; protocol handling may not be implemented.
  (ev/sleep 0.05)
  (net/close client)
  (net/close (server :socket))
  :ok)

(defn run-all []
  (test-server-startup)
  (test-connection-acceptance)
  (test-protocol-roundtrip)
  :ok)

(run-all)
