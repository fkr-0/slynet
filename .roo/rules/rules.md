# General AI Assistant Rules for SLYNET

## Document Access and Usage

- The primary source of project knowledge is the `docs/` directory.
- AI assistants should consult `docs/ai-index/navigation-guide.md` to find relevant information.
- AI assistants must adhere to the standards in `docs/ai-index/documentation-guide.md` when creating or modifying documentation.
- Metadata tags (`ai_keywords`, `ai_contexts`, `ai_relations`) and content markers (`AI-IMPORTANCE`, `AI-CONTEXT-START/END`) in `docs/` should be utilized to understand and process information effectively.

## Mode Collaboration Workflow

To efficiently complete development and documentation tasks for SLYNET, AI modes should follow this collaboration flow:

1.  **Architect Mode**:
    *   Responsible for initial project planning, design, SLYNK analysis, and defining the SLYNET API structure (based on `impl_spec.yml`).
    *   Upon completion of a planning phase, typically switches to **Code Mode** for specific Janet implementation.

2.  **Code Mode**:
    *   Responsible for writing SLYNET's Janet code, porting features from SLYNK, debugging, and unit testing.
    *   After coding work for a feature is done, should switch to **Test Mode** for comprehensive testing.

3.  **Test Mode**:
    *   Responsible for preparing test resources and executing tests against the SLYNET API and SLYNK behavior.
    *   If issues are found during testing, should switch back to **Code Mode** for fixes.
    *   If tests pass without issues, should switch to **Summary Mode** for summarization and document updates.

4.  **Summary Mode**:
    *   After tests pass, responsible for summarizing work and updating all relevant documents in the `docs/` directory, adhering to `docs/ai-index/documentation-guide.md`.
    *   Ensures documentation is consistent with the final Janet implementation, `impl_spec.yml`, and SLYNK concepts.

5.  **Orchestrator Mode** (if used):
    *   Responsible for coordinating complex tasks, possibly involving switching between the above modes and task allocation.

## MCP Usage Scenarios

*Currently, SLYNET does not have specific MCP services integrated. This section will be updated if MCPs are introduced.*

<!--
Example MCP Usage (to be adapted if MCPs are added):

### Playwright
- **Scenario 1**: (If SLYNET had a web UI) Conduct E2E testing for SLYNET's web interface.
- **Scenario 2**: Access external Lisp or Janet documentation websites to gather information for porting.

### Perplexity
- **Scenario 1**: Query unfamiliar Janet language features or Common Lisp concepts during porting.
- **Scenario 2**: Research solutions for complex technical challenges encountered during SLYNET development.
-->