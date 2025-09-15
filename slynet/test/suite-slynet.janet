# SLYNET Test Suite – High Coverage for Backend & RPC Modules

(import ../slynk_janet/backend)
(import ../slynk_janet/rpc)
(import ../slynet-api)

(defn test-make-backend-error []
  (let [err (make-backend-error "fail" {:foo "bar"})]
    (assert (= (:type err) :slynk-backend-error))
    (assert (= (:message err) "fail"))
    (assert (= (:details err) {:foo "bar"}))))

(defn test-make-implementation-error []
  (let [err (make-implementation-error "iface" "missing")]
    (assert (= (:type err) :slynk-implementation-error))
    (assert (= (:interface err) "iface"))
    (assert (= (:reason err) "missing"))
    (assert (string/includes (:message err) "Implementation error for iface"))))

(defn test-make-slynk-reader-error []
  (let [err (make-slynk-reader-error "packet" "cause")]
    (assert (= (:type err) :slynk-reader-error))
    (assert (= (:packet err) "packet"))
    (assert (= (:cause err) "cause"))
    (assert (string/includes (:message err) "Failed to read message"))))

(defn test-make-slynk-protocol-error []
  (let [err (make-slynk-protocol-error "msg" "exp" "got")]
    (assert (= (:type err) :slynk-protocol-error))
    (assert (= (:message err) "msg"))
    (assert (= (:expected err) "exp"))
    (assert (= (:received err) "got"))))

(defn test-if-let-macro []
  (assert (= (if-let [x 42] x) 42))
  (assert (= (if-let [x nil] x "fallback") "fallback")))

(defn test-definterface-macro []
  (definterface testiface [x] "docstring")
  (assert (function? testiface))
  (try
    (testiface 1)
    (error "Should throw for stub interface")
    ([err fib]
      (assert (string/includes (e :message) "Interface stub")))))

(defn test-registry-population []
  (definterface regiface [y] "doc")
  (defimplementation regiface [y] y)
  (assert (= (regiface 99) 99)))

(defn run-all []
  (test-make-backend-error)
  (test-make-implementation-error)
  (test-make-slynk-reader-error)
  (test-make-slynk-protocol-error)
  (test-if-let-macro)
  (test-definterface-macro)
  (test-registry-population)
  :ok)

(run-all)