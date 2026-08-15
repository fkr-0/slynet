;;; release_artifact_smoke.el --- Verify extracted SLYNET release artifacts -*- lexical-binding: t; -*-

(require 'slynet)

(defun slynet-release-smoke--wait-until (predicate description &optional timeout)
  "Wait for PREDICATE or signal an error naming DESCRIPTION."
  (let ((deadline (+ (float-time) (or timeout 10.0)))
        value)
    (while (and (not (setq value (funcall predicate)))
                (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (unless value
      (error "Timed out waiting for %s" description))
    value))

(let* ((port-text (or (getenv "SLYNET_SMOKE_PORT")
                      (error "SLYNET_SMOKE_PORT is required")))
       (port (string-to-number port-text))
       (mrepl-result nil)
       (eval-result nil))
  (unwind-protect
      (progn
        (slynet-connect :host "127.0.0.1" :port port)
        (slynet-create-mrepl (lambda (result) (setq mrepl-result result)))
        (slynet-release-smoke--wait-until
         (lambda () mrepl-result) "artifact MREPL creation")
        (slynet-eval-mrepl-string
         "(+ 40 2)"
         (lambda (result) (setq eval-result result)))
        (slynet-release-smoke--wait-until
         (lambda () eval-result) "artifact MREPL evaluation")
        (unless (string-match-p "42" (format "%S" eval-result))
          (error "Artifact evaluation returned %S instead of 42" eval-result))
        (princ "artifact-smoke: extracted Emacs client connected and evaluated 42\n"))
    (ignore-errors (slynet-disconnect))))

;;; release_artifact_smoke.el ends here
