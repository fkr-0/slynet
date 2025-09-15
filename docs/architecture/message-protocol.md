---
# AI Metadata Tags
ai_keywords: [SLYNET, message protocol, RPC, communication, SLYNK, Janet, API]
ai_contexts: [architecture, implementation]
ai_relations: [docs/architecture/system-overview.md, docs/architecture/slynk-slynet-mapping.md, impl_spec.yml]
---

# SLYNET Message Protocol

<!-- AI-IMPORTANCE:level=high -->
This document outlines the message-based RPC (Remote Procedure Call) protocol used for communication between an IDE front-end and the SLYNET backend. SLYNET aims for compatibility with the SLYNK protocol where feasible, adapting it for Janet.

The core SLYNET API functions for handling messages are `read-message` and `write-message`, as defined in `impl_spec.yml`.

<!-- AI-CONTEXT-START:type=architecture -->
## Protocol Overview

*   **Transport:** Typically TCP/IP sockets, though the protocol itself is transport-agnostic.
*   **Serialization:** Messages are serialized as S-expressions (Lisp-readable data). In SLYNET, this will be Janet-compatible S-expressions.
*   **Message Structure:** Each message is a list. The first element of the list is a keyword or symbol identifying the message type or command. Subsequent elements are arguments or payload.
*   **Communication Style:** Asynchronous. The IDE sends requests, and SLYNET processes them, sending back responses or events. Multiple requests can be in flight.

## Message Types

There are several categories of messages:

1.  **Requests from IDE to SLYNET:**
    *   These are commands initiated by the user or the IDE, asking SLYNET to perform an action.
    *   Example (conceptual SLYNK-like): `(:emacs-rex (swank:eval-string-for-emacs "(+ 1 2)" "user" 1) "user" 1)`
    *   SLYNET will need to parse these, identify the SLYNK command (e.g., `swank:eval-string-for-emacs`), and map it to a SLYNET internal function.

2.  **Responses from SLYNET to IDE:**
    *   Direct replies to specific requests.
    *   Often include a request ID to correlate with the original request.
    *   Example (conceptual): `(:return (:ok 3) 1)` (response to request ID 1, result is 3)

3.  **Events from SLYNET to IDE:**
    *   Asynchronous notifications sent by SLYNET, not necessarily tied to a specific request.
    *   Examples: Debugger events (e.g., breakpoint hit), new thread created, output from a running computation.
    *   Example (conceptual): `(:debug-notify 0 1 "Thread 1 entered debugger")`

<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=implementation -->
## SLYNET Message Handling (`impl_spec.yml`)

*   **`read-message (stream package)`:**
    *   Responsible for reading a complete S-expression message from the input `stream`.
    *   The `package` argument (relevant in Common Lisp for symbol interning) will need a Janet equivalent, likely related to the current module or environment context for symbol resolution if messages contain symbols that need evaluation or lookup.
    *   Must handle potential I/O errors or malformed messages.

*   **`write-message (message package stream)`:**
    *   Responsible for serializing the given `message` (a Janet data structure representing the S-expression) and writing it to the output `stream`.
    *   The `package` context might influence how symbols within the message are serialized.

## Common SLYNK Message Forms (to be adapted for SLYNET)

This section will be populated with examples of common SLYNK message structures as SLYNET modules are developed. The goal is to document how SLYNET interprets incoming SLYNK-style messages and how it formats outgoing messages.

*   **Evaluation Requests:**
    *   SLYNK: `(:emacs-rex (swank:eval-string-for-emacs <code-string> <package> <request-id>) ...)`
    *   SLYNET: Will need to parse this, extract `<code-string>`, and pass it to its Janet evaluation module.

*   **Compilation Requests:**
    *   SLYNK: `(:emacs-rex (swank:compile-string-for-emacs <code-string> ...))`
    *   SLYNET: Similar to evaluation, but targets Janet's compilation mechanisms.

*   **Return Values:**
    *   SLYNK: `(:return (:ok <result>) <request-id>)` or `(:return (:abort <condition-string>) <request-id>)`
    *   SLYNET: Will format Janet results and conditions into this structure.

*   **Debugger Events:**
    *   SLYNK: `(:debug <thread-id> <level> <condition> <restarts> <frames> <continuations>)`
    *   SLYNET: Will need to construct similar messages based on Janet's debugging state (if applicable).

<!-- AI-CONTEXT-END -->

<!-- AI-IMPORTANCE:level=normal -->
## Protocol Evolution

As SLYNET is developed, this message protocol documentation will be refined:
*   Specific Janet data structures used for messages will be detailed.
*   Any SLYNET-specific extensions or deviations from the SLYNK protocol will be clearly noted.
*   Error handling within the protocol will be specified.

The aim is to maintain sufficient compatibility for existing SLY front-end components to interact with SLYNET with minimal changes, while leveraging Janet's strengths in the backend implementation.