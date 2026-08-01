;;; slynet.el --- Emacs client library for SLYNET -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: SLYNET contributors
;; Version: 1.0.5
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, lisp, janet, tools, processes

;;; Commentary:

;; Public Emacs-side entrypoint for connecting to and operating a Janet
;; SLYNET server.  The package provides a daily-use command surface around the
;; low-level transport: connection lifecycle, status/health display, REPL,
;; completion, inspector, xref, diagnostics, and debugger buffers.  SLYNET is
;; Janet-oriented; compatibility facades are marked explicitly when they are not
;; Common Lisp / SLYNK semantic equivalents.

;;; Code:

(require 'cl-lib)
(require 'easymenu)
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

(defcustom slynet-server-command '("janet" "slynet/cli.janet" "--tcp")
  "Command used by `slynet-start-server'.
The first element is the program; remaining elements are arguments."
  :type '(repeat string)
  :group 'slynet)

(defcustom slynet-server-directory nil
  "Directory in which local SLYNET server commands run.
When nil, use the project root detected from `default-directory'.  Set this to
the SLYNET source checkout when starting the bundled server from a directory
that is not inside that checkout."
  :type '(choice (const :tag "Detected project root" nil) directory)
  :group 'slynet)

(defcustom slynet-display-status-in-mode-line t
  "When non-nil, show compact SLYNET connection status in the mode line."
  :type 'boolean
  :group 'slynet)

(defvar slynet-last-host slynet-host
  "Most recent host used by `slynet-connect'.")

(defvar slynet-last-port slynet-port
  "Most recent port used by `slynet-connect'.")

(defvar slynet-last-error nil
  "Most recent user-visible SLYNET lifecycle error, or nil.")

(defvar slynet-status-buffer-name "*slynet-status*"
  "Buffer name used by `slynet-health'.")
(defvar slynet-doc-buffer-name "*slynet-doc*"
  "Buffer name used by `slynet-doc-symbol' and `slynet-autodoc'.")


(defvar slynet-mode-line-string " SLYNET:off"
  "Compact mode-line status for SLYNET.")


(defvar slynet-current-connection nil
  "Current SLYNET client connection, or nil when disconnected.")

(defcustom slynet-repl-buffer-name "*slynet-repl*"
  "Default buffer name for the SLYNET REPL."
  :type 'string
  :group 'slynet)

(defvar-local slynet-repl-connection nil
  "SLYNET connection associated with the current REPL buffer.")

(defvar-local slynet-repl-input-history nil
  "Input forms submitted in the current SLYNET REPL buffer.")

(define-derived-mode slynet-repl-mode special-mode "SLYNET-REPL"
  "Major mode for interacting with a SLYNET MREPL buffer."
  (add-hook 'completion-at-point-functions
            #'slynet-completion-at-point-function nil t))

(defvar slynet-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "c") #'slynet-connect)
    (define-key map (kbd "d") #'slynet-disconnect)
    (define-key map (kbd "r") #'slynet-reconnect)
    (define-key map (kbd "q") #'slynet-quit)
    (define-key map (kbd "s") #'slynet-status)
    (define-key map (kbd "h") #'slynet-health)
    (define-key map (kbd "e") #'slynet-eval-string)
    (define-key map (kbd "m") #'slynet-create-mrepl)
    (define-key map (kbd "i") #'slynet-inspect-value)
    (define-key map (kbd "x") #'slynet-find-definitions)
    (define-key map (kbd "b") #'slynet-debugger-info)
    (define-key map (kbd "D") #'slynet-doc-symbol)
    map)
  "Prefix keymap for user-facing SLYNET commands.")

(defvar slynet-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-s") slynet-command-map)
    map)
  "Keymap used by `slynet-mode'.")

(define-minor-mode slynet-mode
  "Minor mode for a sane Janet SLYNET daily-use command surface.
The prefix key is defined in `slynet-mode-map'.  The mode does not start a
server by itself; use `slynet-connect', `slynet-start-server', or
`slynet-reconnect' explicitly."
  :global t
  :lighter (:eval (when slynet-display-status-in-mode-line slynet-mode-line-string))
  :keymap slynet-mode-map
  (slynet--refresh-mode-line))

(easy-menu-define slynet-menu slynet-mode-map
  "Menu for SLYNET daily-use commands."
  '("SLYNET"
    ["Connect" slynet-connect t]
    ["Disconnect" slynet-disconnect t]
    ["Reconnect" slynet-reconnect t]
    ["Quit" slynet-quit t]
    "---"
    ["Status" slynet-status t]
    ["Health" slynet-health t]
    "---"
    ["REPL" slynet-repl t]
    ["Eval string" slynet-eval-string t]
    ["Inspector" slynet-inspect-value t]
    ["Find definitions" slynet-find-definitions t]
    ["Debugger" slynet-debugger-info t]
    ["Docs" slynet-doc-symbol t]))


(defvar slynet-debugger-buffer-name "*slynet-debugger*"
  "Default buffer name for SLYNET debugger state.")

(defun slynet--handle-wire-message (message)
  "Handle decoded unsolicited SLYNET wire MESSAGE."
  (let ((op (car-safe message)))
    (when (memq op (quote (:debug-activate debug-activate)))
      (let ((buffer (slynet--display-buffer slynet-debugger-buffer-name
                                            (function slynet-debugger-mode))))
        (slynet--render-debugger-info (cadr message) buffer)
        (display-buffer buffer)
        buffer))))

(cl-defun slynet-connect (&key host port on-message)
  "Connect to a SLYNET server and store `slynet-current-connection'.
HOST and PORT default to `slynet-host' and `slynet-port'.  ON-MESSAGE
receives decoded protocol messages.  The endpoint is remembered for
`slynet-reconnect'."
  (interactive)
  (let ((host (or host slynet-host))
        (port (or port slynet-port)))
    (setq slynet-last-host host)
    (setq slynet-last-port port)
    (setq slynet-last-error nil)
    (setq slynet-current-connection
          (slynet-client-connect :host host
                                 :port port
                                 :on-message (lambda (message)
                                               (slynet--handle-wire-message message)
                                               (when on-message
                                                 (funcall on-message message)))))
    (slynet--refresh-mode-line)
    slynet-current-connection))

(defun slynet-disconnect ()
  "Disconnect `slynet-current-connection' when present."
  (interactive)
  (when slynet-current-connection
    (slynet-client-disconnect slynet-current-connection)
    (setq slynet-current-connection nil))
  (slynet--refresh-mode-line)
  nil)


(defun slynet--connection-live-p (&optional connection)
  "Return non-nil when CONNECTION, or the current connection, has a live process."
  (let* ((connection (or connection slynet-current-connection))
         (process (and connection (slynet-client-connection-process connection))))
    (and process (slynet-client--process-live-p process))))

(defun slynet-connection-status (&optional connection)
  "Return a plist describing CONNECTION health for display and test assertions."
  (let* ((connection (or connection slynet-current-connection))
         (connected (and connection t))
         (live (and connection (slynet--connection-live-p connection)))
         (pending (and connection
                       (hash-table-count
                        (slynet-client-connection-pending-requests connection)))))
    (list :connected connected
          :live live
          :host (or (and connection (slynet-client-connection-host connection)) slynet-last-host)
          :port (or (and connection (slynet-client-connection-port connection)) slynet-last-port)
          :package (and connection (slynet-client-connection-package connection))
          :pending-requests (or pending 0)
          :last-error slynet-last-error)))

(defun slynet--status-label (&optional connection)
  "Return a compact human-readable status label for CONNECTION."
  (let* ((status (slynet-connection-status connection))
         (state (cond
                 ((plist-get status :live) "live")
                 ((plist-get status :connected) "stale")
                 (t "off"))))
    (format "SLYNET:%s %s:%s pending=%s"
            state
            (or (plist-get status :host) "?")
            (or (plist-get status :port) "?")
            (plist-get status :pending-requests))))

(defun slynet--refresh-mode-line ()
  "Refresh `slynet-mode-line-string' from current connection state."
  (setq slynet-mode-line-string (concat " " (slynet--status-label)))
  (force-mode-line-update t))

(defun slynet-status ()
  "Echo and return the current SLYNET connection status plist."
  (interactive)
  (let ((status (slynet-connection-status)))
    (message "%s" (slynet--status-label))
    status))

(defun slynet-health ()
  "Display a small health buffer for the current SLYNET session."
  (interactive)
  (let ((buffer (get-buffer-create slynet-status-buffer-name))
        (status (slynet-connection-status)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)
        (insert "SLYNET Health

")
        (insert (format "State: %s
" (cond
                                      ((plist-get status :live) "live")
                                      ((plist-get status :connected) "stale")
                                      (t "off"))))
        (insert (format "Endpoint: %s:%s
"
                        (or (plist-get status :host) "?")
                        (or (plist-get status :port) "?")))
        (insert (format "Package: %s
" (or (plist-get status :package) "-")))
        (insert (format "Pending requests: %s
" (plist-get status :pending-requests)))
        (insert (format "Last error: %s
" (or (plist-get status :last-error) "-")))
        (goto-char (point-min))))
    (when (called-interactively-p 'interactive)
      (display-buffer buffer))
    buffer))

(defun slynet--require-connection ()
  "Return the active SLYNET connection or signal a user-facing error."
  (or slynet-current-connection
      (user-error "Not connected to SLYNET")))

(defun slynet-repl (&optional connection)
  "Return the REPL buffer for CONNECTION, creating it when necessary.
When called interactively, display the buffer.  CONNECTION defaults to the
current SLYNET connection."
  (interactive)
  (let* ((connection (or connection (slynet--require-connection)))
         (buffer (slynet-client-connection-repl-buffer connection)))
    (unless (and buffer (buffer-live-p buffer))
      (setq buffer (get-buffer-create slynet-repl-buffer-name))
      (setf (slynet-client-connection-repl-buffer connection) buffer))
    (with-current-buffer buffer
      (unless (derived-mode-p 'slynet-repl-mode)
        (slynet-repl-mode))
      (setq-local slynet-repl-connection connection)
      (unless (local-variable-p 'slynet-repl-input-history buffer)
        (setq-local slynet-repl-input-history nil)))
    (when (called-interactively-p 'interactive)
      (pop-to-buffer buffer))
    buffer))

(defun slynet-repl--insert-text (buffer text &optional read-only)
  "Insert TEXT at the end of BUFFER.
When READ-ONLY is non-nil, mark inserted text as immutable prompt text."
  (when (and buffer (buffer-live-p buffer))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)
            (start (point-max)))
        (goto-char (point-max))
        (insert text)
        (when read-only
          (add-text-properties start (point)
                               '(read-only t field prompt rear-nonsticky t)))))))

(defun slynet-repl--values-string (values)
  "Return VALUES formatted for insertion into a SLYNET REPL buffer."
  (cond
   ((stringp values) values)
   ((vectorp values)
    (mapconcat (lambda (value)
                 (if (stringp value) value (format "%S" value)))
               (append values nil) ""))
   ((listp values)
    (mapconcat (lambda (value)
                 (if (stringp value) value (format "%S" value)))
               values ""))
   (t (format "%S" values))))

(defun slynet-repl--after-channel-message (connection _channel-id payload)
  "Render channel PAYLOAD for CONNECTION's REPL buffer when it exists."
  (when-let ((buffer (slynet-client-connection-repl-buffer connection)))
    (let ((op (car-safe payload)))
      (cond
       ((or (eq op :write-string) (eq op 'write-string))
        (slynet-repl--insert-text buffer (cadr payload)))
       ((or (eq op :write-values) (eq op 'write-values))
        (slynet-repl--insert-text buffer (slynet-repl--values-string (cadr payload))))
       ((or (eq op :prompt) (eq op 'prompt))
        (slynet-repl--insert-text
         buffer
         (or (slynet-client-connection-prompt-string connection)
             (format "%s> " (or (slynet-client-connection-package connection) "core")))
         t))))))

(defun slynet-repl-submit-string (string)
  "Submit STRING through the current REPL buffer's MREPL connection."
  (interactive "sJanet REPL input: ")
  (let ((connection (or slynet-repl-connection (slynet--require-connection))))
    (setq slynet-repl-input-history
          (append slynet-repl-input-history (list string)))
    (slynet-eval-mrepl-string string (lambda (_values) nil))
    connection))

(add-hook 'slynet-client-after-channel-message-functions
          #'slynet-repl--after-channel-message)

(defun slynet--completion-bounds ()
  "Return completion bounds for the symbol at point, or nil."
  (or (bounds-of-thing-at-point 'symbol)
      (cons (point) (point))))

(defun slynet--completion-candidate (candidate source support-class)
  "Return CANDIDATE annotated with SOURCE and SUPPORT-CLASS text metadata."
  (let ((text (copy-sequence candidate)))
    (add-text-properties 0 (length text)
                         (list 'slynet-completion-source source
                               'slynet-support-class support-class)
                         text)
    text))

(defun slynet--sequence-to-list (value)
  "Return VALUE as a list when it is a list or vector; otherwise nil."
  (cond
   ((vectorp value) (append value nil))
   ((listp value) value)
   (t nil)))

(defun slynet--normalize-completion-result (result source support-class)
  "Normalize backend completion RESULT with SOURCE and SUPPORT-CLASS metadata."
  (let* ((items (slynet--sequence-to-list (car-safe result)))
         (common-prefix (cadr result))
         (candidates
          (mapcar (lambda (candidate)
                    (slynet--completion-candidate
                     (if (stringp candidate) candidate (format "%S" candidate))
                     source support-class))
                  items)))
    (list candidates common-prefix)))

(defun slynet-completions-for-prefix (prefix callback &optional package)
  "Request completions for PREFIX and optional PACKAGE.
Call CALLBACK with candidates and their common prefix."
  (slynet-client-send-rex-async
   (slynet--require-connection)
   (list 'simple-completions prefix (or package "core"))
   (lambda (result)
     (pcase-let ((`(,candidates ,common-prefix)
                  (slynet--normalize-completion-result
                   result 'simple-completions 'native)))
       (funcall callback candidates common-prefix)))))

(defun slynet-completion-annotation (candidate)
  "Return a short annotation for completion CANDIDATE."
  (when (get-text-property 0 'slynet-support-class candidate)
    " [slynet]"))

(defun slynet-completion-at-point-function ()
  "Return a `completion-at-point' entry backed by SLYNET simple completions."
  (when slynet-current-connection
    (let* ((bounds (slynet--completion-bounds))
           (start (car bounds))
           (end (cdr bounds))
           (prefix (buffer-substring-no-properties start end))
           (candidates nil))
      (slynet-completions-for-prefix
       prefix
       (lambda (items _common-prefix)
         (setq candidates items)))
      (list start end (or candidates nil)
            :annotation-function #'slynet-completion-annotation))))

(defun slynet-arglist (operator callback &optional package)
  "Request OPERATOR arglist metadata for optional PACKAGE.
Call CALLBACK with an autodoc payload."
  (slynet-client-send-rex-async
   (slynet--require-connection)
   (list 'operator-arglist operator (or package "core"))
   (lambda (result)
     (funcall callback
              (list :operator operator
                    :arglist result
                    :frontend-surface 'autodoc
                    :support-class 'native)))))


(defcustom slynet-inspector-buffer-name "*slynet-inspector*"
  "Default buffer name for SLYNET inspector results."
  :type 'string
  :group 'slynet)

(defcustom slynet-xref-buffer-name "*slynet-xref*"
  "Default buffer name for SLYNET xref results."
  :type 'string
  :group 'slynet)

(defcustom slynet-debugger-buffer-name "*slynet-debugger*"
  "Default buffer name for SLYNET debugger and execution-unit results."
  :type 'string
  :group 'slynet)

(defvar-local slynet-inspector-object-id nil
  "Stable SLYNET inspector object id displayed by the current buffer.")

(defvar-local slynet-inspector-parent-object-id nil
  "Stable parent object id for the current inspector buffer, or nil.")

(defvar-local slynet-inspector-part-key nil
  "Part key used to navigate to the current inspector object, or nil.")

(define-derived-mode slynet-inspector-mode special-mode "SLYNET-Inspector"
  "Major mode for displaying SLYNET inspector objects.")

(define-derived-mode slynet-xref-mode special-mode "SLYNET-Xref"
  "Major mode for displaying SLYNET source-index xref results.")

(define-derived-mode slynet-debugger-mode special-mode "SLYNET-Debugger"
  "Major mode for displaying SLYNET debugger and execution-unit state.")

(define-derived-mode slynet-doc-mode special-mode "SLYNET-Doc"
  "Major mode for scrollable Janet doc/autodoc payloads.")

(defun slynet--display-buffer (name mode)
  "Return buffer NAME initialized with MODE."
  (let ((buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer))
      (funcall mode))
    buffer))

(defun slynet--insert-line (format-string &rest args)
  "Insert one formatted line using FORMAT-STRING and ARGS."
  (insert (apply #'format format-string args) "\n"))

(defun slynet--plist-string (plist key &optional default)
  "Return PLIST value for KEY formatted as a user-facing string.
When KEY is absent or nil, return DEFAULT or the empty string."
  (let ((value (plist-get plist key)))
    (cond
     ((null value) (or default ""))
     ((stringp value) value)
     ((keywordp value) (substring (symbol-name value) 1))
     ((symbolp value) (symbol-name value))
     (t (format "%S" value)))))

(defun slynet-inspect-value (value)
  "Inspect VALUE through SLYNET and render the result in an inspector buffer."
  (let ((buffer (slynet--display-buffer slynet-inspector-buffer-name #'slynet-inspector-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'inspect-for-emacs value)
     (lambda (payload)
       (slynet--render-inspector payload buffer)))
    buffer))

(defun slynet-inspector-nth-part (index)
  "Navigate the SLYNET inspector to part INDEX and render the result."
  (interactive "nInspector part index: ")
  (let ((buffer (slynet--display-buffer slynet-inspector-buffer-name #'slynet-inspector-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'inspector-nth-part index)
     (lambda (payload)
       (slynet--render-inspector payload buffer)))
    buffer))

(defun slynet-inspector-pop ()
  "Navigate the SLYNET inspector back to the parent object and render it."
  (interactive)
  (let ((buffer (slynet--display-buffer slynet-inspector-buffer-name #'slynet-inspector-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     '(inspector-pop)
     (lambda (payload)
       (slynet--render-inspector payload buffer)))
    buffer))

(defun slynet--render-xref-hit (hit)
  "Insert one source-index HIT with navigation metadata text properties."
  (let* ((file (plist-get hit :file))
         (line (or (plist-get hit :line) 0))
         (column (or (plist-get hit :column) 0))
         (name (slynet--plist-string hit :name "<unknown>"))
         (snippet (slynet--plist-string hit :snippet ""))
         (start (point)))
    (slynet--insert-line "%s %s:%s:%s" name file line column)
    (slynet--insert-line "  %s" snippet)
    (add-text-properties start (point)
                         (list 'slynet-xref-file file
                               'slynet-xref-line line
                               'slynet-xref-column column
                               'slynet-source-index (plist-get hit :source-index)
                               'slynet-xref-kind (plist-get hit :xref-kind)))))

(defun slynet--render-xrefs (symbol hits buffer)
  "Render xref HITS for SYMBOL into BUFFER and return BUFFER."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (erase-buffer)
      (slynet-xref-mode)
      (slynet--insert-line "Definitions for %s" symbol)
      (insert "\n")
      (dolist (hit (slynet--sequence-to-list hits))
        (slynet--render-xref-hit hit)
        (insert "\n")))
    buffer))

(defun slynet-find-definitions (symbol)
  "Find definitions for SYMBOL and render source-index hits."
  (interactive "sSLYNET definitions for: ")
  (let ((buffer (slynet--display-buffer slynet-xref-buffer-name #'slynet-xref-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'find-definitions-for-emacs symbol)
     (lambda (hits)
       (slynet--render-xrefs symbol hits buffer)))
    buffer))

(defun slynet--render-location-string (location)
  "Return LOCATION plist as a compact source string."
  (if (and (listp location) (plist-get location :file))
      (format "%s:%s:%s"
              (plist-get location :file)
              (or (plist-get location :line) 0)
              (or (plist-get location :column) 0))
    "<unknown location>"))

(defun slynet-debugger-info ()
  "Request current SLYNET debugger info and render it in a debugger buffer."
  (interactive)
  (let ((buffer (slynet--display-buffer slynet-debugger-buffer-name #'slynet-debugger-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     '(debugger-info-for-emacs)
     (lambda (payload)
       (slynet--render-debugger-info payload buffer)))
    buffer))

(defun slynet-debugger-invoke-restart (index)
  "Invoke debugger restart INDEX and render the backend result."
  (interactive "nRestart index: ")
  (let ((buffer (slynet--display-buffer slynet-debugger-buffer-name #'slynet-debugger-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'invoke-nth-restart index)
     (lambda (payload)
       (with-current-buffer buffer
         (let ((inhibit-read-only t))
           (erase-buffer)
           (slynet-debugger-mode)
           (slynet--insert-line "Restart result: %S" payload)))))
    buffer))

(defun slynet-list-execution-units ()
  "Request SLYNET execution-unit facade data and render it."
  (interactive)
  (let ((buffer (slynet--display-buffer slynet-debugger-buffer-name #'slynet-debugger-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     '(list-threads)
     (lambda (units)
       (with-current-buffer buffer
         (let ((inhibit-read-only t))
           (erase-buffer)
           (slynet-debugger-mode)
           (slynet--insert-line "Execution units")
           (insert "\n")
           (dolist (unit (slynet--sequence-to-list units))
             (slynet--insert-line "%s [%s]"
                                  (slynet--plist-string unit :name "<unnamed>")
                                  (slynet--plist-string unit :status "unknown"))
             (slynet--insert-line "  Model: %s"
                                  (slynet--plist-string unit :thread-model "unknown"))
             (slynet--insert-line "  CL thread equivalent: %S"
                                  (plist-get unit :cl-thread-equivalent)))))))
    buffer))


;; Interactive inspector, xref, debugger, diagnostics, connection, and completion slices.
(require 'button)

(defvar slynet-named-connections (make-hash-table :test 'equal)
  "Named SLYNET connections keyed by project or user label.")

(defvar slynet-project-servers (make-hash-table :test 'equal)
  "Project server lifecycle records keyed by project name.")

(defvar slynet-server-process nil
  "Process object for a SLYNET server started from Emacs, or nil.")

(defvar slynet-completion-cache (make-hash-table :test 'equal)
  "Cache for SLYNET completion candidates keyed by completion pattern.")

(defcustom slynet-diagnostics-buffer-name "*slynet-diagnostics*"
  "Default buffer name for SLYNET compile/load diagnostics."
  :type 'string
  :group 'slynet)

(define-derived-mode slynet-diagnostics-mode special-mode "SLYNET-Diagnostics"
  "Major mode for displaying SLYNET Janet diagnostics.")

(defun slynet--goto-source-location (file line column)
  "Visit FILE and move to LINE and COLUMN."
  (let ((buffer (find-file-other-window file)))
    (with-current-buffer buffer
      (goto-char (point-min))
      (forward-line (max 0 (1- (or line 1))))
      (move-to-column (or column 0)))
    buffer))

(defun slynet--button-label (value fallback)
  "Return VALUE as a button label, falling back to FALLBACK."
  (cond
   ((stringp value) value)
   ((null value) fallback)
   (t (format "%S" value))))

(defun slynet--insert-inspector-part-button (part)
  "Insert a clickable inspector PART button."
  (let* ((index (plist-get part :index))
         (label (slynet--button-label (plist-get part :label) (format "[%s]" index)))
         (summary (slynet--button-label (plist-get part :summary) "")))
    (insert-button label
                   'slynet-inspector-part-index index
                   'action (lambda (button)
                             (slynet-inspector-nth-part
                              (button-get button 'slynet-inspector-part-index)))
                   'follow-link t)
    (when (> (length summary) 0)
      (insert " " summary))
    (insert "\n")))

(defun slynet--render-inspector (payload buffer)
  "Render inspector PAYLOAD into BUFFER and return BUFFER.
This interactive version also renders clickable part navigation buttons."
  (with-current-buffer buffer
    (let ((inhibit-read-only t)
          (title (slynet--plist-string payload :title "<untitled>"))
          (content (slynet--sequence-to-list (plist-get payload :content)))
          (parts (slynet--sequence-to-list (plist-get payload :parts))))
      (erase-buffer)
      (slynet-inspector-mode)
      (setq-local slynet-inspector-object-id (plist-get payload :object-id))
      (setq-local slynet-inspector-parent-object-id (plist-get payload :parent-object-id))
      (setq-local slynet-inspector-part-key (plist-get payload :part-key))
      (slynet--insert-line "Inspector: %s" title)
      (when slynet-inspector-object-id
        (slynet--insert-line "Object id: %s" slynet-inspector-object-id))
      (when slynet-inspector-parent-object-id
        (slynet--insert-line "Parent object id: %s" slynet-inspector-parent-object-id))
      (when slynet-inspector-part-key
        (slynet--insert-line "Part key: %s" slynet-inspector-part-key))
      (insert "\n")
      (dolist (line content)
        (slynet--insert-line "%s" (slynet--plist-string (list :line line) :line)))
      (when parts
        (insert "\nParts:\n")
        (dolist (part parts)
          (slynet--insert-inspector-part-button part)))))
  buffer)

(defun slynet--xref-location-at-point ()
  "Return source location metadata at point or line beginning."
  (let ((pos (or (point) (line-beginning-position))))
    (list :file (or (get-text-property pos 'slynet-xref-file)
                    (get-text-property (line-beginning-position) 'slynet-xref-file))
          :line (or (get-text-property pos 'slynet-xref-line)
                    (get-text-property (line-beginning-position) 'slynet-xref-line))
          :column (or (get-text-property pos 'slynet-xref-column)
                      (get-text-property (line-beginning-position) 'slynet-xref-column)))))

(defun slynet-xref-visit-at-point ()
  "Visit the xref source location stored at point."
  (interactive)
  (let* ((loc (slynet--xref-location-at-point))
         (file (plist-get loc :file)))
    (unless file
      (user-error "No SLYNET xref location at point"))
    (slynet--goto-source-location file (plist-get loc :line) (plist-get loc :column))))

(defun slynet--insert-debugger-restart-button (index restart)
  "Insert clickable debugger RESTART button at INDEX."
  (let ((label (slynet--button-label (or (plist-get restart :label)
                                         (plist-get restart :name))
                                     "<restart>")))
    (insert "  ")
    (insert-button label
                   'slynet-restart-index index
                   'action (lambda (button)
                             (slynet-debugger-invoke-restart
                              (button-get button 'slynet-restart-index)))
                   'follow-link t)
    (when-let ((name (plist-get restart :name)))
      (unless (equal name label)
        (insert (format " (%s)" name))))
    (insert (format " [%s/%s eq=%S]\n"
                    (slynet--plist-string restart :restart-kind "unknown")
                    (slynet--plist-string restart :support-class "unknown")
                    (plist-get restart :cl-restart-equivalent)))))

(defun slynet--insert-debugger-frame-button (frame)
  "Insert clickable debugger FRAME source button."
  (let* ((location (plist-get frame :location))
         (file (and (listp location) (plist-get location :file)))
         (line (and (listp location) (plist-get location :line)))
         (column (and (listp location) (plist-get location :column)))
         (start (point)))
    (slynet--insert-line "  %s %s at %s [%s]"
                         (slynet--plist-string frame :index "?")
                         (slynet--plist-string frame :callable "<unknown>")
                         (slynet--render-location-string location)
                         (slynet--render-location-support-string location))
    (when file
      (add-text-properties start (point)
                           (list 'slynet-frame-file file
                                 'slynet-frame-line line
                                 'slynet-frame-column column)))))

(defun slynet--frame-location-at-point ()
  "Return debugger frame source metadata at point or line beginning."
  (let ((pos (or (point) (line-beginning-position))))
    (list :file (or (get-text-property pos 'slynet-frame-file)
                    (get-text-property (line-beginning-position) 'slynet-frame-file))
          :line (or (get-text-property pos 'slynet-frame-line)
                    (get-text-property (line-beginning-position) 'slynet-frame-line))
          :column (or (get-text-property pos 'slynet-frame-column)
                      (get-text-property (line-beginning-position) 'slynet-frame-column)))))

(defun slynet-debugger-visit-frame-source ()
  "Visit the debugger frame source location stored at point."
  (interactive)
  (let* ((loc (slynet--frame-location-at-point))
         (file (plist-get loc :file)))
    (unless file
      (user-error "No SLYNET frame source location at point"))
    (slynet--goto-source-location file (plist-get loc :line) (plist-get loc :column))))

(defun slynet--render-debugger-info (payload buffer)
  "Render debugger info PAYLOAD into BUFFER and return BUFFER.
This interactive version buttonizes restart actions and frame source metadata."
  (with-current-buffer buffer
    (let ((inhibit-read-only t)
          (condition (plist-get payload :condition-record))
          (restarts (slynet--sequence-to-list (plist-get payload :restarts)))
          (frames (slynet--sequence-to-list (plist-get payload :frames)))
          (index 0))
      (erase-buffer)
      (slynet-debugger-mode)
      (slynet--insert-line "Condition: %s"
                           (slynet--plist-string condition :message "<no condition>"))
      (slynet--insert-line "Kind: %s" (slynet--plist-string condition :kind "unknown"))
      (slynet--insert-line "Condition support: %s"
                           (slynet--plist-string condition :support-class "unknown"))
      (slynet--insert-line "CL condition equivalent: %S"
                           (plist-get condition :cl-condition-equivalent))
      (insert "\nRestarts:\n")
      (dolist (restart restarts)
        (slynet--insert-debugger-restart-button index restart)
        (setq index (1+ index)))
      (insert "\nFrames:\n")
      (dolist (frame frames)
        (slynet--insert-debugger-frame-button frame))))
  buffer)

(defun slynet--diagnostic-location-at-point ()
  "Return diagnostic source metadata at point or line beginning."
  (let ((pos (or (point) (line-beginning-position))))
    (list :file (or (get-text-property pos 'slynet-diagnostic-path)
                    (get-text-property (line-beginning-position) 'slynet-diagnostic-path))
          :line (or (get-text-property pos 'slynet-diagnostic-line)
                    (get-text-property (line-beginning-position) 'slynet-diagnostic-line))
          :column (or (get-text-property pos 'slynet-diagnostic-column)
                      (get-text-property (line-beginning-position) 'slynet-diagnostic-column)))))

(defun slynet-diagnostics-visit-at-point ()
  "Visit the diagnostic source location stored at point."
  (interactive)
  (let* ((loc (slynet--diagnostic-location-at-point))
         (file (plist-get loc :file)))
    (unless file
      (user-error "No SLYNET diagnostic location at point"))
    (slynet--goto-source-location file (plist-get loc :line) (plist-get loc :column))))

(defun slynet--render-diagnostics (payload buffer)
  "Render diagnostic PAYLOAD into BUFFER and return BUFFER."
  (with-current-buffer buffer
    (let ((inhibit-read-only t)
          (diagnostics (slynet--sequence-to-list (plist-get payload :diagnostics))))
      (erase-buffer)
      (slynet-diagnostics-mode)
      (slynet--insert-line "SLYNET diagnostics [%s]"
                           (slynet--plist-string payload :diagnostic-model "janet-diagnostics"))
      (insert "\n")
      (dolist (diagnostic diagnostics)
        (let ((start (point)))
          (slynet--insert-line "%s %s %s:%s:%s %s"
                               (slynet--plist-string diagnostic :severity "info")
                               (slynet--plist-string diagnostic :phase "unknown")
                               (slynet--plist-string diagnostic :path "<buffer>")
                               (or (plist-get diagnostic :line) 1)
                               (or (plist-get diagnostic :column) 0)
                               (slynet--plist-string diagnostic :message ""))
          (add-text-properties start (point)
                               (list 'slynet-diagnostic-path (plist-get diagnostic :path)
                                     'slynet-diagnostic-line (plist-get diagnostic :line)
                                     'slynet-diagnostic-column (plist-get diagnostic :column)))))))
  buffer)

(defun slynet-compile-string (string buffer-name)
  "Compile STRING for BUFFER-NAME and render Janet diagnostics."
  (let ((buffer (slynet--display-buffer slynet-diagnostics-buffer-name #'slynet-diagnostics-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'compile-string-for-emacs string buffer-name)
     (lambda (payload)
       (slynet--render-diagnostics payload buffer)))
    buffer))

(defun slynet-runtime-error-diagnostics (string path line column)
  "Evaluate STRING for diagnostics at PATH, LINE, and COLUMN, then render results."
  (let ((buffer (slynet--display-buffer slynet-diagnostics-buffer-name #'slynet-diagnostics-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'runtime-error-diagnostics string path line column)
     (lambda (payload)
       (slynet--render-diagnostics payload buffer)))
    buffer))

(cl-defun slynet-connect-named (name &key host port)
  "Connect to SLYNET under NAME using HOST and PORT, then make it current."
  (let ((connection (slynet-client-connect :host (or host slynet-host)
                                           :port (or port slynet-port))))
    (puthash name connection slynet-named-connections)
    (setq slynet-current-connection connection)
    connection))

(defun slynet-switch-connection (name)
  "Switch `slynet-current-connection' to named connection NAME."
  (let ((connection (gethash name slynet-named-connections)))
    (unless connection
      (user-error "No SLYNET connection named %s" name))
    (setq slynet-current-connection connection)
    connection))

(defun slynet-project-root ()
  "Return the nearest Janet/SLYNET project root for `default-directory'."
  (directory-file-name
   (or (locate-dominating-file default-directory "project.janet")
       (locate-dominating-file default-directory "jpm_tree")
       (locate-dominating-file default-directory ".git")
       default-directory)))

(defun slynet--server-ready-p (host port)
  "Return non-nil when a SLYNET server accepts TCP connections on HOST and PORT."
  (condition-case nil
      (let ((process (open-network-stream "slynet-ready-probe" nil host port)))
        (when process
          (delete-process process)
          t))
    (error nil)))

(defun slynet--wait-for-server-ready (host port timeout-seconds)
  "Wait until HOST and PORT are ready or TIMEOUT-SECONDS elapses."
  (let ((deadline (+ (float-time) (or timeout-seconds 5.0)))
        ready)
    (while (and (not ready) (< (float-time) deadline))
      (setq ready (slynet--server-ready-p host port))
      (unless ready
        (accept-process-output nil 0.05)))
    ready))

(cl-defun slynet-start-project-server (project-name &key command host port readiness-timeout)
  "Start a SLYNET server for PROJECT-NAME using COMMAND, HOST, PORT, and READINESS-TIMEOUT."
  (let* ((host (or host slynet-host))
         (port (or port slynet-port))
         (command (or command slynet-server-command))
         (argv (if (listp command) command (list command)))
         (program (car argv))
         (args (cdr argv))
         (default-directory (file-name-as-directory
                             (or slynet-server-directory
                                 (locate-dominating-file default-directory "project.janet")
                                 default-directory)))
         (process (condition-case err
                      (apply #'start-process
                             (format "slynet-%s" project-name)
                             (format "*slynet-%s*" project-name)
                             program args)
                    (file-missing
                     (user-error "Cannot start SLYNET: executable `%s' is unavailable (%s)"
                                 program (error-message-string err)))))
         (ready (slynet--wait-for-server-ready host port (or readiness-timeout 5.0)))
         (record (list :project project-name
                       :process process
                       :host host
                       :port port
                       :status (if ready :ready :starting)
                       :ready ready)))
    (puthash project-name record slynet-project-servers)
    (setq slynet-server-process process)
    process))

(defun slynet-reconnect-project (project-name)
  "Reconnect named PROJECT-NAME while preserving project identity."
  (let* ((old (gethash project-name slynet-named-connections))
         (host (or (and old (slynet-client-connection-host old)) slynet-last-host slynet-host))
         (port (or (and old (slynet-client-connection-port old)) slynet-last-port slynet-port)))
    (when old
      (slynet-client-disconnect old))
    (let ((connection (slynet-client-connect :host host :port port)))
      (puthash project-name connection slynet-named-connections)
      (setq slynet-current-connection connection)
      connection)))

(defun slynet-project-server-status (project-name)
  "Render and return a status buffer for PROJECT-NAME."
  (let* ((record (gethash project-name slynet-project-servers))
         (process (plist-get record :process))
         (live (and process (process-live-p process)))
         (status (cond
                  ((not record) "not-started")
                  (live (substring (symbol-name (plist-get record :status)) 1))
                  (t "stale")))
         (buffer (get-buffer-create slynet-status-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (special-mode)
        (insert (format "Project: %s
" project-name))
        (insert (format "Status: %s
" status))
        (when record
          (insert (format "Endpoint: %s:%s
"
                          (plist-get record :host)
                          (plist-get record :port))))
        (goto-char (point-min))))
    buffer))

(defun slynet-start-server (&optional command)
  "Start a SLYNET server process using COMMAND or `slynet-server-command'.
COMMAND may be a string program name or a list of program plus arguments."
  (interactive)
  (when (and slynet-server-process (process-live-p slynet-server-process))
    (delete-process slynet-server-process))
  (let* ((command (or command slynet-server-command))
         (argv (if (listp command) command (list command)))
         (program (car argv))
         (args (cdr argv))
         (default-directory (file-name-as-directory
                             (or slynet-server-directory
                                 (locate-dominating-file default-directory "project.janet")
                                 default-directory))))
    (setq slynet-server-process
          (condition-case err
              (apply #'start-process "slynet-server" "*slynet-server*" program args)
            (file-missing
             (setq slynet-last-error (error-message-string err))
             (user-error "Cannot start SLYNET: executable `%s' is unavailable (%s)"
                         program slynet-last-error))))
    slynet-server-process))

(defun slynet-reconnect ()
  "Reconnect using the current connection endpoint or last remembered endpoint."
  (interactive)
  (let* ((old slynet-current-connection)
         (host (or (and old (slynet-client-connection-host old)) slynet-last-host slynet-host))
         (port (or (and old (slynet-client-connection-port old)) slynet-last-port slynet-port)))
    (when old
      (slynet-client-disconnect old))
    (slynet-connect :host host :port port)))

(defun slynet-quit ()
  "Stop local SLYNET process if present and disconnect from the current server."
  (interactive)
  (slynet-disconnect)
  (when (and slynet-server-process (process-live-p slynet-server-process))
    (delete-process slynet-server-process))
  (setq slynet-server-process nil)
  (slynet--refresh-mode-line)
  nil)

(defun slynet-clear-completion-cache ()
  "Clear cached SLYNET completion candidates."
  (interactive)
  (clrhash slynet-completion-cache))

(defun slynet--completion-entry-string (entry)
  "Return a completion candidate string from ENTRY."
  (cond
   ((stringp entry) entry)
   ((and (consp entry) (stringp (car entry))) (car entry))
   ((vectorp entry) (format "%S" entry))
   (t (format "%S" entry))))

(defun slynet--completion-entry-doc (entry)
  "Return documentation metadata from completion ENTRY, when available."
  (cond
   ((and (consp entry) (plist-get (cadr entry) :doc))
    (plist-get (cadr entry) :doc))
   ((and (consp entry) (plist-get (cdr entry) :doc))
    (plist-get (cdr entry) :doc))
   (t nil)))

(defun slynet--normalize-rich-completion-result (result source support-class)
  "Normalize rich completion RESULT from SOURCE with SUPPORT-CLASS metadata."
  (let* ((items (slynet--sequence-to-list (car-safe result)))
         (common-prefix (cadr result))
         (candidates
          (mapcar (lambda (entry)
                    (let ((text (slynet--completion-candidate
                                 (slynet--completion-entry-string entry)
                                 source support-class))
                          (doc (slynet--completion-entry-doc entry)))
                      (when doc
                        (add-text-properties 0 (length text) (list 'slynet-doc doc) text))
                      text))
                  items)))
    (list candidates common-prefix)))

(defun slynet-flex-completions-for-pattern (pattern callback &optional package)
  "Request flex completions for PATTERN and PACKAGE, caching candidates before CALLBACK."
  (let ((cached (gethash pattern slynet-completion-cache)))
    (if cached
        (funcall callback cached pattern)
      (slynet-client-send-rex-async
       (slynet--require-connection)
       (list 'flex-completions pattern (or package "core"))
       (lambda (result)
         (pcase-let ((`(,candidates ,common-prefix)
                      (slynet--normalize-rich-completion-result
                       result 'flex-completions 'native)))
           (puthash pattern candidates slynet-completion-cache)
           (funcall callback candidates common-prefix)))))))

(defun slynet-eval-string (string)
  "Send STRING to the SLYNET backend as an `interactive-eval-region' request.
Return the request id assigned to the wire message."
  (interactive "sJanet eval: ")
  (slynet-client-send-rex (slynet--require-connection)
                          (list 'interactive-eval-region string)))

(defun slynet-create-mrepl (callback)
  "Create an MREPL on the current connection and call CALLBACK with its result."
  (slynet-client-create-mrepl (slynet--require-connection) callback))

(defun slynet-eval-mrepl-string (string callback)
  "Evaluate STRING on the active MREPL and call CALLBACK with returned values."
  (interactive "sJanet MREPL eval: ")
  (slynet-client-eval-mrepl-string (slynet--require-connection) string callback))

(defun slynet--render-location-support-string (location)
  "Return source/support metadata for LOCATION."
  (let ((source-kind (slynet--plist-string location :source-kind "unknown"))
        (synthetic (plist-get location :synthetic-location))
        (pc (plist-get location :janet-pc))
        (status (plist-get location :janet-status))
        (slots (plist-get location :janet-slots-count)))
    (concat
     (format "source=%s synthetic=%S" source-kind synthetic)
     (if status (format " janet-status=%s" (slynet--plist-string location :janet-status)) "")
     (if pc (format " pc=%S" pc) "")
     (if slots (format " slots=%S" slots) ""))))


(defun slynet--listify (value)
  "Return VALUE as a list suitable for rendering."
  (cond
   ((null value) nil)
   ((listp value) value)
   ((vectorp value) (append value nil))
   (t (list value))))

(defun slynet--render-doc-payload (payload buffer)
  "Render Janet doc/autodoc PAYLOAD into BUFFER."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (erase-buffer)
      (slynet-doc-mode)
      (slynet--insert-line "SLYNET Janet Docs")
      (slynet--insert-line "Name: %s" (or (plist-get payload :name)
                                          (plist-get payload :operator)
                                          ""))
      (slynet--insert-line "Surface: %s" (slynet--plist-string payload :frontend-surface "doc-browser"))
      (slynet--insert-line "Support: %s" (slynet--plist-string payload :support-class "unknown"))
      (slynet--insert-line "CL-equivalent: %s"
                           (or (plist-get payload :cl-autodoc-equivalent)
                               (plist-get payload :cl-documentation-equivalent)
                               "false"))
      (slynet--insert-line "Arglist: %s" (slynet--plist-string payload :arglist ""))
      (insert "\n")
      (slynet--insert-line "%s" (slynet--plist-string payload :documentation ""))
      (let ((sources (slynet--listify (plist-get payload :source-locations))))
        (when sources
          (insert "\nSource locations:\n")
          (dolist (source sources)
            (slynet--insert-line "- %s:%s:%s source-index=%s"
                                 (slynet--plist-string source :file)
                                 (slynet--plist-string source :line)
                                 (slynet--plist-string source :column)
                                 (slynet--plist-string source :source-index))))))
    buffer))

(defun slynet-autodoc (form &optional callback)
  "Request SLYNET autodoc for FORM and render or pass it to CALLBACK."
  (interactive "sAutodoc form: ")
  (let ((buffer (slynet--display-buffer slynet-doc-buffer-name #'slynet-doc-mode)))
    (slynet-client-send-rex-async
     (slynet--require-connection)
     (list 'autodoc form)
     (lambda (payload)
       (if callback
           (funcall callback payload)
         (slynet--render-doc-payload payload buffer))))
    buffer))

(defun slynet-doc-symbol (symbol-name)
  "Display a scrollable Janet doc buffer for SYMBOL-NAME."
  (interactive "sJanet symbol: ")
  (slynet-autodoc (format "(%s" symbol-name)))

(defun slynet-complete-form (form &optional callback)
  "Request SLYNET complete-form metadata for FORM.
When CALLBACK is non-nil, call it with the decoded response."
  (interactive "sComplete form: ")
  (slynet-client-send-rex-async
   (slynet--require-connection)
   (list 'complete-form form)
   (lambda (payload)
     (when callback (funcall callback payload)))))

(provide 'slynet)
;;; slynet.el ends here
