# Canonical Janet runtime release metadata.
# project.janet remains the package/release source of truth; release-integrity
# verification requires this runtime value to match it exactly.

(def version "1.1.0")
(def compatible-versions @["1.1" "1.0"])

(def export-api
  @{:version version
    :compatible-versions compatible-versions})
