# SLYNK RPC Protocol for Janet
# Translated from slynk-rpc.lisp
# Handles message encoding/decoding and wire protocol.

#
# Configuration
# == slynet/rpc_core.janet ==
# Minimal runtime registrar; safe to call from macros' emitted code.
(import ./print-for-emacs)
(import ./backend :as backend)

# Use backend's register-implementation for all runtime registration


(def *translating-swank-to-slynk* true)
(def *wire-protocol-version* "2021-04-01")

# Supported I/O encodings
(def *io-encodings* {:latin-1 "latin-1" :utf-8 "utf-8"})

# Default to UTF-8 or use environment setting
(def *current-encoding* (or (os/getenv "SLYNK_ENCODING") "utf-8"))
# Helper functions for string conversion
(defn escape-string [str]
  "Escape string for Emacs reader."
  (string/replace-all "\"" "\\\"" str))
#
# Error handling
#

(defn make-slynk-reader-error
  "Create a structured error for reader failures.
   Contains the original packet and the cause of failure."
  [packet cause]
  @{:type :slynk-reader-error
    :packet packet
    :cause cause
    :message (string "Failed to read message: " cause)})

(defn make-slynk-protocol-error
  "Create a structured error for protocol violations.
   Includes details about what was expected vs. received."
  [message expected received]
  @{:type :slynk-protocol-error
    :message message
    :expected expected
    :received received})

#
# Message reading & parsing
#
(defn translate-swank-to-slynk
  "Translate any SWANK symbols to SLYNK symbols.
   Recursively processes all elements in complex data structures."
  [form]
  (match (type form)
    :symbol (let [name (form :name)]
              (if (string/has-prefix? "SWANK" name)
                (symbol (string/replace "SWANK" "SLYNK" name))
                form))
    :tuple (tuple/slice (map translate-swank-to-slynk form))
    :array (map translate-swank-to-slynk form)
    :table (tabseq [[k v] :in (pairs form)]
             (translate-swank-to-slynk k) (translate-swank-to-slynk v))
    # Default case - return as is
    form))


(defn parse-string
  "Parse a string into a Janet data structure.
   This handles Emacs/Common Lisp style s-expressions."
  [string]
  (print "Parsing string: " string) # Debug log
  (def parser (peg/compile ~{# Main parser
                             :main (some :expr)

                             # Whitespace
                             :ws (set " \t\n\r")
                             :comment-to-eol (sequence ";" (any (if-not "\n" 1)))
                             :ignored (choice :ws :comment-to-eol)
                             :sp (any :ignored)

                             # Basic expressions
                             :expr (sequence :sp (choice :nil :t :number :string :keyword :symbol :list :vector :dict) :sp)

                             # Primitives
                             :nil (choice "nil" "NIL")
                             :t (choice "t" "T")
                             :number (choice :integer :float)
                             :integer (cmt (capture (sequence (opt "-") (some (range "09")))) ,scan-number)
                             :float (cmt (capture (sequence (opt "-") (some (range "09")) "." (some (range "09")) (opt (sequence (set "eE") (opt (set "+-")) (some (range "09")))))) ,scan-number)

                             # Strings
                             :string-char (choice (sequence "\\" 1) (if-not "\"" 1))
                             :string (cmt (sequence "\"" (capture (any :string-char)) "\"") ,|(string $))

                             # Keywords and symbols
                             :keyword (cmt (sequence ":" (capture (some (if-not (set " \t\n\r()\"'`;,") 1)))) ,|(keyword $))
                             :symbol-char (if-not (set " \t\n\r()\"'`;,:") 1)
                             :symbol (cmt (capture (some :symbol-char)) ,|
                                          (cond
                                            (= $ "nil") nil
                                            (= $ "NIL") nil
                                            (= $ "t") true
                                            (= $ "T") true
                                            (symbol $)))

                             # Compound types
                             :list (sequence "(" (capture (any :expr)) ")" ,|
                                             (tuple/slice $))
                             :vector (sequence "[" (capture (any :expr)) "]" ,|
                                               (array/slice $))
                             :dict-pair (sequence (choice :keyword :expr) :expr)
                             :dict (sequence "{" (capture (any :dict-pair)) "}" ,|
                                             (let [tbl @{}]
                                               (each [k v] (partition 2 $)
                                                 (put tbl k v))
                                               tbl))}))

  (def result (peg/match parser string))
  (print "Parse result: " result)
  result)

