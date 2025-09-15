<!--
ai_keywords: [changelog, updates, versions, history, slynet]
ai_contexts: [project maintenance, development history]
ai_relations: [documentation guide]
AI-IMPORTANCE: MEDIUM
-->

# SLYNET Changelog

## [Unreleased]

### Added
- Initial documentation structure based on `documentation-guide.md`.
- Architectural overview documents:
    - `docs/architecture/system-overview.md`
    - `docs/architecture/tech-stack.md`
    - `docs/architecture/slynk-slynet-mapping.md`
    - `docs/architecture/message-protocol.md`
- Developer guides:
    - `docs/dev-guides/setup.md`
    - `docs/dev-guides/janet-for-cl-devs.md`
- AI Index documents:
    - `docs/ai-index/overview.md`
    - `docs/ai-index/navigation-guide.md`
    - `docs/ai-index/documentation-guide.md`
- **Module Documentation: SLYNK Backend**
    - `docs/modules/slynk-backend/overview.md`: Overview of the core SLYNK backend server, connection management, and event loop.
    - `docs/modules/slynk-backend/implementation.md`: Implementation details of the SLYNK backend in Janet.
- **Module Documentation: RPC (Remote Procedure Call)**
    - `docs/modules/rpc/overview.md`: Overview of the SLYNET RPC mechanism for IDE communication.
    - `docs/modules/rpc/implementation.md`: Implementation details of the RPC system in Janet.
- **Module Documentation: Initialization**
    - `docs/modules/initialization/overview.md`: Overview of SLYNET startup and backend/RPC initialization.
    - `docs/modules/initialization/implementation.md`: Implementation details and test coverage for initialization logic.
- **Module Documentation: Interface Definition**
    - `docs/modules/interface-definition/overview.md`: Overview of the interface/implementation system.
    - `docs/modules/interface-definition/implementation.md`: Implementation details and test coverage for interface/implementation macros.
### Changed
- Updated `docs/ai-index/overview.md` to include new SLYNK Backend and RPC modules.
- Updated `docs/ai-index/navigation-guide.md` with links to new SLYNK Backend and RPC module documentation.

### Fixed
- All logic tests for Janet core modules passed.
- Noted two environmental test failures: missing `spork/declare-cc` module for `suite-pm.janet` and missing `test/assets/17` directory for `suite-sh.janet`. These are considered setup issues rather than code logic errors.

---
*This changelog is maintained following the guidelines in [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).*
