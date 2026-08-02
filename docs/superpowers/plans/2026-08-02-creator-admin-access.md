# Creator Admin Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure `/farmingcreator` and `/consumablescreator` open only after the server authorizes the player through the configured ESX or QBCore admin permissions.

**Architecture:** Add one server-only `CreatorAccess.RegisterCommand` gate that owns source validation, readiness, authorization, denial notification, and authorized callback dispatch. Wire both Creator commands through it, replace the client Farming command with a server-triggered open event, and retain every mutation-level permission check.

**Tech Stack:** FiveM Lua 5.4, ESX/QBCore abstraction in `Framework`, standalone Lua regression tests.

## Global Constraints

- Register both Creator commands on the server.
- Authorize through the existing `Framework.HasPermission(source)` API.
- Keep `Config.ESXAdminGroups` and `Config.QBPermissionLevel` unchanged.
- Unauthorized players receive one existing `error` notification with `Keine Berechtigung` and no open callback.
- Console, invalid, and non-player sources do nothing.
- Preserve the Consumables `IsReady()` guard and snapshot payload.
- Preserve all Farming and Consumables mutation permission checks.
- Add no dependency, ACE rule, database table, or client-trusted permission decision.
- Use modern, explicit Lua and keep functions focused.
- Write the regression test first and observe the expected failure before creating production code.
- Do not push directly to `main`.

## File Map

- Create `server/creator_access.lua`: reusable server-only protected command registration.
- Create `tests/test_creator_access.lua`: isolated access-gate behavior tests for both Creator command shapes.
- Modify `fxmanifest.lua`: load the access gate before both server consumers.
- Modify `client/main.lua`: replace the local Farming command with the authorized open event.
- Modify `server/main.lua`: register `/farmingcreator` through the shared gate.
- Modify `server/modules/consumables.lua`: migrate `/consumablescreator` from its inline check to the shared gate.
- Modify `CHANGELOG.md`: document the 1.5.0 security fix and affected files.
- Reference `docs/superpowers/specs/2026-08-02-creator-admin-access-design.md`: approved behavior, threat boundary, and non-goals.

---

### Task 1: Gate both Creator commands on the server

**Files:**
- Create: `tests/test_creator_access.lua`
- Create: `server/creator_access.lua`
- Modify: `fxmanifest.lua:37-41`
- Modify: `client/main.lua:911-913`
- Modify: `server/main.lua:223-230`
- Modify: `server/modules/consumables.lua:206-216`
- Modify: `CHANGELOG.md:9-47`
- Reference: `docs/superpowers/specs/2026-08-02-creator-admin-access-design.md`

**Interfaces:**
- Consumes: `Framework.HasPermission(source)`, `Framework.Notify(source, message, notifyType)`, optional `options.isReady()`, and per-command `options.open(source)` callbacks.
- Produces: `CreatorAccess.RegisterCommand(commandName, options)`, the client event `forge_farming:creator:open`, and unchanged `forge_farming:consumables:openCreator(source, snapshot)` behavior.

- [ ] **Step 1: Write the failing access-gate regression test**

Create `tests/test_creator_access.lua` with a real load of the future production
module and representative registrations for both Creator commands:

