---
# AI Metadata Tags
ai_keywords: [SLYNET, backend, SLYNK, Janet, interface, implementation, core, overview]
ai_contexts: [architecture, implementation, porting]
ai_relations: [docs/ai-index/documentation-guide.md, docs/modules/rpc/overview.md, slynet/slynk_janet/backend.janet, slynet/slynk_janet/slynk-backend.janet, impl_spec.yml]
---

# SLYNET Backend Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Purpose and Core Functionality

The `slynk-backend` module in SLYNET provides the foundational interface for interacting with the Janet runtime, mirroring the role of `slynk-backend.lisp` in Common Lisp SLYNK. It defines a set of generic functions (interfaces) that represent core SLYNK operations, and a mechanism for registering specific Janet implementations for these interfaces. This modular design allows for flexible and extensible backend functionality.

The module handles:
- Definition of backend interfaces using `definterface`.
- Registration of implementations for these interfaces using `defimplementation`.
- Basic utility functions for string encoding/decoding (UTF-8), process management, and directory manipulation.
- Core evaluation and introspection capabilities for the Janet environment.

<!-- AI-CONTEXT-START:type=porting_notes -->
## SLYNK Equivalent and Key Differences

The `slynk-backend` module is a direct port of the Common Lisp `slynk-backend.lisp`. The core concepts of defining generic interfaces and providing specific implementations remain the same.

Key differences in the Janet port include:
- **Macro-based Interface/Implementation:** `definterface` and `defimplementation` are implemented as Janet macros, leveraging Janet's powerful macro system to define and register functions dynamically.
- **Dynamic Variables for Registries:** Instead of Common Lisp's package system for managing generic functions, Janet uses dynamic variables (`def *interface-functions*`, `def *implementations*`) to store interface metadata and implementation functions.
- **Error Handling:** Janet's `try-catch` mechanism is used for robust error handling within implementations.
- **UTF-8 Handling:** Janet's native buffer and string functions are utilized for efficient UTF-8 encoding and decoding, simplifying the byte manipulation compared to Common Lisp.
- **MOP (Metaobject Protocol):** Common Lisp's MOP concepts (like `find-symbol2`, `import-to-slynk-mop`) are conceptually mapped or simplified in Janet, as Janet does not have a direct equivalent. These functions are either stubbed or adapted to Janet's environment introspection capabilities.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=architecture -->
## Relevant SLYNET API Points (from `impl_spec.yml`)

The `slynk-backend` module directly implements or provides the mechanisms for:
- [`initialize-backend`](impl_spec.yml:2): Corresponds to the `initialize` function in `backend.janet`, which sets up the backend environment.
- [`definterface`](impl_spec.yml:14): The macro for defining new backend interfaces.
- [`defimplementation`](impl_spec.yml:23): The macro for registering implementations for defined interfaces.
- [`string-to-utf8`](impl_spec.yml:31) / [`utf8-to-string`](impl_spec.yml:38): Handled by `backend/string-to-utf8` and `backend/utf8-to-string` respectively.
- Other interfaces like `make-lock`, `default-directory`, `eval-in-context`, `describe-symbol`, `arglist`, etc., are defined as interfaces and have corresponding implementations within `backend.janet`.
<!-- AI-CONTEXT-END -->

## Relationships to Other SLYNET Modules

- **`rpc` module:** The `slynk-backend` module provides the fundamental evaluation and introspection capabilities that the `rpc` module uses to execute commands and retrieve information from the Janet environment.
- **`gray` module:** Utilized for stream I/O implementations (e.g., `make-output-stream`, `make-input-stream`).
- **`slynet-api`:** The `backend.janet` module imports `slynet-api` for core definitions.
