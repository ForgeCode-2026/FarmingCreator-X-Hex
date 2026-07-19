local currentMultiplier = 1

local function ResolveBoostMultiplier(now)
    for _, window in ipairs(Config.BoostWindows) do
        if window.from <= now and now < window.to then
            return window.multiplier
        end
    end
    return 1
end

function GetActiveBoostMultiplier()
    return currentMultiplier
end

CreateThread(function()
    while true do
        local newMultiplier = ResolveBoostMultiplier(os.date('%H:%M'))

        if newMultiplier ~= currentMultiplier then
            if currentMultiplier == 1 then
                Framework.Announce(string.format(Config.BoostStartAnnounce, newMultiplier))
            elseif newMultiplier == 1 then
                Framework.Announce(string.format(Config.BoostEndAnnounce, currentMultiplier))
            end
            currentMultiplier = newMultiplier
        end

        Wait(60000)
    end
end)

local activeSessions = {}

local function IsPlayerNearPoint(src, point)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local pointCoords = vector3(point.coords.x, point.coords.y, point.coords.z)
    local interactionDistance = (type(point.markerRadius) == 'number' and point.markerRadius > 0)
        and point.markerRadius or Config.InteractionDistance
    return #(playerCoords - pointCoords) <= interactionDistance
end

local function RollGatherAmount(project)
    local base = math.random(project.rawMinAmount, project.rawMaxAmount)
    local boosted = math.floor(base * GetActiveBoostMultiplier() + 0.5)
    return math.max(boosted, 1)
end

local function SendGatherWebhook(src, project, amount)
    SendDiscordWebhook(Config.Webhooks.sammeln, 'Sammeln', 3066993, {
        { name = 'Spieler', value = Framework.GetIdentifier(src) or 'unbekannt', inline = true },
        { name = 'Item', value = project.rawItem, inline = true },
        { name = 'Menge', value = tostring(amount), inline = true },
    })
end

local function ProcessGatherTick(src, point, project)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return false
    end

    if not IsPlayerNearPoint(src, point) then
        Framework.Notify(src, Locale('error_too_far'), 'error')
        return false
    end

    local amount = RollGatherAmount(project)
    if not Framework.CanCarryItem(src, project.rawItem, amount) then
        Framework.Notify(src, Locale('sammler_inventory_full'), 'error')
        return false
    end
    if not Framework.AddItem(src, project.rawItem, amount) then
        Framework.Notify(src, Locale('sammler_inventory_full'), 'error')
        return false
    end

    Framework.Notify(src, Locale('sammler_success', amount, project.rawItem), 'success')
    SendGatherWebhook(src, project, amount)
    return true
end

local function RunGatherLoop(src, session, point, project)
    while true do
        Wait(project.gatherDuration)

        if activeSessions[src] ~= session or session.cancelled then
            break
        end
        if not ProcessGatherTick(src, point, project) then
            break
        end
    end

    if activeSessions[src] == session then
        activeSessions[src] = nil
        Framework.ClearHelpNotify(src)
    end
end

RegisterNetEvent('forge_farming:sammler:start')
AddEventHandler('forge_farming:sammler:start', function(pointId)
    local src = source

    local point = GetFarmPoint(pointId)
    if not point or point.type ~= 'sammler' then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    if activeSessions[src] then
        return
    end

    if not IsPlayerNearPoint(src, point) then
        Framework.Notify(src, Locale('error_too_far'), 'error')
        return
    end

    local project = GetFarmProject(point.projectId)
    if not project then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local session = { pointId = pointId, cancelled = false }
    activeSessions[src] = session
    Framework.HelpNotify(src, 'X', Locale('sammler_help_cancel'))
    TriggerClientEvent('forge_farming:sammler:started', src, pointId)

    CreateThread(function()
        RunGatherLoop(src, session, point, project)
        if activeSessions[src] == nil then
            TriggerClientEvent('forge_farming:sammler:stopped', src)
        end
    end)
end)

RegisterNetEvent('forge_farming:sammler:cancel')
AddEventHandler('forge_farming:sammler:cancel', function()
    local src = source

    local session = activeSessions[src]
    if not session then
        return
    end

    activeSessions[src] = nil
    session.cancelled = true
    Framework.ClearHelpNotify(src)
    Framework.Notify(src, Locale('sammler_cancelled'), 'info')
    TriggerClientEvent('forge_farming:sammler:stopped', src)
end)

AddEventHandler('playerDropped', function()
    activeSessions[source] = nil
end)

CreateThread(function()
    while true do
        Wait(1000)
        for src, session in pairs(activeSessions) do
            local point = GetFarmPoint(session.pointId)
            if not point or not IsPlayerNearPoint(src, point) then
                activeSessions[src] = nil
                session.cancelled = true
                Framework.ClearHelpNotify(src)
                Framework.Notify(src, Locale('sammler_cancelled_distance'), 'error')
                TriggerClientEvent('forge_farming:sammler:stopped', src)
            end
        end
    end
end)
