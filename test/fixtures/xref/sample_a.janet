# Fixture A for xref/source-index contract.
# The scanner must ignore this commented fake definition:
# (defn fixture-target-comment [x] x)

(def sample-value 10)
(var *sample-state* nil)
(def string-noise "(defn fixture-target-string [x] x)")

(defn fixture-target-extra [x]
  x)

(defn fixture-target [x]
  (+ x sample-value))

(defmacro fixture-macro [& body]
  ~(do ,;body))

(definterface fixture-interface [value])
