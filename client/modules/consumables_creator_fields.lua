ConsumablesCreatorFields = {}

local generation = 0

function ConsumablesCreatorFields.NextGeneration()
    generation = generation + 1
    return generation
end

function ConsumablesCreatorFields.CurrentGeneration()
    return generation
end

local HTML_ESCAPES = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&#39;',
}

function ConsumablesCreatorFields.EscapeHtml(value)
    return (tostring(value):gsub('[&<>"\']', HTML_ESCAPES))
end

function ConsumablesCreatorFields.SortedPresetNames()
    local names = {}
    for name in pairs(Config.AnimationPresets or {}) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function Notify(message, notifyType)
    TriggerEvent('forge_farming:notify', message, notifyType or 'info', 'Creator')
end

function ConsumablesCreatorFields.LocaleOr(key, fallback, ...)
    local text = Locale(key)
    if text == key then text = fallback end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

local LocaleOr = ConsumablesCreatorFields.LocaleOr

local function KeyboardInput(title, maxLength, regex)
    local sessionGen = generation
    local inputPromise = promise.new()
    exports['hex_menu_api']:inputOpen(GetCurrentResourceName(), 'rageui_consumables_input', {
        title = title,
        maxLength = maxLength,
        regex = regex,
    }, function(data, menu)
        if sessionGen ~= generation then
            inputPromise:resolve(nil)
            menu.close()
            return
        end
        inputPromise:resolve(data.value)
        menu.close()
    end, function(data, menu)
        inputPromise:resolve(nil)
        menu.close()
    end)
    local result = Citizen.Await(inputPromise)
    Wait(150)
    return result
end

local function SelectFromList(menuId, title, options)
    local sessionGen = generation
    local selectPromise = promise.new()
    local elements = {}
    for _, opt in ipairs(options) do
        elements[#elements + 1] = { title = opt.label, value = opt.value, type = 'button' }
    end
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), menuId, {
        title = title,
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if sessionGen ~= generation then
            selectPromise:resolve(nil)
            menu.close()
            return
        end
        selectPromise:resolve(data.current.value)
        menu.close()
    end, function(data, menu)
        selectPromise:resolve(nil)
        menu.close()
    end, function() end)
    local result = Citizen.Await(selectPromise)
    Wait(150)
    return result
end

function ConsumablesCreatorFields.InputText(title, maxLength, regex)
    return KeyboardInput(title, maxLength, regex)
end

function ConsumablesCreatorFields.SelectOption(menuId, title, options)
    return SelectFromList(menuId, title, options)
end

local NUMBER_REGEX = '^-?[0-9]*[.,]?[0-9]*$'

