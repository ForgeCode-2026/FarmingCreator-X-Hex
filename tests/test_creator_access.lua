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
