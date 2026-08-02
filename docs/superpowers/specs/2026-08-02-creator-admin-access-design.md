# Creator admin access design

## Problem

The `/farmingcreator` command is currently registered on the client and calls
`OpenProjectListMenu()` directly. Normal players can therefore open the menu
without any server permission decision. Individual Farming Creator mutation
events are protected, but the menu entry itself is not.

The `/consumablescreator` command already performs a server-side
`Framework.HasPermission` check. Its authorization logic is embedded in the
Consumables module, however, so both Creator commands do not share one access
contract.

## Goals

- Register both Creator commands on the server.
- Use the same reusable permission gate for both commands.
- Authorize ESX through `Config.ESXAdminGroups` and QBCore through
  `Config.QBPermissionLevel` via the existing `Framework.HasPermission` API.
- Show the existing error notification `Keine Berechtigung` when access is
  denied.
- Send an open event only after a successful server permission decision.
- Keep all existing server-side mutation permission checks.
- Add standalone Lua regression tests for denied, allowed, not-ready, and
  non-player command calls.

## Considered approaches

### Shared server command gate — selected

Add one focused `CreatorAccess` module that registers protected commands. Both
Creator modules provide only their readiness check, denial text, and authorized
open callback. This centralizes the security decision while keeping Farming
and Consumables data preparation separate.

### Separate protected command handlers

Move only `/farmingcreator` to the server and leave the existing Consumables
handler unchanged. This would work but duplicate the same source validation,
permission check, notification, and callback flow.

### Client command followed by a server request

Keep the client command and request authorization over a new network event.
This is server-authoritative but creates an unnecessary event pair when FiveM
already supports server-registered player commands.

## Shared module

Create `server/creator_access.lua` and expose one server-only global API:

```lua
CreatorAccess.RegisterCommand(commandName, options)
```

Required options:

- `open(source)`: runs only after authorization;
- `deniedMessage`: localized text passed to `Framework.Notify`.

Optional option:

- `isReady()`: when present, the command silently stops until its subsystem
  is ready. This preserves current Consumables behavior.

The module validates its registration input at resource startup and fails fast
for an empty command name, missing options, missing open callback, or missing
denial text. The registered command callback:

1. converts the command source to a number;
2. ignores console/non-player sources (`source <= 0`);
3. applies `isReady()` when provided;
4. calls `Framework.HasPermission(source)`;
5. sends `Framework.Notify(source, deniedMessage, 'error')` and stops when
   permission is denied;
6. calls `open(source)` only when permission is granted.

## Farming Creator flow

The client-side `RegisterCommand('farmingcreator', ...)` is replaced with a
client net-event handler:

```lua
forge_farming:creator:open
```

`server/main.lua` registers `farmingcreator` through `CreatorAccess`. The
authorized open callback emits that client event to the requesting player.
The denial message is `Locale('error_no_permission')`.

## Consumables Creator flow

`server/modules/consumables.lua` replaces its inline `RegisterCommand` block
with `CreatorAccess.RegisterCommand(Config.Consumables.CreatorCommand, ...)`.
It keeps `IsReady` as its readiness callback. The authorized open callback
still sends `forge_farming:consumables:openCreator` with
`registry:Snapshot()`, and its existing localized denial message remains
unchanged.

The existing client `forge_farming:consumables:openCreator` handler does not
change.

## Loading and compatibility

`fxmanifest.lua` loads `server/creator_access.lua` before
`server/modules/consumables.lua` and `server/main.lua`. No framework,
configuration key, command name, client menu implementation, or database flow
changes.

All existing Farming and Consumables create/update/delete permission checks
remain in place as defense in depth. A hostile client executor can always draw
client UI locally, but cannot use the server-authoritative Creator operations
without passing those mutation checks. This change guarantees that normal
command execution opens either menu only after the server permission gate.

## Error handling

- Unauthorized player: one existing error notification, no open callback.
- Missing player source or console: silent return, no permission lookup.
- Consumables subsystem not ready: preserve the current silent return.
- Invalid registration configuration: fail fast during resource startup.
- Authorized callback failures are not swallowed, so startup/runtime faults
  remain visible to server operators.

## Testing

Add `tests/test_creator_access.lua`. It stubs `RegisterCommand`,
`Framework.HasPermission`, and `Framework.Notify`, loads the real access
module, and registers two representative Creator commands.

The test verifies:

- both command names are registered server-side;
- an unauthorized Farming player receives exactly one error notification and
  no open callback;
- an authorized Farming player opens exactly once;
- an unauthorized Consumables player receives exactly one error notification
  and no snapshot/open callback;
- an authorized, ready Consumables player opens exactly once;
- a not-ready Consumables command does nothing;
- console and invalid sources do nothing;
- permission and open callbacks receive the normalized numeric source.

The new test must fail before the production module exists. After the minimal
implementation, it and all existing Lua regression tests must pass, followed
by `git diff --check` over the whole branch.

## Documentation

The README already states that both commands are server-authorized and needs
no behavioral rewrite. Add a concise `1.5.0` changelog bullet that the Farming
Creator menu open is now protected and both Creator commands share the same
server gate.

## Non-goals

- No changes to configured ESX groups or QBCore permission level.
- No new permission system, ACE rule, database table, or dependency.
- No removal of mutation-level authorization checks.
- No attempt to prevent arbitrary UI drawing by hostile client executors.
- No direct push to `main`.
