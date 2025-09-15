<!--
ai_keywords: [slynet, ai, documentation, overview, project structure, janet, lisp, ide]
ai_contexts: [project overview, ai navigation, documentation map]
ai_relations: [navigation-guide.md, documentation-guide.md]
AI-IMPORTANCE: HIGH
-->

# SLYNET AI Documentation Overview

**AI-CONTEXT-START**

*Document Type: AI Index Root*

*Purpose: Provides a high-level map of the SLYNET documentation for AI assistants and human developers.*

**AI-CONTEXT-END**

Welcome to the SLYNET project's AI-indexed documentation. This document serves as the primary entry point for understanding the project's structure, goals, and available documentation.

## Project Goal

SLYNET aims to be a Janet implementation of the SLYNK backend, enabling SLY (SLIME's successor for Emacs) to be used as an IDE for Janet development. This involves porting core SLYNK functionalities to Janet, allowing seamless interaction between an Emacs (or other SLY-compatible) frontend and a Janet runtime.

## Key Documentation Areas

The documentation is organized into several key areas to facilitate both human understanding and AI-assisted development:

1.  **Architecture (`docs/architecture/`)**:
    *   [System Overview](./../architecture/system-overview.md): High-level architecture of SLYNET.
    *   [Tech Stack](./../architecture/tech-stack.md): Technologies used in SLYNET.
    *   [SLYNK-SLYNET Mapping](./../architecture/slynk-slynet-mapping.md): How SLYNK features map to SLYNET.
    *   [Message Protocol](./../architecture/message-protocol.md): Details of the communication protocol between SLYNET and the IDE.

2.  **Developer Guides (`docs/dev-guides/`)**:
    *   [Setup Guide](./../dev-guides/setup.md): Instructions for setting up the SLYNET development environment.
    *   [Janet for Common Lisp Developers](./../dev-guides/janet-for-cl-devs.md): A guide for CL developers transitioning to or working with Janet for SLYNET.

3.  **Module Documentation (`docs/modules/`)**:
    *   Detailed information about specific SLYNET modules, their purpose, and implementation.
    *   **SLYNK Backend (`docs/modules/slynk-backend/`)**:
        *   [Overview](./../modules/slynk-backend/overview.md): Core server, connection management.
        *   [Implementation](./../modules/slynk-backend/implementation.md): Janet implementation details.
    *   **RPC (`docs/modules/rpc/`)**:
        *   [Overview](./../modules/rpc/overview.md): Remote Procedure Call mechanism.
        *   [Implementation](./../modules/rpc/implementation.md): Janet implementation details.
    *   **Initialization (`docs/modules/initialization/`)**:
        *   [Overview](./../modules/initialization/overview.md): Startup and backend/RPC initialization.
        *   [Implementation](./../modules/initialization/implementation.md): Implementation and test coverage.
    *   **Interface Definition (`docs/modules/interface-definition/`)**:
        *   [Overview](./../modules/interface-definition/overview.md): Interface/implementation system.
        *   [Implementation](./../modules/interface-definition/implementation.md): Macro logic and test coverage.
    *   *(More modules will be added as they are developed and documented)*

4.  **Maintenance (`docs/maintenance/`)**:
    *   [Changelog](./../maintenance/changelog.md): History of changes to the project.

5.  **AI Index (`docs/ai-index/`)**: (This directory)
    *   [Navigation Guide](./navigation-guide.md): How to navigate and find information.
    *   [Documentation Guide](./documentation-guide.md): Standards for writing and maintaining documentation.

## Using This Documentation (For AI Assistants)

*   Start with this `overview.md` and the `navigation-guide.md` to understand the layout.
*   Refer to the `documentation-guide.md` for standards when contributing or modifying documentation.
*   Utilize the `ai_keywords`, `ai_contexts`, and `ai_relations` metadata in each file to understand its content and connections.
*   Pay attention to `AI-IMPORTANCE` markers to prioritize information.
*   `AI-CONTEXT-START` and `AI-CONTEXT-END` blocks provide specific contextual information for the AI.

This structured approach ensures that AI assistants can efficiently process, understand, and contribute to the SLYNET project.
