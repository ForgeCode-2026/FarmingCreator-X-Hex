
local requestCounter = 0
local pendingRequest = nil
local syncCounter = 0

local OpenItemListMenu, OpenDraftMenu, OpenDeleteConfirmMenu

local MUTATION_EVENTS = {
    create = 'forge_farming:consumables:creator:create',
    update = 'forge_farming:consumables:creator:update',
    delete = 'forge_farming:consumables:creator:delete',
}

local SECTION_EDITORS = {
    basics = 'EditBasics',
    consume = 'EditConsume',
    animation = 'EditAnimation',
    effects = 'EditEffects',
    hallucination = 'EditHallucination',
}

local function Notify(message, notifyType)
    TriggerEvent('forge_farming:notify', message, notifyType or 'info', 'Creator')
end

local function Escape(value)
    return ConsumablesCreatorFields.EscapeHtml(value)
end

local LocaleOr = ConsumablesCreatorFields.LocaleOr

local function IsStale(sessionGen)
    return sessionGen ~= ConsumablesCreatorFields.CurrentGeneration()
end

local function GetSortedItemNames()
    local names = {}
    for name in pairs(Config.Items or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

RegisterNetEvent('forge_farming:consumables:sync')
AddEventHandler('forge_farming:consumables:sync', function()
    syncCounter = syncCounter + 1
end)

local function WaitForSync(baseline)
    local deadline = GetGameTimer() + 2000
    while syncCounter == baseline and GetGameTimer() < deadline do
        Wait(50)
    end
end

local function SendMutation(action, itemName, definition)
    if pendingRequest then
        Notify(LocaleOr('consumables_creator_busy', 'Es laeuft bereits eine Speicherung.'), 'error')
        return { ok = false, busy = true }
    end
    requestCounter = requestCounter + 1
    local request = { id = requestCounter, action = action, resultPromise = promise.new() }
    pendingRequest = request
    TriggerServerEvent(MUTATION_EVENTS[action], itemName, definition)
    SetTimeout(Config.Consumables.RequestTimeoutMs, function()
        if pendingRequest ~= request then return end
        pendingRequest = nil
        request.resultPromise:resolve({ ok = false, timedOut = true })
    end)
    return Citizen.Await(request.resultPromise)
end

RegisterNetEvent('forge_farming:consumables:creator:result')
AddEventHandler('forge_farming:consumables:creator:result', function(action, ok)
    local request = pendingRequest
    if not request or request.action ~= action then return end
    pendingRequest = nil
    request.resultPromise:resolve({ ok = ok == true })
end)

local function DescribeAnimation(consume)
    local animation = consume.animation
    if type(animation) == 'string' then
        return LocaleOr('consumables_animation_preset', 'Preset: %s', Escape(animation))
    end
    if type(animation) == 'table' and animation.scenario then
        return LocaleOr('consumables_describe_scenario', 'Szenario: %s', Escape(animation.scenario))
    end
    if type(animation) == 'table' then
        return LocaleOr('consumables_describe_anim', 'Anim: %s / %s',
            Escape(tostring(animation.dict)), Escape(tostring(animation.clip)))
    end
    return LocaleOr('consumables_none', 'Keine')
end

local function FormatSeconds(ms)
    return ConsumablesCreatorFields.FormatSeconds(ms)
end

local function DescribeEffects(effects)
    local parts = {}
    if (effects.duration or 0) > 0 then parts[#parts + 1] = LocaleOr('consumables_describe_effect_duration', 'Dauer %s s', FormatSeconds(effects.duration)) end
    if effects.health then parts[#parts + 1] = LocaleOr('consumables_describe_health', '+%d Leben', effects.health) end
    if effects.armor then parts[#parts + 1] = LocaleOr('consumables_describe_armor', '+%d Ruestung', effects.armor) end
    if effects.speed then parts[#parts + 1] = LocaleOr('consumables_describe_speed', 'Tempo %.2f', effects.speed) end
    if effects.stamina then parts[#parts + 1] = LocaleOr('consumables_describe_stamina', 'Ausdauer') end
    if #parts == 0 then return LocaleOr('consumables_none', 'Keine') end
    return table.concat(parts, ' | ')
end

local function DescribeHallucination(effects)
    local hallucination = effects.hallucination
    if not hallucination then return LocaleOr('consumables_inactive', 'Aus') end
    local presetLabel = ConsumablesCreatorFields.MatchHallucinationPreset(hallucination)
    if presetLabel then return Escape(presetLabel) end
    return LocaleOr('consumables_hallucination_custom', 'Benutzerdefiniert')
end

local function BuildDraftElements(draft, isNew)
    local consume = draft.consume
    local effects = draft.effects or {}
    local vehicleText = consume.allowInVehicle and LocaleOr('yes', 'Ja') or LocaleOr('no', 'Nein')
    local elements = {
        { title = LocaleOr('consumables_section_basics', 'Basisdaten'), value = 'basics', type = 'button',
            description = LocaleOr('consumables_desc_basics', 'Label: %s | Cooldown: %s s', Escape(draft.label), FormatSeconds(draft.cooldown)) },
        { title = LocaleOr('consumables_section_consume', 'Konsum'), value = 'consume', type = 'button',
            description = LocaleOr('consumables_desc_consume', 'Dauer: %s s | Fahrzeug: %s', FormatSeconds(consume.duration), vehicleText) },
        { title = LocaleOr('consumables_section_animation', 'Animation'), value = 'animation', type = 'button', description = DescribeAnimation(consume) },
        { title = LocaleOr('consumables_section_effects', 'Effekte'), value = 'effects', type = 'button', description = DescribeEffects(effects) },
        { title = LocaleOr('consumables_section_hallucination', 'Halluzination'), value = 'hallucination', type = 'button',
            description = DescribeHallucination(effects) },
        { title = LocaleOr('save', 'Speichern'), value = 'save', type = 'button' },
    }
    if not isNew then
        elements[#elements + 1] = { title = LocaleOr('delete', 'Loeschen'), value = 'delete', type = 'button' }
    end
    return elements
end

local function RunSectionEdit(itemName, draft, isNew, sectionValue)
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    local editor = ConsumablesCreatorFields[SECTION_EDITORS[sectionValue]]
    local updated = editor(draft)
    if IsStale(sessionGen) then return end
    OpenDraftMenu(itemName, updated or draft, isNew)
end

local function SaveDraft(itemName, draft, isNew)
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    local definition, errorCode = ConsumablesSchema.NormalizeDefinition(draft, Config.AnimationPresets)
    if not definition then
        Notify(LocaleOr('consumables_draft_incomplete', 'Der Entwurf ist unvollstaendig (%s).', tostring(errorCode)), 'error')
        return OpenDraftMenu(itemName, draft, isNew)
    end
    local baseline = syncCounter
    local result = SendMutation(isNew and 'create' or 'update', itemName, definition)
    if IsStale(sessionGen) then return end
    if not result.ok then
        if result.timedOut then
            Notify(LocaleOr('consumables_timeout', 'Keine Antwort vom Server, bitte erneut versuchen.'), 'error')
        end
        return OpenDraftMenu(itemName, draft, isNew)
    end
    WaitForSync(baseline)
    if IsStale(sessionGen) then return end
    OpenItemListMenu()
end

local function DeleteItem(itemName, draft)
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    local baseline = syncCounter
    local result = SendMutation('delete', itemName)
    if IsStale(sessionGen) then return end
    if not result.ok then
        if result.timedOut then
            Notify(LocaleOr('consumables_timeout', 'Keine Antwort vom Server, bitte erneut versuchen.'), 'error')
        end
        return OpenDraftMenu(itemName, draft, false)
    end
    WaitForSync(baseline)
    if IsStale(sessionGen) then return end
    OpenItemListMenu()
end

OpenDeleteConfirmMenu = function(itemName, draft)
    exports['hex_menu_api']:rageCloseAll()
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_consumables_delete_confirm', {
        title = LocaleOr('consumables_delete_title', 'Loeschen: %s [%s]', Escape(draft.label), itemName),
        elements = {
            { title = LocaleOr('consumables_delete_confirm', 'Endgueltig loeschen'), value = 'confirm', type = 'button' },
            { title = LocaleOr('back', 'Zurueck'), value = 'back', type = 'button' },
        },
        align = 'left'
    }, function(data, menu)
        if IsStale(sessionGen) then menu.close() return end
        if data.current.value == 'confirm' then
            CreateThread(function() DeleteItem(itemName, draft) end)
        else
            OpenDraftMenu(itemName, draft, false)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

OpenDraftMenu = function(itemName, draft, isNew)
    exports['hex_menu_api']:rageCloseAll()
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_consumables_draft', {
        title = Escape(draft.label) .. ' [' .. itemName .. ']',
        elements = BuildDraftElements(draft, isNew),
        align = 'left'
    }, function(data, menu)
        if IsStale(sessionGen) then menu.close() return end
        if pendingRequest then
            Notify(LocaleOr('consumables_creator_busy', 'Es laeuft bereits eine Speicherung.'), 'error')
            return
        end
        local value = data.current.value
        if SECTION_EDITORS[value] then
            CreateThread(function() RunSectionEdit(itemName, draft, isNew, value) end)
        elseif value == 'save' then
            CreateThread(function() SaveDraft(itemName, draft, isNew) end)
        elseif value == 'delete' then
            OpenDeleteConfirmMenu(itemName, draft)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

local function SortedTemplateOptions()
    local options = {}
    for key, template in pairs(Config.ItemTemplates or {}) do
        options[#options + 1] = { label = Escape(template.label or key), value = key }
    end
    table.sort(options, function(a, b) return a.label < b.label end)
    return options
end

local function PromptTemplate()
    return ConsumablesCreatorFields.SelectOption('rageui_consumables_template',
        LocaleOr('consumables_template_select', 'Vorlage waehlen'), SortedTemplateOptions())
end

local function PromptItemName()
    local rawName = ConsumablesCreatorFields.InputText(
        LocaleOr('consumables_field_item_name', 'Item-Name (a-z, 0-9, _ und -)'), 50, '^[a-z0-9_-]+$')
    if not rawName or rawName == '' then return nil end
    local itemName = ConsumablesSchema.NormalizeItemName(rawName)
    if not itemName then
        Notify(LocaleOr('consumables_invalid_item_name', 'Ungueltiger Item-Name.'), 'error')
        return nil
    end
    if Config.Items[itemName] then
        Notify(LocaleOr('consumables_duplicate_item', 'Dieses Item existiert bereits.'), 'error')
        return nil
    end
    return itemName
end

local function DeriveLabel(itemName)
    local label = itemName:gsub('[_%-]', ' ')
    return label:sub(1, 1):upper() .. label:sub(2)
end

local function PromptLabel(itemName)
    local label = ConsumablesCreatorFields.InputText(
        LocaleOr('consumables_field_label_optional', 'Anzeigename (leer = automatisch aus dem Namen)'), 64, nil)
    if label == nil then return nil end
    if label == '' then return DeriveLabel(itemName) end
    return label
end

local function BuildTemplateDraft(templateKey, label)
    local draft = ConsumablesSchema.Copy(Config.ItemTemplates[templateKey])
    draft.label = label
    local normalized = ConsumablesSchema.NormalizeDefinition(draft, Config.AnimationPresets)
    return normalized or draft
end

local function StartCreateFlow()
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    exports['hex_menu_api']:rageCloseAll()
    local templateKey = PromptTemplate()
    if IsStale(sessionGen) then return end
    if not templateKey or not Config.ItemTemplates[templateKey] then
        return OpenItemListMenu()
    end
    local itemName = PromptItemName()
    if IsStale(sessionGen) then return end
    if not itemName then return OpenItemListMenu() end
    local label = PromptLabel(itemName)
    if IsStale(sessionGen) then return end
    if not label then return OpenItemListMenu() end
    OpenDraftMenu(itemName, BuildTemplateDraft(templateKey, label), true)
end

local function OpenExistingItem(itemName)
    local definition = Config.Items[itemName]
    if not definition then
        return OpenItemListMenu()
    end
    OpenDraftMenu(itemName, ConsumablesSchema.Copy(definition), false)
end

OpenItemListMenu = function()
    exports['hex_menu_api']:rageCloseAll()
    local sessionGen = ConsumablesCreatorFields.CurrentGeneration()
    local elements = {}
    for _, name in ipairs(GetSortedItemNames()) do
        elements[#elements + 1] = {
            title = Escape(Config.Items[name].label or name) .. ' [' .. name .. ']',
            value = 'item_' .. name,
            type = 'button',
        }
    end
    elements[#elements + 1] = { title = LocaleOr('consumables_new_item', 'Neues Consumable'), value = 'new', type = 'button' }
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_consumables_items', {
        title = LocaleOr('consumables_menu_title', 'Consumables-Creator'),
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if IsStale(sessionGen) then menu.close() return end
        if data.current.value == 'new' then
            CreateThread(StartCreateFlow)
            return
        end
        local itemName = string.match(data.current.value or '', '^item_(.+)$')
        if itemName then OpenExistingItem(itemName) end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

RegisterNetEvent('forge_farming:consumables:openCreator')
AddEventHandler('forge_farming:consumables:openCreator', function(snapshot)
    if type(snapshot) ~= 'table' then return end
    Config.Items = ConsumablesSchema.Copy(snapshot)
    ConsumablesCreatorFields.NextGeneration()
    OpenItemListMenu()
end)
