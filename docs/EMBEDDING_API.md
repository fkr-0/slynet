---
layout: page
title: Janet embedding API
---

# Janet embedding API

SLYNET 1.1.0 exposes its stable Janet embedding API from `slynet/api.janet`.
This API is part of the 1.1 release surface; it is not retroactively part of the
immutable v1.0.7 contract.

## Import

```janet
(import slynet/api :as slynet)
```

The historical `slynet/slynet-api.janet` path is retained as an API-v1
compatibility shim and forwards the complete public API-v1 lifecycle surface.
New code should import `slynet/api`.

## API versioning

```janet
slynet/api-version # => "1"
slynet/version     # project release version
```

API version and project SemVer are intentionally separate. Compatible additions
may land within API version 1. API-v1 compatibility follows these rules:

- existing public functions keep their argument and documented return semantics;
- new optional functions/record fields may be added without changing the API
  version;
- a deprecated API-v1 symbol remains callable for at least one subsequent minor
  SLYNET release and until its replacement has shipped;
- deprecations are recorded in this page and `CHANGELOG.md`;
- removing/renaming a public operation or making a documented semantic break
  requires a new embedding API version.

The legacy `slynet/slynet-api` import path is deprecated for new code but is
guaranteed for the lifetime of API v1. It may only be removed at an API-version
boundary, not silently within API v1.

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

For applications that want one owner for initialization and teardown, prefer a
lifecycle context:

```janet
(def context (slynet/create-context))
(def server (slynet/context-start-server context {:port 4005}))

# ... use SLYNET ...

(pp (slynet/context-status context))
(slynet/context-stop-server context) # context remains reusable
(slynet/close-context context)       # idempotent terminal cleanup
```

`context-status` reports only lifecycle facts owned by the embedding context:
ready/serving/closed state and owned server mode/host/port. Its
`:session-state` is deliberately `:transport-dependent`; API v1 does not invent
a connected client, current package, or MREPL channel for an in-process context.

A context owns at most one server. Starting after close, or attaching a second
server without stopping the first, fails rather than silently leaking
resources.

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
| `create-context` | Initialize and return an API-v1 lifecycle owner. |
| `context-start-server` | Start the single server owned by a context. |
| `context-stop-server` | Stop the owned server while keeping the context reusable. |
| `close-context` | Idempotently stop resources and permanently close a context. |
| `context-status` | Return transport-independent context ownership/lifecycle state. |

## Explicit non-contracts

The following remain internal and should not be depended on by embedding code:

- registry table representation in `infrastructure.janet`;
- `cli.janet` module-loading order;
- mutable globals in `slynk.janet`;
- historical Common Lisp package/thread/restart data shapes beyond documented
  adapter records.

## Executable example

Release source artifacts include `examples/embed-server.janet`. From the
extracted SLYNET root:

```sh
JANET_PATH="$PWD" ./examples/embed-server.janet --check
JANET_PATH="$PWD" ./examples/embed-server.janet --port 4005
```

`--check` initializes API v1, executes the context-free `ping` contract and
prints context status without opening a listener. The normal mode starts a
loopback-only embedded server and owns teardown through the lifecycle context.
