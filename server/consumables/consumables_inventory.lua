ConsumablesInventory = {}

local HEX_REMOVE_TIMEOUT_MS = 5000

local function resolveCoreObjects()
    if Config.Framework == 'esx' then
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        return (ok and esx) or nil, nil
    end
    local ok, qbcore = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    return nil, (ok and qbcore) or nil
end

local function getFrameworkPlayer(esx, qbcore, source)
    if esx then return esx.GetPlayerFromId(source) end
    if qbcore then return qbcore.Functions.GetPlayer(source) end
    return nil
end

local function hexInventoryTarget(source)
    return { type = 'player', id = source }
end

local function hexGetCount(esx, qbcore, source, itemName)
    local player = getFrameworkPlayer(esx, qbcore, source)
    if not player then return 0 end
    local ok, inventory = pcall(function()
        return exports['hex_4_inventory']:GetInventory(player, hexInventoryTarget(source))
    end)
    if not ok or type(inventory) ~= 'table' then return 0 end
    local stacks = type(inventory.items) == 'table' and inventory.items or inventory
    local total = 0
    for key, item in pairs(stacks) do
        if type(item) == 'table' and (item.name or item.item or key) == itemName then
            total = total + (tonumber(item.count or item.amount or item.quantity) or 0)
        end
    end
    return total
end

local function hexRemove(esx, qbcore, source, itemName)
    local player = getFrameworkPlayer(esx, qbcore, source)
    if not player then return false end

    local result = promise.new()
    local resolved = false
    local function resolve(success)
        if resolved then return end
        resolved = true
        result:resolve(success ~= false)
    end

    local ok = pcall(function()
        exports['hex_4_inventory']:RemoveItemFromInventory(
            player, { name = itemName }, 1, hexInventoryTarget(source), resolve)
    end)
    if not ok then return false end

    SetTimeout(HEX_REMOVE_TIMEOUT_MS, function()
        resolve(false)
    end)
    return Citizen.Await(result)
end

local function oxGetCount(source, itemName)
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(source, 'count', itemName)
    end)
    if not ok then return 0 end
    return tonumber(count) or 0
end

local function oxRemove(source, itemName)
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(source, itemName, 1)
    end)
    return ok and removed == true
end

function ConsumablesInventory.New()
    local inventoryType = Config.Consumables.Inventory
    local esx, qbcore = resolveCoreObjects()
    local registered = {}
    local adapter = {}

    function adapter.GetCount(source, itemName)
        if inventoryType == 'ox_inventory' then
            return oxGetCount(source, itemName)
        end
        if inventoryType == 'hex_4_inventory' then
            return hexGetCount(esx, qbcore, source, itemName)
        end
        return Framework.GetItemCount(source, itemName)
    end

    function adapter.Remove(source, itemName)
        if inventoryType == 'ox_inventory' then
            return oxRemove(source, itemName)
        end
        if inventoryType == 'hex_4_inventory' then
            return hexRemove(esx, qbcore, source, itemName)
        end
        return Framework.RemoveItem(source, itemName, 1) == true
    end

    function adapter.RegisterUsable(itemName, callback)
        if inventoryType == 'ox_inventory' then return false end
        if registered[itemName] then return false end
        if esx then
            esx.RegisterUsableItem(itemName, callback)
        elseif qbcore then
            qbcore.Functions.CreateUseableItem(itemName, callback)
        else
            return false
        end
        registered[itemName] = true
        return true
    end

    return adapter
end
