# SLYNET: Superior Lisp Interaction Environment for Janet

SLYNET is a comprehensive Janet port of the SLYNK backend protocol used by the Superior Lisp Interaction Mode for Emacs (SLY). It enables powerful IDE features for Janet development within Emacs.

## Overview

SLYNET provides a complete implementation of the SLYNK protocol in idiomatic Janet, including all core functionality and contrib modules from the original Common Lisp implementation.

### Core Features

- **RPC System**: Extensible RPC registration and dispatch
- **Module System**: Modular backend with clear separation of concerns
- **REPL Integration**: Full REPL support with input/output redirection
- **Introspection**: Rich symbol information and documentation
- **Extensible Architecture**: Plugin-based contrib system

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/slynet.git
   ```

2. Add the path to your Janet module path:
   ```
   export JANET_PATH=$JANET_PATH:/path/to/slynet
   ```

## Usage

### Starting a SLYNET server

```janet
(import slynet-api)

# Start with default settings on port 4005
(slynet-api/start)

# Start with custom settings
(slynet-api/start 
  :port 5000
  :host "0.0.0.0"
  :debug true
  :contrib-modules [:arglists :indentation :fancy-inspector])
```

### Connecting from Emacs

1. Install SLY in Emacs
2. Set up connection:
   ```elisp
   (setq inferior-lisp-program "janet /path/to/slynet/start-slynet.janet")
   ```
3. Run `M-x sly` to connect

## Architecture

SLYNET is organized around several key components:

1. **Core Protocol**: Message encoding/decoding, wire format handling
2. **Backend Interface**: Abstract interface for Janet functionality
3. **RPC System**: Registration and dispatch of remote procedures
4. **Contrib System**: Pluggable extension modules

## Contrib Modules

SLYNET implements all the contrib modules from the original SLYNK:

- **slynet-arglists**: Enhanced arglist functionality
- **slynet-fancy-inspector**: Rich data structure inspector
- **slynet-indentation**: Janet indentation rules
- **slynet-mrepl**: Multiple REPL support
- **slynet-package-fu**: Module/package manipulation
- **slynet-profiler**: Basic profiling interface
- **slynet-retro**: Backward compatibility layer
- **slynet-stickers**: Code annotation and instrumentation
- **slynet-trace-dialog**: Function call tracing
- **slynet-apropos**: Symbol search functionality

## Development

### Running Tests

```
make test           # Run all tests
make core-tests     # Run only core tests
make contrib-tests  # Run only contrib module tests
```

### Code Organization

```
slynet/
├── slynet-api.janet        # Main API entry point
├── slynet-cli.janet        # Command-line interface
├── slynet/
│   └── slynk_janet/        # Core implementation
│       ├── backend.janet   # Backend interface
│       ├── completion.janet # Symbol completion
│       ├── contrib.janet   # Contrib module manager
│       ├── contrib/        # Contrib modules
│       ├── gray.janet      # Stream handling
│       ├── init.janet      # Initialization
│       ├── rpc.janet       # RPC protocol
│       ├── slynk.janet     # Core functionality
│       ├── start.janet     # Server startup
│       ├── utils.janet     # Utility functions
│       └── xref.janet      # Cross-references
└── test/                   # Test suite
```

## License

This project is placed in the Public Domain. All warranties are disclaimed.
