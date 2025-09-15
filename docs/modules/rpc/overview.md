---
# AI Metadata Tags
ai_keywords: [SLYNET, RPC, SLYNK, Janet, protocol, message, encoding, decoding, overview]
ai_contexts: [architecture, implementation, porting]
ai_relations: [docs/ai-index/documentation-guide.md, docs/modules/slynk-backend/overview.md, slynet/slynk_janet/rpc.janet, impl_spec.yml]
---

# SLYNET RPC Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Purpose and Core Functionality

The `rpc` module in SLYNET is responsible for handling the Remote Procedure Call (RPC) protocol, which facilitates communication between the SLYNET backend (Janet) and the SLYNK client (Emacs). It is a direct port of the `slynk-rpc.lisp` functionality, focusing on message encoding, decoding, and dispatching RPC requests.

The module provides:
- **Message Serialization/Deserialization:** Functions to read and write length-prefixed messages over a stream, handling UTF-8 encoding.
- **S-expression Parsing:** A PEG (Parsing Expression Grammar) based parser for converting incoming S-expressions (from Emacs) into Janet data structures.
- **RPC Interface Definition:** Macros (`slynet-definterface`) to declare RPC endpoints and their expected arguments.
- **RPC Implementation Registration:** Macros (`slynet-defimplementation`) to associate Janet functions with declared RPC interfaces.
- **RPC Dispatch:** A mechanism to call the appropriate Janet function based on an incoming RPC request.
- **SWANK to SLYNK Translation:** A compatibility layer to translate legacy SWANK symbols to SLYNK symbols.

<!-- AI-CONTEXT-START:type=porting_notes -->
## SLYNK Equivalent and Key Differences

The `rpc` module is a direct port of the Common Lisp `slynk-rpc.lisp`. The fundamental wire protocol and message structure are preserved.

Key differences in the Janet port include:
- **PEG Parser:** Janet utilizes a PEG grammar for robust S-expression parsing, offering a clear and maintainable way to handle the incoming message format.
- **Dynamic Registries:** Similar to the `slynk-backend` module, dynamic variables (`slynet-rpc-interfaces-registry`, `slynet-rpc-implementations-registry`) are used to manage RPC interfaces and their implementations.
- **Macro-based RPC Definition:** `slynet-definterface` and `slynet-defimplementation` are Janet macros that define and register RPC endpoints, providing a declarative way to expose Janet functions as RPC services.
- **UTF-8 Handling:** Leverages Janet's built-in string and buffer manipulation for efficient UTF-8 encoding and decoding.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=architecture -->
## Relevant SLYNET API Points (from `impl_spec.yml`)

The `rpc` module directly implements or provides the mechanisms for:
- [`initialize-rpc`](impl_spec.yml:8): While not an explicit function, the RPC system is initialized by the loading of the `rpc.janet` module and the use of `slynet-definterface` and `slynet-defimplementation` to populate the registries.
- [`read-message`](impl_spec.yml:31): Implemented by the `read-message` function, which handles packet reading, parsing, and translation.
- [`write-message`](impl_spec.yml:38): Implemented by the `write-message` function, which handles message processing, encoding, and writing to the stream.
<!-- AI-CONTEXT-END -->

## Relationships to Other SLYNET Modules

- **`slynk-backend` module:** The `rpc` module relies on the `slynk-backend` module for fundamental string encoding/decoding utilities (`string-to-utf8`, `utf8-to-string`) and potentially for evaluating code in specific contexts.
- **`slynet-api`:** The `rpc.janet` module imports `slynet-api` for core definitions.
