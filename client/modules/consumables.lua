local consuming = false
local consumeProp = nil
local activeEffectId = 0
local activeEffects = nil

local DEFAULT_PROP_BONE = 28422
local CONSUME_BLOCKED_CONTROLS = { 21, 22, 23, 24, 25, 37 }

local function Notify(message, notifyType)
    TriggerEvent('forge_farming:notify', message, notifyType or 'info', 'Konsum')
end

local function LocaleOr(key, fallback, ...)
    local text = Locale(key)
    if text == key then text = fallback end
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

local function LoadAnimSet(animSet)
    if HasAnimSetLoaded(animSet) then return true end
    RequestAnimSet(animSet)
    local timeout = GetGameTimer() + 5000
    while not HasAnimSetLoaded(animSet) and GetGameTimer() < timeout do
        Wait(0)
    end
    return HasAnimSetLoaded(animSet)
end

local function DeleteConsumeProp()
    if consumeProp and DoesEntityExist(consumeProp) then
        DeleteEntity(consumeProp)
    end
    consumeProp = nil
end

local function AttachConsumeProp(propData, ped)
    local position = propData.position or vector3(0.0, 0.0, 0.0)
    local rotation = propData.rotation or vector3(0.0, 0.0, 0.0)
    AttachEntityToEntity(
        consumeProp,
        ped,
        GetPedBoneIndex(ped, propData.bone or DEFAULT_PROP_BONE),
        position.x, position.y, position.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )
end

local function CreateConsumeProp(propData, ped)
    if not propData or not propData.model then return end

    local model = joaat(propData.model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(model) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local coords = GetEntityCoords(ped)
    consumeProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    if consumeProp and DoesEntityExist(consumeProp) then
        AttachConsumeProp(propData, ped)
    end

    SetModelAsNoLongerNeeded(model)
end

local function StopConsumeAnimation(ped)
    ClearPedTasks(ped)
    DeleteConsumeProp()
end

local function ResolveAnimation(consume)
    if type(consume.animation) == 'string' then
        return Config.AnimationPresets[consume.animation]
    end
    if type(consume.animation) == 'table' then
        return consume.animation
    end
    if consume.scenario then
        return { scenario = consume.scenario, prop = consume.prop }
    end
    return nil
end

local function PlayConsumeAnimation(consume, ped, duration)
    local animation = ResolveAnimation(consume)
    if not animation then return end

    if animation.scenario then
        TaskStartScenarioInPlace(ped, animation.scenario, 0, true)
    elseif animation.dict and animation.clip and LoadAnimDict(animation.dict) then
        TaskPlayAnim(
            ped,
            animation.dict,
            animation.clip,
            animation.blendIn or 3.0,
            animation.blendOut or 3.0,
            duration,
            animation.flag or 49,
            animation.playbackRate or 0.0,
            false, false, false
        )
    end

    CreateConsumeProp(consume.prop or animation.prop, ped)
end

local function ResetDrugEffects()
    local ped = PlayerPedId()
    local previous = activeEffects

    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    SetPedMoveRateOverride(ped, 1.0)
    SetPedMotionBlur(ped, false)
    SetPedIsDrunk(ped, false)
    ResetPedMovementClipset(ped, 0.3)
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)

    if previous and previous.hallucination and previous.hallucination.screenEffect then
        AnimpostfxStop(previous.hallucination.screenEffect)
    end

    activeEffects = nil
end

local function AddInstantEffects(effects, ped)
    if effects.health and effects.health ~= 0 then
        local health = GetEntityHealth(ped)
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), health + effects.health))
    end
    if effects.armor and effects.armor ~= 0 then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + effects.armor))
    end
end

local function ApplyHallucination(hallucination, ped)
    if hallucination.timecycle then
        SetTimecycleModifier(hallucination.timecycle)
        SetTimecycleModifierStrength(hallucination.strength or 0.5)
    end
    if hallucination.screenEffect then
        AnimpostfxPlay(hallucination.screenEffect, 0, true)
    end
    if hallucination.cameraShake and hallucination.cameraShake > 0 then
        ShakeGameplayCam('DRUNK_SHAKE', hallucination.cameraShake)
    end
    if hallucination.motionBlur then
        SetPedMotionBlur(ped, true)
    end
    if hallucination.movementClipset and LoadAnimSet(hallucination.movementClipset) then
        SetPedMovementClipset(ped, hallucination.movementClipset, 0.6)
        SetPedIsDrunk(ped, true)
    end
end

local function RunEffectLoop(effectId, effects, endsAt, label)
    local hallucination = effects.hallucination

    while effectId == activeEffectId and activeEffects and GetGameTimer() < endsAt do
        local currentPed = PlayerPedId()

        if IsEntityDead(currentPed) then break end

        if effects.stamina then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        if effects.moveRate then
            SetPedMoveRateOverride(currentPed, effects.moveRate)
        end
        if hallucination and hallucination.pulsing and hallucination.timecycle then
            local base = hallucination.strength or 0.5
            local pulse = (math.sin(GetGameTimer() / 650.0) + 1.0) * 0.12
            SetTimecycleModifierStrength(math.min(1.0, base + pulse))
        end

        Wait(0)
    end

    if effectId == activeEffectId and activeEffects then
        ResetDrugEffects()
        if not IsEntityDead(PlayerPedId()) then
            Notify(LocaleOr('consumables_effect_ended', 'Die Wirkung von %s laesst nach.', label), 'info')
        end
    end
