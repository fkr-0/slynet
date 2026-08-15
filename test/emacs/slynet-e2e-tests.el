;;; slynet-e2e-tests.el --- Live Emacs <-> Janet SLYNET E2E tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'slynet)

(defun slynet-e2e--free-port ()
  "Return an available localhost TCP port for a short-lived E2E server."
  (let ((probe (make-network-process :name "slynet-e2e-port-probe"
                                     :server t
                                     :host 'local
                                     :service t
                                     :noquery t)))
    (unwind-protect
        (process-contact probe :service)
      (delete-process probe))))

(defun slynet-e2e--start-server (port)
  "Start the documented Janet SLYNET CLI on PORT and return its process."
  (let* ((root (file-name-as-directory (expand-file-name default-directory)))
         (default-directory root)
         (process-environment
          (cons (concat "JANET_PATH=" root ":" (or (getenv "JANET_PATH") ""))
                process-environment))
         (buffer (generate-new-buffer " *slynet-e2e-server*"))
         (process (start-process "slynet-e2e-server" buffer
                                 "janet" "slynet/cli.janet"
                                 "--tcp" "--host" "127.0.0.1"
                                 "--port" (number-to-string port))))
    (set-process-query-on-exit-flag process nil)
    process))

(defun slynet-e2e--buffer-contains-p (process needle)
  "Return non-nil when PROCESS output buffer contains NEEDLE."
  (when-let ((buffer (process-buffer process)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (point-min))
        (search-forward needle nil t)))))

(defun slynet-e2e--tcp-accepts-p (port)
  "Return non-nil when localhost PORT accepts TCP connections."
  (condition-case nil
      (let ((probe (open-network-stream "slynet-e2e-ready-probe" nil "127.0.0.1" port)))
        (set-process-query-on-exit-flag probe nil)
        (delete-process probe)
        t)
    (error nil)))

(defun slynet-e2e--wait-until (predicate description &optional timeout-seconds)
  "Wait until PREDICATE returns non-nil, or fail with DESCRIPTION.
The wait is condition-based: each loop gives Emacs process filters a chance to
run, then checks PREDICATE again."
  (let ((deadline (+ (float-time) (or timeout-seconds 10.0)))
        value)
    (while (and (not (setq value (funcall predicate)))
                (< (float-time) deadline))
      (accept-process-output nil 0.05))
    (unless value
      (ert-fail (format "Timed out waiting for %s" description)))
    value))

(defun slynet-e2e--cleanup-process (process)
  "Delete PROCESS and its buffer when present."
  (when (process-live-p process)
    (delete-process process))
  (when-let ((buffer (and process (process-buffer process))))
    (when (buffer-live-p buffer)
      (kill-buffer buffer))))

(ert-deftest slynet-e2e-creates-mrepl-evals-and-closes-live-janet-server ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         (mrepl-result nil)
         (eval-result nil))
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda ()
             (and (process-live-p server)
                  (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (slynet-connect :host "127.0.0.1" :port port)
          (slynet-create-mrepl (lambda (result) (setq mrepl-result result)))
          (slynet-e2e--wait-until (lambda () mrepl-result) "MREPL creation")
          (should (consp mrepl-result))
          (should (numberp (car mrepl-result)))
          (should (string= "core> "
                           (slynet-client-connection-prompt-string
                            slynet-current-connection)))
          (should (string-match-p "SLYNET mrepl ready"
                                  (slynet-client-connection-repl-output
                                   slynet-current-connection)))
          (slynet-eval-mrepl-string
           "(+ 1 2)"
           (lambda (result) (setq eval-result result)))
          (slynet-e2e--wait-until (lambda () eval-result) "MREPL eval values")
          (should (string-match-p "3" (format "%S" eval-result)))
          (slynet-disconnect))
      (ignore-errors (slynet-disconnect))
      (slynet-e2e--cleanup-process server))))

(ert-deftest slynet-e2e-repeated-sessions-remain-clean ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         (iterations (string-to-number
                      (or (getenv "SLYNET_E2E_ITERATIONS") "10"))))
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda ()
             (and (process-live-p server)
                  (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (dotimes (index iterations)
            (let ((mrepl-result nil)
                  (eval-result nil)
                  (connection (slynet-connect :host "127.0.0.1" :port port)))
              (slynet-create-mrepl
               (lambda (result) (setq mrepl-result result)))
              (slynet-e2e--wait-until
               (lambda () mrepl-result)
               (format "MREPL creation iteration %d" index))
              (slynet-eval-mrepl-string
               (format "(+ %d 1)" index)
               (lambda (result) (setq eval-result result)))
              (slynet-e2e--wait-until
               (lambda () eval-result)
               (format "MREPL eval iteration %d" index))
              (should (string-match-p
                       (number-to-string (1+ index))
                       (format "%S" eval-result)))
              (slynet-client-disconnect connection)
              (should-not (slynet-client-connection-process connection))
              (should (= 0 (hash-table-count
                            (slynet-client-connection-pending-requests
                             connection)))))))
      (ignore-errors (slynet-disconnect))
      (slynet-e2e--cleanup-process server))))

(ert-deftest slynet-e2e-inflight-rpc-aborts-when-live-server-disappears ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         (result nil))
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda ()
             (and (process-live-p server)
                  (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (let ((connection (slynet-connect :host "127.0.0.1" :port port)))
            (slynet-client-send-rex-async
             connection '(interactive-eval-region "(os/sleep 10)")
             (lambda (payload) (setq result payload)))
            (delete-process server)
            (slynet-e2e--wait-until
             (lambda () result) "in-flight RPC connection-loss callback")
            (should (equal result '(:abort :connection-lost)))
            (should-not (slynet-client-connection-process connection))
            (should (= (hash-table-count
                        (slynet-client-connection-pending-requests connection))
                       0))))
      (ignore-errors (slynet-disconnect))
      (slynet-e2e--cleanup-process server))))

(provide 'slynet-e2e-tests)
;;; slynet-e2e-tests.el ends here
