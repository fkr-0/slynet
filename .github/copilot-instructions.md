# SLYNET AI Coding Agent Instructions

## Project Overview
SLYNET is a Janet port of the SLYNK backend protocol (from Common Lisp SLY), providing IDE capabilities for Janet development. This is a complex protocol translation project with strict interface patterns and testing requirements.

## Critical Architecture Patterns

### Interface-Implementation Registry Pattern
- **Define interfaces first**: Use `slynet-definterface` in `slynet/interfaces.janet` 
- **Register implementations**: Use `defimpl` from `slynet/infrastructure.janet`
- **Validate registries**: Call `initialize-rpc` to ensure all interfaces have implementations
- **Example pattern**:
```janet
# In interfaces.janet
(definterface 'eval-string [:string :package] "Evaluate STRING in PACKAGE context")

# In backend.janet  
(defimpl 'eval-string (fn [string package] (eval-string string)))
```

### Module Organization (Target State)
- `slynet/runtime/`: Janet runtime interfaces (`interfaces.janet`, `infrastructure.janet`, `backend.janet`)
- `slynet/server/`: Protocol plumbing (`rpc.janet`, `slynk.janet`, `start.janet`)
- Imports use relative paths: `(import ./runtime/interfaces :as interfaces)`

### RPC Protocol Structure
- Messages use SLYNK-compatible wire format (see `slynet/rpc.janet`)
- All RPCs must be registered in the interface registry before dispatch
- Connection state tracked in `*emacs-io*` global in `slynk.janet`

## Essential Development Commands

### Test Workflow
```bash
# Unified test runner (preferred)
janet test-runner.janet
janet test-runner.janet :match core  # Focus on specific tests
janet test-runner.janet :tags slow   # Run tagged subsets

# Legacy individual tests  
janet test/project_core_tests.janet
make test                            # Run all via Makefile
```

### Server Operations
```bash
janet slynet/start.janet              # Start TCP server (localhost:4005)
janet slynet-client.janet :host 127.0.0.1 :port 4005  # CLI smoke test
```

### Environment Setup
```bash
export JANET_PATH="$JANET_PATH:$(pwd)"  # Enable `import slynet/...` resolution
```

## Testing Conventions

### Use Unified Test Framework
- Tests in `test-runner.janet` use mini-test framework with registry
- Prefer `with-test-server` from `test-tools.janet` for in-memory RPC testing
- Real network tests go in `test/server/` with `:tags [:network]`
- **Pattern**:
```janet
(deftest my-test "description" {:tags [:unit]}
  (assert= expected actual "failure message"))
```

### Registry Cleanup
- Always call `inf/reset-interfaces` and `inf/reset-implementations` in test setup
- Use `inf/slynet-sync-rpc-registries!` after loading modules in tests

## Critical Development Patterns

### Error Handling
- Use structured errors: `make-backend-error` and `make-implementation-error` from `infrastructure.janet`
- Prefer pure functions for protocol transforms; isolate side effects

### Handshake Endpoints Are Critical
- `ping`, `connection-info`, `list-all-package-names`, `simple-completions`, `flex-completions` are live
- Regressions in these are "stop-the-line" issues per `AGENT.md`

### Module Loading and Initialization
- Backend initialization: `initialize-backend` → `initialize-rpc` → `initialize-contrib-modules`
- Always validate interface/implementation matching after module loading
- Check `slynet/init.janet` for proper initialization sequence

## File Conventions

### Import Patterns
- Relative imports: `(import ./backend :as backend)`
- Registry access: `inf/*slynet-rpc-interfaces-registry*` and `inf/*slynet-rpc-implementations-registry*`

### Documentation Standards
- All modules need docstrings for non-obvious functions
- See `docs/ai-index/documentation-guide.md` for metadata conventions
- Update `TASKS.md` status when completing SLY parity items

## Common Pitfalls to Avoid

1. **Registry Sync Issues**: Forgetting to sync dynamic registries in tests before dispatch
2. **TCP Server Cleanup**: Use `with-test-server` or ensure `(srv :dispose)` in deferred blocks
3. **Import Cycles**: Use thin façade modules if layers need bidirectional communication
4. **Missing Interface Declarations**: Every RPC implementation needs corresponding interface definition

## Integration Testing
- CLI smoke test: `slynet-client.janet` must evaluate expressions against test server
- Server integration tests validate real TCP protocol compliance
- All tests must pass before releases

Consult `AGENT.md` for detailed operational guidelines and `docs/architecture/system-overview.md` for big-picture understanding.