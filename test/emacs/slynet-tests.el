;;; slynet-tests.el --- ERT tests for public SLYNET Emacs API -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'slynet)

(defmacro slynet-test-with-fake-transport (&rest body)
  "Run BODY with network/process primitives replaced by deterministic fakes."
  (declare (indent 0) (debug t))
  `(let ((opened nil)
         (sent nil)
         (deleted nil)
         (coding nil)
         (installed-sentinel nil)
         (fake-process (list :fake-process)))
     (cl-letf (((symbol-function 'slynet-client--open-network-stream)
                (lambda (name buffer host service)
                  (setq opened (list name buffer host service))
                  fake-process))
               ((symbol-function 'slynet-client--set-process-filter)
                (lambda (_process _filter) :filter-installed))
               ((symbol-function 'slynet-client--set-process-sentinel)
                (lambda (_process sentinel)
                  (setq installed-sentinel sentinel)))
               ((symbol-function 'slynet-client--set-process-coding-system)
                (lambda (_process decoding encoding)
                  (setq coding (list decoding encoding))))
               ((symbol-function 'slynet-client--process-send-string)
                (lambda (_process wire)
                  (push wire sent)))
               ((symbol-function 'slynet-client--process-live-p)
                (lambda (_process) t))
               ((symbol-function 'slynet-client--delete-process)
                (lambda (process) (push process deleted))))
       ,@body)))

(defun slynet-test-decode-wire (wire)
  "Decode a single SLYNET length-prefixed sexp WIRE string."
  (let* ((payload-length (string-to-number (substring wire 0 6) 16))
         (payload (substring wire 6 (+ 6 payload-length))))
    (car (read-from-string payload))))

(ert-deftest slynet-connect-creates-and-stores-client-connection ()
  (slynet-test-with-fake-transport
    (let ((connection (slynet-connect :host "127.0.0.1" :port 4005)))
      (should (slynet-client-connection-p connection))
      (should (eq connection slynet-current-connection))
      (should (equal opened '("slynet" nil "127.0.0.1" 4005)))
      (should (equal coding '(binary binary))))))

(ert-deftest slynet-client-roundtrips-unicode-across-fragmented-frame ()
  (let* ((message '(:return (:ok "λ猫") 7))
         (wire (slynet-client-encode-message message))
         (seen nil)
         (connection (slynet-client-make-test-connection
                      (lambda (decoded) (push decoded seen)))))
    (slynet-client-filter connection (substring wire 0 8))
    (should-not seen)
    (slynet-client-filter connection (substring wire 8))
    (should (equal seen (list message)))
    (should (equal (slynet-client-connection-buffer connection) ""))))

(ert-deftest slynet-client-rejects-invalid-utf8-and-recovers ()
  (let* ((seen nil)
         (connection (slynet-client-make-test-connection
                      (lambda (message) (push message seen))))
         (invalid (unibyte-string #xff)))
    (should-error
     (slynet-client-filter connection (concat "000001" invalid))
     :type 'slynet-client-protocol-error)
    (should (equal (slynet-client-connection-buffer connection) ""))
    (slynet-client-filter connection
                          (slynet-client-encode-message '(:ok recovered)))
    (should (equal seen '((:ok recovered))))))

(ert-deftest slynet-client-delivers-nil-message-and-continues-parsing ()
  (let* ((seen nil)
         (connection (slynet-client-make-test-connection
                      (lambda (decoded) (push decoded seen))))
         (wire (concat (slynet-client-encode-message nil)
                       (slynet-client-encode-message '(:ok 1)))))
    (slynet-client-filter connection wire)
    (should (equal (nreverse seen) '(nil (:ok 1))))
    (should (equal (slynet-client-connection-buffer connection) ""))))

(ert-deftest slynet-client-rejects-malformed-prefix-and-recovers-buffer ()
  (let ((connection (slynet-client-make-test-connection #'ignore)))
    (should-error (slynet-client-filter connection "zzzzzzpayload")
                  :type 'slynet-client-protocol-error)
    (should (equal (slynet-client-connection-buffer connection) ""))
    (slynet-client-filter connection (slynet-client-encode-message '(:ok 1)))
    (should (equal (slynet-client-connection-buffer connection) ""))))

(ert-deftest slynet-client-rejects-invalid-sexp-payload ()
  (let ((connection (slynet-client-make-test-connection #'ignore)))
    (should-error (slynet-client-filter connection "000001(")
                  :type 'slynet-client-protocol-error)
    (should (equal (slynet-client-connection-buffer connection) ""))))

(ert-deftest slynet-client-rejects-trailing-frame-garbage ()
  (let ((connection (slynet-client-make-test-connection #'ignore)))
    (should-error (slynet-client-filter connection "000008(:ok)bad")
                  :type 'slynet-client-protocol-error)
    (should (equal (slynet-client-connection-buffer connection) ""))))

(ert-deftest slynet-client-rejects-oversized-outbound-frame ()
  (let ((slynet-client-max-frame-bytes 4))
    (should-error (slynet-client-encode-message "12345")
                  :type 'slynet-client-protocol-error)))

(ert-deftest slynet-client-rejects-oversized-inbound-frame-before-buffering ()
  (let ((slynet-client-max-frame-bytes 4)
        (connection (slynet-client-make-test-connection #'ignore)))
    (should-error (slynet-client-filter connection "000005")
                  :type 'slynet-client-protocol-error)
    (should (equal (slynet-client-connection-buffer connection) ""))))

(ert-deftest slynet-client-callback-errors-are-isolated ()
  (let* ((connection (make-slynet-client-connection))
         (hook-call nil)
         (slynet-client-callback-error-functions
          (list (lambda (_connection request-id payload error-data)
                  (setq hook-call (list request-id payload error-data))))))
    (puthash 7
             (make-slynet-client-request
              :callback (lambda (_payload) (error "callback exploded")))
             (slynet-client-connection-pending-requests connection))
    (should-not (slynet-client--complete-request connection 7 :ok))
    (should (= (hash-table-count
                (slynet-client-connection-pending-requests connection))
               0))
    (should (equal (car hook-call) 7))
    (should (eq (cadr hook-call) :ok))
    (should (string-match-p "callback exploded"
                            (error-message-string (caddr hook-call))))))

(ert-deftest slynet-client-callback-error-hook-errors-are-also-isolated ()
  (let* ((connection (make-slynet-client-connection))
         (slynet-client-callback-error-functions
          (list (lambda (&rest _ignored) (error "hook exploded")))))
    (puthash 8
             (make-slynet-client-request
              :callback (lambda (_payload) (error "callback exploded")))
             (slynet-client-connection-pending-requests connection))
    (should-not (slynet-client--complete-request connection 8 :ok))
    (should (= (hash-table-count
                (slynet-client-connection-pending-requests connection))
               0))))

(ert-deftest slynet-client-callback-error-reporters-run-independently ()
  (let* ((connection (make-slynet-client-connection))
         (seen nil)
         (slynet-client-callback-error-functions
          (list (lambda (&rest _ignored) (error "reporter exploded"))
                (lambda (_connection request-id payload _error-data)
                  (setq seen (list request-id payload))))))
    (puthash 18
             (make-slynet-client-request
              :callback (lambda (_payload) (error "callback exploded")))
             (slynet-client-connection-pending-requests connection))
    (slynet-client--complete-request connection 18 :ok)
    (should (equal seen '(18 :ok)))))

(ert-deftest slynet-client-wire-observer-errors-do-not-break-frame-processing ()
  (slynet-test-with-fake-transport
    (let ((connection (slynet-client-connect
                       :on-message
                       (lambda (_message) (error "observer exploded"))))
          (reported nil))
      (let ((slynet-client-callback-error-functions
             (list (lambda (_connection _request-id payload _error-data)
                     (push payload reported)))))
        (slynet-client-filter
         connection
         (concat (slynet-client-encode-message '(:unknown 1))
                 (slynet-client-encode-message '(:unknown 2)))))
      (should (equal (nreverse reported) '((:unknown 1) (:unknown 2))))
      (should (equal (slynet-client-connection-buffer connection) "")))))

(ert-deftest slynet-client-channel-hook-errors-do-not-skip-later-hooks ()
  (let* ((connection (make-slynet-client-connection))
         (seen nil)
         (slynet-client-after-channel-message-functions
         (list (lambda (&rest _ignored) (error "hook exploded"))
               (lambda (_connection channel-id payload)
                 (setq seen (list channel-id payload))))))
    (slynet-client-handle-message
     connection '(:channel-send 7 (:write-string "hello")))
    (should (equal seen '(7 (:write-string "hello"))))
    (should (equal (slynet-client-connection-repl-output connection) "hello"))))

(ert-deftest slynet-client-rejects-malformed-return-shapes ()
  (let ((connection (make-slynet-client-connection)))
    (dolist (message '((:return (:ok 1))
                       (:return (:ok 1) not-an-id)
                       (:return (:mystery 1) 7)
                       (:return (:ok 1) 7 extra)))
      (should-error (slynet-client-handle-message connection message)
                    :type 'slynet-client-protocol-error))))

(ert-deftest slynet-client-protocol-errors-carry-actionable-state ()
  (let ((connection
         (make-slynet-client-connection
          :buffer "abc"
          :channel-id 12
          :thread "mrepl"
          :pending-requests (make-hash-table :test 'eql))))
    (puthash 7 #'ignore
             (slynet-client-connection-pending-requests connection))
    (condition-case err
        (progn
          (slynet-client-handle-message connection '(:return (:mystery 1) 7))
          (ert-fail "Malformed return unexpectedly accepted"))
      (slynet-client-protocol-error
       (let ((text (error-message-string err)))
         (should (string-match-p "expected:" text))
         (should (string-match-p "request-id=7" text))
         (should (string-match-p "pending=1" text))
         (should (string-match-p "buffer-bytes=3" text))
         (should (string-match-p "channel=12" text)))))))

(ert-deftest slynet-client-rejects-malformed-channel-message-shapes ()
  (let ((connection (make-slynet-client-connection)))
    (dolist (message '((:channel-send)
                       (:channel-send not-an-id (:write-string "x"))
                       (:channel-send 7 not-a-payload)
                       (:channel-close)
                       (:channel-close not-an-id)))
      (should-error (slynet-client-handle-message connection message)
                    :type 'slynet-client-protocol-error))))

(ert-deftest slynet-client-rejects-malformed-channel-state-payloads ()
  (let ((connection (make-slynet-client-connection)))
    (should-error
     (slynet-client-handle-message
      connection '(:channel-send 7 (:write-string 42)))
     :type 'slynet-client-protocol-error)
    (should-error
     (slynet-client-handle-message
      connection '(:channel-send 7 (:prompt core)))
     :type 'slynet-client-protocol-error)))

(ert-deftest slynet-client-cancel-request-is-idempotent-and-ignores-late-reply ()
  (let* ((connection (make-slynet-client-connection))
         (seen nil)
         (cancelled-timer nil)
         (request (make-slynet-client-request
                   :callback (lambda (payload) (push payload seen))
                   :timer :timer)))
    (puthash 9 request
             (slynet-client-connection-pending-requests connection))
    (cl-letf (((symbol-function 'slynet-client--cancel-timer)
               (lambda (timer) (setq cancelled-timer timer))))
      (should (slynet-client-cancel-request connection 9))
      (should-not (slynet-client-cancel-request connection 9))
      (slynet-client--complete-request connection 9 :late))
    (should (eq cancelled-timer :timer))
    (should (equal seen '((:abort :cancelled))))))

(ert-deftest slynet-client-request-timeout-cancels-and-notifies-once ()
  (slynet-test-with-fake-transport
    (let ((scheduled nil)
          (seen nil)
          (slynet-client-request-timeout 2.5))
      (cl-letf (((symbol-function 'slynet-client--run-at-time)
                 (lambda (seconds function &rest args)
                   (setq scheduled (list seconds function args))
                   :timer))
                ((symbol-function 'slynet-client--cancel-timer)
                 (lambda (_timer) nil)))
        (let ((request-id
               (slynet-client-send-rex-async
                (slynet-connect) '(slow-operation)
                (lambda (payload) (push payload seen)))))
          (should (= (car scheduled) 2.5))
          (apply (cadr scheduled) (caddr scheduled))
          (slynet-client--complete-request
           slynet-current-connection request-id :late)
          (should (equal seen '((:abort :timeout))))
          (should (= (hash-table-count
                      (slynet-client-connection-pending-requests
                       slynet-current-connection))
                     0)))))))

(ert-deftest slynet-client-synchronous-reply-cancels-preinstalled-timeout ()
  (let* ((connection (make-slynet-client-connection
                      :process :live
                      :pending-requests (make-hash-table :test 'eql)))
         (cancelled nil)
         (seen nil))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) t))
              ((symbol-function 'slynet-client--run-at-time)
               (lambda (&rest _ignored) :timer))
              ((symbol-function 'slynet-client--cancel-timer)
               (lambda (timer) (setq cancelled timer)))
              ((symbol-function 'slynet-client--process-send-string)
               (lambda (_process _wire)
                 (slynet-client--complete-request connection 1 :ok))))
      (slynet-client-send-rex-async
       connection '(ping) (lambda (payload) (setq seen payload)) nil nil 5))
    (should (eq seen :ok))
    (should (eq cancelled :timer))
    (should (= (hash-table-count
                (slynet-client-connection-pending-requests connection))
               0))))

(ert-deftest slynet-client-frame-parser-property-roundtrip-fragmentation ()
  (let ((state 2463534242))
    (cl-labels ((next-random
                 (limit)
                 (setq state (logand #xffffffff
                                     (logxor state (lsh state 13))))
                 (setq state (logand #xffffffff
                                     (logxor state (lsh state -17))))
                 (setq state (logand #xffffffff
                                     (logxor state (lsh state 5))))
                 (mod state limit)))
      (dotimes (case (string-to-number
                      (or (getenv "SLYNET_FUZZ_CASES") "1000")))
        (let* ((message (list :case case
                              (make-string (1+ (next-random 40))
                                           (+ ?a (next-random 26)))
                              (if (= 0 (mod case 3)) "λ猫" case)))
               (wire (slynet-client-encode-message message))
               (position 0)
               (seen nil)
               (connection
                (slynet-client-make-test-connection
                 (lambda (decoded) (push decoded seen)))))
          (while (< position (length wire))
            (let ((end (min (length wire)
                            (+ position 1 (next-random 9)))))
              (slynet-client-filter connection (substring wire position end))
              (setq position end)))
          (should (equal seen (list message)))
          (should (equal (slynet-client-connection-buffer connection) "")))))))

(ert-deftest slynet-client-request-lifecycle-stress-preserves-invariants ()
  (let* ((connection
          (make-slynet-client-connection
           :process :live
           :pending-requests (make-hash-table :test 'eql)))
         (completed 0)
         (cancelled-timers 0))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) t))
              ((symbol-function 'slynet-client--process-send-string)
               (lambda (&rest _ignored) nil))
              ((symbol-function 'slynet-client--run-at-time)
               (lambda (&rest _ignored) :timer))
              ((symbol-function 'slynet-client--cancel-timer)
               (lambda (_timer) (cl-incf cancelled-timers))))
      (dotimes (index 1000)
        (let ((request-id
               (slynet-client-send-rex-async
                connection '(ping)
                (lambda (_payload) (cl-incf completed)) nil nil 5)))
          (if (= 0 (mod index 3))
              (slynet-client-cancel-request connection request-id)
            (slynet-client--complete-request connection request-id :ok))
          (slynet-client--complete-request connection request-id :late)
          (should (= (hash-table-count
                      (slynet-client-connection-pending-requests connection))
                     0))))
    (should (= completed 1000))
    (should (= cancelled-timers 1000)))))

(ert-deftest slynet-client-frame-parser-rejects-fuzzed-prefixes ()
  (dolist (prefix '("gggggg" "-00001" " 00001" "00000z" "!!!!!!"))
    (let ((connection (slynet-client-make-test-connection #'ignore)))
      (should-error (slynet-client-filter connection (concat prefix "payload"))
                    :type 'slynet-client-protocol-error)
      (should (equal (slynet-client-connection-buffer connection) "")))))

(ert-deftest slynet-client-send-failure-does-not-leak-pending-callback ()
  (let ((connection (make-slynet-client-connection
                     :process :dead
                     :pending-requests (make-hash-table :test 'eql))))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) nil)))
      (should-error
       (slynet-client-send-rex-async connection '(ping) #'ignore))
      (should (= (hash-table-count
                  (slynet-client-connection-pending-requests connection))
                 0)))))

(ert-deftest slynet-client-connect-rejects-invalid-endpoint-before-opening ()
  (let ((opened nil))
    (cl-letf (((symbol-function 'slynet-client--open-network-stream)
               (lambda (&rest _ignored) (setq opened t))))
      (dolist (args '((:host "") (:host 42) (:port 0) (:port 65536)
                      (:on-message not-a-function)))
        (should-error (apply #'slynet-client-connect args)
                      :type 'slynet-client-argument-error))
      (should-not opened))))

(ert-deftest slynet-client-send-rex-validates-before-allocating-request-id ()
  (let ((connection (make-slynet-client-connection :next-id 9)))
    (dolist (args '(((ping) not-a-function nil nil nil)
                    ((ping) nil 42 nil nil)
                    ((ping) nil nil 42 nil)
                    ((ping) nil nil nil -1)))
      (should-error
       (apply #'slynet-client-send-rex-async connection args)
       :type 'slynet-client-argument-error))
    (should (= 9 (slynet-client-connection-next-id connection)))
    (should (= 0 (hash-table-count
                  (slynet-client-connection-pending-requests connection))))))

(ert-deftest slynet-client-cancel-request-requires-positive-integer-id ()
  (let ((connection (make-slynet-client-connection)))
    (dolist (request-id '(nil 0 -1 "7"))
      (should-error
       (slynet-client-cancel-request connection request-id)
       :type 'slynet-client-argument-error))))

(ert-deftest slynet-client-send-channel-validates-without-sending ()
  (let ((connection (make-slynet-client-connection :process :live))
        (sent nil))
    (cl-letf (((symbol-function 'slynet-client-send)
               (lambda (&rest _ignored) (setq sent t))))
      (dolist (args '((0 (:process "x")) ("1" (:process "x"))
                      (1 nil) (1 not-a-list)))
        (should-error
         (apply #'slynet-client-send-channel connection args)
         :type 'slynet-client-argument-error))
      (should-not sent))))

(ert-deftest slynet-client-eval-validates-before-mutating-mrepl-state ()
  (let ((connection (make-slynet-client-connection :channel-id 12)))
    (should-error
     (slynet-client-eval-mrepl-string connection 42 #'ignore)
     :type 'slynet-client-argument-error)
    (should-error
     (slynet-client-eval-mrepl-string connection "(+ 1 2)" 'not-a-function)
     :type 'slynet-client-argument-error)
    (should-not (slynet-client-connection-mrepl-eval-callback connection))))

(ert-deftest slynet-client-create-mrepl-does-not-install-abort-as-channel-state ()
  (let ((connection (make-slynet-client-connection))
        (seen nil))
    (cl-letf (((symbol-function 'slynet-client-send-rex-async)
               (lambda (_connection _form callback &rest _ignored)
                 (funcall callback '(:abort :connection-lost))
                 1)))
      (slynet-client-create-mrepl
       connection (lambda (result) (setq seen result))))
    (should (equal seen '(:abort :connection-lost)))
    (should-not (slynet-client-connection-channel-id connection))
    (should-not (slynet-client-connection-mrepl-thread connection))
    (should-not (slynet-client-connection-thread connection))))

(ert-deftest slynet-client-mrepl-send-failure-clears-callback ()
  (let ((connection (make-slynet-client-connection
                     :channel-id 12
                     :process :dead)))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) nil)))
      (should-error
       (slynet-client-eval-mrepl-string connection "(+ 1 2)" #'ignore))
      (should-not
       (slynet-client-connection-mrepl-eval-callback connection)))))

(ert-deftest slynet-client-rejects-overlapping-mrepl-evaluations ()
  (let ((connection (make-slynet-client-connection
                     :channel-id 12
                     :process :live
                     :mrepl-eval-callback #'ignore)))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) t)))
      (should-error
       (slynet-client-eval-mrepl-string connection "(+ 1 2)" #'ignore)))))

(ert-deftest slynet-client-nil-callback-still-marks-mrepl-evaluation-in-flight ()
  (let ((connection (make-slynet-client-connection
                     :channel-id 12
                     :process :live)))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) t))
              ((symbol-function 'slynet-client--process-send-string)
               (lambda (&rest _ignored) nil)))
      (slynet-client-eval-mrepl-string connection "(+ 1 2)" nil)
      (should
       (slynet-client-connection-mrepl-eval-callback connection))
      (should-error
       (slynet-client-eval-mrepl-string connection "(+ 3 4)" nil)))))

(ert-deftest slynet-client-channel-close-aborts-active-mrepl-evaluation ()
  (let* ((seen nil)
         (connection (make-slynet-client-connection
                     :channel-id 12
                     :thread "slynet-mrepl"
                     :mrepl-thread "slynet-mrepl"
                     :mrepl-eval-callback
                     (lambda (payload) (setq seen payload)))))
    (slynet-client-handle-message connection '(:channel-close 12))
    (should (equal seen '(:abort :channel-closed)))
    (should-not (slynet-client-connection-channel-id connection))
    (should-not (slynet-client-connection-thread connection))
    (should-not (slynet-client-connection-mrepl-thread connection))
    (should-not (slynet-client-connection-mrepl-eval-callback connection))))

(ert-deftest slynet-client-channel-close-invalidates-state-before-callback ()
  (let* ((reentrant-error nil)
         (connection
          (make-slynet-client-connection
           :channel-id 12
           :thread "slynet-mrepl"
           :mrepl-thread "slynet-mrepl"
           :process :live)))
    (setf (slynet-client-connection-mrepl-eval-callback connection)
          (lambda (_payload)
            (condition-case err
                (slynet-client-eval-mrepl-string connection "(+ 1 2)" nil)
              (error (setq reentrant-error err)))))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) t)))
      (slynet-client-handle-message connection '(:channel-close 12)))
    (should reentrant-error)
    (should (string-match-p
             "channel not initialized"
             (error-message-string reentrant-error)))
    (should-not (slynet-client-connection-channel-id connection))))

(ert-deftest slynet-client-reset-invalidates-transport-before-callbacks ()
  (let* ((reentrant-error nil)
         (connection
          (make-slynet-client-connection
           :process :live
           :pending-requests (make-hash-table :test 'eql))))
    (puthash
     21
     (make-slynet-client-request
      :callback
      (lambda (_payload)
        (condition-case err
            (slynet-client-send-rex-async connection '(ping) #'ignore)
          (error (setq reentrant-error err)))))
     (slynet-client-connection-pending-requests connection))
    (cl-letf (((symbol-function 'slynet-client--process-live-p)
               (lambda (_process) t))
              ((symbol-function 'slynet-client--process-send-string)
               (lambda (&rest _ignored)
                 (ert-fail "teardown callback sent on the old process"))))
      (slynet-client--reset-connection-state connection :connection-lost))
    (should reentrant-error)
    (should (string-match-p
             "connection is not live"
             (error-message-string reentrant-error)))
    (should-not (slynet-client-connection-process connection))
    (should (= (hash-table-count
                (slynet-client-connection-pending-requests connection))
               0))))

(ert-deftest slynet-client-ignores-state-events-from-other-channels ()
  (let* ((seen nil)
         (callback (lambda (payload) (setq seen payload)))
         (connection (make-slynet-client-connection
                      :channel-id 12
                      :thread "slynet-mrepl"
                      :mrepl-thread "slynet-mrepl"
                      :repl-output "original"
                      :mrepl-eval-callback callback)))
    (slynet-client-handle-message
     connection '(:channel-send 99 (:write-string "wrong")))
    (slynet-client-handle-message
     connection '(:channel-send 99 (:write-values (42))))
    (slynet-client-handle-message connection '(:channel-close 99))
    (should (equal (slynet-client-connection-repl-output connection) "original"))
    (should-not seen)
    (should (eq (slynet-client-connection-mrepl-eval-callback connection) callback))
    (should (= (slynet-client-connection-channel-id connection) 12))
    (should (equal (slynet-client-connection-thread connection) "slynet-mrepl"))))

(ert-deftest slynet-client-explicit-disconnect-wins-over-synchronous-sentinel ()
  (slynet-test-with-fake-transport
    (let ((connection (slynet-connect))
          (seen nil))
      (puthash 10
               (make-slynet-client-request
                :callback (lambda (payload) (setq seen payload)))
               (slynet-client-connection-pending-requests connection))
      (cl-letf (((symbol-function 'slynet-client--delete-process)
                 (lambda (process)
                   (push process deleted)
                   (funcall installed-sentinel process "deleted")))
                ((symbol-function 'slynet-client--process-live-p)
                 (lambda (_process) t)))
        (slynet-client-disconnect connection))
      (should (equal seen '(:abort :disconnected)))
      (should (= (hash-table-count
                  (slynet-client-connection-pending-requests connection))
                 0)))))

(ert-deftest slynet-client-sentinel-invalidates-closed-connection-state ()
  (slynet-test-with-fake-transport
    (let ((connection (slynet-connect)))
      (puthash 4 #'ignore
               (slynet-client-connection-pending-requests connection))
      (setf (slynet-client-connection-channel-id connection) 12
            (slynet-client-connection-mrepl-thread connection) 3
            (slynet-client-connection-thread connection) 3
            (slynet-client-connection-mrepl-eval-callback connection) #'ignore)
      (cl-letf (((symbol-function 'slynet-client--process-live-p)
                 (lambda (_process) nil)))
        (funcall installed-sentinel fake-process "connection broken"))
      (should-not (slynet-client-connection-process connection))
      (should-not (slynet-client-connection-channel-id connection))
      (should-not (slynet-client-connection-mrepl-thread connection))
      (should-not (slynet-client-connection-thread connection))
      (should-not (slynet-client-connection-mrepl-eval-callback connection))
      (should (= (hash-table-count
                  (slynet-client-connection-pending-requests connection))
                 0)))))

(ert-deftest slynet-eval-string-sends-interactive-eval-rex ()
  (slynet-test-with-fake-transport
    (slynet-connect :host "localhost" :port 4111)
    (let ((request-id (slynet-eval-string "(+ 1 2)")))
      (should (= request-id 1))
      (should (equal (slynet-test-decode-wire (car sent))
                     '(:emacs-rex (interactive-eval-region "(+ 1 2)") "core" nil 1))))))

(ert-deftest slynet-disconnect-closes-current-connection ()
  (slynet-test-with-fake-transport
    (let ((connection (slynet-connect)))
      (puthash 8 #'ignore
               (slynet-client-connection-pending-requests connection))
      (setf (slynet-client-connection-channel-id connection) 9
            (slynet-client-connection-mrepl-eval-callback connection) #'ignore)
      (slynet-disconnect)
      (should (equal deleted (list fake-process)))
      (should-not (slynet-client-connection-process connection))
      (should-not (slynet-client-connection-channel-id connection))
      (should-not (slynet-client-connection-mrepl-eval-callback connection))
      (should (= (hash-table-count
                  (slynet-client-connection-pending-requests connection))
                 0))
      (should-not slynet-current-connection))))


(ert-deftest slynet-status-and-health-render-connection-state ()
  (slynet-test-with-fake-transport
    (let ((connection (slynet-connect :host "127.0.0.1" :port 4999)))
      (puthash 99 #'ignore (slynet-client-connection-pending-requests connection))
      (let ((status (slynet-connection-status)))
        (should (plist-get status :connected))
        (should (plist-get status :live))
        (should (equal (plist-get status :host) "127.0.0.1"))
        (should (= (plist-get status :port) 4999))
        (should (= (plist-get status :pending-requests) 1))
        (should (string-match-p "SLYNET:live" (slynet--status-label))))
      (let ((buffer (slynet-health)))
        (with-current-buffer buffer
          (should (search-forward "SLYNET Health" nil t))
          (should (search-forward "State: live" nil t))
          (should (search-forward "Endpoint: 127.0.0.1:4999" nil t))
          (should (search-forward "Pending requests: 1" nil t)))))))

(ert-deftest slynet-reconnect-uses-last-endpoint-when-current-connection-is-gone ()
  (slynet-test-with-fake-transport
    (setq slynet-current-connection nil
          slynet-last-host "localhost"
          slynet-last-port 4777)
    (let ((connection (slynet-reconnect)))
      (should (slynet-client-connection-p connection))
      (should (eq slynet-current-connection connection))
      (should (equal opened '("slynet" nil "localhost" 4777))))))

(ert-deftest slynet-mode-exposes-sane-prefix-map-and-quit-lifecycle ()
  (slynet-test-with-fake-transport
    (let* ((connection (slynet-connect :host "127.0.0.1" :port 4005))
           (client-process (slynet-client-connection-process connection))
           (server-deleted nil)
           (fake-server (list :fake-server)))
      (should (eq (lookup-key slynet-mode-map (kbd "C-c C-s c")) #'slynet-connect))
      (should (eq (lookup-key slynet-mode-map (kbd "C-c C-s h")) #'slynet-health))
      (should (eq (lookup-key slynet-mode-map (kbd "C-c C-s D")) #'slynet-doc-symbol))
      (cl-letf (((symbol-function 'process-live-p)
                 (lambda (process) (eq process fake-server)))
                ((symbol-function 'delete-process)
                 (lambda (process) (setq server-deleted process))))
        (setq slynet-server-process fake-server)
        (slynet-quit)
        (should (equal deleted (list client-process)))
        (should (eq server-deleted fake-server))
        (should-not slynet-current-connection)
        (should-not slynet-server-process)))))

(ert-deftest slynet-start-server-reports-missing-executable ()
  (let ((slynet-server-process nil)
        (slynet-server-directory default-directory)
        (slynet-last-error nil))
    (should-error
     (slynet-start-server '("slynet-definitely-missing-executable" "--tcp"))
     :type 'user-error)
    (should (string-match-p "No such file or directory" slynet-last-error))))

(ert-deftest slynet-start-server-preserves-argv-and-spaced-directory ()
  (let* ((root (make-temp-file "slynet path with spaces " t))
         (slynet-server-process nil)
         (slynet-server-directory root)
         captured-directory
         captured-args)
    (unwind-protect
        (cl-letf (((symbol-function 'start-process)
                   (lambda (_name _buffer program &rest args)
                     (setq captured-directory default-directory
                           captured-args (cons program args))
                     :fake-process)))
          (should (eq (slynet-start-server '("janet" "script with spaces.janet" "--tcp"))
                      :fake-process))
          (should (equal captured-directory (file-name-as-directory root)))
          (should (equal captured-args '("janet" "script with spaces.janet" "--tcp"))))
      (delete-directory root t))))

(provide 'slynet-tests)
;;; slynet-tests.el ends here
