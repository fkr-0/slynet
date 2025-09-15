---
# AI Metadata Tags
ai_keywords: [SLYNET, tasks, plan, current work, roadmap]
ai_contexts: [development, project_management] # Assuming project_management is a valid context
ai_relations: [docs/ai-index/overview.md, docs/maintenance/changelog.md]
---

# SLYNET Current Task Plan

<!-- AI-IMPORTANCE:level=high -->
This document outlines the current and upcoming tasks for the SLYNET project. It serves as a short-term roadmap and will be updated regularly by the **Summary Mode** or project maintainers.

<!-- AI-CONTEXT-START:type=project_management -->
## Current Sprint / Immediate Focus

### Task ID: SLYNET-RPC-002
*   **Task:** Reinstate `slynet-definterface`, real `send-to-remote`, and channel dispatch
*   **Description:**
    - Reintroduced `rpc/slynet-definterface` macro with compile-time registry updates and runtime mirroring.
    - Implemented real `rpc/send-to-remote` using `slynk/send-to-emacs` and connection resolution.
    - Exposed `slynk/get-connection` and added `rpc/get-channel-object` for id->object.
    - Implemented channel message handling in `slynk` for `:process`, `:inspect-object`, `:teardown`, and `:clear-history` on registered channel objects.
*   **Status:** Completed
*   **Priority:** High
*   **Depends on:** SLYNET-CORE-API-001
*   **Notes:** Added channel smoke test and exported channel handlers for test harness.

### Task ID: SLYNET-SETUP-001
*   **Task:** Establish AI-Optimized Documentation Management System Foundation
*   **Description:** Create the initial directory structure, rule files (`.roomodes`, `.roo/`), and core documentation files (`docs/ai-index/`, `docs/architecture/`, `docs/dev-guides/`, `docs/tasks/`, `docs/maintenance/`, initial `docs/modules/` placeholders) as per `PLAN.md`.
*   **Status:** Completed
*   **Assignee:** Roo (Code Mode)
*   **Sub-tasks:**
    *   [x] Create `PLAN.md`
    *   [x] Create `.roomodes`
    *   [x] Create `.roo/rules/rules.md`
    *   [x] Create `.roo/rules-architect/rules.md`
    *   [x] Create `.roo/rules-code/rules.md`
    *   [x] Create `.roo/rules-summary/rules.md`
    *   [x] Create `.roo/rules-test/rules.md`
    *   [x] Create `docs/ai-index/overview.md`
    *   [x] Create `docs/ai-index/navigation-guide.md`
    *   [x] Create `docs/ai-index/documentation-guide.md`
    *   [x] Create `docs/architecture/system-overview.md`
    *   [x] Create `docs/architecture/tech-stack.md`
    *   [x] Create `docs/architecture/slynk-slynet-mapping.md`
    *   [x] Create `docs/architecture/message-protocol.md`
    *   [x] Create `docs/modules/initialization/.gitkeep`
    *   [x] Create `docs/modules/rpc/.gitkeep`
    *   [x] Create `docs/modules/interface-definition/.gitkeep`
    *   [x] Create `docs/modules/evaluation/.gitkeep`
    *   [x] Create `docs/modules/completion/.gitkeep`
    *   [x] Create `docs/modules/source-location/.gitkeep`
    *   [x] Create `docs/dev-guides/setup.md`
    *   [x] Create `docs/dev-guides/troubleshooting.md`
    *   [x] Create `docs/dev-guides/porting-guide-from-slynk.md`
    *   [x] Create `docs/dev-guides/janet-for-cl-devs.md`
    *   [x] Create `docs/tasks/current-task-plan.md` (This file)
    *   [x] Create `docs/maintenance/changelog.md`
*   **Deliverables:** Foundational directory and file structure for the documentation system.
*   **Next Step:** Proceed with Task ID: SLYNET-CORE-API-001.

## Upcoming / Next Sprint

*   **Task ID:** SLYNET-CORE-API-001
    *   **Task:** Implement Core SLYNET API functions from `impl_spec.yml`
    *   **Description:** Implemented `initialize-backend`, `initialize-rpc` (implicitly via module loading and macros), `definterface`, `defimplementation`, `read-message`, `write-message` in `slynet/slynk_janet/backend.janet` and `slynet/slynk_janet/rpc.janet`.
    *   **Status:** Completed
    *   **Priority:** High
    *   **Depends on:** SLYNET-SETUP-001

*   **Task ID:** SLYNET-DOCS-MOD-INIT-001
    *   **Task:** Document `slynk-backend` Module (covering initialization)
    *   **Description:** Created `overview.md` and `implementation.md` for the `docs/modules/slynk-backend/` module, covering `initialize-backend` and related backend interfaces.
    *   **Status:** Completed
    *   **Priority:** Medium
    *   **Depends on:** SLYNET-CORE-API-001

*   **Task ID:** SLYNET-DOCS-MOD-RPC-001
    *   **Task:** Document `rpc` Module
    *   **Description:** Created `overview.md` and `implementation.md` for the `docs/modules/rpc/` module, covering `read-message`, `write-message`, and RPC interface/implementation mechanisms.
    *   **Status:** Completed
    *   **Priority:** Medium
    *   **Depends on:** SLYNET-CORE-API-001

*   **Task ID:** SLYNET-DOCS-MOD-INIT-INTERFACE-001
    *   **Task:** Document Initialization and Interface Definition Modules
    *   **Description:** Created `overview.md` and `implementation.md` for `docs/modules/initialization/` and `docs/modules/interface-definition/`, fully documenting initialization logic, interface/implementation macros, and test coverage. Ensured all documentation is consistent with `impl_spec.yml`, Janet code, and SLYNK concepts.
    *   **Status:** Completed
    *   **Priority:** High
    *   **Depends on:** SLYNET-CORE-API-001

## Backlog / Future Considerations

*   Implement SLYNET Evaluation Module
*   Implement SLYNET Completion Module
*   Implement SLYNET Source Location Module
*   Wire RPC channel routing end-to-end (server -> client) and add tests. [Channel smoke test added]
*   Make server roundtrip test robust with short read/retry loop.
*   Align error constructors to exact expected shapes (suite-slynet). [In progress]
*   Re-enable contrib RPC interface macros with correct imports.
*   Expand Fancy Inspector output; add tests against example structs.
*   Develop comprehensive test suite for core API and modules.
*   Investigate SLY front-end compatibility.
*   Explore advanced SLYNK features for porting (debugger, inspector).

<!-- AI-CONTEXT-END -->

---
*This plan is dynamic and will be updated as the project progresses.*