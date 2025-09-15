# SLYNET RPC System Guide

## Overview

The SLYNET RPC system provides a way to define protocol interfaces and their implementations separately. This allows for clear separation of concerns and makes it possible to support multiple implementations of the same interface. The system supports:

- Declaring RPC interfaces with argument specifications and documentation
- Implementing RPC interfaces with Janet functions
- Validating that all interfaces have implementations
- Dispatching RPC calls at runtime

## Core Components

1. **Dynamic Registries**: Two global registries track interfaces and implementations
   - `slynet-rpc-interfaces-registry`: Maps RPC symbols to interface metadata
   - `slynet-rpc-implementations-registry`: Maps RPC symbols to implementing functions

2. **Definition Macros**:
   - `slynet-definterface`: Defines an RPC interface with documentation and argument specs
   - `slynet-defimplementation`: Defines a Janet function that implements an interface

3. **Utility Functions**:
   - `initialize-rpc`: Resets and validates the RPC system
   - `dispatch`: Dispatches a call to the appropriate implementation
   - `validate-rpc`: Validates an RPC interface has a matching implementation
   - `list-interfaces`/`list-implementations`: Lists all registered interfaces/implementations

## How to Use

### 1. Define an Interface

```janet
(slynet-definterface slynet/get-version []
  "Returns the current SLYNET version.")
```

This declares an RPC endpoint without implementing it, specifying:
- The RPC name (`slynet/get-version`)
- The argument specification (`[]` - no arguments)
- Documentation (`"Returns the current SLYNET version."`)

### 2. Implement an Interface

```janet
(slynet-defimplementation slynet/get-version []
  "0.1.0") 
```

This implements the previously defined interface with a Janet function that returns a version string.

### 3. More Complex Example

```janet
# Define an interface with arguments
(slynet-definterface slynet/echo [:message]
  "Echo back the provided message.")

# Implement the interface
(slynet-defimplementation slynet/echo [message]
  message)
```

### 4. Dispatch an RPC Call

```janet
# Call the RPC endpoint
(rpc/dispatch 'slynet/echo ["Hello, SLYNET!"])
# => "Hello, SLYNET!"
```

## Validation and Initialization

The system provides validation to ensure all interfaces have implementations:

```janet
# Initialize and validate the RPC system
(init/initialize-rpc)

# Validate a specific RPC endpoint
(def [valid reason] (rpc/validate-rpc 'slynet/get-version))
```

## Best Practices

1. **Keep interfaces and implementations separate**: Define interfaces in a central location, and implement them in the appropriate modules.

2. **Use descriptive names**: RPC names should be namespaced and descriptive, like `slynet/get-version` or `slynet/evaluate-expression`.

3. **Provide good documentation**: The docstring is important for API consumers.

4. **Validate on startup**: Always call `initialize-rpc` during system startup to ensure the RPC system is properly configured.

5. **Handle errors appropriately**: When dispatching RPCs, catch and handle potential errors from missing implementations or argument mismatches.

## Extending the System

The RPC system can be extended in several ways:

1. **Argument validation**: Enhance the system to validate arguments against interface specifications.

2. **Middleware**: Add support for middleware functions that run before/after RPC calls.

3. **Versioning**: Add support for versioned interfaces and implementations.

## Example

A complete example can be found in `/home/user/code/slynet/slynet/slynk_janet/examples/rpc-example.janet`.
