if IsDuplicityVersion() then
    Framework = {}

    local ESX, QBCore

    if Config.Framework == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    else
        QBCore = exports['qb-core']:GetCoreObject()
    end

    local function GetPlayer(source)
        if Config.Framework == 'esx' then
            return ESX.GetPlayerFromId(source)
        end
        return QBCore.Functions.GetPlayer(source)
    end

    function Framework.GetIdentifier(source)
        local player = GetPlayer(source)
        if not player then return nil end

        if Config.Framework == 'esx' then
            return player.getIdentifier()
        end
        return player.PlayerData.citizenid
    end

    function Framework.AddItem(source, item, amount)
        local player = GetPlayer(source)
        if not player then return false end

        if Config.Framework == 'esx' then
            if string.match(item, '^[Ww][Ee][Aa][Pp][Oo][Nn]_') then
                player.addWeapon(string.upper(item), 0)
                return true
            end
            if not player.getInventoryItem(item) then return false end
            player.addInventoryItem(item, amount)
            return true
        end

        return player.Functions.AddItem(item, amount) == true
    end

    function Framework.CanCarryItem(source, item, amount)
        local player = GetPlayer(source)
        if not player then return false end

        if Config.Framework == 'esx' then
            if string.match(item, '^[Ww][Ee][Aa][Pp][Oo][Nn]_') then
                return true
            end
            if not player.canCarryItem then return true end
            return player.canCarryItem(item, amount) == true
        end

        if not player.Functions.CanCarryItem then return true end
        return player.Functions.CanCarryItem(item, amount) == true
    end

    function Framework.RemoveItem(source, item, amount)
        local player = GetPlayer(source)
        if not player then return false end

        if Config.Framework == 'esx' then
            local invItem = player.getInventoryItem(item)
            if not invItem or invItem.count < amount then return false end
            player.removeInventoryItem(item, amount)
            return true
        end

        local invItem = player.Functions.GetItemByName(item)
        if not invItem or invItem.amount < amount then return false end
        return player.Functions.RemoveItem(item, amount) == true
    end

    function Framework.GetItemCount(source, item)
        local player = GetPlayer(source)
        if not player then return 0 end

        if Config.Framework == 'esx' then
            local invItem = player.getInventoryItem(item)
            return invItem and invItem.count or 0
        end

        local invItem = player.Functions.GetItemByName(item)
        return invItem and invItem.amount or 0
    end

    function Framework.AddMoney(source, amount, account)
        local player = GetPlayer(source)
        if not player then return false end

        if Config.Framework == 'esx' then
            if account == 'cash' then
                player.addMoney(amount)
                return true
            end
            if not player.getAccount(account) then return false end
            player.addAccountMoney(account, amount)
            return true
        end

        return player.Functions.AddMoney(account, amount) == true
    end

    function Framework.HasPermission(source)
        local allowed

        if Config.Framework == 'esx' then
            local player = GetPlayer(source)
            if not player then
                DebugPrint('HasPermission: kein ESX-Player-Objekt fuer source', source)
                return false
            end

            local group = player.getGroup()
            allowed = false
            for _, allowedGroup in ipairs(Config.ESXAdminGroups) do
                if allowedGroup == group then allowed = true end
            end
            DebugPrint('HasPermission (ESX): source', source, 'group', group, 'allowed', allowed)
            return allowed
        end

        if QBCore.Functions.HasPermission then
            allowed = QBCore.Functions.HasPermission(source, Config.QBPermissionLevel) == true
        else
            allowed = QBCore.Functions.GetPermission(source) == Config.QBPermissionLevel
        end
        DebugPrint('HasPermission (QBCore): source', source, 'allowed', allowed)
        return allowed
    end

    function Framework.GetSourceFromIdentifier(identifier)
        for _, playerId in ipairs(GetPlayers()) do
            local candidate = tonumber(playerId)
            if Framework.GetIdentifier(candidate) == identifier then
                return candidate
            end
        end
        return nil
    end

    function Framework.IsPlayerOnline(identifier)
        return Framework.GetSourceFromIdentifier(identifier) ~= nil
    end

    function Framework.Notify(source, message, notifyType, title)
        DebugPrint('Notify -> source', source, ':', message, '(' .. tostring(notifyType) .. ')')
        TriggerClientEvent('forge_farming:notify', source, message, notifyType, title)
    end

    function Framework.HelpNotify(source, key, message)
        TriggerClientEvent('forge_farming:helpNotify', source, key, message)
    end

    function Framework.ClearHelpNotify(source)
        TriggerClientEvent('forge_farming:clearHelpNotify', source)
    end

    function Framework.Announce(message, title, duration)
        TriggerClientEvent('forge_farming:announce', -1, message, title, duration)
    end

    if Config.Framework == 'esx' then
        AddEventHandler('esx:playerLoaded', function(playerId)
            TriggerEvent('forge_farming:playerLoaded', playerId)
        end)
    else
        AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
            TriggerEvent('forge_farming:playerLoaded', player.PlayerData.source)
        end)
    end
