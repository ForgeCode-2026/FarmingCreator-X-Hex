local registry
local useService
local inventory
local creatorService

local EXPIRY_GRACE_MS = 15000

local tokenCounter = 0
local function CreateToken()
    tokenCounter = tokenCounter + 1
    return ('use:%d:%d'):format(tokenCounter, GetGameTimer())
end

local function IsReady()
    return registry ~= nil and registry:IsReady() and useService ~= nil
end

local function LocaleOr(key, fallback)
    local text = Locale(key)
    if text == key then return fallback end
    return text
end

local BEGIN_ERROR_MESSAGES = {
    already_using = { 'consumables_already_using', 'Du benutzt bereits ein Item.' },
    cooldown_active = { 'consumables_cooldown', 'Bitte warte kurz, bevor du das Item erneut benutzt.' },
    missing_item = { 'consumables_missing_item', 'Du besitzt dieses Item nicht.' },
}

local CREATOR_ERROR_MESSAGES = {
    no_permission = { 'error_no_permission', 'Keine Berechtigung.' },
    creator_busy = { 'consumables_creator_busy', 'Der Creator speichert gerade, bitte kurz warten.' },
    duplicate_item = { 'consumables_duplicate_item', 'Dieses Item existiert bereits.' },
    unknown_item = { 'consumables_unknown_item', 'Dieses Item existiert nicht.' },
    database_error = { 'consumables_database_error', 'Speichern fehlgeschlagen, bitte erneut versuchen.' },
}

local CREATOR_SUCCESS_MESSAGES = {
    create = { 'consumables_creator_created', 'Consumable erstellt.' },
    update = { 'consumables_creator_updated', 'Consumable aktualisiert.' },
    delete = { 'consumables_creator_deleted', 'Consumable geloescht.' },
}

local function NotifyBeginError(src, errorCode)
    local entry = BEGIN_ERROR_MESSAGES[errorCode]
    if entry then
        Framework.Notify(src, LocaleOr(entry[1], entry[2]), 'error')
    end
end

local function CreatorErrorText(errorCode)
    local entry = CREATOR_ERROR_MESSAGES[errorCode]
    if entry then return LocaleOr(entry[1], entry[2]) end
    return LocaleOr('error_invalid_input', 'Ungueltige Eingabe.')
end

local function SyncTo(target)
    TriggerClientEvent('forge_farming:consumables:sync', target, registry:Snapshot())
end

local BeginUse

local function RegisterUsable(itemName)
    inventory.RegisterUsable(itemName, function(playerSource)
        BeginUse(playerSource, itemName)
    end)
end

BeginUse = function(src, itemName)
    if not IsReady() then return false end
    local result = useService:Begin(src, itemName)
    if not result.ok then
        if result.error ~= 'invalid_source' and result.error ~= 'unknown_item' then
            NotifyBeginError(src, result.error)
        end
        return false
    end
    TriggerClientEvent('forge_farming:consumables:start', src,
        result.token, result.itemName, result.definition)
    SetTimeout(result.duration + EXPIRY_GRACE_MS, function()
        useService:Expire(src, result.token)
    end)
    return true
end

local function LogMessage(message)
    print('[FarmingCreator] ' .. tostring(message))
end

MySQL.ready(function()
    local store = ConsumablesStore.New(MySQL, json)
    registry = ConsumablesRegistry.New(
        store, ConsumablesSchema, Config.AnimationPresets, Config.Items, LogMessage)
    if not registry:Initialize() then
        print('[FarmingCreator] consumables: Initialisierung fehlgeschlagen')
        return
    end
    inventory = ConsumablesInventory.New()
    useService = ConsumablesUseService.New({
        registry = registry,
        inventory = inventory,
        now = GetGameTimer,
        tokenFactory = CreateToken,
        completionToleranceMs = Config.Consumables.CompletionToleranceMs,
        defaultCooldownMs = Config.Consumables.DefaultCooldownMs,
        removeItem = Config.Consumables.RemoveItem,
    })
    creatorService = ConsumablesCreatorService.New({
        registry = registry,
        hasPermission = function(src) return Framework.HasPermission(src) end,
        logger = LogMessage,
    })
    for itemName in pairs(registry:Snapshot()) do
        RegisterUsable(itemName)
    end
    SyncTo(-1)
end)

