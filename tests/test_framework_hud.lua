local calls = {}
local startedResources = {}
local failedExports = {}
local exportAttempts = {}
local eventHandlers = {}
local createdThreads = {}

Config = {}

function IsDuplicityVersion()
    return false
end

function DebugPrint()
end

function GetResourceState(resourceName)
    if startedResources[resourceName] then return 'started' end
    return 'missing'
end

function RegisterNetEvent()
end

function AddEventHandler(eventName, callback)
    eventHandlers[eventName] = callback
end

function CreateThread(callback)
    createdThreads[#createdThreads + 1] = callback
end

function Wait()
end

function TriggerEvent(name, ...)
    calls[#calls + 1] = {
        kind = 'event',
        resource = name:match('^([^:]+)'),
        method = name:match('^[^:]+:(.+)$'),
        args = { ... },
    }
end

local function RecordExport(resourceName, methodName, ...)
    calls[#calls + 1] = {
        kind = 'export',
        resource = resourceName,
        method = methodName,
        args = { ... },
    }
end

exports = setmetatable({}, {
    __index = function(_, resourceName)
        local resourceExports = {}
        return setmetatable(resourceExports, {
            __index = function(_, methodName)
                return function(self, ...)
                    assert(self == resourceExports,
                        ('%s muss mit Methodensyntax aufgerufen werden'):format(methodName))
                    local exportName = ('%s:%s'):format(resourceName, methodName)
                    exportAttempts[exportName] = (exportAttempts[exportName] or 0) + 1
                    if failedExports[exportName] then
                        error(('Export fehlgeschlagen: %s'):format(exportName))
                    end
                    RecordExport(resourceName, methodName, ...)
                end
            end,
        })
    end,
})

function AddTextEntry(_, message)
    calls[#calls + 1] = { kind = 'fallback', method = 'help', message = message }
end

local function SetStartedResources(...)
    startedResources = {}
    for _, resourceName in ipairs({ ... }) do
        startedResources[resourceName] = true
    end
end

function DisplayHelpTextThisFrame()
end

function SetNotificationTextEntry()
    calls[#calls + 1] = { kind = 'fallback', method = 'notify' }
end

function AddTextComponentSubstringPlayerName(message)
    calls[#calls + 1] = { kind = 'fallback', method = 'text', text = message }
end

function DrawNotification()
end

function BeginTextCommandBusyspinnerOn()
    calls[#calls + 1] = { kind = 'fallback', method = 'progress' }
end

function EndTextCommandBusyspinnerOn()
end

function BusyspinnerOff()
    calls[#calls + 1] = { kind = 'fallback', method = 'stopProgress' }
end

local function ResetCalls()
    calls = {}
    exportAttempts = {}
end

local function AssertEqual(actual, expected, message)
    assert(actual == expected, ('%s: erwartet %s, erhalten %s'):format(
        message, tostring(expected), tostring(actual)))
end

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

dofile('framework/init.lua')

SetStartedResources('fc_hud')
Framework.HelpNotify('E', 'Sammeln')
AssertEqual(calls[1].kind, 'event', 'FC HelpNotify Aufrufart')
AssertEqual(calls[1].resource, 'fc_hud', 'FC HelpNotify Resource')
AssertEqual(calls[1].method, 'helpNotify', 'FC HelpNotify Event')
AssertEqual(calls[1].args[1], 'E', 'FC HelpNotify Taste')
AssertEqual(calls[1].args[2], 'Sammeln', 'FC HelpNotify Text')

ResetCalls()
Framework.Notify('Konsum', 'Konsumiert', 'success', 6000)
AssertEqual(calls[1].method, 'notify', 'FC Notify Event')
AssertEqual(calls[1].args[1], 'success', 'FC Notify Typ')
AssertEqual(calls[1].args[2], 'Konsum', 'FC Notify Titel')
AssertEqual(calls[1].args[3], 'Konsumiert', 'FC Notify Text')
AssertEqual(calls[1].args[4], 6000, 'FC Notify Dauer')

SetStartedResources('fc_hud', 'hex_1_hud')
ResetCalls()
Framework.Notify('Prioritaet', 'FC zuerst', 'info', 5000)
AssertEqual(calls[1].kind, 'event', 'FC vor HEX')
AssertEqual(calls[1].resource, 'fc_hud', 'FC Prioritaet Resource')

SetStartedResources('hex_1_hud', 'hex_2_hud')
ResetCalls()
Framework.Notify('Prioritaet', 'Erster HEX', 'info', 5000)
AssertExport('hex_1_hud', 'Notify', { 'Prioritaet', 'Erster HEX', 'info', 5000 })

failedExports['hex_1_hud:Notify'] = true
ResetCalls()
Framework.Notify('Fallback', 'Zweiter HEX', 'info', 5000)
AssertEqual(exportAttempts['hex_1_hud:Notify'], 1, 'Fehlender erster HEX Versuch')
AssertExport('hex_2_hud', 'Notify', { 'Fallback', 'Zweiter HEX', 'info', 5000 })
failedExports['hex_1_hud:Notify'] = nil

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

for _, resourceName in ipairs(notifyHudResources) do
    SetStartedResources(resourceName)

    ResetCalls()
    Framework.Notify('Titel', 'Nachricht', 'success', 5000)
    AssertExport(resourceName, 'Notify', { 'Titel', 'Nachricht', 'success', 5000 })

    ResetCalls()
    Framework.Announce('Servermeldung', 'Farming', 8000)
    AssertExport(resourceName, 'Announce', { 'Farming', 'Servermeldung', 8000 })

    ResetCalls()
    Framework.StartProgress('Verarbeitung', 3500)
    AssertExport(resourceName, 'StartProgressbar', { 3500, 'Verarbeitung' })

    ResetCalls()
    Framework.StopProgress()
    AssertExport(resourceName, 'StopProgressbar', {})
end

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
    SetStartedResources(resourceName)
    ResetCalls()
    Framework.HelpNotify('E', '~INPUT_PICKUP~ Benutzen')
    AssertExport(resourceName, 'HelpNotify', { 'E Benutzen' })
end

SetStartedResources()
ResetCalls()
Framework.HelpNotify('E', 'Fallback')
AssertEqual(calls[1].kind, 'fallback', 'Help-Fallback')
AssertEqual(calls[1].method, 'help', 'Help-Fallback Methode')
AssertEqual(calls[1].message, 'Fallback', 'Help-Fallback Text')

ResetCalls()
Framework.Notify('Farming', 'Fallback', 'info', 5000)
AssertEqual(calls[1].method, 'notify', 'Notify-Fallback')
AssertEqual(calls[2].method, 'text', 'Notify-Fallback Text Aufruf')
AssertEqual(calls[2].text, 'Farming: Fallback', 'Notify-Fallback Text')

ResetCalls()
Framework.Announce('Fallback-Ankuendigung', 'Farming', 5000)
AssertEqual(calls[1].method, 'notify', 'Announce-Fallback')
AssertEqual(calls[2].text, 'Farming: Fallback-Ankuendigung', 'Announce-Fallback Text')

SetStartedResources('hex_2_hud')
ResetCalls()
Framework.ClearHelpNotify()
AssertExport('hex_2_hud', 'HideHelpNotify', {})

SetStartedResources('hex_1_hud')
ResetCalls()
Framework.StartProgress('Fallback', 1000)
AssertExport('hex_1_hud', 'StartProgressbar', { 1000, 'Fallback' })

SetStartedResources()
ResetCalls()
Framework.StopProgress()
AssertEqual(calls[1].method, 'stopProgress', 'StopProgress-Fallback')

SetStartedResources('hex_1_hud')
ResetCalls()
eventHandlers['forge_farming:notify']('Netzwerk Nachricht', 'warning', 'Netzwerk Titel')
AssertExport('hex_1_hud', 'Notify', { 'Netzwerk Titel', 'Netzwerk Nachricht', 'warning', 5000 })

print('PASS test_framework_hud')
