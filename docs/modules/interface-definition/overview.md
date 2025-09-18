---
# AI Metadata Tags
ai_keywords: [SLYNET, interface, implementation, definterface, defimplementation, backend, overview]
ai_contexts: [architecture, implementation, porting]
ai_relations: [docs/ai-index/documentation-guide.md, docs/modules/slynk-backend/overview.md, impl_spec.yml]
---

# SLYNET Interface Definition Module Overview

<!-- AI-IMPORTANCE:level=critical -->
## Purpose and Core Functionality

The `interface-definition` module in SLYNET provides the macros and mechanisms for defining generic interfaces and registering their implementations. This system enables modular, extensible backend functionality and mirrors the generic function system of SLYNK in Common Lisp.

Key responsibilities:
- **Interface Definition:** Allows developers to declare backend interfaces with argument lists and documentation.
- **Implementation Registration:** Enables associating Janet functions with declared interfaces.
- **Dynamic Dispatch:** Provides runtime selection of the correct implementation for a given interface call.

<!-- AI-CONTEXT-START:type=porting_notes -->
## SLYNK Equivalent and Key Differences

This module is a direct port of SLYNK's generic function and implementation registration system. In Janet, macros (`definterface`, `defimplementation`) and dynamic variables are used to manage interface metadata and dispatch logic, replacing Common Lisp's package and MOP mechanisms.

<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=architecture -->
## Relevant SLYNET API Points (from `impl_spec.yml`)

- [`definterface`](impl_spec.yml:14): Macro to define a backend interface.
- [`defimplementation`](impl_spec.yml:23): Macro to register an implementation for an interface.

<!-- AI-CONTEXT-END -->

## Relationships to Other SLYNET Modules

- **`slynk-backend` module:** Uses the interface/implementation system to define and provide core backend functionality.
- **`rpc` module:** May leverage interface definitions for RPC endpoint registration and dispatch.