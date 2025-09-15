# SLYNET Code Refactoring Plan

## Overall Refactoring Goals:

*   **Target**: All `.janet` files within `slynet/slynk_janet/` and `slynet/slynet/init.janet`.
*   **Style Guide**: Adhere to the coding style observed in the `spork/` repository (modularity, comprehensive docstrings, robust error handling, idiomatic Janet usage).
*   **Error Handling**: Enhance by introducing custom conditions and handlers where beneficial, ensuring fail-safeness.
*   **Documentation**: Implement comprehensive docstrings for all public APIs and internal functions/structs. Add inline comments for complex logic.
*   **Implementation**: Transform stubs and placeholder code into professional, robust implementations.
*   **Clarity & Maintainability**: Improve overall code structure for better readability and future maintenance.

## General Refactoring Principles (derived from `spork/`):

1.  **File Structure & Docstrings:**
    *   Standardize file header comments (e.g., `### filename.janet ### ...`).
    *   Implement/enhance module-level docstrings: `(setdyn :doc "Module purpose...")`.
    *   Ensure all public functions (`defn`) and macros have detailed docstrings covering parameters, return values, and behavior.
    *   Private functions (`defn-`) should also have docstrings or clear explanatory comments.
    *   Document constants and significant global variables.
2.  **Modularity:**
    *   Utilize `(import ./module)` or `(use ./module)` for local dependencies.
    *   Organize code into well-defined, logical functions.
3.  **Error Handling:**
    *   Employ `try...catch` for operations prone to failure (I/O, network operations, parsing).
    *   Define custom error conditions using `(error "custom-error-tag" {:details ...})` for better error semantics where appropriate.
    *   Ensure error messages are informative and actionable.
4.  **Idiomatic Janet:**
    *   Leverage Janet's core constructs: `let`, `if-let`, `when-let`, `cond`, `loop`, `for`, `each`, `map`, `reduce`, `partial`, etc.
    *   Use `(default arg default-value)` for optional function arguments.
    *   Employ `defn-` for internal helper functions.
5.  **Code Clarity & Maintainability:**
    *   Replace all stubs (e.g., `[]`, `nil`, `(print "TODO")`) with full implementations.
    *   Remove dead or obsolete commented-out code.
    *   Add inline comments to clarify non-obvious logic.
    *   Ensure consistent code formatting.

## File-Specific Refactoring Plan:

**1. `slynet/slynet/init.janet`**
    *   **Focus**: Main project entry point for the SLYNET application.
    *   **Current State**: Contains a placeholder `hello` and `main` function.
    *   **Refactoring Actions**:
        *   This file will serve as the primary executable for starting the SLYNET server.
        *   **Imports**: Add an import for the SLYNK Janet system, likely `(import ./slynk_janet/init :as slynk)`.
        *   **Main Function**: The `main` function will be refactored to:
            *   Parse command-line arguments (e.g., for port number, host).
            *   Call the SLYNK server startup function (e.g., `(slynk/start default-port)` or a more specific function from `slynk_janet/start.janet`).
            *   Implement robust error handling for the server startup process (e.g., port already in use, configuration errors).
            *   Provide informative messages to the console during startup.
        *   **Docstrings**: Add a comprehensive file-level docstring explaining its role. Update the docstring for the `main` function to describe its new behavior and arguments.
        *   The current `hello` function can be removed as it's not part of the SLYNET core functionality.
        *   Ensure it adheres to the `spork/` style for argument parsing, error handling, and general structure.

**2. `slynet/slynk_janet/backend.janet`**
    *   **Focus**: Core backend logic, `definterface`/`defimplementation` macros, UTF-8 utilities. **Consolidation target for `slynk-backend.janet`**.
    *   **Actions**:
        *   **Consolidate**: Integrate any unique, valuable logic from `slynet/slynk_janet/slynk-backend.janet` into this file.
        *   Review and enhance docstrings for macros and functions.
        *   **UTF-8 Utilities**: Evaluate custom UTF-8 functions. Prefer Janet's built-in capabilities if they meet requirements. If custom versions are retained, ensure thorough error handling and clear docstrings.
        *   Refine error handling in `definterface` default logic.
        *   Consider privacy for global state variables.

