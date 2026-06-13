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
         (fake-process (list :fake-process)))
     (cl-letf (((symbol-function 'slynet-client--open-network-stream)
                (lambda (name buffer host service)
                  (setq opened (list name buffer host service))
                  fake-process))
               ((symbol-function 'slynet-client--set-process-filter)
                (lambda (_process _filter) :filter-installed))
               ((symbol-function 'slynet-client--set-process-sentinel)
                (lambda (_process _sentinel) :sentinel-installed))
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
      (should (equal opened '("slynet" nil "127.0.0.1" 4005))))))

(ert-deftest slynet-eval-string-sends-interactive-eval-rex ()
  (slynet-test-with-fake-transport
    (slynet-connect :host "localhost" :port 4111)
    (let ((request-id (slynet-eval-string "(+ 1 2)")))
      (should (= request-id 1))
      (should (equal (slynet-test-decode-wire (car sent))
                     '(:emacs-rex (interactive-eval-region "(+ 1 2)") "core" nil 1))))))

(ert-deftest slynet-disconnect-closes-current-connection ()
  (slynet-test-with-fake-transport
    (slynet-connect)
    (slynet-disconnect)
    (should (equal deleted (list fake-process)))
    (should-not slynet-current-connection)))


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
    (let ((connection (slynet-connect :host "127.0.0.1" :port 4005))
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
        (should (equal deleted (list (slynet-client-connection-process connection))))
        (should (eq server-deleted fake-server))
        (should-not slynet-current-connection)
        (should-not slynet-server-process)))))

(provide 'slynet-tests)
;;; slynet-tests.el ends here
