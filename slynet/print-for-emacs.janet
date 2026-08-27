# == slynet/print-for-emacs.janet ==
# Sturdy Elisp-readable printer for SLY/Emacs interop.

# Tunables --------------------------------------------------------------

(def *pfe-max-depth* 6) # max nested levels before eliding
(def *pfe-max-items* 80) # max items per seq/table before " ..."

# Utilities -------------------------------------------------------------

(defn pfe-escape-string
  "Escape a Janet string so that Emacs Lisp `read` can parse it."
  [s]
  (def out @"")
  (loop [i :range [0 (length s)]]
    (def ch (s i))
    (case ch
      34 (buffer/push-string out "\\\"") # "
      92 (buffer/push-string out "\\\\") # \
      10 (buffer/push-string out "\\n") # newline
      13 (buffer/push-string out "\\r") # carriage return
      9 (buffer/push-string out "\\t") # tab
      (buffer/push out ch)))
  (string out))

(defn pfe-safe-symbol
  "Return an Elisp-readable symbol representation for Janet symbols/keywords."
  [name-str]
  name-str)

(defn pfe-type-tag [x]
  # Opaque markers must themselves be valid Elisp reader input.
  (string "\"#<" (type x) ">\""))

(defn pfe-circular []
  "\"#<circular>\"")

# Core printer ----------------------------------------------------------

(defn prin1-to-string-for-emacs
  "Elisp-readable printer with strict depth and collection-length limits.
   `package` is accepted for future pkg-aware printing; currently unused."
  [obj package &opt state]
  (default state @{:depth 0
                   :max-depth *pfe-max-depth*
                   :max-items *pfe-max-items*})

  (when (= "1" (os/getenv "SLYNET_TEST_VERBOSE"))
    (print "prin1-to-string-for-emacs:")
    (print "prin1-to-string-for-emacs package:" package)
    (pp package)
    (print "prin1-to-string-for-emacs state:" state)
    (pp state)
    (print "prin1-to-string-for-emacs called with obj:" obj)
    (pp obj)
    (print "========================="))
  (def depth (state :depth))

  # The depth bound is also the cycle guard. Janet hashes container keys
  # structurally, so a `seen` table keyed by arbitrary debugger containers can
  # fail merely while computing a hash. Ordinary bounded recursion is safer.
  (if (>= depth (state :max-depth))
    "\"#<...>\""
    (match (type obj)
      :nil "nil"
      :boolean (if obj "t" "nil")
      :number (string obj)
      :string (string "\"" (pfe-escape-string obj) "\"")
      :symbol (pfe-safe-symbol (string obj))
      :keyword (string obj)

      :array
      (do
        (def acc @[])
        (def max-items (state :max-items))
        (def limit (min (length obj) max-items))
        (for i 0 limit
          (array/push acc
                      (prin1-to-string-for-emacs
                        (obj i) package
                        (merge state @{:depth (+ depth 1)}))))
        (when (> (length obj) max-items)
          (array/push acc "..."))
        (string "(" (string/join acc " ") ")"))

      :tuple
      (do
        (def acc @[])
        (def max-items (state :max-items))
        (def limit (min (length obj) max-items))
        (for i 0 limit
          (array/push acc
                      (prin1-to-string-for-emacs
                        (obj i) package
                        (merge state @{:depth (+ depth 1)}))))
        (when (> (length obj) max-items)
          (array/push acc "..."))
        (string "(" (string/join acc " ") ")"))

      :table
      (do
        (var all-plist-keys? true)
        (eachp [k _] obj
          (unless (or (keyword? k)
                      (symbol? k)
                      (and (string? k)
                           (> (length k) 0)
                           (= (string k 0) (string ":" 0))))
            (set all-plist-keys? false)))
        (def max-items (state :max-items))
        (if all-plist-keys?
          (do
            (def parts @[])
            (var n 0)
            (eachp [k v] obj
              (when (< n max-items)
                (def kk (if (keyword? k)
                          (string k)
                          (if (symbol? k)
                            (string ":" (pfe-safe-symbol (string k)))
                            (string k))))
                (def vv (prin1-to-string-for-emacs
                          v package (merge state @{:depth (+ depth 1)})))
                (array/push parts (string kk " " vv)))
              (++ n))
            (when (> n max-items)
              (array/push parts "..."))
            (string "(" (string/join parts " :") ")"))
          (do
            (def pairs @[])
            (var n 0)
            (eachp [k v] obj
              (when (< n max-items)
                (def ks (prin1-to-string-for-emacs
                          k package (merge state @{:depth (+ depth 1)})))
                (def vs (prin1-to-string-for-emacs
                          v package (merge state @{:depth (+ depth 1)})))
                (array/push pairs (string "(" ks " . " vs ")")))
              (++ n))
            (when (> n max-items)
              (array/push pairs "..."))
            (string "(" (string/join pairs " ") ")"))))

      :fiber (pfe-type-tag obj)
      :function (pfe-type-tag obj)
      :cfunction (pfe-type-tag obj)
      :buffer (string "\"#<buffer " (length obj) " bytes>\"")
      :abstract (pfe-type-tag obj)
      :nan "0.0e+NaN"
      :infinity "1.0e+INF"
      :neg-infinity "-1.0e+INF"
      (pfe-type-tag obj))))

# Convenience: print tables as plist/alist as described above
(defn table->string [t package]
  (prin1-to-string-for-emacs t package))

# == end/print-for-emacs.janet ==

(def export-api
  @{:table->string table->string
    :prin1-to-string-for-emacs prin1-to-string-for-emacs})
