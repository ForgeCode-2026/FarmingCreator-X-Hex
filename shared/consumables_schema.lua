ConsumablesSchema = {}

local function isFinite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function isBoolean(value)
    return type(value) == 'boolean'
end

local function numberCheck(min, max)
    return function(value)
        return isFinite(value) and value >= min and value <= max
    end
end

local function integerCheck(min, max)
    local inRange = numberCheck(min, max)
    return function(value)
        return inRange(value) and value % 1 == 0
    end
end

local function textCheck(minLength, maxLength)
    return function(value)
        return type(value) == 'string' and #value >= minLength and #value <= maxLength
    end
end

local identifierCheck = textCheck(1, 100)
local labelCheck = textCheck(1, 64)
local cooldownCheck = integerCheck(0, 3600000)
local componentCheck = numberCheck(-360, 360)

local CONSUME_SPEC = {
    duration = { required = true, check = integerCheck(0, 120000) },
    text = { required = true, check = textCheck(1, 160) },
    allowInVehicle = { check = isBoolean },
}

local SCENARIO_SPEC = {
    scenario = { required = true, check = identifierCheck },
}

local ANIMATION_SPEC = {
    dict = { required = true, check = identifierCheck },
    clip = { required = true, check = identifierCheck },
    flag = { check = integerCheck(0, 65535) },
    blendIn = { check = numberCheck(0, 20) },
    blendOut = { check = numberCheck(0, 20) },
    playbackRate = { check = numberCheck(0, 10) },
}

local PROP_SPEC = {
    model = { required = true, check = identifierCheck },
    bone = { check = integerCheck(0, 65535) },
}

local EFFECTS_SPEC = {
    duration = { check = integerCheck(0, 3600000) },
    health = { check = integerCheck(0, 200) },
    armor = { check = integerCheck(0, 100) },
    speed = { check = numberCheck(1.0, 1.49) },
    stamina = { check = isBoolean },
}

local HALLUCINATION_SPEC = {
    enabled = { check = isBoolean },
    timecycle = { check = identifierCheck },
    strength = { check = numberCheck(0, 1) },
    pulsing = { check = isBoolean },
    screenEffect = { check = identifierCheck },
    cameraShake = { check = numberCheck(0, 1) },
    motionBlur = { check = isBoolean },
    movementClipset = { check = identifierCheck },
    ragdollChance = { check = numberCheck(0, 100) },
}

local function normalizeFields(value, spec)
    local result = {}
    for name, rule in pairs(spec) do
        local field = value[name]
        if field == nil then
            if rule.required then return nil end
        elseif rule.check(field) then
            result[name] = field
        else
            return nil
        end
    end
    return result
end

local function normalizeVector(value)
    if type(value) ~= 'table' then return nil end
    if not (componentCheck(value.x) and componentCheck(value.y) and componentCheck(value.z)) then
        return nil
    end
    return { x = value.x, y = value.y, z = value.z }
end

local function normalizeProp(value)
    if type(value) ~= 'table' then return nil end
    local prop = normalizeFields(value, PROP_SPEC)
    if not prop then return nil end
    if value.position ~= nil then
        prop.position = normalizeVector(value.position)
        if not prop.position then return nil end
    end
    if value.rotation ~= nil then
        prop.rotation = normalizeVector(value.rotation)
        if not prop.rotation then return nil end
    end
    return prop
end

local function normalizeAnimation(value, presets)
    if type(value) == 'string' then
        if type(presets) == 'table' and presets[value] ~= nil and identifierCheck(value) then
            return value
        end
        return nil
    end
    if type(value) ~= 'table' then return nil end
    if value.scenario ~= nil then
        return normalizeFields(value, SCENARIO_SPEC)
    end
    return normalizeFields(value, ANIMATION_SPEC)
end

local function normalizeConsume(value, presets)
    if type(value) ~= 'table' then return nil, 'invalid_consume' end
    local consume = normalizeFields(value, CONSUME_SPEC)
    if not consume then return nil, 'invalid_consume' end
    consume.animation = normalizeAnimation(value.animation, presets)
    if not consume.animation then return nil, 'invalid_animation' end
    if value.prop ~= nil then
        consume.prop = normalizeProp(value.prop)
        if not consume.prop then return nil, 'invalid_prop' end
    end
    return consume
end

local function normalizeHallucination(value)
    if type(value) ~= 'table' then return nil, 'invalid_effects' end
    local hallucination = normalizeFields(value, HALLUCINATION_SPEC)
    if not hallucination then return nil, 'invalid_effects' end
    if next(hallucination) == nil then return nil, nil end
    return hallucination, nil
end

local function normalizeEffects(value)
    if type(value) ~= 'table' then return nil, 'invalid_effects' end
    local effects = normalizeFields(value, EFFECTS_SPEC)
    if not effects then return nil, 'invalid_effects' end
    if value.hallucination ~= nil then
        local hallucination, hallucinationError = normalizeHallucination(value.hallucination)
        if hallucinationError then return nil, hallucinationError end
        effects.hallucination = hallucination
    end
    return effects
end

function ConsumablesSchema.Copy(value)
    if type(value) ~= 'table' then return value end
    local copied = {}
    for key, entry in pairs(value) do
        copied[key] = ConsumablesSchema.Copy(entry)
    end
    return copied
end

function ConsumablesSchema.NormalizeItemName(value)
    if type(value) ~= 'string' or #value < 1 or #value > 50 then
        return nil, 'invalid_item_name'
    end
    if not value:match('^[a-z0-9_%-]+$') then
        return nil, 'invalid_item_name'
    end
    return value, nil
end

function ConsumablesSchema.NormalizeDefinition(value, presets)
    if type(value) ~= 'table' then return nil, 'invalid_definition' end
    if not labelCheck(value.label) then return nil, 'invalid_label' end
    if not cooldownCheck(value.cooldown) then return nil, 'invalid_cooldown' end
    local consume, consumeError = normalizeConsume(value.consume, presets)
    if not consume then return nil, consumeError end
    local effects, effectsError = normalizeEffects(value.effects)
    if not effects then return nil, effectsError end
    return {
        label = value.label,
        cooldown = value.cooldown,
        consume = consume,
        effects = effects,
    }, nil
end

function ConsumablesSchema.NormalizeSnapshot(items, presets)
    local normalized, errors = {}, {}
    if type(items) ~= 'table' then return normalized, errors end
    for key, value in pairs(items) do
        local name, nameError = ConsumablesSchema.NormalizeItemName(key)
        if not name then
            errors[tostring(key)] = nameError
        else
            local definition, definitionError = ConsumablesSchema.NormalizeDefinition(value, presets)
            if definition then
                normalized[name] = definition
            else
                errors[name] = definitionError
            end
        end
    end
    return normalized, errors
end
