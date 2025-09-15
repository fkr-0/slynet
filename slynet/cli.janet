# slynet-cli.janet
# Clean bootstrap + transports + in-memory test server for SLYNK

############################
# Imports (wire these paths)
############################
(import ./slynk_janet/slynk :as slynk)
(import ./slynk_janet/backend :as backend)
(import ./slynk_janet/rpc :as rpc)

############################
# Tiny logger
############################
(defn log [lvl & xs]
  (print "[" lvl "] " (string/join (map string xs) "")))

############################
# Core dispatch seam
############################
# This is the only place where transport meets protocol.
# It feeds a *decoded* Janet message into your slynk/process-message.

(defn handle-decoded! [conn decoded]
  # Your slynk/process-message takes (connection message)
  (slynk/process-message conn decoded)
  true)

############################
# STDIO transport (optional)
############################

(defn start-stdio! [mk-conn]
  (var alive true)

  # Minimal connection object that slynk/process-message expects
  (def conn @{:id "_stdio"
              :socket :stdio
              :addr "stdio"
              :package slynk/cl-package
              :rex-handlers @{}
              :repl-results @{}})

  (when (function? mk-conn) (mk-conn conn))

  # --- wire helpers (6-hex header framing) ---
  (defn _write-frame [payload-str]
    (let [bytes (backend/string-to-utf8 payload-str)
          len (length bytes)]
      (ev/write (dyn :out) (string/format "%06x" len))
      (ev/write (dyn :out) (string bytes))
      true))

  (defn _read-exact [s need]
    (def out @"")
    (var got 0)
    (while (< got need)
      (def chunk (ev/read s (max 1 (- need got))))
      (when (or (nil? chunk) (= 0 (length chunk))) (break))
      (buffer/push-string out chunk)
      (set got (+ got (length chunk))))
    (if (= got need) out nil))

  (defn _read-header [s]
    (let [hdr (_read-exact s 6)]
      (when (nil? hdr) nil)
      (scan-number (string hdr) 16)))

  (defn _read-packet [s]
    (let [len (_read-header s)]
      (when (nil? len) nil)
      (let [payload (_read-exact s len)]
        (when (nil? payload) nil)
        (if (= rpc/*current-encoding* "utf-8")
          (backend/utf8-to-string payload)
          (backend/bytes-to-string payload)))))
  (var prev (rpc/set-send-handler
              (fn [conn msg]
                (let [pkg (or (:package conn) (conn :package))
                      wire (rpc/process-outgoing-message msg pkg)
                      bytes (backend/string-to-utf8 wire)]
                  (ev/write (dyn :out) (string/format "%06x" (length bytes)))
                  (ev/write (dyn :out) (string bytes))
                  true))))
  # --- install temporary rpc send handler (mutable hook) ---
  (var prev-send-handler nil)
  (defn _stdio-send [c msg]
    # c is ignored; we always write to stdout
    (let [pkg (or (:package c) (conn :package))
          wire (rpc/process-outgoing-message msg pkg)]
      (_write-frame wire)))

  (def reader
    (fiber/new
      (fn []
        (set prev-send-handler (rpc/set-send-handler _stdio-send)) # ; record old, install new
        (while alive
          (try
            (let [pkt (_read-packet (dyn :in))]
              (when (nil? pkt) (set alive false) (break))
              (let [decoded (rpc/process-incoming-message pkt)]
                (slynk/process-message conn decoded)))
            ([e _]
              (eprintf "[ERR] stdio read/handle: %s\n" e)
              (set alive false))))
        # restore previous send handler
        (when prev-send-handler (rpc/set-send-handler prev-send-handler)))))

  (resume reader)

  {:mode :stdio
   :close! (fn []
             (set alive false)
             (when prev (rpc/set-send-handler prev)))})

############################
# TCP transport
############################
(defn start-tcp! [host port mk-conn]
  (def listener (net/listen host port))
  (log "INFO" "tcp listening on " host ":" port "\n")
  (var alive true)

  (def acceptor
    (fiber/new
      (fn []
        (while alive
          (try
            (let [sock (net/accept listener)]
              (ev/go
                (fn []
                  (log "INFO" "client connected\n")
                  # Per-connection record
                  (def conn @{:id (string (gensym))
                              :socket sock
                              :addr (try (net/address sock) ([_ _] "unknown"))
                              :package slynk/cl-package
                              :rex-handlers @{}
                              :repl-results @{}})

                  (when (function? mk-conn)
                    (mk-conn conn))

                  (while alive
                    (def msg (try (rpc/read-message sock (conn :package))
                               ([_ _] nil)))
                    (when (nil? msg) (break))
                    (handle-decoded! conn msg))
                  (net/close sock)
                  (log "INFO" "client disconnected\n"))))
            ([e _]
              (when alive
                (log "ERR" "accept loop: " (string e) "\n"))))))))

  (resume acceptor)
  {:mode :tcp
   :listener listener
   :close! (fn []
             (set alive false)
             (net/close listener)
             (log "INFO" "tcp transport stopped\n"))})

############################
# Server lifecycle API
############################
(defn server/start!
  "Start SLYNK with :mode :tcp|:stdio. Returns a server record.
   Options: :host, :port, :on-conn (fn [conn] ...) to customize per-conn."
  [&opt mode host port on-conn]
  (default mode :tcp)
  (default host "127.0.0.1")
  (default port 4005)
  (default on-conn nil)
  # mk-conn is a small hook to let SLYNK keep its own globals current (e.g. *emacs-io*)
  (def mk-conn
    (fn [conn]
      # You already do similar inside connection-repl-loop; we mirror that here:
      (when (nil? (slynk/*emacs-io*))
        (set slynk/*emacs-io* conn))
      (when (function? on-conn) (on-conn conn))
      true))

  (var base @{:state :none})
  (case mode
    :stdio (merge base {:transport (start-stdio! mk-conn)})
    :tcp (merge base {:transport (start-tcp! host port mk-conn) :host host :port port})
    (error (string "unknown mode: " mode))))

(defn server/stop! [srv]
  (when-let [f (srv :transport :close!)] (f)))

############################
# CLI
############################
(defn parse-args [args]
  (var mode :tcp) (var host "127.0.0.1") (var port 4005)
  (var i 0)
  (while (< i (length args))
    (match (args i)
      "--stdio" (set mode :stdio)
      "--tcp" (set mode :tcp)
      "--host" (do (set host (args (+ i 1))) (set i (+ i 1)))
      "--port" (do (set port (scan-number (args (+ i 1)))) (set i (+ i 1)))
      _ (log "WARN" "unknown arg: " (args i) "\n"))
    (set i (+ i 1)))
  {:mode mode :host host :port port})

(defn -main [& args]
  (def cfg (parse-args args))
  (def srv (server/start!
             (cfg :mode)
             (cfg :host)
             (cfg :port)))
  (defer (server/stop! srv))
  (match (cfg :mode)
    :stdio (log "INFO" "SLYNK stdio ready\n")
    :tcp (log "INFO" "SLYNK tcp " (cfg :host) ":" (cfg :port) " ready\n"))
  (while true (os/sleep 1.0)))

(when (= (dyn :script) "true")
  (apply -main (dyn :args)))

############################################
# In-memory test server (no TCP no stdio)
############################################

# We capture replies by temporarily overriding `rpc.write-message`
# (only within the test scope) to push decoded replies into a buffer.
#
# This gives you true end-to-end behavior through:
#   emacs-rex -> slynk/process-message -> rpc.process-outgoing-message
# but without sockets and without changing your production code.

(defn- _decode-wire->msg [s package]
  # Your rpc/process-incoming-message expects a single s-expression string.
  # We assume callers of this helper give us one frame already.
  (rpc/process-incoming-message s))

(defn- _encode-msg->wire [msg package]
  # Your rpc/process-outgoing-message returns a printable s-expression string.
  (rpc/process-outgoing-message msg package))
# test_harness.janet

(defn test/make-server [&opt pkg timeout]
  (default pkg slynk/cl-package) # default package for eval
  (default timeout 1.0)

  (def ch (ev/chan 32)) # capture channel for replies
  (var replies @[]) # keep a copy if you want to inspect all
  (def conn @{:id "_test"
              :socket :mem # never used; handler path avoids sockets
              :addr "in-memory"
              :package pkg
              :rex-handlers @{}
              :repl-results @{}})

  (when (nil? slynk/*emacs-io*) (set slynk/*emacs-io* conn))

  # Install capture send-handler (mutable hook in rpc)
  (def prev (rpc/set-send-handler
              (fn [_ msg]
                (print "setsendhandler")
                (pp msg)
                (array/push replies msg)
                (ev/give ch msg) # signal a reply is available
                true)))
  # after you create conn
  (when (nil? slynk/*emacs-io*) (set slynk/*emacs-io* conn))

  # install BOTH: send-handler (puts into channel) AND conn-resolver
  (def prev-send (rpc/set-send-handler
                   (fn [_ msg]
                     (ev/give ch msg) # use ev/put for channels
                     true)))

  (def prev-resolve (rpc/set-conn-resolver
                      (fn [remote-id]
                        (cond
                          (or (nil? remote-id) (= remote-id :current)) conn
                          (= remote-id (conn :id)) conn
                          true nil))))

  # on dispose, restore both:

  (defn await-one []
    (print "AwaitOne")

    (var o (match (ev/take ch)
             [:return [:ok msg]] msg
             _ nil))
    (print "got one:" o)
    o)

  (defn await-all
    "Collect replies until no new messages arrive for idle_ms."
    [&opt idle_ms]
    (default idle_ms 20)
    (print "AwaitAll")
    (var last-count (length replies))
    (while true
      (match (ev/take ch)
        [:ok _] (set last-count (length replies)) # keep draining
        _ (break)))
    (array/slice replies))

  {:conn conn
   :dispose (fn []
              (when prev-send (rpc/set-send-handler prev-send))
              (when prev-resolve (rpc/set-conn-resolver prev-resolve)))
   :chan ch
   :await-one await-one
   :replies replies
   :await-all await-all
   :emacs-rex!
   (fn [form &opt package thread id]
     (default package pkg) (default thread nil) (default id 1)
     (set replies @[])
     (slynk/process-message conn (rpc/create-emacs-rex-message form package thread id))
     (print "sent emacs-rex:" form "\n" "awaiting...")

     (await-one)) # ;waits for the spawned fiber to reply
   :send!
   (fn [decoded-msg]
     (set replies @[])
     (slynk/process-message conn decoded-msg)
     (print "sent message:" decoded-msg "\n" "awaiting...")
     # (await-all)
)})


(defn test/rpc [srv msg] ((srv :send!) msg))
(defn test/emacs-rex [srv form &opt package thread id]
  ((srv :emacs-rex!) form package thread id))

(defmacro with-test-server [binding & body]
  (let [[name opts] (match binding
                      [n o] [n o]
                      [n] [n {}]
                      _ (error "with-test-server needs [name opts?]"))]
    ~(let [,name (apply test/make-server ,(flatten opts))]
       (defer ((,name :dispose)))
       ,;body)))

# in-memory test
# (with-test-server [srv]
#   (pp (test/emacs-rex srv '(+ 1 2 3) :core nil 42))
#   ((srv :await-one))
# => e.g. [[:return [:ok 6] 42]]
# )
# (import ./test_harness :as T)

(let [srv (test/make-server :core 1.0)]
  (defer ((srv :dispose)))
  (print "==> awaiting")
  (pp ((srv :emacs-rex!) '(+ 1 2 3) :core nil 42))
  # (pp ((srv :await-one)))
  (print "<== awaiting end")
  # => [[:return [:ok 6] 42]]
)

# # Convenience helpers
