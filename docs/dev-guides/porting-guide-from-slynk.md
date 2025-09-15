---
# AI Metadata Tags
ai_keywords: [SLYNET, porting, SLYNK, Janet, Common Lisp, development, guide]
ai_contexts: [development, porting]
ai_relations: [docs/architecture/slynk-slynet-mapping.md, docs/dev-guides/setup.md, docs/ai-index/documentation-guide.md]
---

# Porting Guide: From SLYNK (Common Lisp) to SLYNET (Janet)

<!-- AI-IMPORTANCE:level=critical -->
This guide provides practical advice and a general workflow for developers porting features and modules from the SLYNK Common Lisp backend to the SLYNET Janet backend.

The goal is to achieve functional parity while writing idiomatic Janet code.

<!-- AI-CONTEXT-START:type=porting -->
## General Workflow

1.  **Understand the SLYNK Feature:**
    *   **Locate SLYNK Code:** Identify the relevant Common Lisp files and functions in the `sly_source/slynk/` directory.
    *   **Study SLYNK Logic:** Thoroughly understand what the SLYNK code does, its inputs, outputs, side effects, and how it interacts with other SLYNK components.
    *   **Test SLYNK Behavior:** If possible, run the SLYNK feature with a Common Lisp implementation and SLY front-end to observe its behavior directly.

2.  **Plan the SLYNET Port:**
    *   **Consult `impl_spec.yml`:** Check if the API points for this feature are already defined for SLYNET. If not, propose them (coordinate with Architect mode).
    *   **Review SLYNET Architecture:** See [`docs/architecture/slynk-slynet-mapping.md`](docs/architecture/slynk-slynet-mapping.md:1) for high-level component mapping.
    *   **Identify Janet Equivalents:** Think about how Common Lisp constructs (functions, macros, data structures, error handling) will translate to idiomatic Janet.
        *   *Example:* Common Lisp packages map roughly to Janet modules. `defun` maps to `defn` or `def`. `defvar`/`defparameter` map to `def` or `var`.
    *   **Consider Data Structures:** How will SLYNK's Lisp data structures be represented in Janet? (e.g., plists, alists, CLOS objects vs. Janet tables, structs, prototypes).
    *   **Break Down the Task:** Divide the porting effort into smaller, manageable pieces.

3.  **Implement in Janet:**
    *   **Create/Update Module Files:** Organize your Janet code into appropriate files, potentially within a new subdirectory in `docs/modules/` if it's a significant new module, or by adding to [`slynet-api.janet`](slynet-api.janet:1) for smaller additions.
    *   **Write Idiomatic Janet:** Don't just transliterate Common Lisp. Use Janet's features and style.
    *   **Handle Errors:** Implement robust error handling using Janet's mechanisms (e.g., `error`, `try`/`catch`).
    *   **Manage State:** Be mindful of how state is managed in SLYNK and how it should be managed in SLYNET.
    *   **Refer to Janet Documentation:** Use the official Janet language documentation extensively.

4.  **Test the SLYNET Implementation:**
    *   **Unit Tests:** Write unit tests for your Janet functions. (Testing framework TBD).
    *   **Integration Tests:** Test the interaction of your new code with other SLYNET components.
    *   **Behavioral Comparison:** Compare SLYNET's behavior with SLYNK's for the ported feature.

5.  **Document the Ported Feature:**
    *   Follow the standards in [`docs/ai-index/documentation-guide.md`](docs/ai-index/documentation-guide.md:1).
    *   Create or update `overview.md` and `implementation.md` for the module in `docs/modules/`.
    *   Include AI metadata and markers.
    *   Update `docs/maintenance/changelog.md` and `docs/tasks/current-task-plan.md`.

## Key Considerations & Tips

*   **Symbol Management:**
    *   SLYNK uses Common Lisp packages extensively. SLYNET will use Janet modules. Pay attention to symbol visibility and qualification.
    *   The `package` argument in SLYNK functions often dictates the symbol reading context. This needs a Janet equivalent (e.g., current module).

*   **Condition System (Error Handling):**
    *   Common Lisp has a powerful condition system. Janet's error handling is simpler (`error`, `try`/`catch`). You'll need to map SLYNK's error signaling and handling to Janet's mechanisms.
    *   Ensure that errors are reported back to the IDE in a SLYNK-compatible way if possible (e.g., `(:return (:abort <message>) <id>)`).

*   **Macros:**
    *   Both languages have macros, but they differ. If SLYNK uses complex macros, you might need to rethink the logic in Janet or implement simpler Janet macros.

*   **Special Variables (Dynamic Scope):**
    *   Common Lisp uses special variables for dynamic scope. Janet has dynamic bindings (`dyn`). Understand how SLYNK uses them and if a similar approach is needed in SLYNET.

*   **Concurrency:**
    *   SLYNK often deals with multiple threads (e.g., for different client connections or background tasks). Janet has fibers. If concurrency is involved, map SLYNK's threading model to Janet's concurrency primitives.

*   **`*`earmuffs`*` and `+constants+`:**
    *   Common Lisp naming conventions (e.g., `*special-var*`, `+constant+`) should be translated to Janet conventions (e.g., `SPECIAL_VAR` or `special-var`, `CONSTANT` or `constant`).

*   **Don't Be Afraid to Refactor:**
    *   Sometimes a direct port isn't the best approach. If SLYNK's way of doing something is overly complex due to Common Lisp specifics, look for a simpler, more idiomatic Janet solution that achieves the same functional result.

*   **Consult `sly_source/contrib/`:**
    *   Many SLYNK features are in the `contrib` directory. These often show practical examples of SLYNK's extension capabilities.

<!-- AI-CONTEXT-END -->

This guide is a starting point. As more features are ported, best practices and SLYNET-specific patterns will emerge and should be added here.