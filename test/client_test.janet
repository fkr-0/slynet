(use ../mini-test)
(import ../slynet-client :as client)

(deftest
  client-parse-args-defaults "client parser uses default host/port"
  (let [opts (client/parse-args @[])]
    (assert= "127.0.0.1" (opts :host))
    (assert= 4005 (opts :port))
    (assert= 0 (length (opts :eval)))))

(deftest
  client-parse-args-overrides "client parser accepts host, port, and eval forms"
  (let [opts (client/parse-args @["--host" "0.0.0.0" "--port" "4105" "--eval" "(+ 1 2)" "--eval" "(* 3 4)"])]
    (assert= "0.0.0.0" (opts :host))
    (assert= 4105 (opts :port))
    (assert= @["(+ 1 2)" "(* 3 4)"] (opts :eval))))

(deftest
  client-format-prompt-includes-condition "client prompt includes current condition marker"
  (assert= "core> [debug] " (client/format-prompt "core" nil nil nil "debug")))

(defn thrown-message [f]
  (var msg nil)
  (try
    (f)
    ([err _] (set msg (string err))))
  msg)

(defn contains-text? [needle haystack]
  (and (string? haystack)
       (not (= nil (string/find needle haystack)))))

(deftest
  client-parse-args-rejects-missing-option-values "client parser reports which option lacks a value"
  (let [host-err (thrown-message (fn [] (client/parse-args @["--host"])))
        port-err (thrown-message (fn [] (client/parse-args @["--port"])))
        eval-err (thrown-message (fn [] (client/parse-args @["--eval"])))]
    (assert-true (contains-text? "Missing value for --host" host-err) host-err)
    (assert-true (contains-text? "Missing value for --port" port-err) port-err)
    (assert-true (contains-text? "Missing value for --eval" eval-err) eval-err)))

(deftest
  client-parse-args-rejects-invalid-port "client parser rejects nonnumeric ports before connecting"
  (let [err (thrown-message (fn [] (client/parse-args @["--port" "not-a-port"])))]
    (assert-true (contains-text? "Invalid --port value: not-a-port" err) err)))

(deftest
  client-channel-write-values-resolves-awaiting-eval "client channel values resolve the awaiting eval promise"
  (let [state (client/make-state)
        promise (ev/chan 1)
        values @[]]
    (put state :channel-id 7)
    (put state :eval-promise promise)
    (client/handle-channel-message state 7 [:write-values values])
    (assert= [:ok values] (ev/take promise))
    (assert= nil (state :eval-promise))))

(deftest
  client-channel-prompt-updates-debugger-condition "client prompt tracks debugger condition text from channel payloads"
  (let [state (client/make-state)]
    (put state :channel-id 9)
    (client/handle-channel-message state 9 [:prompt "core" "core" nil nil "breakpoint"])
    (assert= "core> [breakpoint] " (state :prompt-string))))

(deftest
  client-send-eval-requires-mrepl-channel "client refuses eval before MREPL handshake initializes a channel"
  (let [err (thrown-message (fn [] (client/send-eval (client/make-state) :fake-stream "(+ 1 2)" true)))]
    (assert-true (contains-text? "MREPL channel not initialized" err) err)))
