;;; slynet-diagnostics-source-tests.el --- ERT tests for source-aware diagnostics -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-diagnostics-source-test--connection ()
  "Return an in-memory SLYNET connection for diagnostics source tests."
  (slynet-client-make-test-connection nil))

(ert-deftest slynet-runtime-error-diagnostics-renders-through-diagnostics-ui ()
  (let ((slynet-current-connection (slynet-diagnostics-source-test--connection))
        (visited nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (should (equal form '(runtime-error-diagnostics "(bad)" "/tmp/runtime.janet" 3 1)))
                 (funcall callback '(:status :error
                                      :diagnostic-model :janet-diagnostics
                                      :cl-compiler-note-equivalent nil
                                      :diagnostics ((:severity :error
                                                     :phase :runtime-error
                                                     :message "unknown symbol bad"
                                                     :path "/tmp/runtime.janet"
                                                     :line 3
                                                     :column 1
                                                     :source-index :slynet-diagnostic-source))))
                 47))
              ((symbol-function 'find-file-other-window)
               (lambda (file) (setq visited file) (get-buffer-create "*slynet-runtime-source*"))))
      (let ((buffer (slynet-runtime-error-diagnostics "(bad)" "/tmp/runtime.janet" 3 1)))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-diagnostics-mode))
          (goto-char (point-min))
          (should (search-forward "runtime-error" nil t))
          (slynet-diagnostics-visit-at-point))
        (should (equal visited "/tmp/runtime.janet"))))))

(provide 'slynet-diagnostics-source-tests)
;;; slynet-diagnostics-source-tests.el ends here
