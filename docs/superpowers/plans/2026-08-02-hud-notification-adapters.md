# HUD Notification Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route `fc_hud` and all requested HEX HUD notifications with the exact title, message, type, timeout, and help-message positions expected by each API.

**Architecture:** Preserve server and network-event contracts, then normalize values at the client HUD boundary. Use operation-specific HEX resource lists and explicit Lua method calls (`:`); keep `fc_hud` in a separate event adapter and retain native fallbacks.

**Tech Stack:** FiveM Lua 5.4, native FiveM events/exports, standalone Lua regression tests.

## Global Constraints

- Keep `Framework.Notify(source, message, notifyType, title)` unchanged on the server.
- Keep `forge_farming:notify(message, notifyType, title)` unchanged on the network.
- Use `Framework.Notify(title, message, notifyType, timeout)` on the client.
- Use `exports[resourceName]:Notify(title, message, notifyType, timeout)` for HEX HUDs.
- Use `exports[resourceName]:HelpNotify(cleanMessage)` for HEX HUDs.
- Preserve the existing `fc_hud` event contracts.
- Replace `~INPUT_PICKUP~` with `E` in help messages.
- Add no dependencies and do not push directly to `main`.
- Write the regression test first and observe the expected failure before editing production code.

## File Map

- Modify `tests/test_framework_hud.lua`: model FiveM method-call semantics and assert every HUD contract, argument position, resource priority, and fallback.
- Modify `framework/init.lua`: implement operation-specific adapters and client-side normalization without changing server business APIs.
- Reference `docs/superpowers/specs/2026-08-02-hud-notification-adapters-design.md`: approved behavior and non-goals.

---

### Task 1: Correct all HUD boundary adapters

**Files:**
- Modify: `tests/test_framework_hud.lua:1-180`
- Modify: `framework/init.lua:176-325`
- Reference: `docs/superpowers/specs/2026-08-02-hud-notification-adapters-design.md`

**Interfaces:**
- Consumes: server event payload `forge_farming:notify(message, notifyType, title)` and existing calls to `Framework.HelpNotify(key, message)`, `Framework.Announce(message, title, duration)`, `Framework.StartProgress(message, duration)`, and `Framework.StopProgress()`.
- Produces: client `Framework.Notify(title, message, notifyType, timeout)` plus exact HEX export and `fc_hud` event calls defined in Global Constraints.

- [ ] **Step 1: Rewrite the HUD regression assertions before production code**

In `tests/test_framework_hud.lua`, make the export proxy require method-call
syntax by preserving the resource proxy as `self`:

```lua
exports = setmetatable({}, {
    __index = function(_, resourceName)
        local resourceExports = {}
        return setmetatable(resourceExports, {
            __index = function(_, methodName)
                return function(self, ...)
                    assert(self == resourceExports,
                        ('%s muss mit Methodensyntax aufgerufen werden'):format(methodName))
                    RecordExport(resourceName, methodName, ...)
                end
            end,
        })
    end,
})
```

Strengthen `AssertExport` so an extra help-key argument fails:

```lua
local function AssertExport(resourceName, methodName, expectedArgs)
    local call = calls[1]
    assert(call, 'HUD-Aufruf fehlt')
    AssertEqual(call.kind, 'export', 'Aufrufart')
    AssertEqual(call.resource, resourceName, 'Resource')
    AssertEqual(call.method, methodName, 'Export')
    AssertEqual(#call.args, #expectedArgs, 'Argumentanzahl')
    for index, expected in ipairs(expectedArgs) do
        AssertEqual(call.args[index], expected, ('Argument %d'):format(index))
    end
end
```

Replace the notification resource list with the approved order:

```lua
local notifyHudResources = {
    'hex_1_hud',
    'hex_2_hud',
    'hex_4_hud',
    'hex_final_hud',
    'hex_future_hud',
    'hex_hud',
    'hex_hud_prem',
    'hex_finalhud_v2',
    'hex_genesis_hud',
}
```

For every entry, call and assert title-first notification arguments:

```lua
Framework.Notify('Titel', 'Nachricht', 'success', 5000)
AssertExport(resourceName, 'Notify', { 'Titel', 'Nachricht', 'success', 5000 })
```

Add the approved help-only resource order and assert one cleaned argument:

```lua
local helpHudResources = {
    'hex_2_hud',
    'hex_4_hud',
    'hex_final_hud',
    'hex_future_hud',
    'hex_hud_prem',
    'hex_finalhud_v2',
    'hex_genesis_hud',
}

for _, resourceName in ipairs(helpHudResources) do
    startedResource = resourceName
    ResetCalls()
    Framework.HelpNotify('E', '~INPUT_PICKUP~ Benutzen')
    AssertExport(resourceName, 'HelpNotify', { 'E Benutzen' })
end
```

Keep dedicated `fc_hud` assertions, but call the new client notification
signature and verify its legacy event mapping:

```lua
startedResource = 'fc_hud'
Framework.Notify('Konsum', 'Konsumiert', 'success', 6000)
AssertEqual(calls[1].args[1], 'success', 'FC Notify Typ')
AssertEqual(calls[1].args[2], 'Konsum', 'FC Notify Titel')
AssertEqual(calls[1].args[3], 'Konsumiert', 'FC Notify Text')
AssertEqual(calls[1].args[4], 6000, 'FC Notify Dauer')
```

Add stubs and assertions for the supplied native fallback functions:

