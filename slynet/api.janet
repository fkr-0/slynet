# Stable Janet embedding API for SLYNET.
#
# This module is intentionally smaller than the internal module graph.  Public
# callers should import slynet/api instead of reaching into cli.janet,
# infrastructure.janet, or slynk.janet directly.

(import ./cli :as cli)
(import ./infrastructure :as inf)
(import ./slynk :as slynk)
(import ./version :as release-version)

(def api-version "1")
(def version release-version/version)
(def loopback-hosts @["127.0.0.1" "localhost" "::1"])

(defn- loopback-host? [host]
  (not (nil? (find |(= $ host) loopback-hosts))))

(defn capabilities []
  "Return the stable embedding surface and its security boundary."
  @{:api-version api-version
    :version version
    :stability :stable
    :transport-modes @[:tcp :stdio]
    :default-host "127.0.0.1"
    :remote-bind-default :denied
    :rpc-resolution true
    :in-process-rpc true})

(defn initialize [&opt options]
  "Initialize SLYNET registries and default contrib modules.

  OPTIONS is passed to SLYNET initialization.  The return value is a stable
  status record rather than the internal initialization return value."
  (default options @{})
  (cli/slynk-init options)
  # CLI initialization validates the complete compatibility interface inventory,
  # much of which is intentionally missing.  Embedding callers need a stronger
  # guarantee: all actually supported core RPCs are registered before returning.
  (slynk/ensure-core-implementations!)
  (inf/slynet-sync-rpc-registries!)
  @{:status :ok
    :api-version api-version
    :version version})

(defn rpc-interface [name]
  "Return declared RPC metadata for NAME, or nil when it is unknown."
  (inf/get-interface (if (symbol? name) name (symbol name))))

(defn rpc-implementation [name]
  "Return the callable registered RPC implementation for NAME, or nil."
  (def entry (inf/get-implementation (if (symbol? name) name (symbol name))))
  (cond
    (function? entry) entry
    (table? entry) (entry :implementation)
    true nil))

(defn call-rpc [name & args]
  "Call registered RPC NAME in-process with ARGS.

  This bypasses transport/session framing; callers that require connection,
  package, or channel state should use a real SLYNET client connection instead."
  (def rpc-name (if (symbol? name) name (symbol name)))
  (def implementation (rpc-implementation rpc-name))
  (unless implementation
    (error (string "No callable SLYNET RPC implementation registered for " rpc-name)))
  (apply implementation args))

(defn start-server [&opt options]
  "Start an embeddable SLYNET server and return its server record.

  OPTIONS supports :mode, :host, :port, :on-conn, :initialize, and
  :allow-remote.  TCP binding is loopback-only unless :allow-remote is true."
  (default options @{})
  (def mode (or (options :mode) :tcp))
  (def host (or (options :host) "127.0.0.1"))
  (def port (or (options :port) 4005))
  (def on-conn (options :on-conn))
  (def initialize? (if (has-key? options :initialize) (options :initialize) true))
  (def allow-remote? (or (options :allow-remote) false))
  (when (and (= mode :tcp) (not allow-remote?) (not (loopback-host? host)))
    (error (string "Refusing non-loopback SLYNET bind through stable API: " host
                   ". Set :allow-remote true only behind an explicit trust boundary.")))
  (when initialize?
    (initialize options))
  (def server (cli/server/start! mode host port on-conn))
  (merge server {:api-version api-version :version version}))

(defn stop-server [server]
  "Stop SERVER created by start-server."
  (cli/server/stop! server)
  true)

(defn- require-context [context]
  (unless (and (table? context)
               (= :slynet-context (context :kind))
               (= api-version (context :api-version)))
    (error "Expected a SLYNET API-v1 lifecycle context"))
  context)

(defn create-context [&opt options]
  "Create an initialized API-v1 lifecycle context.

  The mutable context owns at most one server and can be deterministically
  closed with close-context.  Registry and CLI details remain internal."
  (default options @{})
  (initialize options)
  @{:kind :slynet-context
    :api-version api-version
    :version version
    :status :ready
    :server nil
    :closed false})

(defn context-start-server [context &opt options]
  "Start and attach one server owned by CONTEXT."
  (require-context context)
  (default options @{})
  (when (context :closed)
    (error "Cannot start a server on a closed SLYNET context"))
  (when (context :server)
    (error "SLYNET context already owns a server"))
  (def server-options (merge @{:initialize false} options))
  (def server (start-server server-options))
  (put context :server server)
  (put context :status :serving)
  server)

(defn context-stop-server [context]
  "Stop the server owned by CONTEXT, if any, and keep the context reusable."
  (require-context context)
  (when-let [server (context :server)]
    (stop-server server)
    (put context :server nil))
  (unless (context :closed)
    (put context :status :ready))
  true)

(defn close-context [context]
  "Idempotently stop owned resources and permanently close CONTEXT."
  (require-context context)
  (unless (context :closed)
    (context-stop-server context)
    (put context :closed true)
    (put context :status :closed))
  true)

(defn context-status [context]
  "Return transport-independent lifecycle metadata for CONTEXT.

  This intentionally reports only state owned by the embedding API. It does
  not claim that a client is connected, a package is current, or an MREPL
  channel is live; those remain real-session concerns on the wire protocol."
  (require-context context)
  (def server (context :server))
  @{:kind :slynet-context-status
    :api-version api-version
    :version version
    :status (context :status)
    :closed (context :closed)
    :owns-server (not (nil? server))
    :server-mode (and server (server :mode))
    :server-host (and server (server :host))
    :server-port (and server (server :port))
    :session-state :transport-dependent})

(def export-api
  @{:api-version api-version
    :version version
    :capabilities capabilities
    :initialize initialize
    :rpc-interface rpc-interface
    :rpc-implementation rpc-implementation
    :call-rpc call-rpc
    :start-server start-server
    :stop-server stop-server
    :create-context create-context
    :context-start-server context-start-server
    :context-stop-server context-stop-server
    :close-context close-context
    :context-status context-status})
