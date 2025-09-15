---
# AI Metadata Tags
ai_keywords: [Janet, Common Lisp, comparison, guide, porting, Lisp dialects]
ai_contexts: [development, porting]
ai_relations: [docs/dev-guides/porting-guide-from-slynk.md]
---

# Janet for Common Lisp Developers: A Quick Guide

<!-- AI-IMPORTANCE:level=normal -->
This guide is for developers familiar with Common Lisp (CL) who are new to Janet. It highlights some key similarities and differences to aid in understanding Janet code and porting SLYNK features to SLYNET. This is not a comprehensive Janet tutorial but a focused comparison.

<!-- AI-CONTEXT-START:type=porting -->
## Similarities

*   **Lisp Syntax (S-expressions):** Both use parenthesized prefix notation. Code is data.
*   **Macros:** Both have powerful macro systems for compile-time code generation, though syntax and capabilities differ.
*   **Dynamic Typing (Primarily):** Both are dynamically typed, though CL has more extensive optional type declarations and compile-time type checking.
*   **REPL-Driven Development:** Both excel with interactive development via a Read-Eval-Print Loop.
*   **Functional Programming Features:** Both support first-class functions, closures, and other functional paradigms.

## Key Differences

| Feature                 | Common Lisp (SLYNK Context)                                     | Janet (SLYNET Context)                                                                 | Notes for Porting                                                                                                                               |
| :---------------------- | :-------------------------------------------------------------- | :------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Symbol Case**         | Typically case-insensitive (internally upcased by default)      | Case-sensitive                                                                         | Be mindful of symbol names. `FOO` and `foo` are different in Janet.                                                                             |
| **Packages/Namespaces** | `DEFPACKAGE`, `IN-PACKAGE`, symbol qualification (`package:symbol`) | `defmodule`, `import`. Symbols are typically resolved within modules.                    | Map CL packages to Janet modules. Qualification is different.                                                                                   |
| **Truthiness**          | `NIL` is false, everything else is true.                        | `false` and `nil` are falsey, everything else is truthy.                               | Similar, but Janet has distinct `false` and `nil`. `(if x ...)` works similarly.                                                                |
| **Function Definition** | `DEFUN`, `FLET`, `LABELS`                                       | `defn` (or `def` for anonymous), `fn` (anonymous), `letfn` (local recursive)           | `defn` is most common. Janet's `fn` is more like CL's `LAMBDA`.                                                                                 |
| **Variable Definition** | `DEFVAR`, `DEFPARAMETER`, `LETVAR` (for special vars), `LET`, `LET*` | `def` (global/module scope), `var` (mutable global/module), `let` (lexical)            | `def` for top-level definitions. `var` for mutable top-level. `let` for lexical bindings.                                                       |
| **Special Variables**   | Dynamically scoped variables (e.g., `*standard-output*`)        | Dynamic bindings with `dyn` (`(dyn :my-var 10 (print (dyn :my-var)))`)                   | SLYNK uses special vars. SLYNET might use `dyn` or pass context explicitly.                                                                     |
| **Constants**           | `DEFCONSTANT`                                                   | `def` (by convention, use uppercase for constants, e.g., `(def MY_CONSTANT 42)`)       | No specific `defconstant` in Janet; use `def` and naming convention.                                                                            |
| **Macros**              | `DEFMACRO`, backquote (`\``), comma (`,`), comma-at (`,@`)       | `defmacro`, quasiquote (`~`), unquote (`,`), splice-unquote (`,@`)                      | Similar concepts, but macroexpanders work differently. Janet macros are hygienic by default.                                                    |
| **Object System**       | CLOS (Common Lisp Object System) - `DEFCLASS`, `DEFGENERIC`, `DEFMETHOD` | Prototypes, structs, tables. No built-in CLOS equivalent.                              | SLYNK's use of CLOS will need careful translation to Janet's object/data structuring mechanisms (e.g., using tables with methods, or structs). |
| **Condition System**    | Powerful: `DEFINE-CONDITION`, `SIGNAL`, `HANDLER-CASE`, `RESTART-CASE` | Simpler: `error` (signals), `try`/`catch` (handles). No built-in restarts.           | Error handling logic will need significant adaptation. Focus on `try`/`catch`.                                                                  |
| **Data Structures**     | Lists, vectors, hash tables, arrays, plists, alists.            | Tuples (immutable), arrays (mutable), tables (hash maps), structs (fixed fields), buffers. | Choose appropriate Janet data structures. Janet tables are very versatile.                                                                      |
| **Keywords**            | Symbols starting with `:` (e.g., `:foo`), self-evaluating.      | Keywords starting with `:` (e.g., `:foo`), self-evaluating.                            | Very similar usage.                                                                                                                             |
| **Modules/Build**       | ASDF for system definition.                                     | `jpm` (Janet Package Manager) or manual `import`.                                      | SLYNET might use `jpm` or a simpler module loading approach.                                                                                    |
| **Standard Library**    | Large and comprehensive (ANSI CLHS).                            | Smaller, more focused standard library.                                                | You might need to implement some utilities that are built-in in CL, or find Janet libraries.                                                    |
| **Concurrency**         | Implementation-dependent (threads, etc.). SLYNK uses threads.   | Fibers for lightweight concurrency.                                                    | SLYNK's threading model will map to Janet fibers.                                                                                               |

## Quick Lookup

*   **Looping:** CL's `LOOP` macro is very powerful. Janet has `for`, `while`, `loop`, and functional iteration (`each`, `map`, `filter`).
*   **String Manipulation:** Both have good string functions, but names and arguments will differ.
*   **File I/O:** Similar concepts, different function names.
*   **`nil` vs. `()`:** In CL, `NIL` and `()` are the same. In Janet, `nil` is a distinct value, and `()` is an empty tuple (or list in some contexts).

## Learning More Janet

*   **Official Janet Documentation:** [janet-lang.org/docs](https://janet-lang.org/docs) - The primary resource.
*   **Janet REPL:** Experiment! The best way to learn is by trying things out.
*   **Community:** The Janet community (e.g., forum, Discord) can be helpful.

<!-- AI-CONTEXT-END -->

This guide is intended to bridge the gap. Always refer to official Janet documentation for authoritative information. Happy porting!