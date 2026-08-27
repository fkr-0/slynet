---
layout: page
title: Janet embedding API
---

# Janet embedding API

The post-1.0.7 development line exposes a small stable-facing Janet API from
`slynet/api.janet`. This API is targeted for SLYNET 1.1.0; it is not part of the
immutable v1.0.7 contract.

## Import

```janet
(import slynet/api :as slynet)
```

The historical `slynet/slynet-api.janet` path is retained as a compatibility
shim, but new code should import `slynet/api`.

## API versioning

```janet
slynet/api-version # => "1"
slynet/version     # project release version
```

API version and project SemVer are intentionally separate. Compatible additions
may land within API version 1. Breaking embedding changes require either a new
API version or an explicit deprecation cycle.

## Initialize and call a context-free RPC

```janet
(slynet/initialize)
(slynet/call-rpc 'ping :pong) # => :pong
```

`initialize` guarantees that supported core RPC implementations are registered
before it returns. `call-rpc` is intended for operations that do not depend on a
live SLYNET connection, package/channel ownership, or client session state.
Connection-sensitive operations should continue through the wire protocol and a
real client session.

## Inspect capabilities

```janet
(pp (slynet/capabilities))
```

The capability record describes API version, project version, transport modes,
and the security default.

## Start and stop a server

```janet
(def server
  (slynet/start-server
    {:mode :tcp
     :host "127.0.0.1"
     :port 4005}))

# ... use SLYNET ...

(slynet/stop-server server)
```

TCP binding is fail-closed to loopback by default. A caller can set
`:allow-remote true`, but that only changes bind policy: it does not add
authentication, authorization, transport encryption, or sandboxing. SLYNET
executes Janet code with the server process user's authority, so remote exposure
requires an external trust boundary.

## Public symbols

| Symbol | Contract |
|---|---|
| `api-version` | Embedding API compatibility version. |
| `version` | SLYNET project version. |
| `capabilities` | Stable capability/security description. |
| `initialize` | Initialize and guarantee core callable registrations. |
| `rpc-interface` | Return declared metadata for an RPC name. |
| `rpc-implementation` | Return the registered callable, or nil. |
| `call-rpc` | Invoke a registered context-free RPC in-process. |
| `start-server` | Start TCP/stdio server with loopback-safe TCP default. |
| `stop-server` | Deterministically request server transport teardown. |

## Explicit non-contracts

The following remain internal and should not be depended on by embedding code:

- registry table representation in `infrastructure.janet`;
- `cli.janet` module-loading order;
- mutable globals in `slynk.janet`;
- historical Common Lisp package/thread/restart data shapes beyond documented
  adapter records.

The 1.1.0 roadmap adds an owned lifecycle/context object so callers do not have
to coordinate initialization and teardown manually.
