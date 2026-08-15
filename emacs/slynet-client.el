;;; slynet-client.el --- SLYNET Emacs transport helpers -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: SLYNET contributors
;; Version: 1.0.7
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, lisp, janet, tools, processes

;;; Commentary:

;; Low-level Emacs-side transport helpers for speaking the SLYNET wire
;; protocol.  The public user-facing entrypoint is `slynet.el'.

;;; Code:

(require 'cl-lib)

(define-error 'slynet-client-protocol-error "Malformed SLYNET protocol frame")
(define-error 'slynet-client-request-error "SLYNET request failed")
(define-error 'slynet-client-argument-error "Invalid SLYNET client argument")

(defcustom slynet-client-request-timeout nil
  "Default RPC timeout in seconds, or nil to wait indefinitely."
  :type '(choice (const :tag "No timeout" nil) number)
  :group 'slynet)

(defvar slynet-client-callback-error-functions nil
  "Abnormal hook run when a request callback signals an error.
Each function receives CONNECTION, REQUEST-ID, PAYLOAD, and ERROR-DATA.")

(defconst slynet-client-max-frame-bytes #xffffff
  "Largest payload representable by the six-hex-digit SLYNET frame prefix.")

(cl-defstruct slynet-client-request
  "Bookkeeping for one asynchronous SLYNET request."
  callback
  timer)

(cl-defstruct slynet-client-connection
  "State carried by an Emacs-side SLYNET transport filter."
  process
  host
  port
  (buffer "")
  on-message
  (pending-requests (make-hash-table :test 'eql))
  (next-id 1)
  (package "core")
  thread
  channel-id
  mrepl-thread
  prompt-string
  last-values
  (repl-output "")
  repl-buffer
  mrepl-eval-callback)

(defvar slynet-client-after-channel-message-functions nil
  "Abnormal hook run after a decoded channel message updates CONNECTION state.
Each function receives CONNECTION, CHANNEL-ID, and PAYLOAD.")

(defun slynet-client--open-network-stream (name buffer host service)
  "Open a network process NAME using BUFFER, HOST, and SERVICE."
  (open-network-stream name buffer host service))

(defun slynet-client--set-process-filter (process filter)
  "Set PROCESS filter to FILTER."
  (set-process-filter process filter))

(defun slynet-client--set-process-sentinel (process sentinel)
  "Set PROCESS sentinel to SENTINEL."
  (set-process-sentinel process sentinel))

(defun slynet-client--set-process-coding-system (process decoding encoding)
  "Set PROCESS coding systems to DECODING and ENCODING."
  (set-process-coding-system process decoding encoding))

(defun slynet-client--process-send-string (process string)
  "Send STRING to PROCESS."
  (process-send-string process string))

(defun slynet-client--process-live-p (process)
  "Return non-nil when PROCESS is live."
  (process-live-p process))

(defun slynet-client--delete-process (process)
  "Delete PROCESS."
  (delete-process process))

(defun slynet-client--run-at-time (seconds function &rest args)
  "Run FUNCTION with ARGS after SECONDS."
  (apply #'run-at-time seconds nil function args))

(defun slynet-client--cancel-timer (timer)
  "Cancel TIMER when it is still active."
  (when (timerp timer)
    (cancel-timer timer)))

(defun slynet-client--require (predicate format-string &rest args)
  "Signal an argument error unless PREDICATE is non-nil.
FORMAT-STRING and ARGS describe the violated public API contract."
  (unless predicate
    (signal 'slynet-client-argument-error
            (list (apply #'format format-string args)))))

(defun slynet-client--require-connection (connection)
  "Require CONNECTION to be a SLYNET client connection and return it."
  (slynet-client--require
   (slynet-client-connection-p connection)
   "Expected SLYNET client connection, got %S" connection)
  connection)

(defun slynet-client--require-callback (callback name)
  "Require CALLBACK to be nil or callable for argument NAME."
  (slynet-client--require
   (or (null callback) (functionp callback))
   "%s must be nil or a function, got %S" name callback))

(defun slynet-client-encode-message (message)
  "Encode MESSAGE as a SLY/SLYNK-style six-hex-byte length-prefixed sexp."
  (let* ((payload (encode-coding-string (prin1-to-string message) 'utf-8 t))
         (payload-length (length payload)))
    (when (> payload-length slynet-client-max-frame-bytes)
      (signal 'slynet-client-protocol-error
              (list (format "Frame payload is %d bytes; maximum is %d"
                            payload-length slynet-client-max-frame-bytes))))
    (let ((length-prefix (format "%06x" payload-length)))
      (concat length-prefix payload))))

(defun slynet-client-make-test-connection (on-message)
  "Create an in-memory connection for batch ERT and `process-filter' test code.
