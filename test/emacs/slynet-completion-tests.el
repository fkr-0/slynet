;;; slynet-completion-tests.el --- ERT tests for SLYNET completion UI -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-completion-test--connection ()
  "Return an in-memory SLYNET connection for completion tests."
  (slynet-client-make-test-connection nil))

(ert-deftest slynet-completion-at-point-queries-simple-completions ()
  (let ((slynet-current-connection (slynet-completion-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '(("connect" "connection") "con"))
                 17)))
      (with-temp-buffer
        (insert "con")
        (let ((capf (slynet-completion-at-point-function)))
          (should (equal requested '(simple-completions "con" "core")))
          (should (= (nth 0 capf) 1))
          (should (= (nth 1 capf) 4))
          (should (equal (mapcar #'substring-no-properties (nth 2 capf))
                         '("connect" "connection"))))))))

(ert-deftest slynet-completion-candidates-carry-support-metadata ()
  (let ((slynet-current-connection (slynet-completion-test--connection)))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection _form callback &rest _ignored)
                 (funcall callback '(("map" "mapcat") "map"))
                 18)))
      (with-temp-buffer
        (insert "map")
        (let* ((capf (slynet-completion-at-point-function))
               (candidate (car (nth 2 capf))))
          (should (equal "map" (substring-no-properties candidate)))
          (should (eq 'simple-completions
                      (get-text-property 0 'slynet-completion-source candidate)))
          (should (eq 'native
                      (get-text-property 0 'slynet-support-class candidate))))))))

(ert-deftest slynet-arglist-normalizes-autodoc-metadata ()
  (let ((slynet-current-connection (slynet-completion-test--connection))
        (requested nil)
        (received nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '("x" "y"))
                 19)))
      (slynet-arglist "map" (lambda (payload) (setq received payload)))
      (should (equal requested '(operator-arglist "map" "core")))
      (should (equal (plist-get received :operator) "map"))
      (should (equal (plist-get received :arglist) '("x" "y")))
      (should (eq (plist-get received :frontend-surface) 'autodoc))
      (should (eq (plist-get received :support-class) 'native)))))


(ert-deftest slynet-doc-symbol-renders-scrollable-doc-buffer ()
  (let ((slynet-current-connection (slynet-completion-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback
                          '(:status :ok
                            :operator "connection-info"
                            :frontend-surface :autodoc
                            :support-class :workaround
                            :cl-autodoc-equivalent nil
                            :arglist "()"
                            :documentation "Return connection metadata."
                            :source-locations ((:file "slynet/slynk.janet"
                                                :line 170
                                                :column 7
                                                :source-index :slynet-source-index-v2))))
                 29)))
      (let ((buffer (slynet-doc-symbol "connection-info")))
        (should (equal requested '(autodoc "(connection-info")))
        (with-current-buffer buffer
          (goto-char (point-min))
          (should (eq major-mode 'slynet-doc-mode))
          (should (search-forward "SLYNET Janet Docs" nil t))
          (should (search-forward "Name: connection-info" nil t))
          (should (search-forward "Support: workaround" nil t))
          (should (search-forward "Return connection metadata." nil t))
          (should (search-forward "source-index=slynet-source-index-v2" nil t)))))))

(ert-deftest slynet-autodoc-sends-form-and-callback-payload ()
  (let ((slynet-current-connection (slynet-completion-test--connection))
        (requested nil)
        (received nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '(:status :ok :operator "map" :arglist "(f xs)"))
                 30)))
      (slynet-autodoc "(map" (lambda (payload) (setq received payload)))
      (should (equal requested '(autodoc "(map")))
      (should (equal (plist-get received :operator) "map")))))

(ert-deftest slynet-complete-form-sends-form-and-callback-payload ()
  (let ((slynet-current-connection (slynet-completion-test--connection))
        (requested nil)
        (received nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '(:status :ok :prefix "con" :candidates ((:name "connection-info"))))
                 31)))
      (slynet-complete-form "(con" (lambda (payload) (setq received payload)))
      (should (equal requested '(complete-form "(con")))
      (should (equal (plist-get received :prefix) "con")))))


(provide 'slynet-completion-tests)
;;; slynet-completion-tests.el ends here