(defn read-form
  "Read a form from PACKET using PACKAGE for symbol resolution.
   Handles SWANK -> SLYNK translation if enabled."
  [packet package]
  (let [form (parse-string packet)]
    # Handle SWANK -> SLYNK translation if needed
    (if *translating-swank-to-slynk*
      (translate-swank-to-slynk form)
      form)))
# (defn scan-number [str base]
#   "Scan a number from STR in the given BASE."
#   (try
#     (parse-int str base)
#     ([err fib]
#       (error (string "Invalid number format: " str " in base " base)))))
(defn- recv-exact [stream n]
  (def out @"")
  (var got 0)
  (while (< got n)
    (def chunk (net/read stream (- n got)))
    (when (or (nil? chunk) (= (length chunk) 0)) (break))
    (buffer/push-string out chunk)
    (set got (+ got (length chunk))))
  out)

(defn parse-header [stream]
  "Read a 6-byte hex length header."
  (let [header-bytes (recv-exact stream 6)]
    (if (= (length header-bytes) 6)
      (scan-number (string header-bytes) 16)
      (error "Invalid header length"))))

(defn read-chunk [stream len]
  "Read LEN bytes from STREAM."
  (recv-exact stream len))
(defn read-packet
  "Read a length-prefixed packet from STREAM.
   A packet consists of a 6-byte hex length followed by that many bytes.
   Returns the packet content as a string."
  [stream]
  (let [len (parse-header stream)
        chunk (read-chunk stream len)]
    (if (= *current-encoding* "utf-8")
      (backend/utf8-to-string chunk)
      # For latin-1 or other encodings, may need different conversion
      (backend/bytes-to-string chunk))))

# Function to encode/decode special Lisp forms
(defn encode-special-form
  "Encode special Common Lisp forms that don't have direct Janet equivalents."
  [form]
  # Examples:
  # (:swank-rpc func params 123) => {:form :swank-rpc :func func :params params :id 123}
  # Others can be added
  # For now, we pass through as-is
  form)
(defn flex-scan-number [s]
  (if (string/find s ".")
    (int/to-number s)
    (scan-number s)))

# Compile PEG parser once
# (def parser
#   (peg/compile
#     ~{# Main parser
#       :main (some :expr)

#       # Whitespace
#       :ws (set " \t\n\r")
#       :comment-to-eol (sequence ";" (any (if-not "\n" 1)))
#       :ignored (choice :ws :comment-to-eol)
#       :sp (any :ws)

#       # Basic expressions
#       :expr (sequence :sp (choice :nil :t :number :string :keyword :symbol :list :vector :dict) :sp)

#       # Primitives
#       :nil (choice "nil" "NIL")
#       :t (choice "t" "T")
#       :number (choice :integer :float)
#       :integer (cmt (capture (sequence (opt "-") (some (range "09")))) ,int/to-number)
#       :float (cmt (capture (sequence (opt "-") (some (range "09")) "." (some (range "09")) (opt (sequence (set "eE") (opt (set "+-")) (some (range "09")))))) ,flex-scan-number)

#       # Strings
#       :string-char (choice (sequence "\\" 1) (if-not "\"" 1))
#       :string (cmt (sequence "\"" (capture (any :string-char)) "\"") ,|(string $))

