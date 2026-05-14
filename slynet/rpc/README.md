# SLYNET RPC System

This module provides the core RPC (Remote Procedure Call) system for SLYNET. It handles the definition, registration, validation, and dispatch of RPC endpoints, enabling a clean separation between interface definitions and their implementations.

## Key Files

- **rpc.janet**: Core RPC system with interface/implementation registration macros and dispatch utilities
- **init.janet**: System initialization and validation logic
- **examples/rpc-example.janet**: Example usage of the RPC system

## Core Features

- **Interface/Implementation Separation**: Define what an API does separately from how it does it
- **Dynamic Registration**: Register interfaces and implementations at runtime
- **Validation**: Validate that all interfaces have implementations
- **Dispatch**: Dispatch calls to the appropriate implementation

## Usage

See the [RPC Guide](../../docs/modules/rpc/rpc-guide.md) for detailed usage information.

## Quick Example

```janet
# Define an RPC interface
(slynet-definterface slynet/get-version []
  "Returns the current SLYNET version.")

# Implement the interface
(slynet-defimplementation slynet/get-version []
  "0.1.0")

# Initialize and validate
(initialize-rpc)

# Dispatch a call
(rpc/dispatch 'slynet/get-version [])
# => "0.1.0"
```
