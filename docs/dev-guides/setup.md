---
# AI Metadata Tags
ai_keywords: [SLYNET, setup, development, environment, Janet, installation]
ai_contexts: [development]
ai_relations: [docs/ai-index/overview.md, docs/dev-guides/porting-guide-from-slynk.md]
---

# SLYNET Development Environment Setup

<!-- AI-IMPORTANCE:level=high -->
This guide describes how to set up a development environment for working on SLYNET.

<!-- AI-CONTEXT-START:type=development -->
## Prerequisites

1.  **Janet:**
    *   You need a working Janet installation. Refer to the [official Janet documentation](https://janet-lang.org/docs/index.html) for installation instructions specific to your operating system.
    *   Ensure the `janet` executable is in your system's PATH.
    *   Verify your installation by running `janet -v` in your terminal.

2.  **Git:**
    *   SLYNET's source code is managed with Git. Ensure Git is installed on your system.

3.  **(Optional) SLY and a Common Lisp Implementation:**
    *   If you plan to refer to the original SLYNK behavior or test against a SLY front-end, you will need:
        *   Emacs.
        *   SLY (installed via Emacs package manager, e.g., MELPA).
        *   A Common Lisp implementation (e.g., SBCL, CCL).
    *   This is useful for understanding the target functionality but not strictly required for all SLYNET backend development tasks.

## Getting the SLYNET Source Code

1.  **Clone the Repository:**
    ```bash
    git clone <repository_url> slynet
    cd slynet
    ```
    (Replace `<repository_url>` with the actual URL of the SLYNET Git repository.)

2.  **Project Structure:**
    *   The SLYNET Janet code is primarily in [`slynet-api.janet`](slynet-api.janet:1) (initially).
    *   The API specification is in [`impl_spec.yml`](impl_spec.yml:1).
    *   The original SLYNK Common Lisp source code (for reference) is in the `sly_source/` directory.

## Building and Running SLYNET (Initial Placeholder)

*This section will be updated as SLYNET's build and execution mechanisms are defined.*

Currently, SLYNET is in its early stages. To "run" the existing code, you might load [`slynet-api.janet`](slynet-api.janet:1) into a Janet REPL:

```bash
janet
(import slynet-api)
# You can now interact with the defined functions and classes in slynet-api
```

A `Makefile` or `jpm` configuration might be added later for more structured builds and testing.

## Development Workflow

1.  **Understand the Task:** Refer to `docs/tasks/current-task-plan.md` and relevant module documentation.
2.  **Consult SLYNK Source:** If porting a feature, study the corresponding SLYNK code in `sly_source/`.
3.  **Implement in Janet:** Write Janet code, following conventions in `docs/ai-index/documentation-guide.md` and SLYNET-specific coding standards (to be defined).
4.  **Test:** (Testing framework and procedures to be defined).
5.  **Document:** Update or create documentation as per `docs/ai-index/documentation-guide.md`.
6.  **Commit and Push:** Use Git for version control.

## Editor Configuration for Janet

*   **Emacs:** `janet-mode` is available via MELPA.
*   **VS Code:** Extensions for Janet language support are available.
*   **Other Editors:** Check for Janet support plugins for your preferred editor.

<!-- AI-CONTEXT-END -->

This setup guide will be expanded as the project matures and more specific build, test, and run procedures are established.