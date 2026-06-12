# SLYNET Janet Client - MREPL-aware CLI

(import ./slynet/rpc :as rpc)

(def default-host "127.0.0.1")
(def default-port 4005)

(defn connect-socket [host port]
  (try
    (net/connect host port)
    ([err _]
      (eprintf "Failed to connect to SLYNET server at %s:%d (%s)\n" host port err)
      nil)))

(defn write-message [stream msg]
  (rpc/write-message msg nil stream)
  (net/flush stream))

(defn read-message [stream]
  (rpc/read-message stream nil))

(defn make-state []
  @{:pending @{}
    :next-id 1
    :channel-id nil
    :thread-id nil
    :prompt-string "> "
    :eval-promise nil
    :running true})

(defn format-prompt [pkg nick pending history condition]
  (var base (string pkg "> "))
  (when (and condition (> (length condition) 0))
    (set base (string base "[" condition "] ")))
  base)

(defn wait-loop [pred &opt timeout-ms]
  (default timeout-ms 1000)
  (var waited 0)
  (while (and (not (pred)) (< waited timeout-ms))
    (ev/sleep 0.01)
    (set waited (+ waited 10)))
  (pred))

(defn deliver-pending [state id payload]
  (when-let [ch (get (state :pending) id)]
    (ev/give ch payload)
    (put (state :pending) id nil)))

(defn notify-eval [state payload]
  (when-let [promise (state :eval-promise)]
    (ev/give promise payload)
    (put state :eval-promise nil)))

(defn handle-channel-message [state channel payload]
  (when (nil? (state :channel-id))
    (put state :channel-id channel))
  (when (= channel (state :channel-id))
    (let [kind (payload 0)]
      (case kind
        :write-string
        (do (printf "%s" (payload 1)) (flush))

        :write-values
        (do (let [values (payload 1)]
              (each entry values
                (printf "%s\n" (entry 0)))
              (flush)
              (notify-eval state [:ok values])))

        :evaluation-aborted
        (let [reason (payload 1)]
          (eprintf "Evaluation aborted: %s\n" reason)
          (notify-eval state [:abort reason]))

        :prompt
        (let [pkg (payload 1)
              nick (payload 2)
              pending (payload 3)
              history (payload 4)
              condition (if (> (length payload) 5) (payload 5) nil)]
          (put state :prompt-string (format-prompt pkg nick pending history condition)))

        :describe-entry
        (do (printf "%s\n" (payload 1)) (flush))

        :clear-history nil

        (printf "Unhandled channel payload: %q\n" payload)))))

(defn handle-message [state message]
  (match message
    [:return payload id]
    (deliver-pending state id payload)

    [:channel-send channel payload]
    (handle-channel-message state channel payload)

    [:channel-close channel]
    (when (= channel (state :channel-id))
      (printf "Channel %s closed by server.\n" channel)
      (flush)
      (put state :running false))

    [:slynk-disconnect reason]
    (do (printf "Disconnected: %s\n" reason)
        (flush)
        (put state :running false))

    msg
    (printf "Unhandled message: %q\n" msg)))

