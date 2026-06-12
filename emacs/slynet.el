;;; slynet.el --- Emacs client library for SLYNET -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: SLYNET contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: lisp, janet, sly, processes
;; URL: https://example.invalid/slynet

;;; Commentary:

;; Public Emacs-side entrypoint for connecting to and operating a Janet
;; SLYNET server.  This file intentionally starts small: transport,
;; request construction, and connection lifecycle are tested first; REPL,
;; completion UI, inspector, and debugger buffers can grow from these seams.

;;; Code:

(require 'cl-lib)
(require 'slynet-client)

(defgroup slynet nil
  "Emacs client support for Janet SLYNET."
  :group 'languages
  :prefix "slynet-")

(defcustom slynet-host "127.0.0.1"
  "Default host used by `slynet-connect'."
  :type 'string
  :group 'slynet)

(defcustom slynet-port 4005
  "Default port used by `slynet-connect'."
  :type 'integer
  :group 'slynet)

(defvar slynet-current-connection nil
  "Current SLYNET client connection, or nil when disconnected.")

(cl-defun slynet-connect (&key host port on-message)
  "Connect to a SLYNET server and store `slynet-current-connection'.
HOST and PORT default to `slynet-host' and `slynet-port'.  ON-MESSAGE
receives decoded protocol messages."
  (interactive)
  (setq slynet-current-connection
        (slynet-client-connect :host (or host slynet-host)
                               :port (or port slynet-port)
                               :on-message on-message)))

(defun slynet-disconnect ()
  "Disconnect `slynet-current-connection' when present."
  (interactive)
  (when slynet-current-connection
    (slynet-client-disconnect slynet-current-connection)
    (setq slynet-current-connection nil)))

(defun slynet--require-connection ()
  "Return the active SLYNET connection or signal a user-facing error."
  (or slynet-current-connection
      (user-error "Not connected to SLYNET")))

(defun slynet-eval-string (string)
  "Send STRING to the SLYNET backend as an `interactive-eval-region' request.
Return the request id assigned to the wire message."
  (interactive "sJanet eval: ")
  (slynet-client-send-rex (slynet--require-connection)
                          (list 'interactive-eval-region string)))

(provide 'slynet)
;;; slynet.el ends here
