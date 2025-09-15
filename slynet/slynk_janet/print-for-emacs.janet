# == slynet/slynk_janet/print-for-emacs.janet ==
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
  (string "#<" (type x) ">"))

(defn pfe-circular []
  "#<circular>")

# Core printer ----------------------------------------------------------

(defn prin1-to-string-for-emacs
  "Elisp-readable printer with depth/length limits and cycle protection.
   `package` is accepted for future pkg-aware printing; currently unused."
  [obj package &opt state]
  (default state @{:depth 0
                   :seen (table)
                   :max-depth *pfe-max-depth*
                   :max-items *pfe-max-items*})

  (print "prin1-to-string-for-emacs:")
  (print "prin1-to-string-for-emacs package:" package)
  (pp package)
  (print "prin1-to-string-for-emacs state:" state)
  (pp state)
  (print "prin1-to-string-for-emacs called with obj:" obj)
  (pp obj)
  (print "=========================")
  (def depth (state :depth))
  (def seen (state :seen))

  # Elide when exceeding depth
  (when (>= depth (state :max-depth))
    (return "#<…>"))

  # Container cycle detection: only for reference types
  (def ref-type? (or (array? obj) (tuple? obj) (table? obj) (buffer? obj)))
  (when (and ref-type? (get seen obj))
    (return (pfe-circular)))
  (when ref-type?
    (put seen obj true))

  (match (type obj)
    :nil "nil"
    :boolean (if obj "t" "nil")
    :number (string obj) # Janet prints ints/floats readably for Elisp
    :string (string "\"" (pfe-escape-string obj) "\"")
    :symbol (pfe-safe-symbol (string obj))
    :keyword (do
               # `string obj` is already like ":foo"; keep it readable.
               (string obj))

    :array (do
             (var acc @[])
             (var i 0)
             (each x obj
               (if (>= i (state :max-items))
                 (do (array/push acc "...") (return (string "(" (string/join acc " ") ")")))
                 (do
                   (array/push acc (prin1-to-string-for-emacs
                                     x package
                                     (merge state @{:depth (+ depth 1)})))
                   (++ i))))
             (string "(" (string/join acc " ") ")"))

    :tuple (do
             (var acc @[])
             (var i 0)
             (each x (tuple/slice obj 0 (length obj))
               (if (>= i (state :max-items))
                 (do (array/push acc "...") (return (string "(" (string/join acc " ") ")")))
                 (do
                   (array/push acc (prin1-to-string-for-emacs
                                     x package
                                     (merge state @{:depth (+ depth 1)})))
                   (++ i))))
             (string "(" (string/join acc " ") ")"))

    :table
    (do
      # If all keys are keywords/symbols/strings that look like keywords,
      # emit a plist: (:k v :k2 v2). Otherwise emit an alist: ((k . v)...)
      (var ok true)
      (eachp [k _] obj
        (unless (or (keyword? k)
                    (symbol? k)
                    (and (string? k)
                         (and (> (length k) 0) (= (string k 0) (string ":" 0)))))
          (set ok false)
          (return nil)))
      (var all-plist-keys? ok)

      (if all-plist-keys?
        # plist
        (do
          (var parts @[])
          (var n 0)
          (eachp [k v] obj
            (if (>= n (state :max-items))
              (do (array/push parts "...") (return (string "(" (string/join parts " :") ")")))
              (do
                (var kk (if (keyword? k)
                          (string k)
                          (if (symbol? k)
                            (string ":" (pfe-safe-symbol (string k)))
                            (string k)))) # assume string already has leading ":"
                (var vv (prin1-to-string-for-emacs v package
                                                   (merge state @{:depth (+ depth 1)})))
                (array/push parts (string kk " " vv))
                (++ n))))
          (string "(" (string/join parts " :") ")"))

        # alist
        (do
          (var pairs @[])
          (var n 0)
          (eachp [k v] obj
            (if (>= n (state :max-items))
              (do (array/push pairs "...") (return (string "(" (string/join pairs " ") ")")))
              (do
                (var ks (prin1-to-string-for-emacs k package
                                                   (merge state @{:depth (+ depth 1)})))
                (var vs (prin1-to-string-for-emacs v package
                                                   (merge state @{:depth (+ depth 1)})))
                (array/push pairs (string "(" ks " . " vs ")"))
                (++ n))))
          (string "(" (string/join pairs " ") ")"))))

    :fiber (pfe-type-tag obj)
    :function (pfe-type-tag obj)
    :cfunction (pfe-type-tag obj)
    :buffer (string "#<buffer " (length obj) " bytes>")
    :abstract (pfe-type-tag obj)
    :nan "0.0e+NaN" # Elisp prints/reads NaN as such
    :infinity "1.0e+INF"
    :neg-infinity "-1.0e+INF"
    # default
    (pfe-type-tag obj)))
# Convenience: print tables as plist/alist as described above
(defn table->string [t package]
  (prin1-to-string-for-emacs t package))

# == end/print-for-emacs.janet ==

(def export-api
  @{:table->string table->string
    :prin1-to-string-for-emacs prin1-to-string-for-emacs})
