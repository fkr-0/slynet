;;; slynet-repl-tests.el --- ERT tests for SLYNET REPL buffer UI -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-repl-test--make-connection ()
  "Return an in-memory SLYNET client connection for REPL buffer tests."
  (let ((connection (slynet-client-make-test-connection nil)))
    (setf (slynet-client-connection-channel-id connection) 7)
    connection))

(defmacro slynet-repl-test--with-buffer-cleanup (&rest body)
  "Run BODY and kill any SLYNET REPL buffers created by the test."
  (declare (indent 0) (debug t))
  `(unwind-protect
       (progn ,@body)
     (dolist (buffer (buffer-list))
       (when (string-prefix-p "*slynet-repl" (buffer-name buffer))
         (kill-buffer buffer)))
     (setq slynet-current-connection nil)))

(ert-deftest slynet-repl-opens-and-reuses-buffer-for-current-connection ()
  (slynet-repl-test--with-buffer-cleanup
    (let ((connection (slynet-repl-test--make-connection)))
      (setq slynet-current-connection connection)
      (let ((first-buffer (slynet-repl))
            (second-buffer (slynet-repl)))
        (should (buffer-live-p first-buffer))
        (should (eq first-buffer second-buffer))
        (should (eq first-buffer (slynet-client-connection-repl-buffer connection)))
        (with-current-buffer first-buffer
          (should (derived-mode-p 'slynet-repl-mode)))))))

(ert-deftest slynet-repl-renders-channel-output-values-and-read-only-prompt ()
  (slynet-repl-test--with-buffer-cleanup
    (let ((connection (slynet-repl-test--make-connection)))
      (setq slynet-current-connection connection)
      (let ((buffer (slynet-repl)))
        (slynet-client-handle-message connection '(:channel-send 7 (:write-string "hello\n")))
        (slynet-client-handle-message connection '(:channel-send 7 (:write-values ("3" "\n"))))
        (slynet-client-handle-message connection '(:channel-send 7 (:prompt "core" "core" nil nil)))
        (with-current-buffer buffer
          (should (string= "hello\n3\ncore> " (buffer-string)))
          (goto-char (point-min))
          (search-forward "core> ")
          (should (get-text-property (1- (point)) 'read-only)))))))

(ert-deftest slynet-repl-submit-string-records-history-and-dispatches-eval ()
  (slynet-repl-test--with-buffer-cleanup
    (let ((connection (slynet-repl-test--make-connection))
          (sent nil))
      (setq slynet-current-connection connection)
      (let ((buffer (slynet-repl)))
        (cl-letf (((symbol-function 'slynet-eval-mrepl-string)
                   (lambda (string callback)
                     (push (list string callback) sent))))
          (with-current-buffer buffer
            (slynet-repl-submit-string "(+ 1 2)")
            (slynet-repl-submit-string "(* 2 3)")
            (should (equal slynet-repl-input-history '("(+ 1 2)" "(* 2 3)")))
            (should (equal (mapcar #'car (reverse sent)) '("(+ 1 2)" "(* 2 3)")))))))))

(provide 'slynet-repl-tests)
;;; slynet-repl-tests.el ends here