ON-MESSAGE is called with each decoded protocol message."
  (make-slynet-client-connection :on-message on-message))

(defun slynet-client--utf8-continuation-byte-p (byte)
  "Return non-nil when BYTE is a UTF-8 continuation byte."
  (and (>= byte #x80) (<= byte #xbf)))

(defun slynet-client--valid-utf8-p (string)
  "Return non-nil when STRING is a canonical UTF-8 byte sequence."
  (let* ((bytes (encode-coding-string string 'binary t))
         (length (length bytes))
         (index 0)
         valid)
    (setq valid t)
    (while (and valid (< index length))
      (let ((first (aref bytes index)))
        (cond
         ((<= first #x7f)
          (setq index (1+ index)))
         ((and (>= first #xc2) (<= first #xdf)
               (< (1+ index) length)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (1+ index))))
          (setq index (+ index 2)))
         ((and (= first #xe0)
               (< (+ index 2) length)
               (>= (aref bytes (1+ index)) #xa0)
               (<= (aref bytes (1+ index)) #xbf)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 2))))
          (setq index (+ index 3)))
         ((and (= first #xed)
               (< (+ index 2) length)
               (>= (aref bytes (1+ index)) #x80)
               (<= (aref bytes (1+ index)) #x9f)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 2))))
          (setq index (+ index 3)))
         ((and (or (and (>= first #xe1) (<= first #xec))
                   (and (>= first #xee) (<= first #xef)))
               (< (+ index 2) length)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (1+ index)))
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 2))))
          (setq index (+ index 3)))
         ((and (= first #xf0)
               (< (+ index 3) length)
               (>= (aref bytes (1+ index)) #x90)
               (<= (aref bytes (1+ index)) #xbf)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 2)))
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 3))))
          (setq index (+ index 4)))
         ((and (>= first #xf1) (<= first #xf3)
               (< (+ index 3) length)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (1+ index)))
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 2)))
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 3))))
          (setq index (+ index 4)))
         ((and (= first #xf4)
               (< (+ index 3) length)
               (>= (aref bytes (1+ index)) #x80)
               (<= (aref bytes (1+ index)) #x8f)
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 2)))
               (slynet-client--utf8-continuation-byte-p
                (aref bytes (+ index 3))))
          (setq index (+ index 4)))
         (t
          (setq valid nil)))))
    valid))

(defun slynet-client--try-read-one (connection)
  "Return (t . MESSAGE) from CONNECTION, or nil when its frame is incomplete."
  (let ((buffer (slynet-client-connection-buffer connection)))
    (when (>= (length buffer) 6)
      (let ((prefix (substring buffer 0 6)))
        (unless (string-match-p "\\`[[:xdigit:]]\\{6\\}\\'" prefix)
          (setf (slynet-client-connection-buffer connection) "")
          (signal 'slynet-client-protocol-error
                  (list (format "Invalid frame length prefix: %S" prefix))))
        (let* ((payload-length (string-to-number prefix 16))
               (message-end (+ 6 payload-length)))
          (when (> payload-length slynet-client-max-frame-bytes)
            (setf (slynet-client-connection-buffer connection) "")
            (signal 'slynet-client-protocol-error
                    (list (format "Frame payload is %d bytes; maximum is %d"
                                  payload-length
                                  slynet-client-max-frame-bytes))))
          (when (>= (length buffer) message-end)
            (let ((payload (substring buffer 6 message-end)))
              (condition-case err
                  (progn
                    (unless (slynet-client--valid-utf8-p payload)
                      (error "Payload is not canonical UTF-8"))
                    (let* ((decoded-payload
                            (decode-coding-string payload 'utf-8 t))
                           (read-result (read-from-string decoded-payload))
                           (decoded (car read-result))
                           (read-end (cdr read-result)))
                      (unless (string-match-p "\\`[[:space:]]*\\'"
                                              (substring decoded-payload read-end))
                        (error "Trailing data after protocol expression"))
                      (setf (slynet-client-connection-buffer connection)
                            (substring buffer message-end))
                      (cons t decoded)))
                (error
                 (setf (slynet-client-connection-buffer connection) "")
                 (signal 'slynet-client-protocol-error
                         (list (format "Invalid frame payload: %s"
                                       (error-message-string err)))))))))))))

(defun slynet-client-filter (connection chunk)
  "Append CHUNK to CONNECTION and deliver all complete decoded messages."
  (setf (slynet-client-connection-buffer connection)
        (concat (slynet-client-connection-buffer connection) chunk))
  (let ((decoded-frame (slynet-client--try-read-one connection)))
    (while decoded-frame
      (when-let ((handler (slynet-client-connection-on-message connection)))
        (funcall handler (cdr decoded-frame)))
      (setq decoded-frame (slynet-client--try-read-one connection)))))

(cl-defun slynet-client-connect (&key (host "127.0.0.1") (port 4005) on-message name buffer)
  "Connect to a SLYNET server on HOST and PORT.
ON-MESSAGE is called with each decoded wire message.  NAME and BUFFER
are passed to `open-network-stream'."
  (slynet-client--require
   (and (stringp host) (> (length host) 0))
   "HOST must be a non-empty string, got %S" host)
  (slynet-client--require
   (and (integerp port) (<= 1 port) (<= port 65535))
   "PORT must be an integer from 1 through 65535, got %S" port)
  (slynet-client--require-callback on-message "ON-MESSAGE")
  (let* ((process (slynet-client--open-network-stream (or name "slynet") buffer host port))
         (connection (make-slynet-client-connection
                      :process process
                      :host host
                      :port port)))
    (setf (slynet-client-connection-on-message connection)
          (lambda (message)
            (slynet-client-handle-message connection message)
            (when on-message
              (slynet-client--invoke-callback
               connection nil on-message message))))
    (slynet-client--set-process-filter
     process
     (lambda (_process chunk)
       (slynet-client-filter connection chunk)))
    (slynet-client--set-process-coding-system process 'binary 'binary)
    (slynet-client--set-process-sentinel
     process
     (lambda (sentinel-process _event)
       (unless (slynet-client--process-live-p sentinel-process)
         (when (eq sentinel-process
                   (slynet-client-connection-process connection))
           (slynet-client--reset-connection-state connection :connection-lost)))))
    connection))

(defun slynet-client-send (connection message)
  "Send MESSAGE over CONNECTION and return MESSAGE."
  (slynet-client--require-connection connection)
  (let ((process (slynet-client-connection-process connection)))
    (unless (and process (slynet-client--process-live-p process))
      (error "SLYNET connection is not live"))
    (slynet-client--process-send-string process (slynet-client-encode-message message))
    message))

(defun slynet-client-next-id (connection)
  "Return and increment CONNECTION's next request id."
  (slynet-client--require-connection connection)
  (let ((id (slynet-client-connection-next-id connection)))
    (setf (slynet-client-connection-next-id connection) (1+ id))
    id))

(defun slynet-client--report-callback-error
    (connection request-id payload error-data)
  "Report ERROR-DATA for REQUEST-ID without destabilizing CONNECTION.
PAYLOAD is the value delivered to the failing callback."
  (dolist (function slynet-client-callback-error-functions)
    (condition-case nil
        (funcall function connection request-id payload error-data)
      (error nil))))

(defun slynet-client--invoke-callback (connection request-id callback payload)
  "Invoke CALLBACK for REQUEST-ID without destabilizing CONNECTION."
  (when callback
    (condition-case err
        (funcall callback payload)
      (error
       (slynet-client--report-callback-error
        connection request-id payload err)))))

(defun slynet-client--run-channel-message-hooks (connection channel-id payload)
  "Run channel hooks independently for CONNECTION, CHANNEL-ID, and PAYLOAD."
  (dolist (function slynet-client-after-channel-message-functions)
    (condition-case err
        (funcall function connection channel-id payload)
      (error
       (slynet-client--report-callback-error
        connection nil (list :channel-message channel-id payload) err)))))

(defun slynet-client--take-request (connection request-id)
  "Remove and return REQUEST-ID from CONNECTION, cancelling its timer."
  (let* ((pending (slynet-client-connection-pending-requests connection))
         (request (gethash request-id pending)))
    (when request
      (remhash request-id pending)
      (when (slynet-client-request-p request)
        (slynet-client--cancel-timer (slynet-client-request-timer request))))
    request))

(defun slynet-client--complete-request (connection request-id payload)
  "Complete REQUEST-ID on CONNECTION with PAYLOAD."
  (when-let ((request (slynet-client--take-request connection request-id)))
    (slynet-client--invoke-callback
     connection request-id (if (slynet-client-request-p request)
         (slynet-client-request-callback request)
       request)
     payload)))

(defun slynet-client-cancel-request (connection request-id &optional reason)
  "Cancel REQUEST-ID on CONNECTION and notify its callback.
REASON defaults to `:cancelled'.  Return non-nil when a request was pending."
  (slynet-client--require-connection connection)
  (slynet-client--require
   (and (integerp request-id) (> request-id 0))
   "REQUEST-ID must be a positive integer, got %S" request-id)
  (when-let ((request (slynet-client--take-request connection request-id)))
    (slynet-client--invoke-callback
     connection request-id (if (slynet-client-request-p request)
         (slynet-client-request-callback request)
       request)
     (list :abort (or reason :cancelled)))
    t))

(defun slynet-client--timeout-request (connection request-id)
  "Expire REQUEST-ID on CONNECTION."
  (slynet-client-cancel-request connection request-id :timeout))

(defun slynet-client--append-output (connection text)
  "Append TEXT to CONNECTION's accumulated MREPL output."
  (setf (slynet-client-connection-repl-output connection)
        (concat (slynet-client-connection-repl-output connection) text)))

(defun slynet-client--close-mrepl-state (connection reason)
  "Clear CONNECTION's MREPL state and abort an active eval with REASON."
  (let ((callback
         (slynet-client-connection-mrepl-eval-callback connection)))
    ;; Invalidate the channel before invoking user code.  A callback may be
    ;; reentrant and must not be able to submit work to a channel that is
    ;; already closing.
    (setf (slynet-client-connection-mrepl-eval-callback connection) nil
          (slynet-client-connection-channel-id connection) nil
          (slynet-client-connection-mrepl-thread connection) nil
          (slynet-client-connection-thread connection) nil)
    (when callback
    (slynet-client--invoke-callback
     connection nil callback (list :abort reason)))))

(defun slynet-client--reset-connection-state (connection &optional reason)
  "Clear transient transport and MREPL state on CONNECTION.
Pending callbacks receive an abort payload using REASON or `:connection-lost'."
  ;; Make the transport unusable before invoking callbacks.  Otherwise a
  ;; reentrant abort callback can enqueue a fresh request after REQUEST-IDS has
  ;; been snapshotted, leaving it orphaned on a dead connection.
  (setf (slynet-client-connection-process connection) nil
        (slynet-client-connection-buffer connection) "")
  (let ((request-ids nil)
        (pending (slynet-client-connection-pending-requests connection)))
    (maphash (lambda (request-id _request) (push request-id request-ids)) pending)
    (dolist (request-id request-ids)
      (slynet-client-cancel-request
       connection request-id (or reason :connection-lost))))
  (slynet-client--close-mrepl-state
   connection (or reason :connection-lost)))

(defun slynet-client--payload-op (payload)
  "Return the operation symbol or keyword at the head of PAYLOAD."
  (when (consp payload)
    (car payload)))

(defun slynet-client--op= (actual keyword symbol)
  "Return non-nil when ACTUAL names the same protocol op as KEYWORD or SYMBOL."
  (or (eq actual keyword) (eq actual symbol)))

(defun slynet-client--protocol-context (connection)
  "Return compact diagnostic state for CONNECTION."
  (format "state=%s pending=%d buffer-bytes=%d channel=%S thread=%S"
          (if (and (slynet-client-connection-process connection)
                   (slynet-client--process-live-p
                    (slynet-client-connection-process connection)))
              "connected"
            "disconnected")
          (hash-table-count
           (slynet-client-connection-pending-requests connection))
          (length (slynet-client-connection-buffer connection))
          (slynet-client-connection-channel-id connection)
          (slynet-client-connection-thread connection)))

(defun slynet-client--protocol-error (connection expected received &optional detail)
  "Signal a protocol error for RECEIVED, describing EXPECTED and CONNECTION.
DETAIL, when non-nil, adds operation-specific context."
  (signal
   'slynet-client-protocol-error
   (list
    (concat "SLYNET protocol violation\n"
            "expected: " expected "\n"
            (format "received: %S\n" received)
            (when detail (concat "detail: " detail "\n"))
            "peer: " (slynet-client--protocol-context connection)))))

(defun slynet-client--handle-channel-message (connection channel-id payload)
  "Handle CHANNEL-ID's PAYLOAD for CONNECTION."
  (let ((active-channel (slynet-client-connection-channel-id connection)))
    ;; During MREPL creation the backend can send its greeting and prompt before
    ;; the :return frame installs the channel id.  Once installed, however,
    ;; messages from other channels must not mutate the active MREPL state.
    (when (or (null active-channel) (equal active-channel channel-id))
      (let ((op (slynet-client--payload-op payload)))
        (cond
         ((slynet-client--op= op :write-string 'write-string)
          (let ((text (cadr payload)))
            (unless (stringp text)
              (slynet-client--protocol-error
               connection "(:write-string STRING)" payload))
            (slynet-client--append-output connection text)))
         ((slynet-client--op= op :prompt 'prompt)
          (let ((package-name (cadr payload))
                (condition (nthcdr 5 payload)))
            (unless (stringp package-name)
              (slynet-client--protocol-error
               connection "(:prompt PACKAGE ...) with PACKAGE as a string"
               payload))
            (setf (slynet-client-connection-package connection) package-name)
            (setf (slynet-client-connection-prompt-string connection)
                  (if condition
                      (format "%s> [%s] " package-name (car condition))
                    (format "%s> " package-name)))))
         ((slynet-client--op= op :write-values 'write-values)
          (let ((values (cadr payload)))
            (setf (slynet-client-connection-last-values connection) values)
            (when-let ((callback
                        (slynet-client-connection-mrepl-eval-callback connection)))
              (setf (slynet-client-connection-mrepl-eval-callback connection) nil)
              (slynet-client--invoke-callback connection nil callback values))))
         ((slynet-client--op= op :evaluation-aborted 'evaluation-aborted)
          (when-let ((callback
                      (slynet-client-connection-mrepl-eval-callback connection)))
            (setf (slynet-client-connection-mrepl-eval-callback connection) nil)
            (slynet-client--invoke-callback
             connection nil callback (list :abort (cadr payload)))))
         ((slynet-client--op= op :server-side-repl-close 'server-side-repl-close)
          (slynet-client--close-mrepl-state connection :channel-closed))
         (t nil))))
    (slynet-client--run-channel-message-hooks
     connection channel-id payload)))

(defun slynet-client-handle-message (connection message)
  "Dispatch decoded MESSAGE for CONNECTION."
  (let ((op (slynet-client--payload-op message)))
    (cond
     ((slynet-client--op= op :return 'return)
      (let ((status (cadr message))
            (request-id (caddr message)))
        (unless (and (= (length message) 3)
                     (integerp request-id))
          (slynet-client--protocol-error
           connection "(:return STATUS INTEGER-REQUEST-ID)" message))
        (pcase status
          (`(:ok ,value)
           (slynet-client--complete-request connection request-id value))
          (`(ok ,value)
           (slynet-client--complete-request connection request-id value))
          (`(:abort ,reason)
           (slynet-client--complete-request connection request-id (list :abort reason)))
          (`(abort ,reason)
           (slynet-client--complete-request connection request-id (list :abort reason)))
          (_
           (slynet-client--protocol-error
            connection "(:ok VALUE) or (:abort REASON)" status
            (format "request-id=%S" request-id))))))
     ((slynet-client--op= op :channel-send 'channel-send)
      (unless (and (= (length message) 3)
                   (integerp (cadr message))
                   (consp (caddr message)))
        (slynet-client--protocol-error
         connection "(:channel-send INTEGER-CHANNEL-ID PAYLOAD)" message))
      (slynet-client--handle-channel-message connection (cadr message) (caddr message)))
     ((slynet-client--op= op :channel-close 'channel-close)
      (let ((channel-id (cadr message)))
        (unless (and (= (length message) 2)
                     (integerp channel-id))
          (slynet-client--protocol-error
           connection "(:channel-close INTEGER-CHANNEL-ID)" message))
        (when (equal channel-id (slynet-client-connection-channel-id connection))
          (slynet-client--close-mrepl-state connection :channel-closed))))
     (t nil))))

(defun slynet-client-send-rex-async
    (connection form callback &optional package thread timeout)
  "Send FORM over CONNECTION and call CALLBACK with the :return payload.
TIMEOUT overrides `slynet-client-request-timeout'.  Return the request id."
  (slynet-client--require-connection connection)
  (slynet-client--require-callback callback "CALLBACK")
  (slynet-client--require
   (or (null package) (stringp package))
   "PACKAGE must be nil or a string, got %S" package)
  (slynet-client--require
   (or (null thread) (stringp thread))
   "THREAD must be nil or a string, got %S" thread)
  (slynet-client--require
   (or (null timeout) (and (numberp timeout) (>= timeout 0)))
   "TIMEOUT must be nil or a non-negative number, got %S" timeout)
  (let* ((request-id (slynet-client-next-id connection))
         (effective-timeout (if (null timeout)
                                slynet-client-request-timeout
                              timeout))
         (request (make-slynet-client-request :callback callback)))
    (when callback
      (puthash request-id request
               (slynet-client-connection-pending-requests connection)))
    (condition-case err
        (progn
          (when (and callback effective-timeout (> effective-timeout 0))
            (setf (slynet-client-request-timer request)
                  (slynet-client--run-at-time
                   effective-timeout #'slynet-client--timeout-request
                   connection request-id)))
          (slynet-client-send connection
                              (list :emacs-rex
                                    form
                                    (or package (slynet-client-connection-package connection))
                                    (or thread (slynet-client-connection-thread connection))
                                    request-id)))
      (error
       (slynet-client--take-request connection request-id)
       (signal (car err) (cdr err))))
    request-id))

(defun slynet-client-send-rex (connection form &optional package thread)
  "Send FORM as an :emacs-rex request over CONNECTION.
Return the request id used for the message."
  (slynet-client-send-rex-async connection form nil package thread))

(defun slynet-client-create-mrepl (connection callback)
  "Create an MREPL on CONNECTION and call CALLBACK with the backend result."
  (slynet-client--require-connection connection)
  (slynet-client--require-callback callback "CALLBACK")
  (slynet-client-send-rex-async
   connection
   '(create-mrepl)
   (lambda (result)
     (when (and (consp result)
                (numberp (car result))
                (cadr result))
       (setf (slynet-client-connection-channel-id connection) (car result))
       (setf (slynet-client-connection-mrepl-thread connection) (cadr result))
       (setf (slynet-client-connection-thread connection) (cadr result)))
     (when callback
       (slynet-client--invoke-callback connection nil callback result)))))

(defun slynet-client-send-channel (connection channel-id payload)
  "Send PAYLOAD over CHANNEL-ID on CONNECTION."
  (slynet-client--require-connection connection)
  (slynet-client--require
   (and (integerp channel-id) (> channel-id 0))
   "CHANNEL-ID must be a positive integer, got %S" channel-id)
  (slynet-client--require
   (consp payload) "PAYLOAD must be a non-empty list, got %S" payload)
  (slynet-client-send connection (list :channel-send channel-id payload)))

(defun slynet-client-eval-mrepl-string (connection string callback)
  "Evaluate STRING on CONNECTION's active MREPL and call CALLBACK with values."
  (slynet-client--require-connection connection)
  (slynet-client--require
   (stringp string) "STRING must be a string, got %S" string)
  (slynet-client--require-callback callback "CALLBACK")
  (let ((channel-id (slynet-client-connection-channel-id connection)))
    (unless channel-id
      (error "SLYNET MREPL channel not initialized"))
    (when (slynet-client-connection-mrepl-eval-callback connection)
      (error "SLYNET MREPL evaluation already in flight"))
    ;; The callback slot also acts as the in-flight marker because channel
    ;; replies carry no request id.  Preserve that marker even when the caller
    ;; does not need a completion callback.
    (setf (slynet-client-connection-mrepl-eval-callback connection)
          (or callback #'ignore))
    (condition-case err
        (slynet-client-send-channel connection channel-id (list :process string))
      (error
       (setf (slynet-client-connection-mrepl-eval-callback connection) nil)
       (signal (car err) (cdr err))))))

(defun slynet-client-disconnect (connection)
  "Close CONNECTION and clear pending transport and MREPL state."
  (when (slynet-client-connection-p connection)
    (let ((process (slynet-client-connection-process connection)))
      (slynet-client--reset-connection-state connection :disconnected)
      (when (and process (slynet-client--process-live-p process))
        (slynet-client--delete-process process)))))

(provide 'slynet-client)
;;; slynet-client.el ends here