**3. `slynet/slynk_janet/slynk-backend.janet`**
    *   **Action**: This file will be **removed** after its relevant content is consolidated into `slynet/slynk_janet/backend.janet`.

**4. `slynet/slynk_janet/completion.janet`**
    *   **Focus**: Symbol completion logic (currently stubs).
    *   **Actions**:
        *   Implement `simple-completions`, `flex-completions`, `format-completion-set`. This will involve interacting with Janet's runtime environment.
        *   Add file/module docstrings and comprehensive function docstrings.
        *   Implement robust error handling (e.g., for non-existent modules/packages).

**5. `slynet/slynk_janet/gray.janet`**
    *   **Focus**: SLYNK Gray Stream support (structs defined, methods needed).
    *   **Actions**:
        *   Implement necessary stream operations/methods based on SLYNK specifications.
        *   Add file/module docstrings and detailed docstrings for structs and functions.
        *   Implement error handling for stream operations.

**6. `slynet/slynk_janet/init.janet` (in `slynk_janet/`)**
    *   **Focus**: Main module for `slynk_janet`, imports, re-exports, versioning.
    *   **Actions**:
        *   Verify all imports. The `(import ./core)` line will remain, anticipating the future creation of `core.janet`.
        *   Ensure re-exports point to correct, existing functions (or will, once `core.janet` is implemented).
        *   Review and confirm docstrings.

**7. `slynet/slynk_janet/rpc.janet`**
    *   **Focus**: SLYNK RPC protocol, message encoding/decoding.
    *   **Actions**:
        *   Align closely with `spork/rpc.janet` for style where applicable (error handling, structure).
        *   Add `(import ./backend)` as it uses `backend/utf8-to-string`.
        *   `read-message`: Solidify error handling for `read-form` and packet reading.
        *   `parse-header`: Handle invalid hex input from `(tonumber ... 16)`.
        *   `prin1-to-string-for-emacs`: This is critical and currently a stub `(string obj)`. It needs full implementation according to SLYNK serialization requirements for various Lisp data types.
        *   Add comprehensive docstrings and file/module documentation.

**8. `slynet/slynk_janet/start.janet`**
    *   **Focus**: SLYNK server startup logic (currently a stub).
    *   **Actions**:
        *   Implement the server startup logic, likely using Janet's `net` module and functionalities from other `slynk_janet` modules.
        *   Refer to `spork/rpc.janet`'s `server` function for structural patterns (event loop, connection handling), adapting to SLYNK's protocol.
        *   Implement robust error handling (e.g., port in use).
        *   Define and use a default port constant.
        *   Add comprehensive docstrings.

**9. `slynet/slynk_janet/xref.janet`**
    *   **Focus**: Cross-referencing utilities (currently a stub).
    *   **Actions**:
        *   Implement `list-callers`. This is a non-trivial static analysis task. Define input/output contracts clearly.
        *   Add comprehensive docstrings and file/module documentation.
        *   Implement error handling (file not found, parse errors).

## Conceptual Module Dependencies Diagram:

```mermaid
graph TD
    subgraph slynet
        direction LR
        A("slynet/slynet/init.janet (main entry)")
    end
    subgraph slynk_janet
        direction TB
        B("init.janet")
        C("start.janet")
        D("rpc.janet")
        E("backend.janet")
        F("completion.janet")
        G("gray.janet")
        H("xref.janet")
        I("core.janet (future)")
    end

    A -- imports --> B

    B -- imports & re-exports --> C
    B -- imports --> D
    B -- imports --> E
    B -- imports --> F
    B -- imports --> G
    B -- imports --> H
    B -- imports --> I

    D -- uses --> E # For UTF-8 utils
    C -- uses --> D # For RPC handling
    C -- uses --> E # For backend functions
    E -- potentially uses --> G # For stream ops

    classDef slynet fill:#ccf,stroke:#333,stroke-width:2px;
    class A,B,C,D,E,F,G,H,I slynet;