local function ParseNumber(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    return tonumber((raw:gsub(',', '.')))
end

local function InputOptionalNumber(title, maxLength)
    local raw = KeyboardInput(title, maxLength, NUMBER_REGEX)
    if raw == nil then return nil, false end
    if raw == '' then return nil, true end
    local value = ParseNumber(raw)
    if not value then return nil, false end
    return value, true
end

local function InputOptionalInteger(title, maxLength)
    local raw = KeyboardInput(title, maxLength, '^[0-9]*$')
    if raw == nil then return nil, false end
    if raw == '' then return nil, true end
    local value = tonumber(raw)
    if not value then return nil, false end
    return math.floor(value), true
end

local function InputRequiredNumber(title, maxLength)
    local value = ParseNumber(KeyboardInput(title, maxLength, NUMBER_REGEX))
    if not value then return nil, false end
    return value, true
end

local function SecondsToMs(seconds)
    return math.floor(seconds * 1000 + 0.5)
end

local function InputRequiredSeconds(title, maxSeconds)
    local value = ParseNumber(KeyboardInput(title, 8, NUMBER_REGEX))
    if not value or value < 0 or value > maxSeconds then return nil, false end
    return SecondsToMs(value), true
end

local function InputOptionalSeconds(title, maxSeconds)
    local raw = KeyboardInput(title, 8, NUMBER_REGEX)
    if raw == nil then return nil, false end
    if raw == '' then return nil, true end
    local value = ParseNumber(raw)
    if not value or value < 0 or value > maxSeconds then return nil, false end
    return SecondsToMs(value), true
end

function ConsumablesCreatorFields.FormatSeconds(ms)
    local seconds = (ms or 0) / 1000
    if seconds % 1 == 0 then
        return string.format('%d', seconds)
    end
    return (string.format('%.2f', seconds):gsub('0+$', ''):gsub('%.$', ''))
end

local function SelectBoolean(title)
    local choice = SelectFromList('rageui_consumables_bool', title, {
        { label = LocaleOr('yes', 'Ja'), value = 'yes' },
        { label = LocaleOr('no', 'Nein'), value = 'no' },
    })
    if choice == nil then return nil end
    return choice == 'yes'
end

local function BeginEdit(draft)
    exports['hex_menu_api']:rageCloseAll()
    return ConsumablesSchema.Copy(draft)
end

local function FinishEdit(copy)
    local normalized, errorCode = ConsumablesSchema.NormalizeDefinition(copy, Config.AnimationPresets)
    if not normalized then
        Notify(LocaleOr('consumables_invalid_section', 'Ungueltige Eingabe (%s).', tostring(errorCode)), 'error')
        return nil
    end
    return normalized
end

function ConsumablesCreatorFields.EditLabel(draft)
    local copy = BeginEdit(draft)
    local label = KeyboardInput(LocaleOr('consumables_field_label', 'Anzeigename (max. 64 Zeichen)'), 64, nil)
    if not label or label == '' then return nil end
    copy.label = label
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditCooldown(draft)
    local copy = BeginEdit(draft)
    local cooldown, ok = InputRequiredSeconds(LocaleOr('consumables_field_cooldown', 'Cooldown in Sekunden (0-3600)'), 3600)
    if not ok then return nil end
    copy.cooldown = cooldown
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditConsumeDuration(draft)
    local copy = BeginEdit(draft)
    local duration, ok = InputRequiredSeconds(LocaleOr('consumables_field_duration', 'Konsumdauer in Sekunden (0-120)'), 120)
    if not ok then return nil end
    copy.consume.duration = duration
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditConsumeText(draft)
    local copy = BeginEdit(draft)
    local text = KeyboardInput(LocaleOr('consumables_field_text', 'Fortschrittstext (max. 160 Zeichen)'), 160, nil)
    if not text or text == '' then return nil end
    copy.consume.text = text
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.ToggleVehicle(draft)
    local copy = ConsumablesSchema.Copy(draft)
    copy.consume.allowInVehicle = not copy.consume.allowInVehicle
    return FinishEdit(copy)
end

local function PromptAnimationMode()
    local options = {}
    for _, name in ipairs(ConsumablesCreatorFields.SortedPresetNames()) do
        options[#options + 1] = { label = LocaleOr('consumables_animation_preset', 'Preset: %s', name), value = 'preset:' .. name }
    end
    options[#options + 1] = { label = LocaleOr('consumables_animation_scenario', 'Szenario'), value = 'scenario' }
    options[#options + 1] = { label = LocaleOr('consumables_animation_custom', 'Eigene Animation (Dict/Clip)'), value = 'custom' }
    return SelectFromList('rageui_consumables_animation', LocaleOr('consumables_animation_select', 'Animation waehlen'), options)
end

local function PromptCustomAnimation()
    local dict = KeyboardInput(LocaleOr('consumables_field_anim_dict', 'Animations-Dict'), 100, nil)
    if not dict or dict == '' then return nil end
    local clip = KeyboardInput(LocaleOr('consumables_field_anim_clip', 'Animations-Clip'), 100, nil)
    if not clip or clip == '' then return nil end
    local animation = { dict = dict, clip = clip }
    local optionals = {
        { key = 'flag', prompt = LocaleOr('consumables_field_anim_flag', 'Flag (0-65535, leer = Standard)'), integer = true, max = 5 },
        { key = 'blendIn', prompt = LocaleOr('consumables_field_blend_in', 'Blend-In (0-20, leer = Standard)'), max = 6 },
        { key = 'blendOut', prompt = LocaleOr('consumables_field_blend_out', 'Blend-Out (0-20, leer = Standard)'), max = 6 },
        { key = 'playbackRate', prompt = LocaleOr('consumables_field_playback_rate', 'Abspielrate (0-10, leer = Standard)'), max = 6 },
    }
    for _, field in ipairs(optionals) do
        local value, ok
        if field.integer then
            value, ok = InputOptionalInteger(field.prompt, field.max)
        else
            value, ok = InputOptionalNumber(field.prompt, field.max)
        end
        if not ok then return nil end
        animation[field.key] = value
    end
    return animation
end

local function PromptVector(titlePrefix)
    local axes = {}
    for _, axis in ipairs({ 'X', 'Y', 'Z' }) do
        local value, ok = InputRequiredNumber(titlePrefix .. ' ' .. axis, 10)
        if not ok then return nil end
        axes[#axes + 1] = value
    end
    return { x = axes[1], y = axes[2], z = axes[3] }
end

local function PromptProp()
    local model = KeyboardInput(LocaleOr('consumables_field_prop_model', 'Prop-Modell'), 100, nil)
    if not model or model == '' then return nil end
    local prop = { model = model }
    local bone, ok = InputOptionalInteger(LocaleOr('consumables_field_prop_bone', 'Bone-ID (leer = rechte Hand)'), 5)
    if not ok then return nil end
    prop.bone = bone
    prop.position = PromptVector(LocaleOr('consumables_field_prop_position', 'Prop-Position'))
    if not prop.position then return nil end
    prop.rotation = PromptVector(LocaleOr('consumables_field_prop_rotation', 'Prop-Rotation'))
    if not prop.rotation then return nil end
    return prop
end

local function ApplyOptionalProp(consume)
    local withProp = SelectBoolean(LocaleOr('consumables_field_prop_use', 'Prop verwenden?'))
    if withProp == nil then return false end
    if not withProp then
        consume.prop = nil
        return true
    end
    local prop = PromptProp()
    if not prop then return false end
    consume.prop = prop
    return true
end

function ConsumablesCreatorFields.EditAnimation(draft)
    local copy = BeginEdit(draft)
    local mode = PromptAnimationMode()
    if not mode then return nil end
    local presetName = mode:match('^preset:(.+)$')
    if presetName then
        copy.consume.animation = presetName
        copy.consume.prop = nil
    elseif mode == 'scenario' then
        local scenario = KeyboardInput(LocaleOr('consumables_field_scenario', 'Szenario-Name'), 100, nil)
        if not scenario or scenario == '' then return nil end
        copy.consume.animation = { scenario = scenario }
        copy.consume.prop = nil
    else
        local animation = PromptCustomAnimation()
        if not animation then return nil end
        copy.consume.animation = animation
        if not ApplyOptionalProp(copy.consume) then return nil end
    end
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditEffectDuration(draft)
    local copy = BeginEdit(draft)
    local duration, ok = InputOptionalSeconds(
        LocaleOr('consumables_field_effect_duration', 'Effektdauer in Sekunden (0-3600, 0 = nur Sofort-Effekte)'), 3600)
    if not ok then return nil end
    copy.effects = copy.effects or {}
    copy.effects.duration = duration or 0
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditHealth(draft)
    local copy = BeginEdit(draft)
    local value, ok = InputOptionalInteger(LocaleOr('consumables_field_health', 'Leben 0-200 (0 oder leer = kein Effekt)'), 3)
    if not ok then return nil end
    if value == 0 then value = nil end
    copy.effects = copy.effects or {}
    copy.effects.health = value
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditArmor(draft)
    local copy = BeginEdit(draft)
    local value, ok = InputOptionalInteger(LocaleOr('consumables_field_armor', 'Ruestung 0-100 (0 oder leer = kein Effekt)'), 3)
    if not ok then return nil end
    if value == 0 then value = nil end
    copy.effects = copy.effects or {}
    copy.effects.armor = value
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.EditSpeed(draft)
    local copy = BeginEdit(draft)
    local value, ok = InputOptionalNumber(LocaleOr('consumables_field_speed', 'Tempo 1.0-1.49 (leer oder 1.0 = aus)'), 4)
    if not ok then return nil end
    if value == 1.0 then value = nil end
    copy.effects = copy.effects or {}
    copy.effects.speed = value
    return FinishEdit(copy)
end

function ConsumablesCreatorFields.ToggleStamina(draft)
    local copy = ConsumablesSchema.Copy(draft)
    copy.effects = copy.effects or {}
    if copy.effects.stamina then
        copy.effects.stamina = nil
    else
        copy.effects.stamina = true
    end
    return FinishEdit(copy)
end

local HALLUCINATION_KEYS = {
    'enabled', 'timecycle', 'strength', 'pulsing', 'screenEffect',
    'cameraShake', 'motionBlur', 'movementClipset', 'ragdollChance',
}

local function CopyHallucinationPreset(preset)
    local copy = {}
    for _, key in ipairs(HALLUCINATION_KEYS) do
        copy[key] = preset[key]
    end
    return copy
end

local function SortedHallucinationPresets()
    local presets = {}
    for name, preset in pairs(Config.HallucinationPresets or {}) do
        presets[#presets + 1] = { name = name, label = preset.label or name }
    end
    table.sort(presets, function(a, b) return a.label < b.label end)
    return presets
end

function ConsumablesCreatorFields.MatchHallucinationPreset(hallucination)
    if type(hallucination) ~= 'table' then return nil end
    for _, preset in pairs(Config.HallucinationPresets or {}) do
        local matches = true
        for _, key in ipairs(HALLUCINATION_KEYS) do
            if preset[key] ~= hallucination[key] then
                matches = false
                break
            end
        end
        if matches then return preset.label end
    end
    return nil
end

function ConsumablesCreatorFields.EditHallucination(draft)
    local copy = BeginEdit(draft)
    local options = {
        { label = LocaleOr('consumables_hallucination_off', 'Aus'), value = 'off' },
    }
    for _, preset in ipairs(SortedHallucinationPresets()) do
        options[#options + 1] = { label = preset.label, value = 'preset:' .. preset.name }
    end
    local choice = SelectFromList('rageui_consumables_hallucination',
        LocaleOr('consumables_hallucination_select', 'Halluzination waehlen'), options)
    if not choice then return nil end
    copy.effects = copy.effects or {}
    local presetName = choice:match('^preset:(.+)$')
    if presetName then
        copy.effects.hallucination = CopyHallucinationPreset(Config.HallucinationPresets[presetName])
    else
        copy.effects.hallucination = nil
    end
    return FinishEdit(copy)
end