#       # Keywords and symbols
#       :keyword (cmt (sequence ":" (capture (some (if-not (set " \t\n\r()\"'`;,") 1)))) ,|(keyword $))
#       :symbol-char (if-not (set " \t\n\r()\"'`;,:") 1)
#       :symbol (cmt (capture (some :symbol-char)) ,|
#                    (cond
#                      (= $ "nil") nil
#                      (= $ "NIL") nil
#                      (= $ "t") true
#                      (= $ "T") true
#                      (symbol $)))

#       # Compound types
#       :list (sequence "(" (capture (any :expr)) ")" ,|(tuple/slice $))
#       :vector (sequence "[" (capture (any :expr)) "]" ,|(array/slice $))
#       :dict-pair (sequence (choice :keyword :expr) :expr)
#       :dict (sequence "{" (capture (any :dict-pair)) "}" ,|(let [tbl @{}]
#                                                              (each [k v] (partition 2 $)
#                                                                (put tbl k v))
#                                                              tbl))}))
# == janpeg/src/parser.janet ==
# action helpers ---------------------------------------------------------------
# note: each of these is called by `cmt` with the capture(s).
# keep signatures simple: one arg for (capture ...), a seq for (group ...)

(defn A:int
  "Turn an integer string into a Janet number."
  [s]
  (print "Parsing int: " s) # Debug log
  (scan-number s))

(defn A:float
  "Turn a float/exp string into a Janet number."
  [s]
  (scan-number s)) # ;robust number scanner from stdlib

(defn A:string
  "Return the string contents (capture already assembled by PEG)."
  [s]
  s)

(defn A:keyword
  "Convert \":foo\" (already captured including the leading :) into a keyword."
  [s]
  (keyword s))

(defn A:symbol
  "Map special symbols and otherwise make a symbol."
  [s]
  (cond
    (= s "nil") nil
    (= s "NIL") nil
    (= s "t") true
    (= s "T") true
    :else (symbol s)))

(defn A:tuple
  "Build an immutable tuple from grouped exprs."
  [xs]
  (tuple/slice xs))

(defn A:array
  "Build a mutable array from grouped exprs."
  [xs]
  (array/slice xs))

(defn A:dict
  "Build a table from grouped [k v ...] seq."
  [pairs]
  (let [tbl @{}]
    (each [k v] (partition 2 pairs)
      (put tbl k v))
    tbl))

# grammar ----------------------------------------------------------------------
(def parser
  (peg/compile
    ~{# Main
      :main (some :expr)

      # Whitespace / comments
      :ws (set " \t\r\n")
      :comment-to-eol (sequence ";" (any (if-not "\n" 1)))
      :ignored (choice :ws :comment-to-eol)
      :sp (any :ignored)

      # Expressions
      :expr (sequence :sp (choice :nil :t :number :string :keyword :symbol :list :vector :dict) :sp)

      # Primitives
      :nil (choice "nil" "NIL")
      :t (choice "t" "T")
      :number (choice :float :integer)

      :integer (cmt
                 (capture (sequence (opt "-") (some (range "09"))))
                 ,A:int)

      :float (cmt
               (capture (sequence
                          (opt "-")
                          (some (range "09"))
                          "."
                          (some (range "09"))
                          (opt (sequence (set "eE") (opt (set "+-")) (some (range "09"))))))
               ,A:float)

      # Strings
      # :string-char joins naturally when captured around the whole (any ...)
      :string-char (choice (sequence "\\" 1) (if-not "\"" 1))
      :string (cmt
                (capture (sequence "\"" (any :string-char) "\""))
                ,A:string)

      # Keywords and symbols
      :keyword (cmt
                 (capture (sequence ":" (some (if-not (set " \t\n\r()\"'`;,") 1))))
                 ,A:keyword)

      :symbol-char (if-not (set " \t\n\r()\"'`;,:") 1)
      :symbol (cmt
                (capture (some :symbol-char))
                ,A:symbol)

      # Compound types
      # use (group ...) when you want the *list of subcaptures*, not the raw substring
      :list (cmt (sequence "(" (group (any :expr)) ")") ,A:tuple)
      :vector (cmt (sequence "[" (group (any :expr)) "]") ,A:array)

      :dict-pair (sequence (choice :keyword :expr) :expr)
      :dict (cmt (sequence "{" (group (any :dict-pair)) "}") ,A:dict)}))

