;;; slynet-client.el --- SLYNET Emacs transport helpers -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: SLYNET contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: lisp, janet, sly, processes
;; URL: https://example.invalid/slynet

;;; Commentary:

;; Low-level Emacs-side transport helpers for speaking the SLYNET wire
;; protocol.  The public user-facing entrypoint is `slynet.el'.

;;; Code:

(require 'cl-lib)

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

(defun slynet-client--process-send-string (process string)
  "Send STRING to PROCESS."
  (process-send-string process string))

(defun slynet-client--process-live-p (process)
  "Return non-nil when PROCESS is live."
  (process-live-p process))

(defun slynet-client--delete-process (process)
  "Delete PROCESS."
  (delete-process process))

(defun slynet-client-encode-message (message)
  "Encode MESSAGE as a SLY/SLYNK-style six-hex-byte length-prefixed sexp."
  (let* ((payload (prin1-to-string message))
         (length-prefix (format "%06x" (string-bytes payload))))
    (concat length-prefix payload)))

(defun slynet-client-make-test-connection (on-message)
  "Create an in-memory connection for batch ERT and `process-filter' test code.
ON-MESSAGE is called with each decoded protocol message."
  (make-slynet-client-connection :on-message on-message))

(defun slynet-client--try-read-one (connection)
  "Return one complete decoded message from CONNECTION, or nil if incomplete."
  (let ((buffer (slynet-client-connection-buffer connection)))
    (when (>= (length buffer) 6)
      (let* ((payload-length (string-to-number (substring buffer 0 6) 16))
             (message-end (+ 6 payload-length)))
        (when (>= (length buffer) message-end)
          (let* ((payload (substring buffer 6 message-end))
                 (decoded (car (read-from-string payload))))
            (setf (slynet-client-connection-buffer connection)
                  (substring buffer message-end))
            decoded))))))

(defun slynet-client-filter (connection chunk)
  "Append CHUNK to CONNECTION and deliver all complete decoded messages."
  (setf (slynet-client-connection-buffer connection)
        (concat (slynet-client-connection-buffer connection) chunk))
  (let ((decoded (slynet-client--try-read-one connection)))
    (while decoded
      (when-let ((handler (slynet-client-connection-on-message connection)))
        (funcall handler decoded))
      (setq decoded (slynet-client--try-read-one connection)))))