```lua
local commands = {}
local permissionBySource = {}
local permissionCalls = {}
local notifications = {}
local farmingOpens = {}
local consumablesOpens = {}
local consumablesReady = true

function RegisterCommand(commandName, callback, restricted)
    commands[commandName] = {
        callback = callback,
        restricted = restricted,
    }
end

Framework = {
    HasPermission = function(source)
        permissionCalls[#permissionCalls + 1] = source
        return permissionBySource[source] == true
    end,
    Notify = function(source, message, notifyType)
        notifications[#notifications + 1] = {
            source = source,
            message = message,
            notifyType = notifyType,
        }
    end,
}

local function AssertEqual(actual, expected, message)
    assert(actual == expected, ('%s: erwartet %s, erhalten %s'):format(
        message, tostring(expected), tostring(actual)))
end

dofile('server/creator_access.lua')

CreatorAccess.RegisterCommand('farmingcreator', {
    deniedMessage = 'Keine Berechtigung',
    open = function(source)
        farmingOpens[#farmingOpens + 1] = source
    end,
})

CreatorAccess.RegisterCommand('consumablescreator', {
    isReady = function() return consumablesReady end,
    deniedMessage = 'Keine Berechtigung',
    open = function(source)
        consumablesOpens[#consumablesOpens + 1] = source
    end,
})

assert(commands.farmingcreator, 'Farming-Command fehlt')
assert(commands.consumablescreator, 'Consumables-Command fehlt')
AssertEqual(commands.farmingcreator.restricted, false, 'Farming restricted-Flag')
AssertEqual(commands.consumablescreator.restricted, false, 'Consumables restricted-Flag')

commands.farmingcreator.callback(11)
AssertEqual(#notifications, 1, 'Farming-Denial Notify-Anzahl')
AssertEqual(notifications[1].source, 11, 'Farming-Denial Source')
AssertEqual(notifications[1].message, 'Keine Berechtigung', 'Farming-Denial Text')
AssertEqual(notifications[1].notifyType, 'error', 'Farming-Denial Typ')
AssertEqual(#farmingOpens, 0, 'Farming darf nicht oeffnen')

permissionBySource[12] = true
commands.farmingcreator.callback('12')
AssertEqual(farmingOpens[1], 12, 'Farming normalisierte Source')
AssertEqual(permissionCalls[#permissionCalls], 12, 'Farming Permission-Source')

consumablesReady = false
local permissionCallCount = #permissionCalls
commands.consumablescreator.callback(21)
AssertEqual(#permissionCalls, permissionCallCount, 'Not-ready darf Permission nicht pruefen')
AssertEqual(#consumablesOpens, 0, 'Not-ready darf nicht oeffnen')

consumablesReady = true
commands.consumablescreator.callback(21)
AssertEqual(#notifications, 2, 'Consumables-Denial Notify-Anzahl')
AssertEqual(notifications[2].source, 21, 'Consumables-Denial Source')
AssertEqual(notifications[2].message, 'Keine Berechtigung', 'Consumables-Denial Text')
AssertEqual(notifications[2].notifyType, 'error', 'Consumables-Denial Typ')
AssertEqual(#consumablesOpens, 0, 'Consumables-Denial darf nicht oeffnen')

permissionBySource[22] = true
commands.consumablescreator.callback('22')
AssertEqual(consumablesOpens[1], 22, 'Consumables normalisierte Source')
AssertEqual(permissionCalls[#permissionCalls], 22, 'Consumables Permission-Source')

permissionCallCount = #permissionCalls
commands.farmingcreator.callback(0)
commands.farmingcreator.callback(nil)
commands.farmingcreator.callback('ungueltig')
AssertEqual(#permissionCalls, permissionCallCount, 'Nicht-Spieler duerfen Permission nicht pruefen')

assert(not pcall(function()
    CreatorAccess.RegisterCommand('', {
        deniedMessage = 'Keine Berechtigung',
        open = function() end,
    })
end), 'Leerer Command-Name muss fehlschlagen')

assert(not pcall(function()
    CreatorAccess.RegisterCommand('invalid_creator', {
        deniedMessage = '',
        open = function() end,
    })
end), 'Leerer Denial-Text muss fehlschlagen')

assert(not pcall(function()
    CreatorAccess.RegisterCommand('missing_options')
end), 'Fehlende Optionen muessen fehlschlagen')

assert(not pcall(function()
    CreatorAccess.RegisterCommand('missing_open', {
        deniedMessage = 'Keine Berechtigung',
    })
end), 'Fehlender Open-Callback muss fehlschlagen')

assert(not pcall(function()
    CreatorAccess.RegisterCommand('invalid_ready', {
        deniedMessage = 'Keine Berechtigung',
        isReady = true,
        open = function() end,
    })
end), 'Ungueltiger Ready-Callback muss fehlschlagen')

print('PASS test_creator_access')
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
lua tests/test_creator_access.lua
```

Expected: FAIL because `server/creator_access.lua` does not exist. Confirm that
the failure names the missing production module; correct any test syntax or
setup error before proceeding.

- [ ] **Step 3: Implement the minimal reusable server gate**

Create `server/creator_access.lua`:

```lua
CreatorAccess = {}

local function ValidateRegistration(commandName, options)
    if type(commandName) ~= 'string' or commandName == '' then
        error('CreatorAccess commandName must be a non-empty string')
    end
    if type(options) ~= 'table' then
        error('CreatorAccess options must be a table')
    end
    if type(options.open) ~= 'function' then
        error('CreatorAccess options.open must be a function')
    end
    if type(options.deniedMessage) ~= 'string' or options.deniedMessage == '' then
        error('CreatorAccess options.deniedMessage must be a non-empty string')
    end
    if options.isReady ~= nil and type(options.isReady) ~= 'function' then
        error('CreatorAccess options.isReady must be a function')
    end
end

function CreatorAccess.RegisterCommand(commandName, options)
    ValidateRegistration(commandName, options)

    RegisterCommand(commandName, function(commandSource)
        local source = tonumber(commandSource)
        if not source or source <= 0 then return end
        if options.isReady and not options.isReady() then return end

        if not Framework.HasPermission(source) then
            Framework.Notify(source, options.deniedMessage, 'error')
            return
        end

        options.open(source)
    end, false)
end
```

