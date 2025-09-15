---
# AI Metadata Tags
ai_keywords: [SLYNET, troubleshooting, debugging, issues, errors, Janet]
ai_contexts: [development, usage]
ai_relations: [docs/dev-guides/setup.md, docs/ai-index/navigation-guide.md]
---

# SLYNET Troubleshooting Guide

<!-- AI-IMPORTANCE:level=high -->
This guide provides advice on troubleshooting common issues encountered during SLYNET development or usage. As SLYNET is in early development, this guide will be expanded as common problems and their solutions are identified.

<!-- AI-CONTEXT-START:type=development -->
## General Debugging Steps for SLYNET Development

1.  **Check Janet Output:**
    *   When running SLYNET (e.g., loaded in a Janet REPL or as a server), carefully examine any error messages or unexpected output printed to the console/REPL. Janet's error messages can provide valuable clues.

2.  **Isolate the Problem:**
    *   Try to reproduce the issue with the simplest possible case.
    *   If a complex IDE interaction fails, try to replicate the underlying SLYNET API call directly (if possible) to see if the issue is in SLYNET or the IDE communication.

3.  **Consult SLYNK Behavior:**
    *   If SLYNET is behaving unexpectedly for a ported feature, refer to how the original SLYNK behaves in a similar scenario with a Common Lisp backend. This can help clarify the expected outcome. The SLYNK source is in `sly_source/`.

4.  **Add Logging/Print Statements:**
    *   Temporarily add `(print ...)` statements or use a more structured logging approach within the SLYNET Janet code to trace execution flow and inspect variable values at critical points.
    *   Remember to remove or disable debug prints before committing.

5.  **Review `impl_spec.yml` and Documentation:**
    *   Ensure your understanding of the SLYNET API (`impl_spec.yml`) and the relevant module documentation (`docs/modules/...`) is correct.

6.  **Step Through Code (if possible):**
    *   Depending on your Janet development setup, you might be able to step through Janet code. (Janet's debugging capabilities are evolving).

## Common Issues (Anticipated - To Be Populated)

This section will list common problems and their solutions as they are discovered.

*   **Issue:** SLYNET fails to start.
    *   **Possible Cause:** Janet not installed correctly, incorrect path to SLYNET files, syntax errors in core SLYNET Janet files.
    *   **Solution:** Verify Janet installation. Check console for Janet errors on startup. Lint/check Janet code.

*   **Issue:** Messages not being correctly read/written between IDE and SLYNET.
    *   **Possible Cause:** Serialization/deserialization errors, mismatch in expected message format (see [`docs/architecture/message-protocol.md`](docs/architecture/message-protocol.md:1)).
    *   **Solution:** Add logging around `read-message` and `write-message` implementations. Compare message structures with SLYNK.

*   **Issue:** Feature X (e.g., evaluation, completion) not working as expected.
    *   **Possible Cause:** Logic error in the Janet port of the SLYNK feature, misunderstanding of Janet's behavior vs. Common Lisp's.
    *   **Solution:** Deep dive into the relevant module in `docs/modules/`, compare with SLYNK source, add targeted logging.

<!-- AI-CONTEXT-END -->

## Reporting Issues

If you encounter an issue not covered here or cannot resolve a problem:

1.  Gather relevant information:
    *   SLYNET version (if applicable, or Git commit).
    *   Janet version.
    *   IDE front-end and version (if applicable).
    *   Steps to reproduce the issue.
    *   Full error messages and stack traces.
    *   Expected behavior vs. actual behavior.
2.  Check if the issue is already reported (e.g., in a project issue tracker).
3.  If not, report it clearly with all gathered information.

---
This guide is a starting point. Community contributions and experiences will help improve it over time.