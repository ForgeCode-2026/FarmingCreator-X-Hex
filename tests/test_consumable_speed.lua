local handlers = {}
local speedCalls = {}
local notifications = {}
local gameTimer = 0
local progressStarts = 0
local progressStops = 0

Config = {
    Playerspeed = 1.20,
    AnimationPresets = {},
    Consumables = {
        AllowCancel = true,
        CancelKey = 73,
    },
}

Framework = {
    StartProgress = function()
        progressStarts = progressStarts + 1
    end,
    StopProgress = function()
        progressStops = progressStops + 1
    end,
}

function Locale(key)
    return key
end

function RegisterNetEvent()
end

function AddEventHandler(name, handler)
    handlers[name] = handler
end

function exports()
end

function CreateThread(callback)
    callback()
end

function Wait(duration)
    gameTimer = gameTimer + math.max(1, duration or 0)
end

function GetGameTimer()
    return gameTimer
end

function PlayerId()
    return 1
end

function PlayerPedId()
    return 10
end

function SetRunSprintMultiplierForPlayer(_, value)
    speedCalls[#speedCalls + 1] = value
end

function TriggerEvent(name, message, notifyType)
    if name ~= 'forge_farming:notify' then return end
    notifications[#notifications + 1] = {
        message = message,
        notifyType = notifyType,
    }
end

function TriggerServerEvent()
end

function DisableControlAction()
end

function IsControlJustReleased()
    return false
end

function ClearPedTasks()
end

function SetPedMoveRateOverride()
end

function SetPedMotionBlur()
end

function SetPedIsDrunk()
end

function ResetPedMovementClipset()
end

function ClearTimecycleModifier()
end

function StopGameplayCamShaking()
end

function IsEntityDead()
    return false
end

function RestorePlayerStamina()
end

dofile('client/modules/consumables.lua')

handlers['forge_farming:consumables:start']('token', 'test_drug', {
    label = 'Testdroge',
    consume = {
        duration = 2,
        allowInVehicle = true,
    },
})

assert(progressStarts == 1, 'Konsum muss die Progressbar genau einmal starten')
assert(progressStops == 1, 'Erfolgreicher Konsum muss die Progressbar genau einmal stoppen')

handlers['forge_farming:consumables:apply']('test_drug', {
    label = 'Testdroge',
    effects = {
        duration = 4,
        speed = 1.38,
    },
})

local itemSpeedWrites = 0
for _, value in ipairs(speedCalls) do
    if value == 1.38 then
        itemSpeedWrites = itemSpeedWrites + 1
    end
end

assert(itemSpeedWrites > 1, 'Item-Speed muss waehrend der Wirkung erneut gesetzt werden')
assert(speedCalls[#speedCalls] == 1.20, 'Server-Standard muss zuletzt wiederhergestellt werden')
local successNotifications = {}
for _, notification in ipairs(notifications) do
    if notification.notifyType == 'success' then
        successNotifications[#successNotifications + 1] = notification
    end
end

assert(#successNotifications == 1, 'Erfolgreicher Konsum muss genau eine Success-Notify senden')
assert(successNotifications[1].message == 'Du hast Testdroge konsumiert.', 'Konsum-Notify hat den falschen Text')

print('PASS test_consumable_speed')
