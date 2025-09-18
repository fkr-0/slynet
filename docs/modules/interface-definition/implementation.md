---
# AI Metadata Tags
ai_keywords: [SLYNET, interface, implementation, Janet, definterface, defimplementation, macro, test]
ai_contexts: [implementation, development, porting]
ai_relations: [docs/ai-index/documentation-guide.md, docs/modules/interface-definition/overview.md, slynet/slynk_janet/backend.janet, impl_spec.yml]
---

# SLYNET Interface Definition Module Implementation

<!-- AI-IMPORTANCE:level=critical -->
## Interface and Implementation Macros

The interface/implementation system in SLYNET is built around two Janet macros: `definterface` and `defimplementation`. These macros provide a declarative way to define extensible backend APIs and register concrete implementations.

### `definterface` Macro

- Declares a new backend interface with a name, argument list, and documentation string.
- Registers interface metadata in a dynamic registry.
- Optionally accepts a default body for fallback behavior.
- Tracks unimplemented interfaces for diagnostics.

### `defimplementation` Macro

- Registers a Janet function as the implementation for a declared interface.
- Updates the registry to associate the implementation with the interface.
- Removes the interface from the unimplemented tracker.

<!-- AI-CONTEXT-START:type=implementation -->
## Key Logic

- **Dynamic Registries:** Interface metadata and implementations are stored in dynamic variables for runtime lookup and dispatch.
- **Dispatch Logic:** When an interface is called, the system checks for a registered implementation and invokes it, or falls back to the default body or error.
- **Error Handling:** Robust error handling ensures that missing implementations or runtime errors are reported clearly.

<!-- AI-CONTEXT-END -->

<!-- AI-CONTEXT-START:type=testing_strategies -->
## Testing Strategies

The interface/implementation system is tested by:
- Defining test interfaces and implementations in unit tests.
- Asserting correct dispatch and fallback behavior.
- Verifying error handling for missing implementations.
- Integration tests in [`suite-slynet.janet`](slynet/test/suite-slynet.janet:1) cover macro usage and registry population.

<!-- AI-CONTEXT-END -->