end

local function RunRagdollLoop(effectId, ragdollChance, endsAt)
    while effectId == activeEffectId and activeEffects and GetGameTimer() < endsAt do
        Wait(1000)

        local currentPed = PlayerPedId()
        if not IsPedInAnyVehicle(currentPed, false)
            and not IsPedRagdoll(currentPed)
            and math.random(1, 100) <= ragdollChance then
            SetPedToRagdoll(currentPed, 900, 1300, 0, false, false, false)
        end
    end
end

local function StartTimedEffects(definition, itemName)
    local effects = definition.effects or {}
    local ped = PlayerPedId()
    local label = definition.label or itemName

    AddInstantEffects(effects, ped)

    local duration = math.max(0, tonumber(effects.duration) or 0)
    if duration == 0 then return end

    activeEffectId = activeEffectId + 1
    local effectId = activeEffectId

    ResetDrugEffects()
    activeEffects = effects

    if effects.speed then
        SetRunSprintMultiplierForPlayer(PlayerId(), math.min(1.49, math.max(1.0, effects.speed)))
    end
    if effects.hallucination then
        ApplyHallucination(effects.hallucination, ped)
    end

    local endsAt = GetGameTimer() + duration
    CreateThread(function()
        RunEffectLoop(effectId, effects, endsAt, label)
    end)

    local hallucination = effects.hallucination
    if hallucination and (hallucination.ragdollChance or 0) > 0 then
        CreateThread(function()
            RunRagdollLoop(effectId, hallucination.ragdollChance, endsAt)
        end)
    end
end

local function RunConsumeLoop(duration)
    local endsAt = GetGameTimer() + duration

    while GetGameTimer() < endsAt do
        Wait(0)
        for _, control in ipairs(CONSUME_BLOCKED_CONTROLS) do
            DisableControlAction(0, control, true)
        end

        if IsEntityDead(PlayerPedId())
            or (Config.Consumables.AllowCancel
                and IsControlJustReleased(0, Config.Consumables.CancelKey)) then
            return true
        end
    end

    return false
end

local function StartProgress(text, duration)
    Framework.StartProgress(text, duration)
end

local function StopProgress()
    Framework.StopProgress()
end

local function RejectStart(token, message)
    if message then Notify(message, 'error') end
    TriggerServerEvent('forge_farming:consumables:cancel', token)
end

RegisterNetEvent('forge_farming:consumables:sync')
AddEventHandler('forge_farming:consumables:sync', function(items)
    if type(items) ~= 'table' then return end
    Config.Items = ConsumablesSchema.Copy(items)
end)

RegisterNetEvent('forge_farming:consumables:start')
AddEventHandler('forge_farming:consumables:start', function(token, itemName, definition)
    if consuming then
        return RejectStart(token)
    end
    if type(definition) ~= 'table' or type(definition.consume) ~= 'table' then
        return RejectStart(token)
    end

    local consume = definition.consume
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        return RejectStart(token, LocaleOr('consumables_not_now', 'Du kannst dieses Item gerade nicht benutzen.'))
    end
    if consume.allowInVehicle == false and IsPedInAnyVehicle(ped, false) then
        return RejectStart(token, LocaleOr('consumables_not_in_vehicle', 'Du kannst dieses Item nicht im Fahrzeug benutzen.'))
    end

    local duration = math.max(0, tonumber(consume.duration) or 0)

    consuming = true
    PlayConsumeAnimation(consume, ped, duration)
    StartProgress(
        consume.text or LocaleOr('consumables_progress_default', 'Du benutzt %s ...', definition.label or itemName),
        duration)

    local canceled = RunConsumeLoop(duration)

    StopConsumeAnimation(PlayerPedId())
    consuming = false

    if canceled then
        StopProgress()
        Notify(LocaleOr('consumables_cancelled', 'Benutzung abgebrochen.'), 'error')
        TriggerServerEvent('forge_farming:consumables:cancel', token)
    else
        TriggerServerEvent('forge_farming:consumables:complete', token)
    end
end)

RegisterNetEvent('forge_farming:consumables:apply')
AddEventHandler('forge_farming:consumables:apply', function(itemName, definition)
    if type(definition) ~= 'table' then return end

    StartTimedEffects(definition, itemName)
    Notify(LocaleOr('consumables_used', '%s wurde benutzt.', definition.label or itemName), 'success')
end)

exports('UseConsumable', function(data)
    local itemName = type(data) == 'table' and data.name or data
    if type(itemName) ~= 'string' then return end

    TriggerServerEvent('forge_farming:consumables:requestUse', itemName)
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('forge_farming:consumables:requestSync')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    StopConsumeAnimation(PlayerPedId())
    if consuming then StopProgress() end
    activeEffectId = activeEffectId + 1
    ResetDrugEffects()
end)