# quick smoke tests ------------------------------------------------------------
# (pp (peg/match parser "  (1 2 3)  "))
# (pp (peg/match parser " [\"a\" :b t NIL] "))
# (pp (peg/match parser " { :x 1 :y (2 3) } ; comment"))
# == end/parser.janet ==

(defn parse-string
  "Parse a string into a Janet data structure.
   This handles Emacs/Common Lisp style s-expressions."
  [string]
  (print "Parsing string: " string) # Debug log
  (def result (peg/match parser string))
  (print "Parse result: " result)
  result)

(defn parse-sexp
  "Parse a single s-expression string into a Janet value.
   Specifically designed for SLYNK protocol messages."
  [str]
  (let [result (parse-string str)]
    (let [res (if (and (array? result) (pos? (length result)))
                (first result)
                (error (string "Failed to parse s-expression: " str)))]
      (print "res:")
      (pp res)
      res)))
(defn process-incoming-message
  "Process a raw incoming message, converting it to a Janet-friendly form.
   This decodes the s-expression and translates any special protocol forms."
  [message]
  (print "processing incoming message:")
  (pp message)
  (-> message
      parse-sexp
      encode-special-form))

(defn read-message
  "Read a message from STREAM, using PACKAGE for symbol resolution.
   Throws a slynk-reader-error if the message cannot be parsed."
  [stream package]
  (print "Reading message from stream..." stream)
  (let [packet (read-packet stream)]
    (pp packet) # Debug log
    (try
      (process-incoming-message packet)
      ([err fib]
        (print "Read MSGERR")
        (pp err)
        (error (make-slynk-reader-error packet err))))))
(def prin1-to-string-for-emacs nil)

(defn table->string [table package]
  "Convert a table to a string representation."
  (let [parts @[]]
    (eachp [k v] table
      (array/push parts (string (prin1-to-string-for-emacs k package) " "
                                (prin1-to-string-for-emacs v package))))
    (string "(:" (string/join parts " :") ")")))

# (let [pfsfe (fn [obj package]
#               "Convert OBJ to a string representation for Emacs."
#               (match (type obj)
#                 :nil "nil"
#                 :boolean (if obj "t" "nil")
#                 :number (string obj)
#                 :string (string "\"" (escape-string obj) "\"")
#                 :symbol (string obj)
#                 :keyword (string ":" (string/slice (string obj) 1))
#                 :array (string "(" (string/join (map |(pfsfe $ package) obj) " ") ")")
#                 :tuple (string "(" (string/join (map |(pfsfe $ package) obj) " ") ")")
#                 :table (table->string obj package)
#                 # Default
#                 (string "#<" (type obj) " " (string obj) ">")))]
#   (set prin1-to-string-for-emacs pfsfe))
(defn decode-special-form
  "Decode special Common Lisp forms from Janet structures."
  [form]
  # Inverse of encode-special-form
  form)
(defn process-outgoing-message
  "Process an outgoing message, preparing it for sending over wire.
   This encodes any special forms and ensures the message is properly formatted."
  [message package]
  (print-for-emacs/prin1-to-string-for-emacs
    (-> message
        decode-special-form) package))

(defn write-header [stream len]
  "Write a 6-byte hex length header."
  (net/write stream (string/format "%06x" len)))

(defn write-message [message package stream]
  "Write a message to STREAM."
  (let [str (process-outgoing-message message package)
        bytes (if (= *current-encoding* "utf-8")
                (backend/string-to-utf8 str)
                (backend/string-to-bytes str))]
    (write-header stream (length bytes))
    (net/write stream (string bytes))))

