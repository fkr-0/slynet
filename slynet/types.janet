#! A *minimal* CL-style `deftype` for Janet ─ sufficient for
#!     (deftype octet  [0 255])
#!     (deftype octets [octet])
#! Nothing more is implemented.

### helpers -------------------------------------------------------------

(defn %all? [iter pred]
  (var ok true)
  (each x iter
    (unless (pred x)
      (set ok false)
      (break)))
  ok)

### the macro -----------------------------------------------------------

(defmacro deftype
  "Very small subset of CL’s `deftype`.
   * `[lo hi]`  → numeric range subtype of integer
   * `[sym]`    → sequence-of previously declared subtype
   Expands to a single predicate called NAME? ."
  [name spec]
  (assert (array? spec) "deftype: spec must be an array")
  (var pred-sym (symbol (string name "?")))

  (cond
    #---------------- range subtype ------------------------------------
    (= (length spec) 2)
    (let [[lo hi] spec]
      ~(defn ,pred-sym [x]
         (and (int? x) (>= x ,lo) (<= x ,hi))))

    #---------------- sequence-of subtype ------------------------------
    (= (length spec) 1)
    (let [inner (in spec 0)
          inner-pred (symbol (string inner "?"))]
      ~(defn ,pred-sym [xs]
         (and (lengthable? xs) (%all? xs ,inner-pred))))

    #-------------------------------------------------------------------
    true
    (error (string "deftype: unsupported specification " spec))))

### concrete types ------------------------------------------------------

## 0–255 unsigned byte
(deftype octet  @[0 255])

## any iterable (buffer, array, string, …) whose elements are octets
(deftype octets @[octet])
