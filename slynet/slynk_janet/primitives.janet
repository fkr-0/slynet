# == slynet/slynk_janet/primitives.janet ==
# Minimal, dependency-free helpers shared by backend and gray.

# (import ev)

(defn make-lock [name]
  @{:type :lock :name name :lock (ev/lock)})

# Convenience function for ergonomic bodies:
# Use like this:
# (with-lock lock (fn [] ...body...))
# lock is a map created by make-lock
# body is a thunk (fn [])
(defn with-lock [lock thunk]
  (ev/with-lock (lock :lock)
    (thunk)))

# Convenience macro for ergonomic bodies
(defmacro with-lock/do [lock & body]
  ~(with-lock ,lock (fn [] ,;body)))

# re-export table if you want to import-as namespace
(def export-api
  @{:make-lock make-lock
    :with-lock with-lock
    :with-lock/do with-lock/do})
# == end/primitives.janet ==
