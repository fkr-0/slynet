---
# AI Metadata Tags
ai_keywords: [SLYNET, tech stack, technology, Janet, Lisp, SLYNK]
ai_contexts: [architecture]
ai_relations: [docs/architecture/system-overview.md]
---

# SLYNET Technology Stack

<!-- AI-IMPORTANCE:level=high -->
## Primary Technologies

*   **Janet Programming Language:**
    *   SLYNET is primarily implemented in Janet.
    *   Janet is a modern, functional, and imperative programming language with a Lisp-like syntax. It is lightweight, embeddable, and designed for scripting and application development.
    *   Key Janet features relevant to SLYNET include its C interop capabilities (if needed for performance-critical sections or OS interaction, though less likely for a pure backend), its module system, and its dynamic nature.

*   **SLY/SLYNK (Reference):**
    *   **Common Lisp:** The original SLYNK backend is written in Common Lisp. Understanding Common Lisp concepts is beneficial for porting SLYNK features accurately.
    *   **Emacs Lisp (Elisp):** The SLY IDE front-end is written in Emacs Lisp. While SLYNET focuses on the backend, understanding how SLY interacts with SLYNK provides context for SLYNET's API design and expected behavior.

<!-- AI-CONTEXT-START:type=architecture -->
## Development Environment & Tooling (Anticipated)

*   **Janet Build System:** Standard Janet project tooling (e.g., `jpm` if used, or custom Makefiles/scripts).
*   **Version Control:** Git (as evidenced by the project structure).
*   **IDE for SLYNET Development:** Likely Emacs with SLY (for interacting with a Common Lisp SLYNK instance for reference) or another text editor with Janet language support.

## Communication Protocol

*   SLYNET will use a message-based RPC protocol, adapted from SLYNK's protocol. This involves serializing requests and responses, likely using a Lisp-readable format (e.g., S-expressions or a Janet-native equivalent).
*   Details will be specified in [`docs/architecture/message-protocol.md`](docs/architecture/message-protocol.md:1).

## Potential Future Considerations (Not in initial scope)

*   **Networking Libraries:** If SLYNET needs to communicate over TCP/IP sockets (standard for SLYNK), appropriate Janet networking libraries or built-in capabilities will be used.
*   **Concurrency:** Janet's approach to concurrency (e.g., fibers, event loops) might be leveraged if SLYNET needs to handle multiple client requests or background tasks efficiently.

<!-- AI-CONTEXT-END -->

This document outlines the core technologies. Specific Janet libraries or tools used will be detailed further in module-specific documentation or developer guides as SLYNET evolves.