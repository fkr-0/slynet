;;; slynet-client-tests.el --- Batch ERT tests for the SLYNET Emacs client -*- lexical-binding: t; -*-

(require 'ert)
(require 'slynet-client)

(ert-deftest slynet-client-encodes-six-byte-length-prefixed-sexp ()
  (let* ((message '(:emacs-rex (ping :pong) "core" nil 1))
         (payload (prin1-to-string message))
         (wire (slynet-client-encode-message message)))
    (should (equal (format "%06x" (string-bytes payload))
                   (substring wire 0 6)))
    (should (equal payload (substring wire 6)))))

(ert-deftest slynet-client-filter-waits-for-complete-fragmented-message ()
  (let* ((seen nil)
         (message '(:return (:ok 3) 1))
         (wire (slynet-client-encode-message message))
         (conn (slynet-client-make-test-connection
                (lambda (decoded) (push decoded seen)))))
    (slynet-client-filter conn (substring wire 0 4))
    (should (equal nil seen))
    (slynet-client-filter conn (substring wire 4))
    (should (equal (list message) seen))))

(ert-deftest slynet-client-filter-decodes-multiple-messages-from-one-chunk ()
  (let* ((seen nil)
         (first-message '(:return (:ok :one) 1))
         (second-message '(:channel-send 7 (:write-string "hello")))
         (wire (concat (slynet-client-encode-message first-message)
                       (slynet-client-encode-message second-message)))
         (conn (slynet-client-make-test-connection
                (lambda (decoded) (push decoded seen)))))
    (slynet-client-filter conn wire)
    (should (equal (list second-message first-message) seen))))

(provide 'slynet-client-tests)
;;; slynet-client-tests.el ends here
