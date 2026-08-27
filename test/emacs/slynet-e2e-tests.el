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


(defun slynet-e2e--rex (form &optional timeout)
  "Send FORM to the live backend and synchronously await its RPC payload."
  (let ((done nil)
        result)
    (slynet-client-send-rex-async
     slynet-current-connection form
     (lambda (payload)
       (setq result payload
             done t))
     nil nil (or timeout 5.0))
    (slynet-e2e--wait-until (lambda () done) (format "RPC %S" form) (or timeout 5.0))
    result))

(defun slynet-e2e--eval-values (code)
  "Evaluate CODE through the live backend and return its printed values."
  (let ((payload (slynet--sequence-to-list
                  (slynet-e2e--rex (list 'interactive-eval-region code)))))
    (slynet--sequence-to-list
     (or (slynet--plist-get payload :values)
         (slynet--plist-get payload 'values)))))

(defun slynet-e2e--connect-live (port)
  "Connect the public Emacs client to localhost PORT."
  (slynet-connect :host "127.0.0.1" :port port))

(ert-deftest slynet-e2e-daily-eval-compile-load-interrupt-and-cancel-live ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         (source-file (make-temp-file "slynet-editor-e2e-" nil ".janet"))
         cancel-result)
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda () (and (process-live-p server) (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (slynet-e2e--connect-live port)

          ;; Region: define a value and prove the following live RPC observes it.
          (with-temp-buffer
            (emacs-lisp-mode)
            (insert "(def slynet-e2e-region 101)")
            (slynet-eval-region (point-min) (point-max)))
          (should (equal (slynet-e2e--eval-values "slynet-e2e-region") '("101")))

          ;; Last form: only the final balanced form is submitted.
          (with-temp-buffer
            (emacs-lisp-mode)
            (insert "(def slynet-e2e-ignore 1)\n(def slynet-e2e-last 102)\n")
            (goto-char (point-max))
            (slynet-eval-last-form))
          (should (equal (slynet-e2e--eval-values "slynet-e2e-last") '("102")))

          ;; Definition: locate and evaluate the top-level form at point.
          (with-temp-buffer
            (emacs-lisp-mode)
            (insert "(def slynet-e2e-definition 103)\n")
            (goto-char (point-min))
            (forward-char 8)
            (slynet-eval-definition))
          (should (equal (slynet-e2e--eval-values "slynet-e2e-definition") '("103")))

          ;; Buffer: preserve order across multiple top-level forms.
          (with-temp-buffer
            (emacs-lisp-mode)
            (insert "(def slynet-e2e-buffer-a 104)\n(def slynet-e2e-buffer-b 105)\n")
            (slynet-eval-buffer))
          (should (equal (slynet-e2e--eval-values "(+ slynet-e2e-buffer-a slynet-e2e-buffer-b)")
                         '("209")))

          ;; Compile/load commands use an actual visiting file and their rendered
          ;; diagnostics buffers; load is additionally proven by backend state.
          (with-temp-file source-file
            (insert "(def slynet-e2e-file-value 211)\n"))
          (with-current-buffer (find-file-noselect source-file)
            (unwind-protect
                (progn
                  (let ((diagnostics (slynet-compile-current-file)))
                    (slynet-e2e--wait-until
                     (lambda () (> (buffer-size diagnostics) 0))
                     "compile-current-file diagnostics"))
                  (let ((diagnostics (slynet-load-current-file)))
                    (slynet-e2e--wait-until
                     (lambda () (> (buffer-size diagnostics) 0))
                     "load-current-file diagnostics")))
              (kill-buffer (current-buffer))))
          (should (equal (slynet-e2e--eval-values "slynet-e2e-file-value") '("211")))

          ;; Cooperative interruption targets a managed execution unit and is
          ;; verified through the live unit registry, not an Emacs message mock.
          (slynet-e2e--rex
           '(register-execution-unit "e2e-unit" "editor-e2e" :worker nil 1 1))
          (slynet-interrupt-execution-unit "e2e-unit")
          (let ((status (slynet-e2e--rex '(execution-unit-status "e2e-unit"))))
            (should (slynet--enum= (slynet--plist-get status :status) :interrupt-requested))
            (should (eq (slynet--plist-get status :interrupt-requested) t)))

          ;; Client cancellation resolves local callback/bookkeeping exactly
          ;; once. It deliberately does not claim to terminate arbitrary Janet
          ;; evaluation; the short backend sleep is allowed to complete later.
          (let ((request-id
                 (slynet-client-send-rex-async
                  slynet-current-connection
                  '(interactive-eval-region "(os/sleep 0.25)")
                  (lambda (payload) (setq cancel-result payload))
                  nil nil 2.0)))
            (should (= request-id (slynet-cancel-latest-request)))
            (slynet-e2e--wait-until (lambda () cancel-result) "client cancellation callback")
            (should (equal cancel-result '(:abort :user-cancelled)))
            (should-not (gethash request-id
                                 (slynet-client-connection-pending-requests
                                  slynet-current-connection))))
          (accept-process-output nil 0.35))
      (ignore-errors (slynet-disconnect))
      (ignore-errors (delete-file source-file))
      (slynet-e2e--cleanup-process server))))

(ert-deftest slynet-e2e-inspector-history-and-actions-live ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         kill-ring)
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda () (and (process-live-p server) (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (slynet-e2e--connect-live port)
          (let ((buffer (slynet-inspect-value '(10 20 30))))
            (slynet-e2e--wait-until
             (lambda () (with-current-buffer buffer slynet-inspector-object-id))
             "root inspector render")
            (let ((root-id (with-current-buffer buffer slynet-inspector-object-id)))
              (slynet-inspector-nth-part 1)
              (slynet-e2e--wait-until
               (lambda ()
                 (with-current-buffer buffer
                   (and slynet-inspector-parent-object-id
                        (not (equal slynet-inspector-object-id root-id)))))
               "inspector child navigation")
              (let ((child-id (with-current-buffer buffer slynet-inspector-object-id)))
                (slynet-inspector-pop)
                (slynet-e2e--wait-until
                 (lambda () (with-current-buffer buffer (equal slynet-inspector-object-id root-id)))
                 "inspector back navigation")
                (slynet-inspector-next)
                (slynet-e2e--wait-until
                 (lambda () (with-current-buffer buffer (equal slynet-inspector-object-id child-id)))
                 "inspector forward navigation")
                (slynet-inspector-reinspect)
                (slynet-e2e--wait-until
                 (lambda () (with-current-buffer buffer (equal slynet-inspector-object-id child-id)))
                 "inspector refresh")
                (let ((actions (slynet-inspector-actions)))
                  (slynet-e2e--wait-until
                   (lambda () (with-current-buffer actions (> (buffer-size) 0)))
                   "inspector action discovery"))
                (slynet-inspector-call-action 0)
                (slynet-e2e--wait-until
                 (lambda () (and kill-ring (string-match-p "20" (car kill-ring))))
                 "inspector copy action")))))
      (ignore-errors (slynet-disconnect))
      (slynet-e2e--cleanup-process server))))

(ert-deftest slynet-e2e-session-loss-marks-stale-and-reconnect-recovers-live ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         stale-buffer)
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda () (and (process-live-p server) (slynet-e2e--tcp-accepts-p port)))
           "initial Janet server TCP readiness")
          (slynet-e2e--connect-live port)
          (setq stale-buffer (slynet-inspect-value '(1 2 3)))
          (slynet-e2e--wait-until
           (lambda () (with-current-buffer stale-buffer slynet-inspector-object-id))
           "pre-loss inspector render")

          (let (loss-result)
            (slynet-client-send-rex-async
             slynet-current-connection
             '(interactive-eval-region "(os/sleep 10)")
             (lambda (payload) (setq loss-result payload)))
            (delete-process server)
            (slynet-e2e--wait-until
             (lambda () (equal loss-result '(:abort :connection-lost)))
             "connection-loss callback during server restart")
            (slynet-e2e--wait-until
             (lambda ()
               (and (not (slynet-client-connection-process slynet-current-connection))
                    (with-current-buffer stale-buffer slynet-buffer-stale)))
             "stale-session marking after server loss"))
          (with-current-buffer stale-buffer
            (should (string-match-p "stale session" (format "%s" header-line-format))))

          ;; Restart the same endpoint, reconnect through the public command,
          ;; and prove a fresh UI request clears stale state and reaches Janet.
          (setq server (slynet-e2e--start-server port))
          (slynet-e2e--wait-until
           (lambda () (and (process-live-p server) (slynet-e2e--tcp-accepts-p port)))
           "replacement Janet server TCP readiness")
          (slynet-reconnect)
          (should (equal (slynet-e2e--eval-values "(+ 40 2)") '("42")))
          (setq stale-buffer (slynet-inspect-value '(4 5 6)))
          (slynet-e2e--wait-until
           (lambda ()
             (with-current-buffer stale-buffer
               (and slynet-inspector-object-id (not slynet-buffer-stale))))
           "fresh inspector after reconnect"))
      (ignore-errors (slynet-disconnect))
      (slynet-e2e--cleanup-process server))))

(ert-deftest slynet-e2e-request-timeout-ignores-late-reply-and-recovers-live ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         result)
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda () (and (process-live-p server) (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (slynet-e2e--connect-live port)
          (let ((request-id
                 (slynet-client-send-rex-async
                  slynet-current-connection
                  '(interactive-eval-region "(os/sleep 0.25)")
                  (lambda (payload) (setq result payload))
                  nil nil 0.05)))
            (slynet-e2e--wait-until (lambda () result) "live request timeout")
            (should (equal result '(:abort :timeout)))
            (should-not
             (gethash request-id
                      (slynet-client-connection-pending-requests
                       slynet-current-connection)))
            (should (= 0 (hash-table-count
                          (slynet-client-connection-pending-requests
                           slynet-current-connection)))))
          ;; Let the backend's late reply arrive.  It must not resurrect the
          ;; timed-out callback or poison the next request on this connection.
          (accept-process-output nil 0.35)
          (should (equal result '(:abort :timeout)))
          (should (equal (slynet-e2e--eval-values "(+ 6 7)") '("13"))))
      (ignore-errors (slynet-disconnect))
      (slynet-e2e--cleanup-process server))))

(ert-deftest slynet-e2e-debugger-diagnostics-xref-and-recovery-live ()
  (let* ((port (slynet-e2e--free-port))
         (server (slynet-e2e--start-server port))
         (source-file (make-temp-file "slynet-error-e2e-" nil ".janet")))
    (unwind-protect
        (progn
          (slynet-e2e--wait-until
           (lambda () (and (process-live-p server) (slynet-e2e--tcp-accepts-p port)))
           "Janet server TCP readiness")
          (slynet-e2e--connect-live port)

          ;; A real evaluation failure must populate debugger state without
          ;; rendering the connection unusable.
          (let ((failed (slynet-e2e--rex
                         '(interactive-eval-region "(not-a-real-e2e-symbol)"))))
            (should (and (consp failed) (eq (car failed) :abort))))
          (let ((debugger (slynet-debugger-info)))
            (slynet-e2e--wait-until
             (lambda ()
               (with-current-buffer debugger
                 (and (string-match-p "Condition:" (buffer-string))
                      (string-match-p "evaluation-error" (buffer-string))
                      (string-match-p "Frames:" (buffer-string)))))
             "live debugger rendering")
            (let ((restart-buffer (slynet-debugger-invoke-restart 0)))
              (slynet-e2e--wait-until
               (lambda ()
                 (with-current-buffer restart-buffer
                   (string-match-p "abort-to-repl" (buffer-string))))
               "live debugger restart")))

          ;; Source navigation is exercised through the public UI command and
          ;; the real project source index.
          (let ((xref-buffer (slynet-find-definitions "connection-info")))
            (slynet-e2e--wait-until
             (lambda ()
               (with-current-buffer xref-buffer
                 (and (string-match-p "connection-info" (buffer-string))
                      (string-match-p "slynet/" (buffer-string)))))
             "live xref rendering"))

          ;; Compile a genuinely malformed visiting file and assert that the
          ;; diagnostic renderer receives a path-aware backend error.
          (with-temp-file source-file
            (insert "(def slynet-e2e-broken "))
          (with-current-buffer (find-file-noselect source-file)
            (unwind-protect
                (let ((diagnostics (slynet-compile-current-file)))
                  (slynet-e2e--wait-until
                   (lambda ()
                     (with-current-buffer diagnostics
                       (and (string-match-p "SLYNET diagnostics" (buffer-string))
                            (string-match-p "error" (buffer-string))
                            (string-match-p
                             (regexp-quote source-file) (buffer-string)))))
                   "live compile diagnostic rendering"))
              (kill-buffer (current-buffer))))

          ;; A protocol-level inspector error must abort only that request.
          (slynet-e2e--rex '(inspect-for-emacs @[1 2]))
          (let ((bad-part (slynet-e2e--rex '(inspector-nth-part 99))))
            (should (and (consp bad-part) (eq (car bad-part) :abort))))
          (should (equal (slynet-e2e--eval-values "(+ 20 22)") '("42"))))
      (ignore-errors (slynet-disconnect))
      (ignore-errors (delete-file source-file))
      (slynet-e2e--cleanup-process server))))

(provide 'slynet-e2e-tests)
;;; slynet-e2e-tests.el ends here
