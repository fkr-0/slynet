;;; slynet-debugger-tests.el --- ERT tests for SLYNET debugger UI -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defun slynet-debugger-test--connection ()
  "Return an in-memory SLYNET connection for debugger tests."
  (slynet-client-make-test-connection nil))

(ert-deftest slynet-debugger-info-renders-condition-restarts-and-frames ()
  (let ((slynet-current-connection (slynet-debugger-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback
                          '(:condition-record (:id "cond-1"
                                                :kind :evaluation-error
                                                :message "unknown symbol"
                                                :support-class :emulated
                                                :cl-condition-equivalent nil)
                            :restarts ((:name "abort-to-repl"
                                      :label "Abort to REPL"
                                      :restart-kind :synthetic
                                      :support-class :emulated))
                            :frames ((:index 0
                                      :callable "trigger-debugger"
                                      :location (:file "slynet/slynk.janet"
                                                 :line 42
                                                 :column 3
                                                 :source-kind :janet-debug-stack
                                                 :synthetic-location nil
                                                 :janet-status :error
                                                 :janet-pc 9
                                                 :janet-slots-count 2)))))
                 31)))
      (let ((buffer (slynet-debugger-info)))
        (should (equal requested '(debugger-info-for-emacs)))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-debugger-mode))
          (should (string-match-p "unknown symbol" (buffer-string)))
          (should (string-match-p "Condition support: emulated" (buffer-string)))
          (should (string-match-p "CL condition equivalent: nil" (buffer-string)))
          (should (string-match-p "abort-to-repl" (buffer-string)))
          (should (string-match-p "eq=nil" (buffer-string)))
          (should (string-match-p "trigger-debugger" (buffer-string)))
          (should (string-match-p "slynet/slynk.janet:42:3" (buffer-string)))
          (should (string-match-p "source=janet-debug-stack" (buffer-string)))
          (should (string-match-p "janet-status=error" (buffer-string)))
          (should (string-match-p "pc=9" (buffer-string))))))))

(ert-deftest slynet-wire-event-renders-buffer ()
  (let ((payload (list :condition-record (list :message "boom" :kind :evaluation-error :support-class :emulated :cl-condition-equivalent nil)
                       :restarts (list (list :name "abort-to-repl" :restart-kind :synthetic :support-class :emulated))
                       :frames (list (list :index 0 :callable "leaf"
                                           :location (list :file "src/app.janet" :line 7 :column 11
                                                           :source-kind :janet-debug-stack :synthetic-location nil
                                                           :janet-status :error :janet-pc 3 :janet-slots-count 1))))))
    (let ((buffer (slynet--handle-wire-message (list (intern (concat ":debug" "-activate")) payload))))
      (should (buffer-live-p buffer))
      (with-current-buffer buffer
        (should (derived-mode-p 'slynet-debugger-mode))
        (should (string-match-p "boom" (buffer-string)))
        (should (string-match-p "source=janet-debug-stack" (buffer-string)))
        (should (string-match-p "pc=3" (buffer-string)))))))

(ert-deftest slynet-debugger-invoke-restart-sends-restart-request-and-renders-result ()
  (let ((slynet-current-connection (slynet-debugger-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '(:ok "abort-to-repl"))
                 32)))
      (let ((buffer (slynet-debugger-invoke-restart 0)))
        (should (equal requested '(invoke-nth-restart 0)))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-debugger-mode))
          (should (string-match-p "Restart result" (buffer-string)))
          (should (string-match-p "abort-to-repl" (buffer-string))))))))

(ert-deftest slynet-list-execution-units-renders-thread-facade-metadata ()
  (let ((slynet-current-connection (slynet-debugger-test--connection))
        (requested nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection form callback &rest _ignored)
                 (setq requested form)
                 (funcall callback '((:id 1
                                      :name "main-repl"
                                      :status :running
                                      :execution-unit t
                                      :thread-model :slynet-execution-unit
                                      :cl-thread-equivalent nil)))
                 33)))
      (let ((buffer (slynet-list-execution-units)))
        (should (equal requested '(list-threads)))
        (with-current-buffer buffer
          (should (derived-mode-p 'slynet-debugger-mode))
          (should (string-match-p "main-repl" (buffer-string)))
          (should (string-match-p "slynet-execution-unit" (buffer-string)))
          (should (string-match-p "CL thread equivalent: nil" (buffer-string))))))))

(provide 'slynet-debugger-tests)
;;; slynet-debugger-tests.el ends here
