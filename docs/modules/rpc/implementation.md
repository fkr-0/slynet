---
# AI Metadata Tags
ai_keywords: [SLYNET, RPC, Janet, implementation, message, encoding, decoding, s-expression, parser, dispatch]
ai_contexts: [implementation, development, porting]
ai_relations: [docs/ai-index/documentation-guide.md, docs/modules/rpc/overview.md, slynet/slynk_janet/rpc.janet]
---

# SLYNET RPC Module Implementation

<!-- AI-IMPORTANCE:level=critical -->
## Message Reading and Writing

The `rpc` module handles the low-level details of reading and writing messages over a stream, adhering to the SLYNK wire protocol.

### `read-message`

The `read-message` function is the primary entry point for consuming incoming RPC packets. It first calls `read-packet` to get the raw byte data, then `process-incoming-message` to parse the S-expression and perform any necessary translations.

```janet
(defn read-message
  "Read a message from STREAM, using PACKAGE for symbol resolution.
   Throws a slynk-reader-error if the message cannot be parsed."
  [stream package]
  (let [packet (read-packet stream)]
    (try
      (process-incoming-message packet)
      ([err fib]
        (error (make-slynk-reader-error packet err))))))
```

### `write-message`

The `write-message` function serializes a Janet data structure into a SLYNK-compatible S-expression and writes it to the stream. It uses `process-outgoing-message` to prepare the message and `write-header` to prefix it with a 6-byte hexadecimal length.

```janet
(defn write-message [message package stream]
  "Write a message to STREAM."
  (let [str (process-outgoing-message message)
        bytes (if (= *current-encoding* "utf-8")
                (backend/string-to-utf8 str)
                (backend/string-to-bytes str))]
    (write-header stream (length bytes))
    (buffer/write stream bytes)))
```

### Packet Handling

- **`read-packet`**: Reads the 6-byte hex length header, then reads the specified number of bytes from the stream. It uses `backend/utf8-to-string` or `backend/bytes-to-string` for conversion based on `*current-encoding*`.
- **`parse-header`**: Extracts the 6-byte hexadecimal length from the stream.
- **`read-chunk`**: Reads a specified number of bytes from the stream.
- **`write-header`**: Formats and writes the 6-byte hexadecimal length prefix for outgoing messages.

<!-- AI-CONTEXT-START:type=implementation -->
## S-expression Parsing and Serialization

The module includes a custom PEG parser for S-expressions and a function for converting Janet data back into Emacs-compatible S-expression strings.

### `parse-string`

This function uses a `peg/compile` grammar to parse a string containing one or more S-expressions into Janet data structures (tuples, arrays, tables, symbols, numbers, strings, booleans, nil). It supports Common Lisp-style comments and various literal types.

```janet
(defn parse-string 
  "Parse a string into a Janet data structure.
   This handles Emacs/Common Lisp style s-expressions."
  [string]
  (def parser (peg/compile ~{
    # ... PEG grammar definition ...
  }))
  (peg/match parser string))
```

### `prin1-to-string-for-emacs`

This function converts a Janet object into a string representation suitable for Emacs's Lisp reader. It handles various Janet types, including `nil`, booleans, numbers, strings (with escaping), symbols, keywords, arrays, tuples, and tables.

```janet
(defn prin1-to-string-for-emacs [obj package]
  "Convert OBJ to a string representation for Emacs."
  (match (type obj)
    :nil "nil"
    :boolean (if obj "t" "nil")
    :number (string obj)
    :string (string "\"" (escape-string obj) "\"")
    :symbol (string obj)
    :keyword (string ":" (string/slice (string obj) 1))
    :array (string "(" (string/join (map |(prin1-to-string-for-emacs $ package) obj) " ") ")")
    :tuple (string "(" (string/join (map |(prin1-to-string-for-emacs $ package) obj) " ") ")")
    :table (table->string obj package)
    (string "#<" (type obj) " " (string obj) ">")))
```

### Message Processing

- **`process-incoming-message`**: Takes a raw message string, parses it using `parse-sexp`, and then applies `encode-special-form` (currently a pass-through) for potential future special form handling.
- **`process-outgoing-message`**: Takes a Janet message, applies `decode-special-form` (currently a pass-through), and then converts it to an Emacs-compatible string using `prin1-to-string-for-emacs`.

## RPC Interface and Implementation Macros

The `rpc` module defines macros for a declarative approach to defining RPC endpoints.

### `slynet-definterface`

This macro declares an RPC interface, registering its name, argument list specification, and documentation string in the `slynet-rpc-interfaces-registry` dynamic variable. This metadata is used for validation and introspection.

```janet
(defmacro slynet-definterface
  "Declares an RPC interface for SLYNET."
  [rpc-name arglist-spec docstring]
  # ... validation and registration logic ...
  ~(put (dyn slynet-rpc-interfaces-registry) (quote ,rpc-name)
     {:name (quote ,rpc-name)
      :arglist-spec ,arglist-spec
      :doc ,docstring}))
```

### `slynet-defimplementation`

This macro defines a Janet function and registers it as the implementation for a declared RPC interface in the `slynet-rpc-implementations-registry` dynamic variable. It also includes a warning if an implementation is defined without a corresponding interface declaration.

```janet
(defmacro slynet-defimplementation
  "Defines the Janet implementation for an RPC interface."
  [rpc-name janet-arglist & body]
  # ... validation and registration logic ...
  ~(do
     (defn ,rpc-name ,janet-arglist ,@body)
     (unless (get (dyn slynet-rpc-interfaces-registry) (quote ,rpc-name))
       (eprintf "Warning: SLYNET RPC implementation for '%s' has no corresponding slynet-definterface declaration (at the time of defining %s)."
                (quote ,rpc-name) (quote ,rpc-name)))
     (put (dyn slynet-rpc-implementations-registry) (quote ,rpc-name) ,rpc-name)))
```

## RPC Dispatch and Utilities

- **`dispatch`**: The core function for executing an RPC call. It retrieves the interface and implementation from their respective registries and calls the implementation with the provided arguments.
- **`get-interface` / `get-implementation`**: Functions to retrieve metadata or the function object for a given RPC name.
- **`list-interfaces` / `list-implementations`**: Functions to list all registered RPC interfaces or implementations.
- **`validate-rpc`**: Checks if an RPC interface has both a declaration and an implementation.

<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=testing_strategies -->
## Testing Strategies

Testing the `rpc` module involves:
- **Serialization/Deserialization:** Unit tests for `read-message`, `write-message`, `parse-string`, and `prin1-to-string-for-emacs` with various valid and invalid S-expressions and data types.
- **RPC Definition and Dispatch:** Testing `slynet-definterface`, `slynet-defimplementation`, and `dispatch` to ensure interfaces are correctly registered and implementations are called with the right arguments.
- **Error Handling:** Verifying that `make-slynk-reader-error` and `make-slynk-protocol-error` are correctly raised for malformed messages or missing RPC definitions.
- **SWANK Translation:** Testing `translate-swank-to-slynk` with various SWANK symbols to ensure correct conversion.
<!-- AI-CONTEXT-END -->
