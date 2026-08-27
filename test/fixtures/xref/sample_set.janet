(var fixture-state 0)

(defn fixture-update [value]
  (set fixture-state value)
  fixture-state)
