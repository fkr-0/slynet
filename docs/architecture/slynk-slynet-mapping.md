---
# AI Metadata Tags
ai_keywords: [SLYNET, SLYNK, mapping, porting, architecture, Janet, Common Lisp]
ai_contexts: [architecture, porting]
ai_relations: [docs/architecture/system-overview.md, docs/architecture/message-protocol.md, docs/dev-guides/porting-guide-from-slynk.md]
---

# SLYNK to SLYNET Architecture Mapping

<!-- AI-IMPORTANCE:level=critical -->
This document provides a high-level overview of how core SLYNK (Common Lisp) architectural concepts and components are intended to be mapped or ported to SLYNET (Janet). This is a living document and will be updated as the SLYNET port progresses.

The primary goal is functional parity, meaning SLYNET should offer the same capabilities to an IDE front-end as SLYNK does, but implemented in idiomatic Janet.

<!-- AI-CONTEXT-START:type=architecture -->
## Core SLYNK Components and their SLYNET Equivalents

| SLYNK Component (Common Lisp)        | SLYNET Equivalent (Janet) - Planned/Conceptual                                  | Key Considerations for Porting                                                                                                                               | Relevant SLYNET API (`impl_spec.yml`) |
| :----------------------------------- | :------------------------------------------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------ |
| **RPC Layer (`slynk-rpc.lisp`)**     | `rpc/` module in SLYNET, utilizing Janet's data structures and I/O.             | Message serialization/deserialization (S-expressions), connection handling, request dispatching. Protocol compatibility is key.                              | `read-message`, `write-message`       |
| **Backend Interface (`slynk-backend.lisp`)** | Core SLYNET API, potentially organized into modules within `slynet-api.janet`. | Defining clear interfaces for Janet operations (eval, compile, inspect, etc.) that mirror SLYNK's backend functions.                                   | `definterface`, `defimplementation`   |
| **Main SLYNK Loop (`slynk.lisp`)**   | SLYNET's main server loop, handling client connections and processing requests. | Event-driven architecture, managing multiple client sessions (if applicable), robust error handling.                                                       | `initialize-backend`                  |
| **Evaluation (`*slynk-evaluator*`)** | `evaluation/` module in SLYNET.                                                 | Capturing output, handling conditions/errors, managing evaluation context (e.g., current package/module). Janet's `eval` and related functions.             | (To be defined in `impl_spec.yml`)    |
| **Compilation**                      | `compilation/` module (or part of `evaluation/`).                               | Interfacing with Janet's compiler, reporting compilation diagnostics (errors, warnings).                                                                     | (To be defined in `impl_spec.yml`)    |
| **Completion (`slynk-completion.lisp`)** | `completion/` module.                                                         | Analyzing Janet's environment (modules, bindings) to provide relevant completion candidates. Adapting SLYNK's completion logic.                            | (To be defined in `impl_spec.yml`)    |
| **Debugger**                         | `debugger/` module.                                                             | Interfacing with Janet's debugging capabilities (if any, or implementing hooks). Managing stack frames, breakpoints, stepping. This is often complex.        | (To be defined in `impl_spec.yml`)    |
| **Inspector (`slynk-fancy-inspector.lisp` etc.)** | `inspector/` module.                                                          | Traversing Janet data structures, providing detailed and structured descriptions. Handling different Janet types.                                          | (To be defined in `impl_spec.yml`)    |
| **Source Location (`slynk-source-path-parser.lisp`, XREF)** | `source-location/` module.                                                    | Parsing Janet source files (or using Janet's own tools) to find definitions. Cross-referencing capabilities.                                               | (To be defined in `impl_spec.yml`)    |
| **Package/Namespace Management (`slynk-package-fu.lisp`)** | Module/environment management in SLYNET.                                      | Janet uses modules. Mapping SLYNK's package operations to Janet module operations.                                                                           | (To be defined in `impl_spec.yml`)    |
| **Contrib Modules (e.g., MREPL, Profiler)** | Potentially separate `contrib/` modules in SLYNET, or integrated if core.     | Each contrib needs individual assessment for relevance and porting effort.                                                                                   | (To be defined in `impl_spec.yml`)    |

<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=porting_notes -->
## Key Differences and Challenges

*   **Language Paradigms:** While both are Lisps, Common Lisp and Janet have differences in their standard libraries, object systems (CLOS vs. Janet's prototypes/structs), error handling, and concurrency models. Idiomatic translation is key.
*   **Ecosystem and Libraries:** SLYNK leverages a mature Common Lisp ecosystem. SLYNET will rely on Janet's standard library and potentially a smaller set of third-party Janet libraries.
*   **Debugging Hooks:** Common Lisp often provides more extensive low-level hooks for debuggers than younger languages. Implementing a full-featured debugger in SLYNET might require creative solutions or a more limited scope initially.
*   **Macro Systems:** Differences in macro systems might affect how certain SLYNK utilities or DSLs are ported.

## Guiding Principles for Porting

*   **Understand SLYNK First:** Before writing Janet code, thoroughly understand the purpose and implementation of the SLYNK component being ported.
*   **Idiomatic Janet:** Strive for clean, idiomatic Janet code rather than a direct line-by-line translation from Common Lisp.
*   **Incremental Porting:** Port features incrementally, starting with the core RPC and evaluation mechanisms.
*   **Test Continuously:** Develop tests for SLYNET components to ensure they behave as expected (ideally matching SLYNK's behavior).

<!-- AI-CONTEXT-END -->

This mapping will be refined in more detail within the specific module documentation in `docs/modules/`. Refer to [`docs/dev-guides/porting-guide-from-slynk.md`](docs/dev-guides/porting-guide-from-slynk.md:1) for practical advice on the porting process.