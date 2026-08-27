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

(def export-api
  @{:api-version api-version
    :version version
    :capabilities capabilities
    :initialize initialize
    :rpc-interface rpc-interface
    :rpc-implementation rpc-implementation
    :call-rpc call-rpc
    :start-server start-server
    :stop-server stop-server})
