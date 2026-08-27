# Fail closed when the generated 1.1 stable protocol subset is below the
# per-frontend-surface direct-test threshold.

(def inventory-path "docs/generated/protocol-inventory.yml")

(defn- section-between [text start-marker end-marker]
  (def start (string/find start-marker text))
  (unless start
    (error (string "protocol coverage gate: missing " start-marker)))
  (def finish (string/find end-marker text (+ start (length start-marker))))
  (unless finish
    (error (string "protocol coverage gate: missing " end-marker)))
  (string/slice text start finish))

(defn run-gate []
  (def text (slurp inventory-path))
  (def audit (section-between text "stable_subset_coverage:\n" "operations:\n"))
  (unless (not (nil? (string/find "required_percent: 100" audit)))
    (error "protocol coverage gate: stable subset threshold is not 100 percent"))
  (when (not (nil? (string/find "gate: fail" audit)))
    (eprintf "%s\n" audit)
    (error "protocol coverage gate: one or more stable frontend surfaces are below threshold"))
  (unless (not (nil? (string/find "  gate: pass" audit)))
    (error "protocol coverage gate: aggregate stable subset gate is not pass"))
  (print "protocol-coverage: every declared stable frontend surface is 100% directly tested")
  true)

(run-gate)
