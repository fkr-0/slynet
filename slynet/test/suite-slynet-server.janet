# SLYNET Integration Test Suite – Server Startup, Connection, and Protocol Roundtrip

(import ../slynk_janet/slynk)
(import ../slynk_janet/rpc)
(import ../slynet-api)
(import net)
(import fiber)
(import os)

(defn test-server-startup []
  (var port 4010)
  (var host "127.0.0.1")
  (var dont-close true)
  (def server (start-server port host dont-close))
  (assert (= (server :port) port))
  (assert (= (server :host) host))
  (assert (server :running))
  (net/close (server :socket))
  :ok)

(defn test-connection-acceptance []
  (var port 4011)
  (var host "127.0.0.1")
  (var dont-close true)
  (def server (start-server port host dont-close))
  (def client (net/connect host port))
  (assert client)
  (net/close client)
  (net/close (server :socket))
  :ok)

(defn test-protocol-roundtrip []
  (var port 4012)
  (var host "127.0.0.1")
  (var dont-close true)
  (def server (start-server port host dont-close))
  (def client (net/connect host port))
  (def test-message "(:emacs-rex (quote (+ 1 2)) \"CL-USER\" :repl-thread 1)")
  # Write a SLYNK protocol message (length-prefixed)
  (defn send-packet [sock msg]
    (def bytes (string/bytes msg))
    (def len (string/format "%06x" (length bytes)))
    (net/send sock (string/bytes len))
    (net/send sock bytes))
  (send-packet client test-message)
  # Try to read a response (should not error, may be nil if not implemented)
  (defn read-packet [sock]
    (def header (net/recv sock 6))
    (if (= (length header) 6)
      (def len (tonumber header 16))
      (error "Invalid header"))
    (def body (net/recv sock len))
    (backend/utf8-to-string body))
  (try
    (def response (read-packet client))
    (assert (string? response))
    (print "Received response: " response)
    (net/close client)
    (net/close (server :socket))
    :ok
    ([err fib]
      (net/close client)
      (net/close (server :socket))
      (error (string "Protocol roundtrip failed: " err)))))

(defn run-all []
  (test-server-startup)
  (test-connection-acceptance)
  (test-protocol-roundtrip)
  :ok)

(run-all)