else
    Framework = {}

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

    local currentHelpNotify = nil
    local activeProgressResource = nil

    local function IsResourceStarted(resourceName)
        return GetResourceState(resourceName) == 'started'
    end

    local function TryHudCall(resourceNames, callback)
        for _, resourceName in ipairs(resourceNames) do
            if IsResourceStarted(resourceName)
                and pcall(callback, resourceName) then
                return resourceName
            end
        end
        return nil
    end

    local function DrawFallbackHelp(message)
        AddTextEntry('hex_farmingcreator_help', message)
        DisplayHelpTextThisFrame('hex_farmingcreator_help', false)
    end

    local function DrawFallbackNotify(title, message)
        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName(('%s: %s'):format(title, message))
        DrawNotification(false, true)
    end

    local function StartFallbackProgress(message)
        BeginTextCommandBusyspinnerOn('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandBusyspinnerOn(4)
    end

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

    function Framework.ClearHelpNotify()
        currentHelpNotify = nil
        TryHudCall(HELP_HUD_RESOURCES, function(hudResource)
            exports[hudResource]:HideHelpNotify()
        end)
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

    function Framework.Announce(message, title, duration)
        local safeMessage = tostring(message or '')
        local safeTitle = tostring(title or 'Farming')
        local safeDuration = tonumber(duration) or 8000

        if IsResourceStarted('fc_hud') then
            TriggerEvent('fc_hud:announce', 'Farming', safeTitle, safeMessage, safeDuration)
            return
        end
        if TryHudCall(NOTIFY_HUD_RESOURCES, function(hudResource)
            exports[hudResource]:Announce(safeTitle, safeMessage, safeDuration)
        end) then return end
        DrawFallbackNotify(safeTitle, safeMessage)
    end

    function Framework.StartProgress(message, duration)
        local safeMessage = tostring(message or '')
        local safeDuration = math.max(0, tonumber(duration) or 0)
        activeProgressResource = TryHudCall(NOTIFY_HUD_RESOURCES, function(hudResource)
            exports[hudResource]:StartProgressbar(safeDuration, safeMessage)
        end)
        if activeProgressResource then return end
        StartFallbackProgress(safeMessage)
    end

    function Framework.StopProgress()
        local resourceName = activeProgressResource
        activeProgressResource = nil

        if resourceName and IsResourceStarted(resourceName)
            and pcall(function()
                exports[resourceName]:StopProgressbar()
            end) then
            return
        end
        BusyspinnerOff()
    end

    CreateThread(function()
        while true do
            if currentHelpNotify then
                Framework.HelpNotify(currentHelpNotify.key, currentHelpNotify.message)
                Wait(0)
            else
                Wait(500)
            end
        end
    end)

    RegisterNetEvent('forge_farming:notify')
    AddEventHandler('forge_farming:notify', function(message, notifyType, title)
        DebugPrint('Notify empfangen:', message, '(' .. tostring(notifyType) .. ')')
        Framework.Notify(title, message, notifyType, 5000)
    end)

    RegisterNetEvent('forge_farming:helpNotify')
    AddEventHandler('forge_farming:helpNotify', function(key, message)
        currentHelpNotify = { key = key, message = message }
    end)

    RegisterNetEvent('forge_farming:clearHelpNotify')
    AddEventHandler('forge_farming:clearHelpNotify', function()
        Framework.ClearHelpNotify()
    end)

    RegisterNetEvent('forge_farming:announce')
    AddEventHandler('forge_farming:announce', function(message, title, duration)
        Framework.Announce(message, title, duration)
    end)
end
