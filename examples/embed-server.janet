#!/usr/bin/env janet

# Minimal executable embedding example for SLYNET API v1.
#
# From an installed/extracted SLYNET tree:
#   JANET_PATH="$PWD" ./examples/embed-server.janet --check
#   JANET_PATH="$PWD" ./examples/embed-server.janet --port 4005

(import slynet/api :as slynet)

(defn- option-value [args option default]
  (def index (find |(= $ option) args))
  (if (and index (< (+ index 1) (length args)))
    (args (+ index 1))
    default))

(defn- has-option? [args option]
  (not (nil? (find |(= $ option) args))))

(defn -main [& args]
  (def check-only? (has-option? args "--check"))
  (def port (scan-number (option-value args "--port" "4005")))
  (def context (slynet/create-context))
  (defer (slynet/close-context context))

  # Context-free RPCs can be called without inventing a transport session.
  (unless (= :pong (slynet/call-rpc 'ping :pong))
    (error "SLYNET embedding ping failed"))

  (if check-only?
    (do
      (print "SLYNET API v" slynet/api-version " embedding check passed")
      (pp (slynet/context-status context)))
    (do
      (slynet/context-start-server
        context
        {:mode :tcp :host "127.0.0.1" :port port})
      (print "SLYNET embedded server listening on 127.0.0.1:" port)
      (pp (slynet/context-status context))
      (while true
        (os/sleep 1.0)))))

(apply -main (array/slice (dyn :args) 1))
