# slynk-backend.janet --- SLYNK backend interface.
# 
# This file is a compatibility layer for code that might expect
# the original backend module naming. It imports and re-exports
# the backend.janet functionality.

(import ./backend)
(import ./primitives)

# Re-export all backend functionality
(def *debug-slynk-backend* backend/*debug-slynk-backend*)
(def warn-unimplemented-interfaces backend/warn-unimplemented-interfaces)
(def string-to-utf8 backend/string-to-utf8)
(def utf8-to-string backend/utf8-to-string)
(def string-to-bytes backend/string-to-bytes)
(def bytes-to-string backend/bytes-to-string)
(def make-lock primitives/make-lock)
(def getpid os/getpid)
(def default-directory backend/default-directory)
(def set-default-directory backend/set-default-directory)

(defn find-symbol2
  "Find a symbol in the current environment or a specific module."
  [name]
  # Janet's symbol resolution is different from Common Lisp
  # This function attempts to find a symbol by name in the environment
  (try
    (eval (symbol name))
    ([_ fib]
      nil)))

(defn arglist [fn-symbol]
  "Get the argument list for a function symbol (conceptual)."
  # Janet does not have a direct equivalent of Common Lisp's arglists.
  # This would require introspection or metadata on functions.
  (printf "Getting arglist for %s (conceptual)" fn-symbol)
  nil)
(def arglist backend/arglist)
(def arglist-structured backend/arglist-structured) # optional

(defn import-to-slynk-mop
  "Import symbols into a SLYNK-MOP module (conceptual)."
  [symbol-list]
  # Janet doesn't have a direct equivalent of CL's MOP or import into a specific package in the same way.
  # This would likely involve managing tables or environments.
  (printf "Importing to SLYNK-MOP (conceptual): %s" symbol-list))

(defn import-slynk-mop-symbols
  "Import MOP symbols from a conceptual package to SLYNK-MOP."
  [package except]
  (printf "Importing SLYNK-MOP symbols from %s, except %s" package except))

# (definterface gray-package-name
#   []
#   "Return a package-name that contains the Gray stream symbols."
#   nil)

# Utilities

(comment
  "Janet's destructuring is powerful. `with-struct` might be replaced by direct destructuring in `let` or function arguments.")

(defmacro when-let
  "Bind var to value and execute body if value is not nil or false."
  [[var value] & body]
  ~(let [v value]
     (when v
       (with-dyns [var v]
         (do ;body)))))

(defn boolean-to-feature-expression
  "Convert a boolean to a feature expression (conceptual)."
  [value]
  # Janet doesn't have a direct equivalent of CL's feature expressions in this manner.
  value)

(defn with-symbol
  "Check if a symbol with a given NAME exists in a conceptual package."
  [name package]
  # In Janet, this might involve checking if a symbol is bound or if a key exists in a module table.
  (printf "Checking for symbol %s in package %s (conceptual)" name package)
  (if (dyn package) (not (nil? (get (dyn package) name))) false))

(defn choose-symbol
  "Choose a symbol based on availability (conceptual)."
  [package name alt-package alt-name]
  (if (with-symbol name package)
    (symbol (string package "/" name)) # Conceptual representation
    (symbol (string alt-package "/" alt-name))))

# UTF-8

(def octet
  "An unsigned 8-bit byte."
  # Janet bytes are already unsigned 8-bit.
  :int)

(def octets
  "A buffer of octets."
  :buffer)

(defn << [x n] (blshift x n))

(defn utf8-decode-aux
  "Helper function. Decode the next N bytes starting from INDEX.
  Return the decoded char and the new index."
  [buffer index limit byte0 n]
  (unless (<= (+ index n) limit)
    (error "not enough bytes for UTF-8 sequence"))
  (var char-code byte0)
  (for i 1 n
    (set char-code (<< char-code 6))
    (set char-code (|char-code (and 0x3F (buffer (+ index i))))))
  (string/from-bytes char-code)) # Simplified, assumes single codepoint

(defn bit-xor [a b]
  (bxor a b))

(defn utf8-decode
  "Decode one character in BUFFER starting at INDEX.
  Return 2 values: the character and the new index.
  If there aren't enough bytes between INDEX and LIMIT return nil."
  [buffer index limit]
  (unless (< index limit) (error "index out of bounds"))
  (let [byte0 (buffer index)]
    (cond
      (< byte0 0x80) # 1-byte sequence (ASCII)
      [(string/from-bytes (buffer/slice buffer index (+ index 1))) (+ index 1)]
      (< byte0 0xC2) (error "invalid UTF-8 start byte") # Overlong 0xxxxxxx or 10xxxxxx
      (< byte0 0xE0) # 2-byte sequence
      (let [char (utf8-decode-aux buffer index limit (bit-xor byte0 0xC0) 1)]
        [char (+ index 2)])
      (< byte0 0xF0) # 3-byte sequence
      (let [char (utf8-decode-aux buffer index limit (bit-xor byte0 0xE0) 2)]
        [char (+ index 3)])
      (< byte0 0xF5) # 4-byte sequence
      (let [char (utf8-decode-aux buffer index limit (bit-xor byte0 0xF0) 3)]
        [char (+ index 4)])
      (error "invalid UTF-8 start byte"))))

(defn utf8-decode-string
  "Decode characters from BUFFER and write them to STRING.
  Return 2 values: LASTINDEX and LASTSTART where"
  [buffer index limit]
  (let [out @""]
    (var current-index index)
    (while (< current-index limit)
      (let [[char next-index] (utf8-decode buffer current-index limit)]
        (buffer/push-string out char)
        (set current-index next-index)))
    [current-index out]))


(defn string-to-utf8
  "Convert a string to a UTF-8 encoded buffer."
  [str]
  (buffer/format @"" "%s" str)) # Janet's string to buffer conversion is UTF-8 by default.
(defn utf8-to-string
  "Convert a UTF-8 encoded buffer to a string."
  [buf]
  (string/from-bytes buf)) # Janet's buffer to string conversion assumes UTF-8.

(comment "Ensure all interface functions are defined before warning.")
(warn-unimplemented-interfaces)
