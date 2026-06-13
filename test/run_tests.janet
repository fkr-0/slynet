(import ../mini-test :as runner)
(import ./suite_manifest :as suites)

(defn- strip-script-arg [args]
  (if (and (> (length args) 0)
           (string? (args 0))
           (not (string/has-prefix? (args 0) ":")))
    (slice args 1)
    args))

(defn- print-loaded [suite files opts]
  (unless (= :compact (get opts :report nil))
    (print "\nLoaded suite " (string (suites/suite-key suite)) " from " (length files) " file(s).\n")
    (print (string/format "Options: %p\n" opts))))

(defn main [& args]
  (def opts (runner/parse-cli-args (strip-script-arg args)))
  (def suite (get opts :suite :all))
  (def files (suites/files-for-suite suite))
  (suites/load-test-files! files)
  (print-loaded suite files opts)
  (runner/run-tests opts))
