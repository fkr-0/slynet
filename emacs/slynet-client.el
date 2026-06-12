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
  (next-id 1)
  (package "core")
  thread)

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
                      :port port
                      :on-message on-message)))
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

(defun slynet-client-send-rex (connection form &optional package thread)
  "Send FORM as an :emacs-rex request over CONNECTION.
Return the request id used for the message."
  (let* ((request-id (slynet-client-next-id connection))
         (message (list :emacs-rex
                        form
                        (or package (slynet-client-connection-package connection))
                        (or thread (slynet-client-connection-thread connection))
                        request-id)))
    (slynet-client-send connection message)
    request-id))

(defun slynet-client-disconnect (connection)
  "Close CONNECTION's process if it is live."
  (when (slynet-client-connection-p connection)
    (let ((process (slynet-client-connection-process connection)))
      (when (and process (slynet-client--process-live-p process))
        (slynet-client--delete-process process)))))

(provide 'slynet-client)
;;; slynet-client.el ends here
