;;; slynet-interactive-ui-tests.el --- ERT tests for interactive SLYNET UI phases -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-interactive-ui-test--connection ()
  "Return an in-memory SLYNET connection for interactive UI tests."
  (slynet-client-make-test-connection nil))

(defun slynet-interactive-ui-test--source-buffer (name line-count)
  "Return NAME populated with LINE-COUNT navigable source lines."
  (let ((buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (dotimes (index line-count)
          (insert (format "source line %03d ................................\n"
                          (1+ index))))))
    buffer))

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
        (source-buffer (slynet-interactive-ui-test--source-buffer
                        "*slynet-test-source*" 20)))
    (unwind-protect
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
                   (lambda (file) (setq visited file) source-buffer)))
          (let ((buffer (slynet-find-definitions "fixture-target")))
            (with-current-buffer buffer
              (goto-char (point-min))
              (search-forward "/tmp/project/sample_a.janet" nil t)
              (slynet-xref-visit-at-point))
            (should (equal visited "/tmp/project/sample_a.janet"))
            (with-current-buffer source-buffer
              (should (= (line-number-at-pos) 12))
              (should (= (current-column) 7)))))
      (kill-buffer source-buffer))))

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
        (source-buffer (slynet-interactive-ui-test--source-buffer
                        "*slynet-debug-source*" 50)))
    (unwind-protect
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
                   (lambda (file) (setq visited file) source-buffer)))
          (let ((buffer (slynet-debugger-info)))
            (with-current-buffer buffer
              (goto-char (point-min))
              (search-forward "trigger-debugger" nil t)
              (slynet-debugger-visit-frame-source))
            (should (equal visited "/tmp/slynk.janet"))
            (with-current-buffer source-buffer
              (should (= (line-number-at-pos) 42))
              (should (= (current-column) 3)))))
      (kill-buffer source-buffer))))

(ert-deftest slynet-compile-string-renders-clickable-diagnostics ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        (visited nil)
        (source-buffer (slynet-interactive-ui-test--source-buffer
                        "*slynet-diagnostic-source*" 10)))
    (unwind-protect
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
                   (lambda (file) (setq visited file) source-buffer)))
          (let ((buffer (slynet-compile-string "(bad" "buffer.janet")))
            (with-current-buffer buffer
              (should (derived-mode-p 'slynet-diagnostics-mode))
              (goto-char (point-min))
              (should (search-forward "unexpected EOF" nil t))
              (slynet-diagnostics-visit-at-point))
            (should (equal visited "/tmp/project/buffer.janet"))
            (with-current-buffer source-buffer
              (should (= (line-number-at-pos) 4))
              (should (= (current-column) 2)))))
      (kill-buffer source-buffer))))

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

(ert-deftest slynet-daily-eval-region-and-buffer-send-exact-source ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        requests)
    (cl-letf (((symbol-function 'slynet-client-send-rex)
               (lambda (_connection form &rest _ignored)
                 (push form requests)
                 70)))
      (with-temp-buffer
        (insert "(+ 1 2)\n(+ 3 4)")
        (slynet-eval-region 1 8)
        (slynet-eval-buffer))
      (should (equal (nreverse requests)
                     '((interactive-eval-region "(+ 1 2)")
                       (interactive-eval-region "(+ 1 2)\n(+ 3 4)")))))))

(ert-deftest slynet-daily-eval-last-form-selects-complete-form ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        request)
    (cl-letf (((symbol-function 'slynet-client-send-rex)
               (lambda (_connection form &rest _ignored)
                 (setq request form)
                 71)))
      (with-temp-buffer
        (emacs-lisp-mode)
        (insert "(+ 1 2)\n(* 6 7)   \n")
        (goto-char (point-max))
        (slynet-eval-last-form))
      (should (equal request '(interactive-eval-region "(* 6 7)"))))))

(ert-deftest slynet-daily-eval-definition-uses-balanced-top-level-form-bounds ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        request)
    (cl-letf (((symbol-function 'slynet-client-send-rex)
               (lambda (_connection form &rest _ignored)
                 (setq request form)
                 72)))
      (with-temp-buffer
        (emacs-lisp-mode)
        (insert "(defn first [] 1)\n\n(defn second [] 2)\n")
        (goto-char (point-max))
        (forward-line -1)
        (slynet-eval-definition))
      (should (equal request '(interactive-eval-region "(defn second [] 2)"))))))

(ert-deftest slynet-daily-compile-and-load-current-file-use-file-rpcs ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        requests)
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (push form requests)
                 (funcall callback '(:diagnostic-model :janet-diagnostics
                                      :diagnostics nil))
                 73)))
      (with-temp-buffer
        (setq buffer-file-name "/tmp/slynet-daily.janet")
        (slynet-compile-current-file)
        (slynet-load-current-file))
      (should (equal (nreverse requests)
                     '((compile-file-for-emacs "/tmp/slynet-daily.janet")
                       (load-file "/tmp/slynet-daily.janet")))))))

(ert-deftest slynet-daily-file-commands-require-visiting-file ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection)))
    (with-temp-buffer
      (should-error (slynet-compile-current-file) :type 'user-error)
      (should-error (slynet-load-current-file) :type 'user-error))))

(ert-deftest slynet-daily-interrupt-targets-managed-execution-unit ()
  (let ((slynet-current-connection (slynet-interactive-ui-test--connection))
        request)
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq request form)
                 (funcall callback '(:status :requested :cooperative t))
                 74)))
      (should (= 74 (slynet-interrupt-execution-unit "unit-7")))
      (should (equal request '(interrupt-execution-unit "unit-7"))))))

(ert-deftest slynet-create-mrepl-is-a-working-interactive-command ()
  (let ((connection (slynet-interactive-ui-test--connection))
        opened)
    (let ((slynet-current-connection connection))
      (cl-letf (((symbol-function 'slynet-client-create-mrepl)
                 (lambda (_connection callback)
                   (funcall callback '(7 11))
                   75))
                ((symbol-function 'slynet-repl)
                 (lambda (&optional _connection)
                   (get-buffer-create "*slynet-test-interactive-repl*")))
                ((symbol-function 'pop-to-buffer)
                 (lambda (buffer &rest _ignored)
                   (setq opened buffer)
                   buffer)))
        (should (= 75 (call-interactively #'slynet-create-mrepl)))
        (should (buffer-live-p opened))
        (kill-buffer opened)))))

(ert-deftest slynet-daily-cancel-latest-request-selects-newest-pending-id ()
  (let* ((connection (slynet-interactive-ui-test--connection))
         (slynet-current-connection connection)
         cancelled)
    (puthash 3 t (slynet-client-connection-pending-requests connection))
    (puthash 9 t (slynet-client-connection-pending-requests connection))
    (puthash 5 t (slynet-client-connection-pending-requests connection))
    (cl-letf (((symbol-function 'slynet-client-cancel-request)
               (lambda (_connection request-id reason)
                 (setq cancelled (list request-id reason))
                 t)))
      (should (= 9 (slynet-cancel-latest-request)))
      (should (equal cancelled '(9 :user-cancelled))))))

(provide 'slynet-interactive-ui-tests)
;;; slynet-interactive-ui-tests.el ends here
