---
# AI Metadata Tags
ai_keywords: [SLYNET, documentation, guide, standards, metadata, AI markers]
ai_contexts: [usage, development]
ai_relations: [docs/ai-index/overview.md, docs/ai-index/navigation-guide.md]
---

# SLYNET Documentation Standards Guide

This guide outlines the standards and processes for creating, maintaining, and using documentation within the SLYNET project. Adherence to these standards is crucial for ensuring the documentation is effective for both human developers and AI assistants.

<!-- AI-IMPORTANCE:level=critical -->
## Core Principles

*   **Accuracy:** Documentation must accurately reflect the SLYNET implementation and its relationship to SLYNK.
*   **Clarity:** Write clearly and concisely. Avoid jargon where possible or explain it.
*   **Completeness:** Ensure all relevant aspects of a feature or module are covered.
*   **Consistency:** Follow the defined structures, metadata, and marking conventions.
*   **AI-Optimization:** Structure content and use metadata/markers to enhance AI understanding and utility.

## Document Lifecycle for SLYNET Features/Modules

1.  **Plan (Architect Mode):** Identify the SLYNK feature to be ported and define its SLYNET API in `impl_spec.yml`. Plan the corresponding documentation (new files or updates).
2.  **Implement (Code Mode):** Implement the feature in Janet.
3.  **Test (Test Mode):** Verify the implementation.
4.  **Document (Summary Mode):**
    *   **Create/Update:** Create new module documents (e.g., `docs/modules/<module_name>/overview.md` and `implementation.md`) or update existing ones.
    *   Apply metadata and AI markers.
    *   Update related documents (architecture, dev guides, changelog, task plan).
5.  **Review (Summary Mode / Peer Review):** Verify documentation against these standards and the implementation.
6.  **Maintain:** As SLYNET evolves, update documentation to reflect changes. Deprecate or archive outdated documents if necessary.

## Document Structure Specifications

### Module Documents (`docs/modules/<module_name>/`)

Each SLYNET module ported from SLYNK should have its own subdirectory within `docs/modules/`. At a minimum, each module directory should contain:

*   **`overview.md`**:
    *   High-level description of the module's purpose and core functionality.
    *   Its SLYNK equivalent and key differences/similarities in the SLYNET Janet port.
    *   Relevant SLYNET API points from `impl_spec.yml`.
    *   Relationships to other SLYNET modules.
*   **`implementation.md`**:
    *   Detailed explanation of the Janet implementation.
    *   Key data structures, algorithms, and logic flow.
    *   Code snippets (Janet) where appropriate.
    *   Notes on porting challenges or specific design decisions.
    *   Testing strategies for this module.

Templates for these files are provided in the main task brief and should be adapted.

## Metadata System (`ai_keywords`, `ai_contexts`, `ai_relations`)

All Markdown documents in `docs/` (especially within `modules/`, `architecture/`, and `dev-guides/`) **must** begin with a YAML frontmatter block containing AI metadata tags.

```yaml
---
# AI Metadata Tags
ai_keywords: [keyword1, ModuleName, SLYNKFeature, JanetConcept] # Precise keywords for search
ai_contexts: [architecture|development|implementation|usage|porting] # Document's primary purpose
ai_relations: [docs/path/to/related/doc1.md, docs/another/relevant/file.md] # Links to related docs
---
```

*   **`ai_keywords`**: A list of 3-7 specific keywords that accurately describe the document's main topics. Include SLYNET module names, corresponding SLYNK feature names, and relevant Janet or Lisp concepts.
*   **`ai_contexts`**: One or more contexts from the predefined list:
    *   `architecture`: For documents describing system structure, design principles.
    *   `development`: For guides and information directly aiding code writing.
    *   `implementation`: For deep dives into how specific features are built.
    *   `usage`: For instructions on how to use SLYNET or its features (more relevant if SLYNET had direct user-facing commands, but can apply to API usage).
    *   `porting`: For documents specifically guiding the SLYNK-to-SLYNET porting process.
*   **`ai_relations`**: A list of relative paths to other Markdown documents within the `docs/` structure that are directly related. This helps build a knowledge graph.

## AI Content Marking System

Use these HTML-style comments to mark sections of content for AI understanding.

### Importance Markers

Signal the relative importance of content sections.

```markdown
<!-- AI-IMPORTANCE:level=critical -->
This information is absolutely essential for understanding the core concept.

<!-- AI-IMPORTANCE:level=high -->
This information is highly relevant and should be prioritized.

<!-- AI-IMPORTANCE:level=normal -->
Standard informational content.
```

### Contextual Information Blocks

Denote the primary purpose or type of information within a block.

```markdown
<!-- AI-CONTEXT-START:type=architecture -->
Architectural discussions, design rationale.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=development -->
Information for developers actively writing SLYNET code.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=implementation -->
Detailed breakdown of how a feature is implemented in Janet.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=usage -->
How to use a specific SLYNET API or feature.
<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=porting_notes -->
Specific notes relevant to porting this feature from SLYNK.
<!-- AI-CONTEXT-END -->
```

## Document Review Checklist (For Summary Mode & Peer Reviews)

*   [ ] **Accuracy:** Does the document accurately reflect the current SLYNET code and `impl_spec.yml`?
*   [ ] **Clarity:** Is the language clear, concise, and unambiguous?
*   [ ] **Completeness:** Are all relevant aspects of the topic covered?
*   [ ] **Metadata:**
    *   [ ] Is the YAML frontmatter present and correctly formatted?
    *   [ ] Are `ai_keywords` specific and relevant?
    *   [ ] Are `ai_contexts` appropriate for the content?
    *   [ ] Do `ai_relations` point to existing, relevant documents? Are links valid?
*   [ ] **AI Markers:**
    *   [ ] Are `AI-IMPORTANCE` markers used appropriately?
    *   [ ] Are `AI-CONTEXT-START/END` blocks used to delineate different types of information?
*   [ ] **Structure:** Does the document follow the prescribed structure (e.g., for module overviews/implementations)?
*   [ ] **Links:** Are all internal and external links working?
*   [ ] **Code Snippets:** Are Janet code snippets accurate and well-formatted?
*   [ ] **Consistency:** Is the terminology consistent with other SLYNET documents and SLYNK?
*   [ ] **Changelog/Task Plan:** Has `docs/maintenance/changelog.md` and `docs/tasks/current-task-plan.md` been updated if this document reflects a significant change or task completion?

---
By following these standards, we can build a powerful and effective documentation system for SLYNET.