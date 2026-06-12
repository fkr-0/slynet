;;; slynet-interactive-ui-tests.el --- ERT tests for interactive SLYNET UI phases -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-interactive-ui-test--connection ()
  "Return an in-memory SLYNET connection for interactive UI tests."
  (slynet-client-make-test-connection nil))

(ert-deftest slynet-inspector-renders-clickable-parts ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (requests nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (push form requests)
                 (if (equal form '(inspect-for-emacs root-value))
                     (funcall callback '(:title "root"
                                          :object-id "obj-1"
                                          :content ("root value")
                                          :parts ((:index 0 :label "[0] alpha" :summary "alpha"))))
                   (funcall callback '(:title "alpha"
                                        :object-id "obj-2"
                                        :parent-object-id "obj-1"
                                        :part-key "0"
                                        :content ("alpha"))))
                 41)))
      (let ((buffer (slynet-inspect-value 'root-value)))
        (with-current-buffer buffer
          (goto-char (point-min))
          (should (search-forward "[0] alpha" nil t))
          (let ((button (button-at (1- (point)))))
            (should button)
            (button-activate button)))
        (should (equal (car requests) '(inspector-nth-part 0)))))))

(ert-deftest slynet-xref-visit-at-point-opens-source-location ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (visited nil)
        (line nil)
        (column nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection _form callback &rest _ignored)
                 (funcall callback '((:name "fixture-target"
                                      :file "/tmp/project/sample_a.janet"
                                      :line 12
                                      :column 7
                                      :snippet "(defn fixture-target [] :ok)"
                                      :source-index :slynet-source-index
                                      :xref-kind :definition)))
                 42))
              ((symbol-function 'find-file-other-window)
               (lambda (file) (setq visited file) (get-buffer-create "*slynet-test-source*")))
              ((symbol-function 'forward-line)
               (lambda (n) (setq line (1+ n))))
              ((symbol-function 'move-to-column)
               (lambda (n) (setq column n))))
      (let ((buffer (slynet-find-definitions "fixture-target")))
        (with-current-buffer buffer
          (goto-char (point-min))
          (search-forward "/tmp/project/sample_a.janet" nil t)
          (slynet-xref-visit-at-point))
        (should (equal visited "/tmp/project/sample_a.janet"))
        (should (equal line 12))
        (should (equal column 7))))))

(ert-deftest slynet-debugger-restarts-are-clickable ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (requests nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (push form requests)
                 (if (equal form '(debugger-info-for-emacs))
                     (funcall callback '(:condition-record (:message "boom" :kind :evaluation-error)
                                          :restarts ((:name "abort-to-repl"
                                                      :label "Abort to REPL"
                                                      :restart-kind :synthetic
                                                      :support-class :emulated))
                                          :frames nil))
                   (funcall callback '(:ok "abort-to-repl")))
                 43)))
      (let ((buffer (slynet-debugger-info)))
        (with-current-buffer buffer
          (goto-char (point-min))
          (should (search-forward "Abort to REPL" nil t))
          (let ((button (button-at (1- (point)))))
            (should button)
            (button-activate button)))
        (should (equal (car requests) '(invoke-nth-restart 0)))))))

(ert-deftest slynet-debugger-frame-source-jumps-to-location ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (visited nil)
        (line nil)
        (column nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection _form callback &rest _ignored)
                 (funcall callback '(:condition-record (:message "boom")
                                      :restarts nil
                                      :frames ((:index 0
                                                :callable "trigger-debugger"
                                                :location (:file "/tmp/slynk.janet"
                                                           :line 42
                                                           :column 3
                                                           :source-kind :source-index)))))
                 44))
              ((symbol-function 'find-file-other-window)
               (lambda (file) (setq visited file) (get-buffer-create "*slynet-debug-source*")))
              ((symbol-function 'forward-line)
               (lambda (n) (setq line (1+ n))))
              ((symbol-function 'move-to-column)
               (lambda (n) (setq column n))))
      (let ((buffer (slynet-debugger-info)))
        (with-current-buffer buffer
          (goto-char (point-min))
          (search-forward "trigger-debugger" nil t)
          (slynet-debugger-visit-frame-source))
        (should (equal visited "/tmp/slynk.janet"))
        (should (equal line 42))
        (should (equal column 3))))))

(ert-deftest slynet-compile-string-renders-clickable-diagnostics ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (visited nil)
        (line nil)
        (column nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (should (equal form '(compile-string-for-emacs "(bad" "buffer.janet")))
                 (funcall callback '(:status :error
                                      :diagnostic-model :janet-diagnostics
                                      :diagnostics ((:severity :error
                                                     :phase :compile-string
                                                     :message "unexpected EOF"
                                                     :path "/tmp/project/buffer.janet"
                                                     :line 4
                                                     :column 2))))
                 45))
              ((symbol-function 'find-file-other-window)
               (lambda (file) (setq visited file) (get-buffer-create "*slynet-diagnostic-source*")))
              ((symbol-function 'forward-line)
               (lambda (n) (setq line (1+ n))))
              ((symbol-function 'move-to-column)
               (lambda (n) (setq column n))))
      (let ((buffer (slynet-compile-string "(bad" "buffer.janet")))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-diagnostics-mode))
          (goto-char (point-min))
          (should (search-forward "unexpected EOF" nil t))
          (slynet-diagnostics-visit-at-point))
        (should (equal visited "/tmp/project/buffer.janet"))
        (should (equal line 4))
        (should (equal column 2))))))

(ert-deftest slynet-named-connection-management-switches-current-connection ()
  (let ((opened nil))
    (cl-letf (((symbol-function 'slynet-client-connect)
               (lambda (&rest args)
                 (push args opened)
                 (slynet-client-make-test-connection nil))))
      (let ((first (slynet-connect-named "project-a" :host "127.0.0.1" :port 4005))
            (second (slynet-connect-named "project-b" :host "127.0.0.1" :port 4006)))
        (should (eq slynet-current-connection second))
        (should (eq (slynet-switch-connection "project-a") first))
        (should (eq slynet-current-connection first))
        (should (= (length opened) 2))))))

(ert-deftest slynet-project-root-finds-janet-project-marker ()
  (let* ((root (make-temp-file "slynet-root" t))
         (child (expand-file-name "src/nested" root)))
    (unwind-protect
        (progn
          (make-directory child t)
          (with-temp-file (expand-file-name "project.janet" root) (insert "# project"))
          (let ((default-directory child))
            (should (equal (file-truename root)
                           (file-truename (slynet-project-root))))))
      (delete-directory root t))))

(ert-deftest slynet-flex-completions-cache-and-clear ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (requests nil))
    (slynet-clear-completion-cache)
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (push form requests)
                 (funcall callback '((("connection-info" (:doc "Connection metadata"))) "connection-"))
                 46)))
      (slynet-flex-completions-for-pattern "conn" (lambda (_items _prefix) nil))
      (slynet-flex-completions-for-pattern "conn" (lambda (_items _prefix) nil))
      (should (= (length requests) 1))
      (let ((cached (gethash "conn" slynet-completion-cache)))
        (should cached)
        (should (equal (get-text-property 0 'slynet-doc (car cached)) "Connection metadata")))
      (slynet-clear-completion-cache)
      (should-not (gethash "conn" slynet-completion-cache)))))

(provide 'slynet-interactive-ui-tests)
;;; slynet-interactive-ui-tests.el ends here
