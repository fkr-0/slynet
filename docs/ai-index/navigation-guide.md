<!--
ai_keywords: [navigation, documentation map, sitemap, slynet, ai help]
ai_contexts: [ai navigation, project documentation structure]
ai_relations: [overview.md, documentation-guide.md]
AI-IMPORTANCE: HIGH
-->

# SLYNET Documentation Navigation Guide

**AI-CONTEXT-START**

*Document Type: AI Index Navigation*

*Purpose: Helps AI assistants and developers locate specific information within the SLYNET documentation.*

**AI-CONTEXT-END**

This guide provides a roadmap to navigate the SLYNET documentation effectively.

## Core Structure

The `docs/` directory is the root of all SLYNET documentation. Key subdirectories include:

*   **`docs/ai-index/`**: (Current directory) Contains meta-documentation for AI assistants.
    *   `overview.md`: High-level overview of all documentation. (Start here)
    *   `navigation-guide.md`: This file.
    *   `documentation-guide.md`: Standards and guidelines for SLYNET documentation.
*   **`docs/architecture/`**: Describes the system design and technical foundations.
    *   `system-overview.md`: Overall SLYNET architecture.
    *   `tech-stack.md`: Core technologies used.
    *   `slynk-slynet-mapping.md`: Mapping SLYNK concepts to SLYNET.
    *   `message-protocol.md`: SLYNET's communication protocol with IDEs.
*   **`docs/dev-guides/`**: Practical guides for developers working on or with SLYNET.
    *   `setup.md`: Setting up the development environment.
    *   `janet-for-cl-devs.md`: Guide for Common Lisp developers new to Janet.
*   **`docs/modules/`**: In-depth documentation for individual SLYNET modules. Each module typically has an `overview.md` and an `implementation.md`.
    *   **`slynk-backend/`**: Core server functionality.
        *   `overview.md`: [Link to SLYNK Backend Overview](../modules/slynk-backend/overview.md)
        *   `implementation.md`: [Link to SLYNK Backend Implementation](../modules/slynk-backend/implementation.md)
    *   **`rpc/`**: Remote Procedure Call mechanism.
        *   `overview.md`: [Link to RPC Overview](../modules/rpc/overview.md)
        *   `implementation.md`: [Link to RPC Implementation](../modules/rpc/implementation.md)
    *   **`initialization/`**: Startup and backend/RPC initialization.
        *   `overview.md`: [Link to Initialization Overview](../modules/initialization/overview.md)
        *   `implementation.md`: [Link to Initialization Implementation](../modules/initialization/implementation.md)
    *   **`interface-definition/`**: Interface/implementation system.
        *   `overview.md`: [Link to Interface Definition Overview](../modules/interface-definition/overview.md)
        *   `implementation.md`: [Link to Interface Definition Implementation](../modules/interface-definition/implementation.md)
    *   *(This section will grow as more modules are added.)*
*   **`docs/maintenance/`**: Project maintenance documents.
    *   `changelog.md`: Record of changes and versions.
*   **`docs/tasks/`**: Task planning and tracking documents.
    *   `current-task-plan.md`: Current development tasks (if used).
    *   *(Other task-related documents may reside here.)*

## Finding Information

1.  **High-Level Understanding**: Start with `docs/ai-index/overview.md` and `docs/architecture/system-overview.md`.
2.  **Specific SLYNK Feature Porting**: Consult `docs/architecture/slynk-slynet-mapping.md` and then look for the corresponding module in `docs/modules/`.
3.  **Code Implementation Details**: Navigate to the relevant module in `docs/modules/` and view its `implementation.md` file. These often link to the source Janet files.
4.  **Communication Protocol**: See `docs/architecture/message-protocol.md`.
5.  **Development Setup**: Refer to `docs/dev-guides/setup.md`.
6.  **Documentation Standards**: Always refer to `docs/ai-index/documentation-guide.md` before creating or modifying documentation.

## AI Assistant Guidance

*   Use the `ai_keywords`, `ai_contexts`, and `ai_relations` in file headers to quickly assess relevance.
*   Follow links provided in `ai_relations` or within the document body to explore connected topics.
*   When asked to summarize or find information about a SLYNET feature, start by identifying the relevant module in `docs/modules/`.

This guide will be updated as the documentation evolves.
