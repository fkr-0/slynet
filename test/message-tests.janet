# Test for SLYNET message pipeline: getpid request/response
#
# This test uses the with-test-server macro to start an in-process SLYNET server,
# sends a (:emacs-rex (getpid) "user" "0") message, and asserts the response
# is a valid protocol reply containing a numeric PID.

(import ../slynet/slynk_janet/test-server-macro :as m)
(import ../slynet/slynk_janet/rpc :as rpc)
# (import test)

# (defn- test-getpid []
#   (test/deftest "getpid returns numeric pid and correct protocol structure"
(m/with-test-server [client]
                    (client/send '(:emacs-rex (getpid) "user" 1))
                    (def resp (client/recv))
                    (print "Response:" resp)

                    (assert (tuple? resp) "Response should be a tuple")
                    (assert (= :return (get resp 0)) "Tag should be :return")

                    (def payload (get resp 1))
                    (assert (tuple? payload) "Payload should be a tuple")
                    (assert (= :ok (get payload 0)) "Payload tag should be :ok")

                    (def pid (get payload 1))
                    (assert (number? pid) "PID should be a number")

                    (assert (= 1 (get resp 2)) "Thread id should match")) # ))

# (defn- test-connection-info []
#   (test/deftest "connection-info returns a valid info struct"
#                 (with-test-server [client]
#                   (client/send '(:emacs-rex (slynk/connection-info) "user" 2))
#                   (def resp (client/recv))

#                   (assert (tuple? resp) "Response should be a tuple")
#                   (assert (= :return (get resp 0)) "Tag should be :return")

#                   (def payload (get resp 1))
#                   (assert (tuple? payload) "Payload should be a tuple")
#                   (assert (= :ok (get payload 0)) "Payload tag should be :ok")

#                   (def info (get payload 1))
#                   (assert (table? info) "Connection info should be a table")
#                   (assert (number? (get-in info [:pid])) "PID should be a number")
#                   (assert (= :spawn (get-in info [:style])) "Style should be :spawn")

#                   (assert (= 2 (get resp 2)) "Thread id should match"))))

# (defn- test-describe-function []
#   (test/deftest "describe-function returns a string"
#                 (with-test-server [client]
#                   (client/send '(:emacs-rex (slynet-describe-function "getpid") "user" 3))
#                   (def resp (client/recv))

#                   (assert (tuple? resp) "Response should be a tuple")
#                   (assert (= :return (get resp 0)) "Tag should be :return")

#                   (def payload (get resp 1))
#                   (assert (tuple? payload) "Payload should be a tuple")
#                   (assert (= :ok (get payload 0)) "Payload tag should be :ok")

#                   (def description (get payload 1))
#                   (assert (string? description) "Description should be a string")

#                   (assert (= 3 (get resp 2)) "Thread id should match"))))

# (defn- test-apropos []
#   (test/deftest "apropos returns a list of symbols"
#                 (with-test-server [client]
#                   (client/send '(:emacs-rex (apropos "get") "user" 4))
#                   (def resp (client/recv))

#                   (assert (tuple? resp) "Response should be a tuple")
#                   (assert (= :return (get resp 0)) "Tag should be :return")

#                   (def payload (get resp 1))
#                   (assert (tuple? payload) "Payload should be a tuple")
#                   (assert (= :ok (get payload 0)) "Payload tag should be :ok")

#                   (def symbols (get payload 1))
#                   (assert (indexed? symbols) "Symbols should be an array or tuple")
#                   (assert (every? |(symbol? $) symbols) "All elements should be symbols")

#                   (assert (= 4 (get resp 2)) "Thread id should match"))))

# (defn- test-eval-and-grab-output []
#   (test/deftest "eval-and-grab-output returns a string"
#                 (with-test-server [client]
#                   (client/send '(:emacs-rex (slynet-eval-and-grab-output "(+ 1 2)") "user" 5))
#                   (def resp (client/recv))

#                   (assert (tuple? resp) "Response should be a tuple")
#                   (assert (= :return (get resp 0)) "Tag should be :return")

#                   (def payload (get resp 1))
#                   (assert (tuple? payload) "Payload should be a tuple")
#                   (assert (= :ok (get payload 0)) "Payload tag should be :ok")

#                   (def result (get payload 1))
#                   (assert (string? result) "Result should be a string")
#                   (assert (= "3" result) "Result should be 3")

#                   (assert (= 5 (get resp 2)) "Thread id should match"))))

# (test-getpid)
# (test-connection-info)
# (test-describe-function)
# (test-apropos)
# (test-eval-and-grab-output)

# (test/run-tests)
