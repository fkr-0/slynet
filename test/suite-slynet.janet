# (use ../mini-test)
(use ../mini-test)

(import ../slynet/infrastructure :as inf)
(import ../slynet/rpc :as rpc)

(register-test
  {:name "backend error helper"
   :tags [:unit]
   :fn (fn []
         (def err (inf/make-backend-error "fail" {:foo "bar"}))
         (assert= :slynk-backend-error (err :type))
         (assert= "fail" (err :message))
         (assert= {:foo "bar"} (err :details)))})

(register-test
  {:name "implementation error helper"
   :tags [:unit]
   :fn (fn []
         (def err (inf/make-implementation-error 'iface "missing"))
         (assert= :slynk-implementation-error (err :type))
         (assert= 'iface (err :interface))
         (assert-true (string/find (string (err :message)) "Implementation error")))})

(register-test
  {:name "rpc reader error helper"
   :tags [:unit]
   :fn (fn []
         (def err (rpc/make-slynk-reader-error "packet" "oops"))
         (assert= :slynk-reader-error (err :type))
         (assert= "packet" (err :packet))
         (assert= "oops" (err :cause)))})

(register-test
  {:name "rpc protocol error helper"
   :tags [:unit]
   :fn (fn []
         (def err (rpc/make-slynk-protocol-error "msg" "want" "got"))
         (assert= :slynk-protocol-error (err :type))
         (assert= "msg" (err :message))
         (assert= "want" (err :expected))
         (assert= "got" (err :received)))})
