# HUD notification adapter design

## Problem

The client framework currently routes all HEX HUD calls through one dynamic
function invocation. That invocation uses Lua's dot-call form, while the HUD
exports are documented and known to work with method-call syntax. The shared
router also passes the interaction key to `HelpNotify`, although the HEX HUD
contract accepts only the cleaned message. In addition,
`hex_finalhud_v2` is missing from the supported resource list.

These inconsistencies can shift `title`, `message`, and `notifyType` into the
wrong HUD fields and make behavior depend on the active HUD resource.

## Goals

- Support `fc_hud` and every requested HEX HUD resource.
- Call HEX notifications as `Notify(title, message, notifyType, timeout)`.
- Call HEX help notifications as `HelpNotify(cleanMessage)`.
- Replace `~INPUT_PICKUP~` with `E` before rendering help text.
- Preserve existing server call sites and network event payloads.
- Preserve announce, progress, clear-help, and native fallback behavior.
- Add regression coverage for every supported HUD and argument position.

## Considered approaches

### Explicit adapters per operation — selected

Use a small router for resource discovery but invoke each export explicitly
with Lua method-call syntax, for example
`exports[resourceName]:Notify(title, message, notifyType, timeout)`.
`fc_hud` remains a separate event adapter because its argument order differs.

This approach makes each external contract visible and testable while keeping
existing business logic unchanged.

### Change every call site to one new signature

This would make the entire codebase use title-first parameters. It creates a
large, unnecessary migration across server modules and increases regression
risk without improving the HUD boundary.

### Keep the generic dynamic export caller

This is the smallest edit, but it hides method-specific signatures and cannot
safely represent the different `Notify`, `HelpNotify`, announce, and progress
contracts.

## Interfaces and routing

The server API stays unchanged:

```lua
Framework.Notify(source, message, notifyType, title)
```

The network event stays unchanged:

```lua
forge_farming:notify(message, notifyType, title)
```

The event handler maps that payload to the canonical client HUD API:

```lua
Framework.Notify(title, message, notifyType, timeout)
```

HEX HUD notifications receive exactly:

```lua
exports[resourceName]:Notify(title, message, notifyType, timeout)
```

The existing `fc_hud` adapter keeps its event contract:

```lua
TriggerEvent('fc_hud:notify', notifyType, title, message, timeout)
```

`Framework.HelpNotify(key, message)` remains compatible with current call
sites. It cleans the message once. `fc_hud` receives `key, cleanMessage`, while
HEX HUDs receive only `cleanMessage` through method-call syntax.

## Supported resources

Notification detection follows the provided priority:

1. `hex_1_hud`
2. `hex_2_hud`
3. `hex_4_hud`
4. `hex_final_hud`
5. `hex_future_hud`
6. `hex_hud`
7. `hex_hud_prem`
8. `hex_finalhud_v2`
9. `hex_genesis_hud`

Help notification detection follows the provided compatibility list:

1. `hex_2_hud`
2. `hex_4_hud`
3. `hex_final_hud`
4. `hex_future_hud`
5. `hex_hud_prem`
6. `hex_finalhud_v2`
7. `hex_genesis_hud`

`fc_hud` is checked before the HEX lists to preserve its established behavior.
Announce and progress retain their current contracts and gain
`hex_finalhud_v2` through the shared supported-resource registry.

## Fallbacks and errors

Every external HUD call stays protected by `pcall`. If an export is absent or
fails, the router tries the next started compatible HUD. If none succeeds,
help text uses `AddTextEntry` plus `DisplayHelpTextThisFrame`, and notifications
use `SetNotificationTextEntry` plus `DrawNotification` as in the supplied
reference implementation.

Inputs are normalized before routing:

- missing title becomes `Farming`;
- missing type becomes `info`;
- missing timeout becomes `5000`;
- message and title are converted to strings;
- the help token `~INPUT_PICKUP~` becomes `E`.

## Testing

The existing Lua HUD regression test will be changed first and observed
failing before production code is edited. It will verify:

- title, message, type, and timeout positions for every notification HUD;
- method-call invocation rather than a plain dynamic function call;
- one-argument HEX `HelpNotify` calls for every compatible help HUD;
- `~INPUT_PICKUP~` cleanup;
- `hex_finalhud_v2` support;
- unchanged `fc_hud` event mappings;
- announce, progress, and native fallback behavior.

After the focused test passes, all Lua regression tests and `git diff --check`
must pass before the implementation is committed.

## Non-goals

- No change to localized message contents.
- No change to server business logic or permissions.
- No new dependency or framework.
- No direct push to `main`.