# Channel + remote dispatch ---------------------------------------------------
(var _channel-id-counter 0)
(var _channel-id->object @{})
(var _object->channel-id @{})

(defn register-channel-object [obj]
  (set _channel-id-counter (+ _channel-id-counter 1))
  (put _channel-id->object _channel-id-counter obj)
  (put _object->channel-id obj _channel-id-counter)
  _channel-id-counter)

(defn close-channel [cid]
  (when-let [obj (get _channel-id->object cid)]
    (put _channel-id->object cid nil)
    (put _object->channel-id obj nil))
  true)

(defn find-channel-id-for-object [obj]
  (get _object->channel-id obj))

(defn get-channel-object [cid]
  (get _channel-id->object cid))

# Indirection hooks to avoid circular deps with slynk
# in rpc.janet
(var _send-handler nil)
(var _resolve-conn nil)

(defn set-send-handler [f]
  (def old _send-handler)
  (set _send-handler f)
  old)

(defn set-conn-resolver [f]
  (def old _resolve-conn)
  (set _resolve-conn f)
  old)

(defn send-to-remote [remote-id message]
  # (print "send-to-remote: remote-id=" remote-id " message=" message)
  (def conn (if _resolve-conn (_resolve-conn remote-id) nil))
  # (print "send-to-remote: conn=" conn " message=" message "cond=" (and conn _send-handler))
  # (pp message)
  # (pp table)
  (when (and conn _send-handler)
    # (print "Invoking send handler...")
    (_send-handler conn message)
    true))


(defn parse [string]
  "Parse a string into a Janet data structure."
  (try
    (parse-string string)
    ([err fib]
      (error (string "Error parsing: " string " - " err)))))

# Protocol constants
(def *protocol-version* "2021-04-01")
(def *protocol-features* @[:encoding-length-in-bytes])
# Export public API
(def export-api
  @{:read-message read-message
    :write-message write-message
    :register-channel-object register-channel-object
    :find-channel-id-for-object find-channel-id-for-object
    :get-channel-object get-channel-object
    :close-channel close-channel
    :send-to-remote send-to-remote
    :set-send-handler set-send-handler
    :set-conn-resolver set-conn-resolver
    :send-handler _send-handler
    :conn-resolver _resolve-conn
    :*translating-swank-to-slynk* *translating-swank-to-slynk*
    :*wire-protocol-version* *wire-protocol-version*
    :*protocol-features* *protocol-features*})

