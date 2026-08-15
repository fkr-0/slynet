# slynet/cli.janet
# Unified CLI and initialization for SLYNK Janet backend

(print "Loading SLYNK CLI...")

############################
# Imports
############################
(import ./infrastructure :as inf)
(import ./backend :as backend)
(import ./rpc :as rpc)
(import ./slynk :as slynk)
(import ./gray)
(import ./completion)
(import ./xref)
(import ./contrib)
(import ./version :as release-version)

############################
# Version and Module Registry
############################
(def version release-version/version)
(def compatible-versions release-version/compatible-versions)
(def required-modules @["backend" "rpc" "slynk" "gray" "completion" "xref"])
(def optional-modules @["contrib"])
(def modules @{})
(def contrib-modules @{})

############################
# User Configuration and Hooks
############################
(def *user-init-file* "~/.slynk.janet")
(var *loaded-user-init-file* false)
(def *load-path* @["./" "./slynet/" "./slynet/" "./"])
(var *slynk-hooks* @{:init @[]})
(setdyn :doc "SLYNK implementation for Janet - A backend for the Superior Lisp Interaction Mode for Emacs (SLY)")

############################
# Logging
############################
(defn log [lvl & xs]
  (print "[" lvl "] " (string/join (map string xs) "")))

############################
# Module Loading and Initialization
############################
(defn load-module [name]
  (def module-name (string name))
  (def full-name (string (os/cwd) "/slynet/" module-name ".janet"))
  (try
    (do (log "INFO" "Loading module: " full-name "\n")
      (dofile full-name))
    ([err _]
      (eprintf "Error loading module %s: %s\n" module-name err))))

(defn initialize-backend [&opt options]
  (default options @{})
  (backend/initialize options)
  true)

(defn load-user-init []
  (try
    (do (dofile *user-init-file*)
      (set *loaded-user-init-file* true))
    ([err _]
      (eprintf "Error loading user init file: %s\n" err))))

(defn initialize-rpc [&opt options]
  (default options @{})
  # (def interfaces rpc/*slynet-rpc-interfaces-registry*)
  # (def implementations rpc/*slynet-rpc-implementations-registry*)
  (when (options :reset-registries)
    (eprintf "Resetting RPC registries...\n")
    (inf/reset-interfaces)
    (inf/reset-implementations))
  (var all-implementations-found true)
  # (unless (and (table? interfaces) (table? implementations))
  #   (eprintf "Error: SLYNET RPC registries are not properly initialized (not tables).\n")
  #   (set all-implementations-found false)
  #   (break "RPC registries not tables"))
  (let [interfaces (inf/list-interfaces)
        implementation-names (inf/list-implementations)]
    (eachp [rpc-name interface-meta] interfaces
      (unless (inf/get-implementation rpc-name)
        (eprintf "Warning: SLYNET RPC interface '%s' (Doc: \"%s\") is declared but not implemented.\n"
                 (string rpc-name) (get interface-meta :doc "no docstring"))
        (set all-implementations-found false)))
    (each rpc-name implementation-names
      (unless (get interfaces rpc-name)
        (eprintf "Warning: SLYNET RPC implementation for '%s' has no corresponding interface declaration.\n"
                 (string rpc-name))
        (set all-implementations-found false)))
    all-implementations-found))

(defn initialize-contrib-modules [&opt modules]
  (default modules nil)
  (if contrib/export-api
    (do
      (def results (contrib/initialize-contrib modules))
      (log "INFO" "SLYNET: Contrib modules initialized:\n")
      (eachp [name result] results
        (if (= (result :status) :ok)
          (log "INFO" "  - " name ": OK\n")
          (log "ERR" "  - " name ": ERROR - " (result :message) "\n")))
      results)
    (do
      (log "WARN" "SLYNET: Contrib system not available\n")
      @{})))

(defn add-hook [hook-name func]
  (unless (get *slynk-hooks* hook-name)
    (put *slynk-hooks* hook-name @[]))
  (array/push (get *slynk-hooks* hook-name) func))

(defn remove-hook [hook-name func]
  (when-let [hooks (get *slynk-hooks* hook-name)]
    (array/remove hooks func)))

(defn slynk-version [] version)