(defn perform-handshake! [state stream]
  (def req-id (state :next-id))
  (put state :next-id (+ req-id 1))
  (write-message stream (rpc/create-emacs-rex-message '(create-mrepl) "user" nil req-id))

  (var handshake nil)
  (while (nil? handshake)
    (def msg (read-message stream))
    (when (nil? msg)
      (error "Connection closed during handshake"))
    (match msg
      [:return payload id]
      (if (= id req-id)
        (set handshake payload)
        (deliver-pending state id payload))

      [:channel-send channel payload]
      (handle-channel-message state channel payload)

      other
      (handle-message state other)))

  (match handshake
    [:ok [channel thread]]
    (do (put state :channel-id channel)
        (put state :thread-id thread)
        true)
    [:abort reason]
    (error (string "create-mrepl aborted: " reason))
    other
    (error (string "Unexpected handshake payload: " other))))

(defn start-reader! [state stream]
  (def reader
    (fiber/new
      (fn []
        (while (state :running)
          (try
            (let [msg (read-message stream)]
              (if (nil? msg)
                (put state :running false)
                (handle-message state msg)))
            ([err _]
              (eprintf "Reader error: %s\n" err)
              (put state :running false)
              (break)))))))
  (resume reader)
  reader)

(defn send-eval [state stream code &opt await?]
  (default await? false)
  (when (and await? (state :eval-promise))
    (error "Evaluation already pending"))
  (when (not (state :channel-id))
    (error "MREPL channel not initialized"))
  (when await?
    (put state :eval-promise (ev/chan 1)))
  (write-message stream [:channel-send (state :channel-id) [:process code]])
  (when await?
    (match (ev/take (state :eval-promise))
      [:ok values] values
      [:abort reason] (error reason))))

(defn send-teardown [state stream]
  (when-let [channel (state :channel-id)]
    (write-message stream [:channel-send channel [:teardown]])))

(defn wait-for-prompt [state]
  (wait-loop (fn [] (state :prompt-string))))

(defn interactive-loop [state stream]
  (printf "Type Janet code and press Enter to evaluate. Type :quit to exit.\n")
  (flush)
  (wait-for-prompt state)
  (while (state :running)
    (printf "%s" (state :prompt-string))
    (flush)
    (def line (file/read stdin :line))
    (if (or (nil? line) (= line ":quit"))
      (do
        (printf "Exiting.\n")
        (flush)
        (send-teardown state stream)
        (put state :running false))
      (do
        (def code (string/trim line))
        (when (> (length code) 0)
          (try
            (send-eval state stream code false)
            ([err _]
              (eprintf "Error sending evaluation: %s\n" err)
              (file/flush stderr))))))))

(defn run-batch [state stream forms]
  (each form forms
    (try
      (send-eval state stream form true)
      ([err _]
        (eprintf "Evaluation error: %s\n" err)
        (file/flush stderr))))
  (send-teardown state stream)
  (put state :running false))

(defn- option-value [args i option]
  (def value-index (+ i 1))
  (when (>= value-index (length args))
    (error (string "Missing value for " option)))
  (args value-index))

(defn parse-args [args]
  (var host default-host)
  (var port default-port)
  (var eval-forms @[])
  (var i 0)
  (while (< i (length args))
    (match (args i)
      "--host"
      (do
        (set host (option-value args i "--host"))
        (++ i))

      "--port"
      (do
        (def port-text (option-value args i "--port"))
        (def parsed-port (scan-number port-text))
        (when (nil? parsed-port)
          (error (string "Invalid --port value: " port-text)))
        (set port parsed-port)
        (++ i))

      "--eval"
      (do
        (array/push eval-forms (option-value args i "--eval"))
        (++ i))

      "--help" (do
                 (printf "Usage: janet slynet-client.janet [--host HOST] [--port PORT] [--eval FORM]\n")
                 (os/exit 0))
      unknown (error (string "Unknown argument: " unknown)))
    (++ i))
  {:host host :port port :eval eval-forms})

(defn main [& args]
  (let [args (if (and (pos? (length args)) (string/has-suffix? "slynet-client.janet" (args 0)))
               (slice args 1)
               args)
        opts (parse-args args)
        host (opts :host)
        port (opts :port)
        forms (opts :eval)
        stream (connect-socket host port)]
    (if (nil? stream)
      (os/exit 1)
      (let [state (make-state)]
        (printf "Connected to SLYNET server at %s:%d\n" host port)
        (flush)
        (try
          (perform-handshake! state stream)
          ([err _]
            (eprintf "Handshake failed: %s\n" err)
            (net/close stream)
            (os/exit 1)))
        (def reader (start-reader! state stream))
        (if (pos? (length forms))
          (run-batch state stream forms)
          (interactive-loop state stream))
        (send-teardown state stream)
        (put state :running false)
        (net/close stream)
        (os/exit 0)))))

(let [args (dyn :args)]
  (when (and (pos? (length args))
             (string/has-suffix? "slynet-client.janet" (args 0)))
    (apply main args)))
