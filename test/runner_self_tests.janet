(use ../mini-test)
(import ../mini-test :as runner)

(deftest runner-cli-parses-compact-report
  "Runner CLI parser recognizes compact report mode and keeps existing filters."
  (def opts (runner/parse-cli-args [":report" "compact" ":match" "connection" ":headers" "false"]))
  (assert= :compact (opts :report))
  (assert= "connection" (opts :match))
  (assert= false (opts :headers)))

(deftest runner-normalizes-compact-report
  "Compact report mode maps to quiet, failure-preserving reporter options."
  (def opts (runner/normalize-report-options @{:report :compact :headers true :stream :all :stdout :always}))
  (assert= false (opts :headers))
  (assert= :none (opts :stream))
  (assert= :on-failure (opts :stdout))
  (assert= :fails (opts :loc)))
