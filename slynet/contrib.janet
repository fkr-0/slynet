# slynet/contrib.janet
# SLYNET Contrib Module Manager
# Registers and initializes all contrib modules
# probably the def list of contribs
# slynk/slynk.asd:20:(defsystem :slynk
# slynk/slynk.asd:87:(defsystem :slynk/arglists
# slynk/slynk.asd:91:(defsystem :slynk/fancy-inspector
# slynk/slynk.asd:95:(defsystem :slynk/package-fu
# slynk/slynk.asd:99:(defsystem :slynk/mrepl
# slynk/slynk.asd:103:(defsystem :slynk/trace-dialog
# slynk/slynk.asd:107:(defsystem :slynk/profiler
# slynk/slynk.asd:111:(defsystem :slynk/stickers
# slynk/slynk.asd:115:(defsystem :slynk/indentation
# slynk/slynk.asd:119:(defsystem :slynk/retro

(print "Loading SLYNET Contrib Module Manager...\n")
(import ./contrib/slynet-arglists :as arglists)
(import ./contrib/slynet-indentation :as indentation)
(import ./contrib/slynet-apropos :as apropos)
(import ./contrib/slynet-mrepl :as mrepl)
(import ./contrib/slynet-fancy-inspector :as fancy-inspector)

# Registry of available contrib modules
(def contrib-modules
  @{:arglists arglists/export-api
    :indentation indentation/export-api
    :apropos apropos/export-api
    :mrepl mrepl/export-api
    :fancy-inspector fancy-inspector/export-api})

# Default modules to load on init
(def default-modules [:arglists :indentation :apropos :mrepl])

(defn initialize-contrib
  "Initialize contrib modules. If modules is nil, load default modules.
   Returns a table mapping module names to initialization status."
  [&opt modules]
  (default modules default-modules)

  (def results @{})

  (each name modules
    (let [module (get contrib-modules name)]
      (print (string "SLYNET Contrib ...." name ".. module" (pp module)))
      (if module
        (try
          (do
            (var initialize (module :initialize-module))
            (if (function? initialize)
              (do
                (def success (initialize))
                (put results name {:status :ok :result success}))))
          ([err fib]
            (do
              (print (string "Error initializing module " name ": " err))
              (put results name {:status :error :message (string err)}))))
        (put results name {:status :error :message "Module not found"}))))
  (pp results)

  results)

(defn list-contrib-modules
  "Return a list of all available contrib modules."
  []
  (print (keys contrib-modules))
  (keys contrib-modules))

(defn get-module
  "Get a specific contrib module."
  [name]
  (get contrib-modules name))

# Export public API
(def export-api
  @{:contrib-modules contrib-modules
    :default-modules default-modules
    :initialize-contrib initialize-contrib
    :list-contrib-modules list-contrib-modules
    :get-module get-module})
