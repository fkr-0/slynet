;;; slynet-inspector-xref-tests.el --- ERT tests for SLYNET inspector/xref UI -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-inspector-xref-test--connection ()
  "Return an in-memory SLYNET connection for inspector/xref tests."
  (slynet-client-make-test-connection nil))

(ert-deftest slynet-inspect-value-renders-stable-object-buffer ()
  (let ((slynet-current-connection (slynet-inspector-xref-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '(:title "root table"
                                      :object-id "obj-1"
                                      :content ("[0] alpha" "[1] beta")))
                 21)))
      (let ((buffer (slynet-inspect-value '("alpha" "beta"))))
        (should (equal requested '(inspect-for-emacs ("alpha" "beta"))))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-inspector-mode))
          (should (equal slynet-inspector-object-id "obj-1"))
          (should (string-match-p "root table" (buffer-string)))
          (goto-char (point-min))
          (should (search-forward "[0] alpha" nil t)))))))

(ert-deftest slynet-inspector-nth-part-renders-navigation-metadata ()
  (let ((slynet-current-connection (slynet-inspector-xref-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '(:title "child value"
                                      :object-id "obj-2"
                                      :parent-object-id "obj-1"
                                      :part-key "1"
                                      :content ("beta")))
                 22)))
      (let ((buffer (slynet-inspector-nth-part 1)))
        (should (equal requested '(inspector-nth-part 1)))
        (with-current-buffer buffer
          (should (equal slynet-inspector-object-id "obj-2"))
          (should (equal slynet-inspector-parent-object-id "obj-1"))
          (should (equal slynet-inspector-part-key "1"))
          (should (string-match-p "child value" (buffer-string))))))))

(ert-deftest slynet-inspector-history-controls-send-back-forward-refresh-rpcs ()
  (let ((slynet-current-connection (slynet-inspector-xref-test--connection))
        requests)
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (push form requests)
                 (funcall callback '(:title "value" :object-id "obj" :content ("value")))
                 24)))
      (slynet-inspector-pop)
      (slynet-inspector-next)
      (slynet-inspector-reinspect)
      (should (equal (nreverse requests)
                     '((inspector-pop) (inspector-next) (inspector-reinspect)))))))

(ert-deftest slynet-inspector-history-and-actions-are-discoverable ()
  (let ((slynet-current-connection (slynet-inspector-xref-test--connection))
        requests)
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (push form requests)
                 (pcase form
                   ('(inspector-history)
                    (funcall callback '((:index 0 :title "root" :object-id "obj-1" :current t))))
                   ('(inspector-actions)
                    (funcall callback '((:action-id :copy-value :label "Copy printed value" :callable t :support-class :native)
                                        (:action-id :edit-value :label "Edit inspected value" :callable nil :support-class :unsupported)))))
                 25)))
      (let ((history (slynet-inspector-history))
            (actions (slynet-inspector-actions)))
        (with-current-buffer history
          (should (string-match-p "root" (buffer-string))))
        (with-current-buffer actions
          (goto-char (point-min))
          (should (search-forward "Copy printed value" nil t))
          (should (button-at (1- (point))))
          (should (search-forward "Edit inspected value" nil t))
          (should-not (button-at (1- (point)))))
        (should (equal (nreverse requests) '((inspector-history) (inspector-actions))))))))

(ert-deftest slynet-inspector-copy-action-populates-kill-ring ()
  (let ((slynet-current-connection (slynet-inspector-xref-test--connection))
        kill-ring)
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (should (equal form '(inspector-call-nth-action 0)))
                 (funcall callback '(:status :ok :action-id :copy-value :value "{:answer 42}"))
                 26)))
      (slynet-inspector-call-action 0)
      (should (equal (current-kill 0 t) "{:answer 42}")))))

(ert-deftest slynet-find-definitions-renders-source-index-hits ()
  (let ((slynet-current-connection (slynet-inspector-xref-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '((:name "fixture-target"
                                      :file "/tmp/project/sample_a.janet"
                                      :line 12
                                      :column 7
                                      :snippet "(defn fixture-target [] :ok)"
                                      :source-index :slynet-source-index
                                      :xref-kind :definition)))
                 23)))
      (let ((buffer (slynet-find-definitions "fixture-target")))
        (should (equal requested '(find-definitions-for-emacs "fixture-target")))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-xref-mode))
          (goto-char (point-min))
          (should (search-forward "fixture-target" nil t))
          (should (search-forward "/tmp/project/sample_a.janet:12:7" nil t))
          (should (search-forward "(defn fixture-target [] :ok)" nil t))
          (goto-char (point-min))
          (should (search-forward "/tmp/project/sample_a.janet" nil t))
          (should (equal (get-text-property (line-beginning-position) 'slynet-xref-file)
                         "/tmp/project/sample_a.janet")))))))

(provide 'slynet-inspector-xref-tests)
;;; slynet-inspector-xref-tests.el ends here