(put export-api :make-slynk-reader-error make-slynk-reader-error)
(put export-api :make-slynk-protocol-error make-slynk-protocol-error)
(comment "SLYNET RPC Definition and Registration
This file provides the core mechanisms for defining and registering
SLYNET RPC (Remote Procedure Call) endpoints.")

# Global, mutable registries for RPC interfaces and their implementations.
# Using defdyn to allow them to be reset/re-initialized by init.janet,
# and to be accessible across modules that load/import this one.

# == slynet/rpc.janet ==
# Compile-time registries (macros can mutate these during expansion)
# == slynet/rpc.janet ==
# 1) Compile-time registries (macros can mutate these during expansion)
# Already defined above near the top of this file.

# 2) Runtime dynamic mirrors (NO defdyn; use setdyn/dyn with a keyword key)


# Removed defimplementation macro; use plain functions and backend/register-implementation.

# Call this at module init if you actually use the dynamic mirrors at runtime:
# (slynet-sync-rpc-registries!)
# == end/rpc.janet ==
# RPC utility functions

# == slynet/rpc_macros.janet ==
# compile-time registries must be defined/required BEFORE importing this file:
# (def *slynet-rpc-implementations-registry* @{})

# Runtime registrar used in expansion (no module leaks)


# == slynet/contrib/slynet-arglists.janet ==
# Replace your macro with this version

# == slynet/contrib/slynet-arglists.janet ==
# Replace your macro with this version (no `bound?`, no compile-time registry writes)

# == slynet/contrib/slynet-arglists.janet ==
# Replace your slynet-defimplementation with this version (no hard ref to registrar)

(import ./infrastructure :as inf)
(defn dispatch
  "Dispatch an RPC call to the appropriate implementation.

  rpc-name - the symbol identifying the RPC endpoint
  args - a tuple or array of arguments to pass to the implementation

  Throws an error if the RPC endpoint doesn't exist or if there's
  a mismatch between the provided arguments and the expected signature."
  [rpc-name args]
  (def interface (inf/get-interface rpc-name))
  (def implementation (inf/get-implementation rpc-name))

  # Check if the RPC endpoint exists
  (unless interface
    (error (string "Unknown RPC interface: " rpc-name)))

  (unless implementation
    (error (string "No implementation for RPC: " rpc-name)))

  # In a more advanced system, we might validate args against the interface spec here

  # Call the implementation with the provided arguments
  (match (type args)
    :tuple (implementation ;args)
    :array (implementation ;args)
    # Handle non-tuple/non-array args by wrapping in tuple
    (implementation args)))

(defn validate-rpc
  "Validate that an RPC interface and implementation match.
  Returns a tuple of [valid reason] where valid is a boolean
  and reason is a string explaining any validation failures."
  [rpc-name]
  (def interface (inf/get-interface rpc-name))
  (def implementation (inf/get-implementation rpc-name))

  (cond
    (nil? interface) [false (string "Missing interface declaration for " rpc-name)]
    (nil? implementation) [false (string "Missing implementation for " rpc-name)]
    # Additional validation could be added here in the future
    [true "Valid"]))

# Update export API to include the new RPC functionality
(put export-api :dispatch dispatch)
(put export-api :validate-rpc validate-rpc)

# S-expression parsing and encoding for SLYNK protocol



# Special message types for SLYNK protocol
(def *message-types*
  {:emacs-rex {:id 1 :doc "Emacs Remote EXecute - Request from Emacs to execute code"}
   :return {:id 2 :doc "Return value from a previous request"}
   :debug {:id 3 :doc "Debug information"}
   :debug-activate {:id 4 :doc "Activate debugger"}
   :debug-return {:id 5 :doc "Return from debugger"}
   :channel-send {:id 6 :doc "Send data on a channel"}
   :channel-close {:id 7 :doc "Close a channel"}
   :emacs-channel-send {:id 8 :doc "Emacs sending data on a channel"}
   :presentation-start {:id 9 :doc "Start of a presentation"}
   :presentation-end {:id 10 :doc "End of a presentation"}
   :new-package {:id 11 :doc "Change current package"}
   :slynk-disconnect {:id 12 :doc "Disconnect notification"}
   :read-string {:id 13 :doc "Read string request"}
   :read-aborted {:id 14 :doc "Read aborted"}
   :y-or-n-p {:id 15 :doc "Yes or no question"}
   :indentation-update {:id 16 :doc "Update indentation information"}})

(defn create-emacs-rex-message
  "Create a :emacs-rex message to send to Emacs."
  [form package thread id]
  [:emacs-rex form package thread id])

(defn create-return-message
  "Create a :return message to send to Emacs."
  [value id]
  [:return [:ok value] id])

(defn create-return-error-message
  "Create a :return message with an error to send to Emacs."
  [condition id]
  [:return [:abort condition] id])

# Update export API with the new functions
(put export-api :parse-sexp parse-sexp)

(put export-api :process-incoming-message process-incoming-message)
(put export-api :process-outgoing-message process-outgoing-message)
(put export-api :create-emacs-rex-message create-emacs-rex-message)
(put export-api :create-return-message create-return-message)
(put export-api :create-return-error-message create-return-error-message)
(put export-api :*message-types* *message-types*)
