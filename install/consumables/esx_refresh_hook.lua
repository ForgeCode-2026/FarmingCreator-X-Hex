AddEventHandler('forge_farming:refreshItems', function()
    if ESX and type(ESX.RefreshItems) == 'function' then
        ESX.RefreshItems()
    end
end)
