# SLYNK core for Janet
# Translated from slynk.lisp to idiomatic Janet
# Core server functionality for the SLYNK protocol

(print "Loading SLYNK core module...slynk\n")
# Import necessary modules
(import ./backend)
(import ./rpc)
(import ./gray)
(import ./print-for-emacs :as print-for-emacs)
(import ./xref)
(import ./completion)

(var *standard-input* (dyn :in))
(var *standard-output* (dyn :out))
(var *standard-error* (dyn :err))
(var *trace-output* nil)
#
# Constants and configuration
#

(def cl-package :core)
# Current package context for printing/prompt
(var *package* @{:name "core" :nick "core"})
(comment "Wire protocol version alias for convenience")
(var *wire-version* rpc/*wire-protocol-version*)
(def +keyword-package+ :keyword)

# Network configuration
(def default-server-port 4005)

# Debug settings
(def *slynk-debug-p* true)

# Emacs connection identifier
(def *m-x-sly-from-emacs* nil)

(print "1") #
# Connection and server state
#

# Active connections map (id -> connection)
(var *connections* @{})
(var *channels* @{})
# Active server instance
(var *server* nil)

# Current I/O package
(var *io-package* nil)

# Current Emacs I/O stream
(var *emacs-io* nil)

# Exposed IO stream vars for contrib code (conceptual)
(var *standard-input* nil)
(var *standard-output* nil)
(var *standard-error* nil)
(var *trace-output* nil)
(var *debug-io* nil)

#
(print "2") #
# Default preferences and settings
#

# Message prefix for echo area
(def *echo-area-prefix* "[SLYNET] ")

# Communication style (spawn, stream, etc.)
(def *communication-style* :spawn)

# Current debugger hook function
(var *debugger-hook-function* nil)
(print "3") #

# Default bindings for worker threads
(def *default-worker-thread-bindings*
  @{:*print-pretty* true
    :*print-level* nil
    :*print-length* nil})
(var channel-counter 0)

(defn make-channel [&opt thread name]
  (set channel-counter (+ channel-counter 1))
  (let [c {:id channel-counter
           :thread (if thread thread nil)
           :name (if name name nil)}]
    (put *channels* channel-counter c)
    c))

(defn find-channel [id]
  (get *channels* id))

(defn get-connection [id]
  (get *connections* id))

# Default connection information returned to clients
(def *connection-info*
  @{:pid (os/getpid)
    :style :spawn
    :lisp-implementation
    @{:type "Janet"
      :version (string/join [(string janet/version) " [" (string janet/build) "]"])
      :program (or (dyn :executable) "janet")}
    :machine
    @{:type (os/which)
      :version 1} #(os/exit)}
    :features @[]
    :modules @{}})
(print "4") #

#
# Error handling
#

(defn make-slynk-error
  "Create a structured SLYNK error object."
  [message details]
  @{:type :slynk-error
    :message message
    :details details})

(defn format-for-emacs
  "Format a message to be displayed in Emacs.
   Adds the SLYNET prefix and ensures proper string conversion."
  [& args]
  (string *echo-area-prefix* (string/join (map string args) " ")))
(print "3") #

(defn eval-for-emacs [form buffer-package id]
  # Evaluate a form for Emacs
  (print (string/format "Evaluating form for Emacs: %p" form))

  (try
    (do
      (def result (eval form))
      [:ok result])
    ([err fib]
      [:error (string "Evaluation error: " err)])))
# in slynk.janet
(defn send-to-emacs [arg1 &opt arg2]
  (var conn nil) (var message nil)
  (if (nil? arg2)
    (do (set conn *emacs-io*) (set message arg1))
    (do (set conn arg1) (set message arg2)))
  (when (nil? conn) (error "send-to-emacs: no active connection"))

  # 1) Try handler with this connection's id
  (when (rpc/send-to-remote (conn :id) message)
    (break true))
  # 2) Try handler with :current / nil (depends on your resolver)
  (when (rpc/send-to-remote :current message)
    (break true))
  (when (rpc/send-to-remote nil message)
    (break true))

  # 3) Fallback: write to socket (TCP/stdio)
  (let [stream (conn :socket) package (conn :package)]
    (rpc/write-message message package stream)))


# (defn send-to-emacs [arg1 &opt arg2]
#   (print "sending to emacs" arg1 arg2)
#   # Arity dispatch
#   (var conn nil)
#   (var message nil)
#   (if (nil? arg2)
#     (do (set conn *emacs-io*) (set message arg1))
#     (do (set conn arg1) (set message arg2)))

#   (when (nil? conn)
#     (error "send-to-emacs: no active connection"))

#   # 1) Prefer the mutable send-handler path (avoids sockets for tests & stdio)
#   #    IMPORTANT: pass NIL as remote-id so resolver picks *emacs-io*.
#   (if (rpc/send-to-remote nil message)
#     true
#     # 2) Fallback: real socket write (TCP/stdio)
#     (let [stream (conn :socket)
#           package (conn :package)]
#       (rpc/write-message message package stream))))


# Register RPC hooks to avoid circular dependencies
# (rpc/set-send-handler (fn [conn msg] (send-to-emacs conn msg)))
# REMOVE this if it exists:
# (rpc/set-send-handler (fn [conn msg] (send-to-emacs conn msg)))

# INSTEAD install a *non-recursive* default that goes straight to the socket.
# (Your stdio/test harness will override this anyway.)
(rpc/set-send-handler
  (fn [conn msg]
    (let [stream (conn :socket)
          package (conn :package)]
      # if there's a real socket, write; otherwise say "not handled"
      (if (and stream (not= stream :mem) (not= stream :stdio))
        (do (rpc/write-message msg package stream) true)
        false))))

(rpc/set-conn-resolver (fn [remote-id]
                         (cond
                           (or (nil? remote-id) (= remote-id :current)) *emacs-io*
                           (get-connection remote-id)
                           (and (pos? (length *connections*))
                                (get *connections* (first (keys *connections*))))
                           :else nil)))

(defmacro with-file [filehandle filename &opt append & body]
  "Open a file, execute body, and ensure the file is closed.
Usage: (with-file f \"log.txt\" true (file/write f \"message\"))"
  (default append true)
  (let [f (gensym)]
    ~(let [mode (if ,append :a "w")]
       (try
         (do
           (def ,filehandle (file/open ,filename mode))
           (try
             (do
               ,;body
               (file/close ,filehandle))
             ([err fib]
               (file/close ,filehandle)
               (error err))))
         ([err fib]
           (error err))))))

(defn log-to-file [filename message]
  (try
    (do
      (with-file f filename true
        (file/write f (string (os/strftime "%Y-%m-%d %H:%M:%S") " - " message "\n")))

      true)
    ([err fib]
      (do (eprintf "SLYNET: Failed to log to file %s: %s\n" filename err)
        false))))

(def server-logger (fn [& msg]
                     (log-to-file "slynk-server.log" (apply string msg))))
# in slynk.janet
(defn process-emacs-rex [connection form package thread id]
  # (print "processing emacs rex")
  (def eval-fiber
    (ev/spawn
      (try
        (do # (print "Running async")
          (let [res (eval-for-emacs form package id)]
            (match res
              [:ok v]
              (send-to-emacs connection (rpc/create-return-message v id))
              [:error e]
              (send-to-emacs connection (rpc/create-return-error-message e id))
              _ #defensive: unknown shape
              (send-to-emacs connection (rpc/create-return-error-message
                                          (string "invalid eval result: " res) id)))))
        ([err _]
          (send-to-emacs connection
                         (rpc/create-return-error-message (string err) id))))))
  (put (connection :rex-handlers) id eval-fiber))

# (defn process-emacs-rex
#   "Process an emacs-rex command (evaluate form from Emacs)."
#   [connection form package thread id]
#   (print "SLYNET: Processing emacs-rex: " form)
#   (server-logger "SLYNET: Processing emacs-rex: %s" form)

#   # Spawn a fiber to handle the evaluation so we don't block the main thread
#   (def eval-fiber (ev/spawn
#                     (try
#                       (do
#                         (def result (eval-for-emacs form package id))
#                         (send-to-emacs connection (rpc/create-return-message result id)))
#                       ([err fib]
#                         (server-logger "SLYNET: Error evaluating form: %s" err)
#                         (send-to-emacs connection (rpc/create-return-error-message (string err) id))))))

#   # Store handler in connection's rex-handlers map
#   (put (connection :rex-handlers) id eval-fiber))

(print "4") #
(server-logger "SLYNET: Server module loaded.")
(defn process-channel-send
  "Process a channel-send message."
  [connection channel-id data]
  (var handled false)
  (try
    (do
      (def obj (rpc/get-channel-object channel-id))
      (when obj
        # Convention: dispatch by first element keyword in data
        (when (and (indexed? data) (> (length data) 0))
          (def op (get data 0))
          (case op
            :process (do
                       (when (function? (obj :mrepl-channel-process))
                         ((obj :mrepl-channel-process) (get data 1))
                         (set handled true)))
            :inspect-object (do
                              (when (function? (obj :mrepl-channel-inspect-object))
                                ((obj :mrepl-channel-inspect-object) (get data 1) (get data 2))
                                (set handled true)))
            :teardown (do
                        (when (function? (obj :mrepl-channel-teardown))
                          ((obj :mrepl-channel-teardown))
                          (rpc/close-channel channel-id)
                          (set handled true)))
            :clear-history (do
                             (when (function? (obj :mrepl-channel-clear-history))
                               ((obj :mrepl-channel-clear-history))
                               (set handled true)))
            (set handled false)))))
    ([err fib]
      (do (eprintf "SLYNET: Channel handler error: %s" err)
        (server-logger "SLYNET: Channel handler error: %s" err))))
  (unless handled
    (eprintf "SLYNET: Channel send unhandled. Channel %s, data: %j" channel-id data)))

(defn process-channel-close
  "Process a channel-close message."
  [connection channel-id]
  (when (rpc/get-channel-object channel-id)
    (rpc/close-channel channel-id))
  (server-logger "SLYNET: Channel %s closed" channel-id)
  (eprintf "SLYNET: Channel %s closed" channel-id))

(defn close-connection
  "Close a connection cleanly."
  [connection reason]
  (server-logger "SLYNET: Closing connection: " reason)
  (print "SLYNET: Closing connection: " reason)

  # Try to send disconnect notification
  (try
    (send-to-emacs connection [:slynk-disconnect reason])
    ([_ fib] nil))

  # Close socket
  (try
    (net/close (connection :socket))
    ([_ fib] nil))

  # Remove from connections registry
  (put *connections* (connection :id) nil)

  # If this was the current emacs-io, clear it
  (when (= *emacs-io* connection)
    (set *emacs-io* nil)))

(defn read-from-emacs [connection]
  # Read a message from Emacs
  (let [stream (connection :socket)
        package (connection :package)]
    (print "Reading message from Emacs...")
    (pp stream)
    (pp package)
    (rpc/read-message stream package)))

(defn process-message
  "Process a message received from Emacs."
  [connection message]
  (printf "SLYNET RECV: %j\n" message)
  (server-logger "SLYNET RECV: %j\n" message)
  (match message
    [:emacs-rex form package thread id]
    (process-emacs-rex connection form package thread id)
    [:emacs-rex form package id]
    (process-emacs-rex connection form package nil id)
    ['emacs-rex form package id]
    (process-emacs-rex connection form package nil id)
    [:slynk-disconnect]
    (close-connection connection "Client requested disconnect")

    [:channel-send channel-id data]
    (process-channel-send connection channel-id data)

    [:channel-close channel-id]
    (process-channel-close connection channel-id)

    # Default case - unknown message type
    (do (server-logger "SLYNET: Unknown message type: %j" message)
      (eprintf "SLYNET: Unknown message type: %j" message))))

(defn connection-repl-loop
  "Main REPL loop for a connection."
  [connection]
  ## enumerate table:
  (print (map print (keys connection)))
  (print (pp connection))
  # @{:addr "unknown"
  # :fiber <fiber 0x563FD57C6EB0>
  # :id "_0000ik"
  # :package
  # :core
  # :repl-results @{}
  # :rex-handlers @{} :socket <core/stream [fd=9]>}

  (def socket (connection :socket))
  (print "Socket: " socket)
  (print "*Connections*: " (pp (keys *connections*)))
  # Set current connection for this thread context
  (when (= (connection :id) (first (keys *connections*)))
    (set *emacs-io* connection))

  # Enter message handling loop
  (var running true)
  (while running
    (try
      # Try to read a message
      (do
        (def message (read-from-emacs connection))
        (print "Read message: " message)

        # If we got a message, process it
        (if message
          (process-message connection message)
          # If read-from-emacs returns nil, the connection was closed
          (set running false)))

      ([err fib]
        (eprintf "SLYNET: Error in connection loop: %s" err)
        # Send error back to client if possible
        (try
          (send-to-emacs connection [:reader-error (string err)])
          ([e fib]
            (do (eprintf "SLYNET: Failed to send error to client: %s" e)
              (error e))))

        # Continue loop unless it looks like a disconnection
        (when (or (string/find "connection" (string err))
                  (string/find "closed" (string err)))
          (set running false)))))

  # When loop exits, clean up
  (print "SLYNET: Connection loop exited for " (connection :addr)))
(print "4") #

(defn start-server
  "Start the SLYNK server on the specified port.

   Parameters:
   - port: The port number to listen on (default: 4005)
   - host: The host address to bind to (default: 127.0.0.1)
   - dont-close: If true, keep the server running after client disconnect"
  [port &opt host dont-close]
  (default host "127.0.0.1")
  (default dont-close false)

  # Create server socket
  (print "Starting SLYNET server on " host ":" port)

  (def socket (net/listen host port))
  (print "Server socket created successfully on " host ":" port)

  # Create server and store in global
  (def server @{:host host :port port :socket socket :running true})
  (set *server* server)

  (defn handle-new-connection
    "Handle a new client connection."
    [server client dont-close]
    (print "client " client)
    (def client-addr # (net/address client)
      "unknown")
    (print "SLYNET: New connection from " client-addr)

    # Create a connection record
    (def connection-id (string (gensym)))
    (def connection @{:id connection-id
                      :socket client
                      :addr client-addr
                      :package cl-package # Default package
                      :thread-id nil
                      :rex-handlers @{} # Map of message ID to handler functions
                      :repl-results @{} # Map of evaluation IDs to results
                      :repl-thread nil}) # Thread for REPL evaluations

    # Store connection in global registry
    (put *connections* connection-id connection)
    # Spawn fiber to handle this connection
    (def conn-fiber (ev/spawn
                      (connection-repl-loop connection)
                      # When loop exits, clean up connection
                      (unless dont-close
                        (net/close client)
                        (print "SLYNET: Closed connection from " client-addr))
                      # Remove from connections registry
                      (put *connections* connection-id nil)))

    # Store fiber in connection record
    (put connection :fiber conn-fiber)
    # (net/accept-loop socket handle-new-connection)
    # Return the connection
    connection)

  (defn server-loop
    "Main server loop that accepts connections and spawns handlers for each."
    [server dont-close]
    (def socket (server :socket))

    # Loop to accept connections while server is running
    (while (server :running)
      (print "SLYNET: Waiting for new connections...")
      (try
        (do
          (def client (net/accept socket))
          (print ">client " client)
          (if client
            (handle-new-connection server client dont-close)
            (ev/sleep 0.05))) # Short sleep if no connections to avoid CPU spinning
        ([err fib]
          # On any accept error, mark server not running and exit the loop.
          (eprintf "SLYNET: Error in server loop: %s" err)
          (put server :running false)
          (break))))

    # When loop exits, close the socket if allowed
    (unless dont-close
      (net/close socket)
      (print "SLYNET: Server socket closed.")))
  # Start accepting connections in a separate fiber
  # (def accept-fiber (ev/spawn
  #                     (server-loop server dont-close)))

  # (ev/do-thread accept-fiber)
  # (put server :accept-fiber accept-fiber)
  (server-loop server dont-close)
  (print "Server started. Listening for connections...")
  # (fiber/detach accept-fiber) # Detach so it runs independently

  # Return the port that was opened
  server)

(defn create-server [&opt port host dont-close]
  (default port default-server-port)
  (default host "127.0.0.1")

  (start-server port host dont-close))

(defn connection-info []
  # Return current connection information
  *connection-info*)

(defn handle-request [connection message]
  # Process a request from Emacs
  (print "Handling request: " message)
  # TODO: Implement actual message dispatch
  [:ok "Request processed"])


(defn stop-server
  "Stop the server and close all connections."
  []
  (when *server*
    (print "SLYNET: Stopping server...")
    (put *server* :running false)

    # Close all connections
    (each [id conn] (pairs *connections*)
      (close-connection conn "Server shutting down"))

    # Clear connections registry
    (set *connections* @{})

    # Close server socket
    (try
      (net/close (*server* :socket))
      ([_ fib] nil))

    # Wait for accept thread to terminate
    (when-let [fiber (*server* :accept-fiber)]
      (try
        (ev/sleep 2) # Wait up to 2 seconds
        ([_ fib] nil)))

    (set *server* nil)
    (print "SLYNET: Server stopped.")
    true))


(defn list-connections
  "List all active connections."
  []
  (let [conns @[]]
    (each [id conn] (pairs *connections*)
      (array/push conns [id (conn :addr)]))
    conns))

(defn started-from-emacs?
  "Check if the current session was started from Emacs."
  []
  (not (nil? *m-x-sly-from-emacs*)))

# Export public API
(def export-api
  @{:create-server create-server
    :start-server start-server
    :*package* *package*
    :*wire-version* *wire-version*
    :started-from-emacs? started-from-emacs?
    :stop-server stop-server
    :list-connections list-connections
    :connection-info connection-info
    :eval-for-emacs eval-for-emacs
    :send-to-emacs send-to-emacs
    :*io-package* *io-package*
    :find-channel find-channel
    :get-connection get-connection
    :*emacs-io* *emacs-io*
    :*standard-input* *standard-input*
    :*standard-output* *standard-output*
    :*trace-output* *trace-output*
    :*standard-error* *standard-error*
    :*connections* *connections*
    :*channels* *channels*
    :make-channel make-channel
    :connection-repl-loop connection-repl-loop
    :*connection-info* *connection-info*
    :cl-package cl-package
    :connection-repl-loop connection-repl-loop})

# Listener helpers and utilities used by contrib/mrepl

(defn set-package [pkg]
  (cond
    (string? pkg) (do (put *package* :name pkg) (put *package* :nick pkg) *package*)
    (keyword? pkg) (do (put *package* :name (string pkg)) (put *package* :nick (string pkg)) *package*)
    (table? pkg) (do (put *package* :name (or (pkg :name) "core"))
                   (put *package* :nick (or (pkg :nick) (*package* :name)))
                   *package*)
    (*package*)))

(defn set-default-directory [dir]
  (try
    (os/cd dir)
    ([err _] (eprintf "Failed to set directory: %s" err)))
  dir)

(defn make-listener-output-stream [mrepl which]
  (gray/make-listener-output-stream mrepl which))

(defmacro with-listener-bindings [mrepl & body]
  ~(let [old-in (dyn :in)
         old-out (dyn :out)
         old-err (dyn :err)
         in-stream (or (,mrepl :input-stream) old-in)
         out-stream (slyk-gray/make-listener-output-stream ,mrepl :stdout)
         err-stream (slyk-gray/make-listener-output-stream ,mrepl :stderr)]
     (try
       (do
         (setdyn :in in-stream)
         (setdyn :out out-stream)
         (setdyn :err err-stream)
         ,;body
         (setdyn :in old-in)
         (setdyn :out old-out)
         (setdyn :err old-err))
       ([err fib]
         (setdyn :in old-in)
         (setdyn :out old-out)
         (setdyn :err old-err)
         (error err)))))

(defmacro saving-listener-bindings [mrepl & body]
  # For now, do not alter bindings further — just execute body in current context
  ~(do ,;body))

(defn flush-listener-streams [_mrepl]
  (def o (dyn :out))
  (def e (dyn :err))
  (when (and (table? o) (= (o :type) :sly-output-stream))
    (gray/stream-finish-output o))
  (when (and (table? e) (= (e :type) :sly-output-stream))
    (gray/stream-finish-output e))
  true)

(defn slynk-pprint-for-emacs [v]
  (print-for-emacs/prin1-to-string-for-emacs v *package*))

(defn slynk-buffer-to-string-for-emacs [buf]
  (string/from-bytes buf))

(defn slynk-inspect [obj]
  @{:type (type obj)
    :repr (print-for-emacs/prin1-to-string-for-emacs obj *package*)})

(defn slynk-describe-to-string [obj]
  (print-for-emacs/prin1-to-string-for-emacs obj *package*))

(defn slynk-eval-in-emacs [_form]
  # Stub — in a real session this would send to Emacs
  true)

(defn process-requests [_blocking?]
  # Minimal cooperative yield# integrate with your event loop as needed
  (ev/sleep 0)
  nil)

(defn format-output [_mrepl fmt & args]
  (var argv @[fmt])
  (each a args (array/push argv a))
  (print (apply string/format argv)))
(defn send-to-remote [remote-id message]
  # Resolve a connection and forward message via slynk/send-to-emacs.
  (var conn nil)
  (cond
    (or (nil? remote-id) (= remote-id :current)) (set conn *emacs-io*)
    :else (set conn (get-connection remote-id)))
  (when (nil? conn)
    # Fallback: first active connection, if any
    (when (pos? (length *connections*))
      (set conn (get *connections* (first (keys *connections*))))))
  (when conn
    (send-to-emacs conn message)
    true))
# Export the helper API additions
(put export-api :set-package set-package)
(put export-api :set-default-directory set-default-directory)
(put export-api :with-listener-bindings with-listener-bindings)
(put export-api :saving-listener-bindings saving-listener-bindings)
(put export-api :send-to-remove send-to-remote)
(put export-api :flush-listener-streams flush-listener-streams)
(put export-api :slynk-pprint-for-emacs slynk-pprint-for-emacs)
(put export-api :slynk-buffer-to-string-for-emacs slynk-buffer-to-string-for-emacs)
(put export-api :slynk-inspect slynk-inspect)
(put export-api :slynk-describe-to-string slynk-describe-to-string)
(put export-api :slynk-eval-in-emacs slynk-eval-in-emacs)
(put export-api :process-requests process-requests)
(put export-api :format-output format-output)
(put export-api :*standard-input* *standard-input*)
(put export-api :*standard-output* *standard-output*)
(put export-api :*standard-error* *standard-error*)
(put export-api :*trace-output* *trace-output*)
(put export-api :*debug-io* *debug-io*)

# Macros used by contrib code -------------------------------------------------
(defmacro defslyfun [name args & body]
  ~(defn ,name ,args ,;body))

(var *debugger-hook* nil)
(put export-api :*debugger-hook* *debugger-hook*)

(defmacro with-slyk-interrupts [& body]
  ~(do ,;body))

(defn slynk-pprint [xs]
  (each x xs (print (print-for-emacs/prin1-to-string-for-emacs x *package*)))
  true)
(put export-api :slynk-pprint slynk-pprint)
