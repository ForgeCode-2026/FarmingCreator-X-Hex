local function FindSellPriceRange(project, item)
    for _, entry in ipairs(project.sellPrices) do
        if entry.item == item then
            return entry.minPrice, entry.maxPrice
        end
    end
    return nil, nil
end

local function IsPositiveInteger(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function IsPlayerNearPoint(src, point)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local pointCoords = vector3(point.coords.x, point.coords.y, point.coords.z)
    return #(playerCoords - pointCoords) <= Config.InteractionDistance
end

RegisterNetEvent('forge_farming:verkaeufer:getSellableItems')
AddEventHandler('forge_farming:verkaeufer:getSellableItems', function(pointId)
    local src = source

    local list = {}
    local point = GetFarmPoint(pointId)
    if not point or point.type ~= 'verkaeufer' then
        TriggerClientEvent('forge_farming:verkaeufer:sellableItems', src, list)
        return
    end

    local project = GetFarmProject(point.projectId)
    if not project then
        TriggerClientEvent('forge_farming:verkaeufer:sellableItems', src, list)
        return
    end

    for _, entry in ipairs(project.sellPrices) do
        local count = Framework.GetItemCount(src, entry.item)
        if count > 0 then
            list[#list + 1] = { item = entry.item, minPrice = entry.minPrice, maxPrice = entry.maxPrice, count = count }
        end
    end

    TriggerClientEvent('forge_farming:verkaeufer:sellableItems', src, list)
end)

RegisterNetEvent('forge_farming:verkaeufer:sell')
AddEventHandler('forge_farming:verkaeufer:sell', function(pointId, item, amount)
    local src = source

    local point = GetFarmPoint(pointId)
    if not point or point.type ~= 'verkaeufer' then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
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

    local minPrice, maxPrice = FindSellPriceRange(project, item)
    if not minPrice then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    if not IsPositiveInteger(amount) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    if Framework.GetItemCount(src, item) < amount then
        Framework.Notify(src, Locale('verkaeufer_not_enough_items'), 'error')
        return
    end

    if not Framework.RemoveItem(src, item, amount) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local pricePerUnit = math.random(math.floor(minPrice), math.floor(maxPrice))
    local totalPrice = pricePerUnit * amount
    Framework.AddMoney(src, totalPrice, point.payoutAccount or Config.DefaultPayoutAccount)

    SendDiscordWebhook(Config.Webhooks.verkaufen, 'Verkauf', 15844367, {
        { name = 'Spieler', value = Framework.GetIdentifier(src) or 'unbekannt', inline = true },
        { name = 'Item', value = item, inline = true },
        { name = 'Menge', value = tostring(amount), inline = true },
        { name = 'Erloes', value = '$' .. tostring(totalPrice), inline = true },
    })

    Framework.Notify(src, Locale('verkaeufer_sold_success', amount, item, totalPrice), 'success')

    if point.payoutAccount == 'black_money' and point.policeAlert and SendPoliceAlert then
        local chance = (Config.PoliceAlert and Config.PoliceAlert.chance) or 100
        if math.random(1, 100) <= chance then
            SendPoliceAlert(src, vector3(point.coords.x, point.coords.y, point.coords.z), {
                item = item,
                amount = amount,
                pointId = point.id,
            })
        end
    end
end)
