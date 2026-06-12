(use ../mini-test)
(import ../test-tools :as tt)
(import ../slynet/rpc :prefix "rpc/")

(register-test
  {:name "getpid returns numeric pid"
   :tags [:integration :server]
   :fn (fn []
         (tt/with-test-server [srv]
                              (def resp ((srv :emacs-rex!) '(os/getpid) :core nil 1))
                              (assert-true (number? resp))))})

(register-test
  {:name "transport frame encodes payload with six-byte hex length"
   :tags [:transport :phase1]
   :fn (fn []
         (def frame (rpc/encode-packet "hello"))
         (assert= "000005hello" frame)
         (def decoded (rpc/read-packet-from-buffer frame))
         (assert= :complete (decoded :status))
         (assert= "hello" (decoded :payload))
         (assert= "" (decoded :remaining)))})

(register-test
  {:name "transport frame waits for complete fragmented payload"
   :tags [:transport :phase1]
   :fn (fn []
         (def decoded (rpc/read-packet-from-buffer "000005he"))
         (assert= :incomplete (decoded :status))
         (assert= 5 (decoded :needed))
         (assert= 2 (decoded :available)))})

(register-test
  {:name "transport frame preserves remaining bytes for multi-frame buffers"
   :tags [:transport :phase1]
   :fn (fn []
         (def first (rpc/encode-packet "one"))
         (def second (rpc/encode-packet "two"))
         (def decoded (rpc/read-packet-from-buffer (string first second)))
         (assert= :complete (decoded :status))
         (assert= "one" (decoded :payload))
         (assert= second (decoded :remaining)))})

(register-test
  {:name "transport frame reports malformed length prefix"
   :tags [:transport :phase1]
   :fn (fn []
         (def decoded (rpc/read-packet-from-buffer "zzzzzzhello"))
         (assert= :error (decoded :status))
         (assert= :malformed-length-prefix (decoded :type))
         (assert= "zzzzzz" (decoded :header)))})

(register-test
  {:name "incoming emacs rex parses keywords and strings for live clients"
   :tags [:transport :phase2]
   :fn (fn []
         (def parsed (rpc/process-incoming-message (string "(:emacs-rex (create-mrepl) " "\"" "core" "\"" " nil 1)")))
         (assert= :emacs-rex (parsed 0))
         (assert= 'create-mrepl ((parsed 1) 0))
         (assert= "core" (parsed 2))
         (assert= 1 (parsed 3)))})
