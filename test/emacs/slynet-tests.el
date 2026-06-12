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

(provide 'slynet-tests)
;;; slynet-tests.el ends here
