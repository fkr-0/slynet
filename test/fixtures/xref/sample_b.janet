# Fixture B for xref/source-index contract.
(import ./sample_a)

(defn fixture-helper [x]
  (fixture-target x))

(defn fixture-caller [x]
  (fixture-helper x))