############################
# Unified Initialization
############################
(defn slynk-init
  "Initialize the SLYNK environment."
  [&opt options]
  (default options @{})
  (def delete (options :delete))
  (def reload (options :reload))
  (when (get modules :slynk)
    (cond
      delete (each name (keys modules) (put modules name nil))
      (not reload) (do
                     (log "INFO" "SLYNK already loaded. Use :reload true to reload.\n")
                     (return nil))))
  (each module required-modules (load-module module))
  (put modules :backend backend/export-api)
  (put modules :rpc rpc/export-api)
  (put modules :slynk slynk/export-api)
  (put modules :gray gray/export-api)
  (put modules :completion completion/export-api)
  (put modules :xref xref/export-api)
  (initialize-backend options)
  (initialize-rpc options)
  (when (and (not *loaded-user-init-file*) (os/stat *user-init-file*))
    (load-user-init))
  (each hook (get *slynk-hooks* :init) (hook))
  (when (or (options :enable-contrib) true)
    (def contrib-modules (options :contrib-modules))
    (initialize-contrib-modules contrib-modules)
    (put modules :contrib contrib/export-api))
  true)

############################
# Server Lifecycle (TCP/STDIO)
############################
(defn handle-decoded! [conn decoded]
  (slynk/process-message conn decoded)
  true)

(defn start-stdio! [mk-conn]
  (var alive true)
  (def conn @{:id "_stdio"
              :socket :stdio
              :addr "stdio"
              :package slynk/cl-package
              :rex-handlers @{}
              :repl-results @{}})
  (when (function? mk-conn) (mk-conn conn))
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
  (var prev-send-handler nil)
  (defn _stdio-send [c msg]
    (let [pkg (or (:package c) (conn :package))
          wire (rpc/process-outgoing-message msg pkg)]
      (_write-frame wire)))
  (def reader
    (fiber/new
      (fn []
        (set prev-send-handler (rpc/set-send-handler _stdio-send))
        (while alive
          (try
            (let [pkt (_read-packet (dyn :in))]
              (when (nil? pkt) (set alive false) (break))
              (let [decoded (rpc/process-incoming-message pkt)]
                (slynk/process-message conn decoded)))
            ([e _]
              (eprintf "[ERR] stdio read/handle: %s\n" e)
              (set alive false))))
        (when prev-send-handler (rpc/set-send-handler prev-send-handler)))))
  (resume reader)
  {:mode :stdio
   :close! (fn []
             (set alive false)
             (when prev (rpc/set-send-handler prev)))})

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
                  (when (= slynk/*emacs-io* conn)
                    (set slynk/*emacs-io* nil))
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

(defn server/start!
  "Start SLYNK with :mode :tcp|:stdio. Returns a server record.
   Options: :host, :port, :on-conn (fn [conn] ...) to customize per-conn."
  [&opt mode host port on-conn]
  (default mode :tcp)
  (default host "127.0.0.1")
  (default port 4005)
  (default on-conn nil)
  (def mk-conn
    (fn [conn]
      (set slynk/*emacs-io* conn)
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
      "--version" (do (print "SLYNET version: " version "\n") (os/exit 0))
      "--help" (do
                 (print "Usage: janet slynet/cli.janet [--tcp|--stdio] [--host HOST] [--port PORT]\n")
                 (os/exit 0))
      _ (log "WARN" "unknown arg: " (args i) "\n"))
    (set i (+ i 1)))
  {:mode mode :host host :port port})

(defn -main [& args]
  (def cfg (parse-args args))
  (slynk-init cfg)
  (def srv (server/start!
             (cfg :mode)
             (cfg :host)
             (cfg :port)))
  (defer (server/stop! srv))
  (match (cfg :mode)
    :stdio (log "INFO" "SLYNK stdio ready\n")
    :tcp (log "INFO" "SLYNK tcp " (cfg :host) ":" (cfg :port) " ready\n"))
  (while true (os/sleep 1.0)))

(defn script-invoked-directly? []
  (let [args (dyn :args)]
    (and (indexed? args)
         (> (length args) 0)
         (string/has-suffix? "slynet/cli.janet" (args 0)))))

(when (or (= (dyn :script) "true")
          (script-invoked-directly?))
  (apply -main (array/slice (dyn :args) 1)))

############################
# Exported API (for library use)
############################
(def export-api
  @{:init slynk-init
    :version version
    :slynk-version slynk-version
    :add-hook add-hook
    :remove-hook remove-hook
    :modules modules
    :required-modules required-modules
    :optional-modules optional-modules
    :*user-init-file* *user-init-file*
    :server/start! server/start!
    :server/stop! server/stop!})