RegisterNetEvent('forge_farming:consumables:requestSync')
AddEventHandler('forge_farming:consumables:requestSync', function()
    local src = source
    if not IsReady() then return end
    SyncTo(src)
end)

RegisterNetEvent('forge_farming:consumables:requestUse')
AddEventHandler('forge_farming:consumables:requestUse', function(itemName)
    local src = source
    if type(itemName) ~= 'string' then return end
    if Config.Consumables.Inventory ~= 'ox_inventory' then return end
    BeginUse(src, itemName)
end)

RegisterNetEvent('forge_farming:consumables:cancel')
AddEventHandler('forge_farming:consumables:cancel', function(token)
    local src = source
    if not IsReady() then return end
    useService:Cancel(src, token)
end)

RegisterNetEvent('forge_farming:consumables:complete')
AddEventHandler('forge_farming:consumables:complete', function(token)
    local src = source
    if not IsReady() then return end
    local result = useService:Complete(src, token)
    if result.ok then
        TriggerClientEvent('forge_farming:consumables:apply', src, result.itemName, result.definition)
    elseif result.error == 'remove_failed' then
        Framework.Notify(src,
            LocaleOr('consumables_remove_failed', 'Das Item konnte nicht entfernt werden.'), 'error')
    end
end)

local function FinishCreatorMutation(src, action, itemName, ok, errorCode)
    TriggerClientEvent('forge_farming:consumables:creator:result', src, action, ok == true, errorCode)
    if not ok then
        Framework.Notify(src, CreatorErrorText(errorCode), 'error')
        return
    end
    SyncTo(-1)
    if action == 'create' then
        local name = ConsumablesSchema.NormalizeItemName(itemName)
        if name then RegisterUsable(name) end
        TriggerEvent('forge_farming:refreshItems')
    end
    local entry = CREATOR_SUCCESS_MESSAGES[action]
    Framework.Notify(src, LocaleOr(entry[1], entry[2]), 'success')
end

RegisterNetEvent('forge_farming:consumables:creator:create')
AddEventHandler('forge_farming:consumables:creator:create', function(itemName, definition)
    local src = source
    if not IsReady() then return end
    if not Framework.HasPermission(src) then
        Framework.Notify(src, CreatorErrorText('no_permission'), 'error')
        return
    end
    local ok, errorCode = creatorService:Create(src, itemName, definition)
    FinishCreatorMutation(src, 'create', itemName, ok, errorCode)
end)

RegisterNetEvent('forge_farming:consumables:creator:update')
AddEventHandler('forge_farming:consumables:creator:update', function(itemName, definition)
    local src = source
    if not IsReady() then return end
    if not Framework.HasPermission(src) then
        Framework.Notify(src, CreatorErrorText('no_permission'), 'error')
        return
    end
    local ok, errorCode = creatorService:Update(src, itemName, definition)
    FinishCreatorMutation(src, 'update', itemName, ok, errorCode)
end)

RegisterNetEvent('forge_farming:consumables:creator:delete')
AddEventHandler('forge_farming:consumables:creator:delete', function(itemName)
    local src = source
    if not IsReady() then return end
    if not Framework.HasPermission(src) then
        Framework.Notify(src, CreatorErrorText('no_permission'), 'error')
        return
    end
    local ok, errorCode = creatorService:Delete(src, itemName)
    FinishCreatorMutation(src, 'delete', itemName, ok, errorCode)
end)

RegisterCommand(Config.Consumables.CreatorCommand, function(commandSource)
    local src = commandSource
    if not src or src <= 0 then return end
    if not IsReady() then return end
    if not Framework.HasPermission(src) then
        Framework.Notify(src, CreatorErrorText('no_permission'), 'error')
        return
    end
    TriggerClientEvent('forge_farming:consumables:openCreator', src, registry:Snapshot())
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    if useService then useService:Clear(src) end
end)

exports('UseConsumable', function(playerSource, itemName)
    if type(itemName) ~= 'string' then return false end
    return BeginUse(playerSource, itemName)
end)