(cl-defun slynet-client-connect (&key (host "127.0.0.1") (port 4005) on-message name buffer)
  "Connect to a SLYNET server on HOST and PORT.
ON-MESSAGE is called with each decoded wire message.  NAME and BUFFER
are passed to `open-network-stream'."
  (let* ((process (slynet-client--open-network-stream (or name "slynet") buffer host port))
         (connection (make-slynet-client-connection
                      :process process
                      :host host
                      :port port)))
    (setf (slynet-client-connection-on-message connection)
          (lambda (message)
            (slynet-client-handle-message connection message)
            (when on-message
              (funcall on-message message))))
    (slynet-client--set-process-filter
     process
     (lambda (_process chunk)
       (slynet-client-filter connection chunk)))
    (slynet-client--set-process-sentinel
     process
     (lambda (_process _event)
       nil))
    connection))

(defun slynet-client-send (connection message)
  "Send MESSAGE over CONNECTION and return MESSAGE."
  (unless (slynet-client-connection-p connection)
    (error "Not a SLYNET client connection: %S" connection))
  (let ((process (slynet-client-connection-process connection)))
    (unless (and process (slynet-client--process-live-p process))
      (error "SLYNET connection is not live"))
    (slynet-client--process-send-string process (slynet-client-encode-message message))
    message))

(defun slynet-client-next-id (connection)
  "Return and increment CONNECTION's next request id."
  (let ((id (slynet-client-connection-next-id connection)))
    (setf (slynet-client-connection-next-id connection) (1+ id))
    id))

(defun slynet-client--complete-request (connection request-id payload)
  "Complete REQUEST-ID on CONNECTION with PAYLOAD."
  (let* ((pending (slynet-client-connection-pending-requests connection))
         (callback (gethash request-id pending)))
    (when callback
      (remhash request-id pending)
      (funcall callback payload))))

(defun slynet-client--append-output (connection text)
  "Append TEXT to CONNECTION's accumulated MREPL output."
  (setf (slynet-client-connection-repl-output connection)
        (concat (slynet-client-connection-repl-output connection) text)))

(defun slynet-client--payload-op (payload)
  "Return the operation symbol or keyword at the head of PAYLOAD."
  (when (consp payload)
    (car payload)))

(defun slynet-client--op= (actual keyword symbol)
  "Return non-nil when ACTUAL names the same protocol op as KEYWORD or SYMBOL."
  (or (eq actual keyword) (eq actual symbol)))

(defun slynet-client--handle-channel-message (connection _channel-id payload)
  "Handle a channel PAYLOAD for CONNECTION."
  (let ((op (slynet-client--payload-op payload)))
    (cond
     ((slynet-client--op= op :write-string 'write-string)
      (slynet-client--append-output connection (cadr payload)))
     ((slynet-client--op= op :prompt 'prompt)
      (let ((package-name (cadr payload))
            (condition (nthcdr 5 payload)))
        (setf (slynet-client-connection-package connection) package-name)
        (setf (slynet-client-connection-prompt-string connection)
              (if condition
                  (format "%s> [%s] " package-name (car condition))
                (format "%s> " package-name)))))
     ((slynet-client--op= op :write-values 'write-values)
      (let ((values (cadr payload)))
        (setf (slynet-client-connection-last-values connection) values)
        (when-let ((callback (slynet-client-connection-mrepl-eval-callback connection)))
          (setf (slynet-client-connection-mrepl-eval-callback connection) nil)
          (funcall callback values))))
     ((slynet-client--op= op :evaluation-aborted 'evaluation-aborted)
      (when-let ((callback (slynet-client-connection-mrepl-eval-callback connection)))
        (setf (slynet-client-connection-mrepl-eval-callback connection) nil)
        (funcall callback (list :abort (cadr payload)))))
     ((slynet-client--op= op :server-side-repl-close 'server-side-repl-close)
      (setf (slynet-client-connection-channel-id connection) nil))
     (t nil))
    (run-hook-with-args 'slynet-client-after-channel-message-functions
                        connection _channel-id payload)))

(defun slynet-client-handle-message (connection message)
  "Dispatch decoded MESSAGE for CONNECTION."
  (let ((op (slynet-client--payload-op message)))
    (cond
     ((slynet-client--op= op :return 'return)
      (let ((status (cadr message))
            (request-id (caddr message)))
        (pcase status
          (`(:ok ,value)
           (slynet-client--complete-request connection request-id value))
          (`(ok ,value)
           (slynet-client--complete-request connection request-id value))
          (`(:abort ,reason)
           (slynet-client--complete-request connection request-id (list :abort reason)))
          (`(abort ,reason)
           (slynet-client--complete-request connection request-id (list :abort reason))))))
     ((slynet-client--op= op :channel-send 'channel-send)
      (slynet-client--handle-channel-message connection (cadr message) (caddr message)))
     ((slynet-client--op= op :channel-close 'channel-close)
      (let ((channel-id (cadr message)))
        (when (equal channel-id (slynet-client-connection-channel-id connection))
          (setf (slynet-client-connection-channel-id connection) nil))))
     (t nil))))

(defun slynet-client-send-rex-async (connection form callback &optional package thread)
  "Send FORM over CONNECTION and call CALLBACK with the :return payload.
Return the request id used for the message."
  (let ((request-id (slynet-client-next-id connection)))
    (when callback
      (puthash request-id callback
               (slynet-client-connection-pending-requests connection)))
    (slynet-client-send connection
                        (list :emacs-rex
                              form
                              (or package (slynet-client-connection-package connection))
                              (or thread (slynet-client-connection-thread connection))
                              request-id))
    request-id))

(defun slynet-client-send-rex (connection form &optional package thread)
  "Send FORM as an :emacs-rex request over CONNECTION.
Return the request id used for the message."
  (slynet-client-send-rex-async connection form nil package thread))

(defun slynet-client-create-mrepl (connection callback)
  "Create an MREPL on CONNECTION and call CALLBACK with the backend result."
  (slynet-client-send-rex-async
   connection
   '(create-mrepl)
   (lambda (result)
     (when (consp result)
       (setf (slynet-client-connection-channel-id connection) (car result))
       (setf (slynet-client-connection-mrepl-thread connection) (cadr result))
       (setf (slynet-client-connection-thread connection) (cadr result)))
     (when callback
       (funcall callback result)))))

(defun slynet-client-send-channel (connection channel-id payload)
  "Send PAYLOAD over CHANNEL-ID on CONNECTION."
  (slynet-client-send connection (list :channel-send channel-id payload)))

(defun slynet-client-eval-mrepl-string (connection string callback)
  "Evaluate STRING on CONNECTION's active MREPL and call CALLBACK with values."
  (let ((channel-id (slynet-client-connection-channel-id connection)))
    (unless channel-id
      (error "SLYNET MREPL channel not initialized"))
    (setf (slynet-client-connection-mrepl-eval-callback connection) callback)
    (slynet-client-send-channel connection channel-id (list :process string))))

(defun slynet-client-disconnect (connection)
  "Close CONNECTION's process if it is live."
  (when (slynet-client-connection-p connection)
    (let ((process (slynet-client-connection-process connection)))
      (when (and process (slynet-client--process-live-p process))
        (slynet-client--delete-process process)))))

(provide 'slynet-client)
;;; slynet-client.el ends here
