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

(provide 'slynet-completion-tests)
;;; slynet-completion-tests.el ends here