Keep the module server-only and do not add client-trusted state, permission
caches, or additional configuration.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
lua tests/test_creator_access.lua
```

Expected output:

```text
PASS test_creator_access
```

- [ ] **Step 5: Wire the real Farming Creator command through the gate**

In `client/main.lua`, replace the local command block with:

```lua
RegisterNetEvent('forge_farming:creator:open')
AddEventHandler('forge_farming:creator:open', function()
    OpenProjectListMenu()
end)
```

In `server/main.lua`, keep `EnsureCreatorPermission` unchanged for mutation
events and add the protected command registration after that helper:

```lua
CreatorAccess.RegisterCommand('farmingcreator', {
    deniedMessage = Locale('error_no_permission'),
    open = function(source)
        TriggerClientEvent('forge_farming:creator:open', source)
    end,
})
```

- [ ] **Step 6: Migrate the Consumables Creator command to the same gate**

In `server/modules/consumables.lua`, replace only the existing
`RegisterCommand(Config.Consumables.CreatorCommand, ...)` block with:

```lua
CreatorAccess.RegisterCommand(Config.Consumables.CreatorCommand, {
    isReady = IsReady,
    deniedMessage = CreatorErrorText('no_permission'),
    open = function(source)
        TriggerClientEvent(
            'forge_farming:consumables:openCreator',
            source,
            registry:Snapshot())
    end,
})
```

Do not change the existing Consumables mutation handlers or client open-event
handler.

- [ ] **Step 7: Load and document the shared gate**

In `fxmanifest.lua`, insert the shared server module before either consumer:

```lua
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/sv_config.lua',
    'server/creator_access.lua',
```

In the `1.5.0` `### Behoben` section of `CHANGELOG.md`, add:

```markdown
- **Creator-Admin-Gate**: `/farmingcreator` und `/consumablescreator` öffnen ihre Menüs nur nach einer gemeinsamen serverseitigen Prüfung über die konfigurierten ESX-/QBCore-Adminrechte. Abgewiesene Spieler erhalten „Keine Berechtigung“; alle Mutation-Checks bleiben erhalten.
```

Add affected-file rows for `server/creator_access.lua`,
`server/modules/consumables.lua`, `server/main.lua`, and
`tests/test_creator_access.lua`. Update the existing `client/main.lua` row so
its reason also names the authorized open event. Do not bump the version or
rewrite README behavior that is already accurate.

- [ ] **Step 8: Run focused and full verification**

Run:

```powershell
lua tests/test_creator_access.lua

$testFiles = @(
    'tests/test_version_utils.lua',
    'tests/test_version_check.lua',
    'tests/test_framework_hud.lua',
    'tests/test_consumable_speed.lua',
    'tests/test_creator_access.lua'
)
foreach ($testFile in $testFiles) {
    & lua $testFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

git diff --check 76ec7d0b8911cdbf9c1c6d18e7c47b6e3657ee4d..HEAD
git diff --check
git status --short
```

Expected: focused `PASS test_creator_access`, then five `PASS` lines, both
whitespace checks exit `0`, and only the files listed in this task are changed.

- [ ] **Step 9: Commit the verified security change**

Run:

```powershell
git add server/creator_access.lua tests/test_creator_access.lua fxmanifest.lua client/main.lua server/main.lua server/modules/consumables.lua CHANGELOG.md
git commit -m "fix: protect Creator menu commands"
```

Expected: one focused Conventional Commit containing the shared access gate,
both real command migrations, regression coverage, manifest loading, and the
1.5.0 changelog entry.

- [ ] **Step 10: Verify the committed branch range and clean worktree**

Run:

```powershell
git diff --check 76ec7d0b8911cdbf9c1c6d18e7c47b6e3657ee4d..HEAD
git status --short --branch
```

Expected: the branch-range whitespace check exits `0`; status contains only
the clean `fix/hud-notification-adapters` branch header and no file entries.
