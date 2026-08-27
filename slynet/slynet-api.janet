# Compatibility import for the pre-1.1 SLYNET API module name.
#
# New embedding code should use:
#   (import slynet/api :as slynet)

(import ./api :as api)

(def api-version api/api-version)
(def version api/version)
(def capabilities api/capabilities)
(def initialize api/initialize)
(def rpc-interface api/rpc-interface)
(def rpc-implementation api/rpc-implementation)
(def call-rpc api/call-rpc)
(def start-server api/start-server)
(def stop-server api/stop-server)
(def export-api api/export-api)
