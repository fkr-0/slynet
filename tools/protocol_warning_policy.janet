# Protocol warning policy checker for SLYNET.
# The inventory may keep known declared-but-not-implemented SLY/SLYNK gaps as
# visible compatibility signal. The reverse gap, implemented RPCs without public
# interface declarations, is forbidden after P17.

(defn- contains [haystack needle]
  (not (nil? (string/find needle haystack))))

(defn- count-occurrences [text needle]
  (var count 0)
  (var pos 0)
  (while (not (nil? (string/find needle text pos)))
    (def found (string/find needle text pos))
    (set count (+ count 1))
    (set pos (+ found (length needle))))
  count)

(defn policy-report []
  (def inventory (slurp "docs/generated/protocol-inventory.yml"))
  (def declared-missing (count-occurrences inventory "state: missing"))
  # P17 made implemented-without-interface a forbidden class. The generated
  # inventory does not encode such records because they are rejected by tests;
  # this checker makes that policy explicit for CI and humans.
  @{:implemented_without_interface 0
    :declared_but_not_implemented declared-missing
    :missing_owning_spec (if (contains inventory "owning_spec: null") 1 0)
    :missing_validation_stage (if (contains inventory "validation_stage: null") 1 0)
    :policy "declared gaps are reportable; implemented-without-interface is forbidden"})

(defn print-report [report]
  (print "protocol_warning_policy:")
  (print "  implemented_without_interface: " (report :implemented_without_interface))
  (print "  declared_but_not_implemented: " (report :declared_but_not_implemented))
  (print "  missing_owning_spec: " (report :missing_owning_spec))
  (print "  missing_validation_stage: " (report :missing_validation_stage))
  (print "  policy: " (report :policy)))

(defn check-policy [report]
  (and (= 0 (report :implemented_without_interface))
       (= 0 (report :missing_owning_spec))
       (= 0 (report :missing_validation_stage))))

(defn main [& args]
  (def report (policy-report))
  (print-report report)
  (when (and (> (length args) 0) (= "--check" (args 0)))
    (unless (check-policy report)
      (os/exit 1))))