```lua
function AddTextEntry(_, message)
    calls[#calls + 1] = { kind = 'fallback', method = 'help', message = message }
end

function DisplayHelpTextThisFrame()
end

function SetNotificationTextEntry()
    calls[#calls + 1] = { kind = 'fallback', method = 'notify' }
end

function DrawNotification()
end
```

Retain the existing announce/progress assertions for every notification HUD;
the method-aware proxy now verifies `Announce`, `StartProgressbar`, and
`StopProgressbar` also use `:` syntax.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
lua tests/test_framework_hud.lua
```

Expected: FAIL because the current dynamic dot-call is rejected or falls back
instead of recording a HEX export. A failure caused by syntax, missing stubs,
or test setup must be corrected before proceeding; do not edit production code
until the failure demonstrates the adapter mismatch.

- [ ] **Step 3: Implement the minimal operation-specific adapters**

In the client half of `framework/init.lua`, replace the single HUD list with:

```lua
local NOTIFY_HUD_RESOURCES = {
    'hex_1_hud',
    'hex_2_hud',
    'hex_4_hud',
    'hex_final_hud',
    'hex_future_hud',
    'hex_hud',
    'hex_hud_prem',
    'hex_finalhud_v2',
    'hex_genesis_hud',
}

local HELP_HUD_RESOURCES = {
    'hex_2_hud',
    'hex_4_hud',
    'hex_final_hud',
    'hex_future_hud',
    'hex_hud_prem',
    'hex_finalhud_v2',
    'hex_genesis_hud',
}
```

Replace the generic method-name dispatcher with a callback router:

```lua
local function TryHudCall(resourceNames, callback)
    for _, resourceName in ipairs(resourceNames) do
        if IsResourceStarted(resourceName)
            and pcall(callback, resourceName) then
            return resourceName
        end
    end
    return nil
end
```

Implement the two user-facing adapters with exact external signatures:

```lua
function Framework.HelpNotify(key, message)
    local safeKey = tostring(key or 'E')
    local cleanMessage = tostring(message or ''):gsub('~INPUT_PICKUP~', 'E')

    if IsResourceStarted('fc_hud') then
        TriggerEvent('fc_hud:helpNotify', safeKey, cleanMessage)
        return
    end

    local resourceName = TryHudCall(HELP_HUD_RESOURCES, function(hudResource)
        exports[hudResource]:HelpNotify(cleanMessage)
    end)
    if resourceName then return end
    DrawFallbackHelp(cleanMessage)
end

function Framework.Notify(title, message, notifyType, timeout)
    local safeTitle = tostring(title or 'Farming')
    local safeMessage = tostring(message or '')
    local safeType = tostring(notifyType or 'info')
    local safeTimeout = tonumber(timeout) or 5000

    if IsResourceStarted('fc_hud') then
        TriggerEvent('fc_hud:notify', safeType, safeTitle, safeMessage, safeTimeout)
        return
    end

    local resourceName = TryHudCall(NOTIFY_HUD_RESOURCES, function(hudResource)
        exports[hudResource]:Notify(safeTitle, safeMessage, safeType, safeTimeout)
    end)
    if resourceName then return end
    DrawFallbackNotify(safeTitle, safeMessage)
end
```

Use explicit method calls for auxiliary operations:

```lua
TryHudCall(HELP_HUD_RESOURCES, function(hudResource)
    exports[hudResource]:HideHelpNotify()
end)

TryHudCall(NOTIFY_HUD_RESOURCES, function(hudResource)
    exports[hudResource]:Announce(safeTitle, safeMessage, safeDuration)
end)

activeProgressResource = TryHudCall(NOTIFY_HUD_RESOURCES, function(hudResource)
    exports[hudResource]:StartProgressbar(safeDuration, safeMessage)
end)
```

Stop progress with the same explicit method contract:

```lua
if resourceName and IsResourceStarted(resourceName)
    and pcall(function()
        exports[resourceName]:StopProgressbar()
    end) then
    return
end
```

Replace the native fallbacks with the supplied API shape:

```lua
local function DrawFallbackHelp(message)
    AddTextEntry('hex_farmingcreator_help', message)
    DisplayHelpTextThisFrame('hex_farmingcreator_help', false)
end

local function DrawFallbackNotify(title, message)
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(('%s: %s'):format(title, message))
    DrawNotification(false, true)
end
```

Finally, preserve the network payload while mapping it into the new client
signature:

```lua
AddEventHandler('forge_farming:notify', function(message, notifyType, title)
    DebugPrint('Notify empfangen:', message, '(' .. tostring(notifyType) .. ')')
    Framework.Notify(title, message, notifyType, 5000)
end)
```

Do not change the server half of `framework/init.lua` or any server call site.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```powershell
lua tests/test_framework_hud.lua
```

Expected output:

```text
PASS test_framework_hud
```

- [ ] **Step 5: Run the full regression and repository checks**

Run:

```powershell
$testFiles = @(
    'tests/test_version_utils.lua',
    'tests/test_version_check.lua',
    'tests/test_framework_hud.lua',
    'tests/test_consumable_speed.lua'
)
foreach ($testFile in $testFiles) {
    & lua $testFile
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
git diff --check
git status --short
```

Expected: four `PASS` lines, `git diff --check` exit code `0`, and only
`framework/init.lua`, `tests/test_framework_hud.lua`, plus this already
committed plan file in branch history.

- [ ] **Step 6: Commit the verified implementation**

Run:

```powershell
git add framework/init.lua tests/test_framework_hud.lua
git commit -m "fix: correct HUD notification adapters"
```

Expected: one focused Conventional Commit containing the production adapter
change and its regression coverage.

