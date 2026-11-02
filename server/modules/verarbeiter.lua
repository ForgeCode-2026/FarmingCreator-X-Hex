ActiveJobs = {}

local TICK_INTERVAL_MS = 30000
local MAX_TOTAL_DURATION = 2147483647

local function IsPositiveInteger(value)
    return type(value) == 'number' and value > 0 and value == math.floor(value)
end

local function IsPlayerNearPoint(src, point)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return false
    end
    local pointCoords = vector3(point.coords.x, point.coords.y, point.coords.z)
    return #(GetEntityCoords(ped) - pointCoords) <= Config.InteractionDistance
end

local function FindPlayerJobAtPoint(identifier, pointId)
    for _, job in pairs(ActiveJobs) do
        if job.playerIdentifier == identifier and job.pointId == pointId then
            return job
        end
    end
    return nil
end

local function CountUncollectedJobs(identifier)
    local count = 0
    for _, job in pairs(ActiveJobs) do
        if job.playerIdentifier == identifier then
            count = count + 1
        end
    end
    return count
end

function RemoveJobsForPoint(pointId)
    local affectedIdentifiers = {}
    for id, job in pairs(ActiveJobs) do
        if job.pointId == pointId then
            affectedIdentifiers[job.playerIdentifier] = true
            ActiveJobs[id] = nil
        end
    end

    SafeQuery(MySQL.update, 'DELETE FROM forge_farming_jobs WHERE point_id = ?', { pointId })

    for identifier in pairs(affectedIdentifiers) do
        local target = Framework.GetSourceFromIdentifier(identifier)
        if target then
            Framework.Notify(target, Locale('verarbeiter_job_removed'), 'error')
        end
    end
end

local function GetPointRecipe(point, recipeId)
    if RecipeProjectIndex[recipeId] ~= point.projectId then
        return nil
    end
    local project = GetFarmProject(point.projectId)
    return project and project.recipes[recipeId] or nil
end

local function GetJobRecipe(job)
    local point = GetFarmPoint(job.pointId)
    local project = point and GetFarmProject(point.projectId)
    return project and project.recipes[job.recipeId] or nil
end

local function GetRequiredInputs(recipe, amount)
    local required = {}
    for _, input in ipairs(recipe.inputs) do
        required[input.item] = (required[input.item] or 0) + input.amount * amount
    end
    return required
end

local function HasRequiredInputs(src, recipe, amount)
    for item, count in pairs(GetRequiredInputs(recipe, amount)) do
        if Framework.GetItemCount(src, item) < count then
            return false
        end
    end
    return true
end

local function RefundRecipeInputs(src, recipe, amount)
    for item, count in pairs(GetRequiredInputs(recipe, amount)) do
        Framework.AddItem(src, item, count)
    end
end

local function RemoveRecipeInputs(src, recipe, amount)
    local removed = {}
    for item, count in pairs(GetRequiredInputs(recipe, amount)) do
        if not Framework.RemoveItem(src, item, count) then
            for removedItem, removedCount in pairs(removed) do
                Framework.AddItem(src, removedItem, removedCount)
            end
            return false
        end
        removed[item] = count
    end
    return true
end

local function ComputeMaxCraftable(src, recipe)
    local maxAmount = nil
    for item, perRun in pairs(GetRequiredInputs(recipe, 1)) do
        local possible = math.floor(Framework.GetItemCount(src, item) / perRun)
        if not maxAmount or possible < maxAmount then
            maxAmount = possible
        end
    end
    return maxAmount or 0
end

local function ResolveAmount(src, recipe, amount)
    if amount == 'max' then
        return ComputeMaxCraftable(src, recipe)
    end
    if IsPositiveInteger(amount) then
        return amount
    end
    return 0
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ActiveJobs = {}

    SafeQuery(MySQL.update, "DELETE FROM forge_farming_jobs WHERE status = 'collected'", {})

    local rows = SafeQuery(MySQL.query,
        "SELECT * FROM forge_farming_jobs WHERE status != 'collected'", {}
    ) or {}

    for _, row in ipairs(rows) do
        ActiveJobs[row.id] = {
            id = row.id,
            playerIdentifier = row.player_identifier,
            pointId = row.point_id,
            recipeId = row.recipe_id,
            amount = row.amount,
            totalDuration = row.total_duration,
            accumulatedMs = row.accumulated_ms,
            status = row.status,
            lastTickAt = os.time(),
        }
    end
end)

local function ShouldAccumulateTime(job)
    if Config.ProcessingContinuesOffline then
        return true
    end
    return Framework.IsPlayerOnline(job.playerIdentifier)
end

local function GetLiveAccumulatedMs(job)
    if job.status ~= 'running' or not ShouldAccumulateTime(job) then
        return math.min(job.accumulatedMs, job.totalDuration)
    end
    return math.min(job.accumulatedMs + (os.time() - job.lastTickAt) * 1000, job.totalDuration)
end

local function CountFinishedRuns(job, recipe, accumulatedMs)
    if recipe.duration <= 0 then
        return job.amount
    end
    return math.min(math.floor(accumulatedMs / recipe.duration), job.amount)
end

local function NotifyJobReady(job)
    local src = Framework.GetSourceFromIdentifier(job.playerIdentifier)
    if not src then
        return
    end
    local recipe = GetJobRecipe(job)
    Framework.Notify(src, Locale('verarbeiter_job_ready_notify', recipe and recipe.label or '?'), 'success')
end

local function TickJob(job)
    local elapsedSeconds = os.time() - job.lastTickAt
    job.lastTickAt = os.time()

    if elapsedSeconds <= 0 or not ShouldAccumulateTime(job) then
        return
    end

    job.accumulatedMs = math.min(job.accumulatedMs + elapsedSeconds * 1000, job.totalDuration)
    if job.accumulatedMs >= job.totalDuration then
        job.status = 'ready'
    end

    SafeQuery(MySQL.update,
        'UPDATE forge_farming_jobs SET accumulated_ms = ?, status = ? WHERE id = ?',
        { job.accumulatedMs, job.status, job.id }
    )

    if job.status == 'ready' then
        NotifyJobReady(job)
    end
end

CreateThread(function()
    while true do
        Wait(TICK_INTERVAL_MS)

        local jobIds = {}
        for id in pairs(ActiveJobs) do
            jobIds[#jobIds + 1] = id
        end

        for _, id in ipairs(jobIds) do
            local job = ActiveJobs[id]
            if job and job.status == 'running' and not job.busy then
                TickJob(job)
            end
        end
    end
end)

local function BuildJobState(job)
    if not job then
        return { status = 'none' }
    end

    local recipe = GetJobRecipe(job)
    if not recipe then
        return { status = 'none' }
    end

    local liveAccumulated = GetLiveAccumulatedMs(job)
    local finishedRuns = CountFinishedRuns(job, recipe, liveAccumulated)

    return {
        status = job.status,
        recipeLabel = recipe.label,
        outputItem = recipe.outputItem,
        totalRuns = job.amount,
        finishedRuns = finishedRuns,
        finishedOutput = recipe.outputAmount * finishedRuns,
        totalOutput = recipe.outputAmount * job.amount,
        remainingMs = math.max(0, job.totalDuration - liveAccumulated),
    }
end

RegisterNetEvent('forge_farming:verarbeiter:getJobState')
AddEventHandler('forge_farming:verarbeiter:getJobState', function(pointId)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local job = FindPlayerJobAtPoint(identifier, pointId)
    TriggerClientEvent('forge_farming:verarbeiter:jobState', src, BuildJobState(job))
end)

local function ValidateJobStart(src, identifier, pointId, recipeId, amountInput)
    local point = GetFarmPoint(pointId)
    if not point or point.type ~= 'verarbeiter' then
        return nil, nil, Locale('error_invalid_input')
    end
    if not IsPlayerNearPoint(src, point) then
        return nil, nil, Locale('error_too_far')
    end

    local recipe = GetPointRecipe(point, recipeId)
    if not recipe then
        return nil, nil, Locale('error_invalid_input')
    end
    if CountUncollectedJobs(identifier) >= Config.MaxParallelProcessingJobs then
        return nil, nil, Locale('verarbeiter_job_limit', Config.MaxParallelProcessingJobs)
    end
    if FindPlayerJobAtPoint(identifier, pointId) then
        return nil, nil, Locale('error_invalid_input')
    end

    local amount = ResolveAmount(src, recipe, amountInput)
    if amount <= 0 or not HasRequiredInputs(src, recipe, amount) then
        return nil, nil, Locale('verarbeiter_not_enough_items')
    end
    if recipe.duration * amount > MAX_TOTAL_DURATION then
        return nil, nil, Locale('error_invalid_input')
    end
    return recipe, amount, nil
end

local reservationCounter = 0

local function CreateJob(identifier, pointId, recipeId, amount, totalDuration)
    reservationCounter = reservationCounter + 1
    local reservationId = 'pending_' .. reservationCounter

    local job = {
        id = reservationId,
        playerIdentifier = identifier,
        pointId = pointId,
        recipeId = recipeId,
        amount = amount,
        totalDuration = totalDuration,
        accumulatedMs = 0,
        status = 'running',
        lastTickAt = os.time(),
        busy = true,
    }
    ActiveJobs[reservationId] = job

    local insertId = SafeQuery(MySQL.insert,
        "INSERT INTO forge_farming_jobs (player_identifier, point_id, recipe_id, amount, total_duration, accumulated_ms, status) VALUES (?, ?, ?, ?, ?, 0, 'running')",
        { identifier, pointId, recipeId, amount, totalDuration }
    )

    ActiveJobs[reservationId] = nil
    if not insertId then
        return nil
    end

    job.id = insertId
    job.busy = nil
    job.lastTickAt = os.time()
    ActiveJobs[insertId] = job
    return job
end

RegisterNetEvent('forge_farming:verarbeiter:startJob')
AddEventHandler('forge_farming:verarbeiter:startJob', function(pointId, recipeId, amountInput)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local recipe, amount, errorMessage = ValidateJobStart(src, identifier, pointId, recipeId, amountInput)
    if not recipe then
        Framework.Notify(src, errorMessage, 'error')
        return
    end

    if not RemoveRecipeInputs(src, recipe, amount) then
        Framework.Notify(src, Locale('verarbeiter_not_enough_items'), 'error')
        return
    end

    local job = CreateJob(identifier, pointId, recipeId, amount, recipe.duration * amount)
    if not job then
        RefundRecipeInputs(src, recipe, amount)
        Framework.Notify(src, Locale('error_database'), 'error')
        return
    end

    SendDiscordWebhook(Config.Webhooks.verarbeiten, 'Verarbeitung gestartet', 3447003, {
        { name = 'Spieler', value = identifier, inline = true },
        { name = 'Rezept', value = recipe.label, inline = true },
        { name = 'Menge', value = tostring(amount), inline = true },
    })

    Framework.Notify(src, Locale('verarbeiter_job_started', amount, recipe.label), 'success')
end)

RegisterNetEvent('forge_farming:verarbeiter:addToJob')
AddEventHandler('forge_farming:verarbeiter:addToJob', function(pointId, amountInput)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local point = GetFarmPoint(pointId)
    if not point or point.type ~= 'verarbeiter' then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end
    if not IsPlayerNearPoint(src, point) then
        Framework.Notify(src, Locale('error_too_far'), 'error')
        return
    end

    local job = FindPlayerJobAtPoint(identifier, pointId)
    if not job or job.status ~= 'running' or job.busy then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local recipe = GetJobRecipe(job)
    if not recipe then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local amount = ResolveAmount(src, recipe, amountInput)
    if amount <= 0 or not HasRequiredInputs(src, recipe, amount) then
        Framework.Notify(src, Locale('verarbeiter_not_enough_items'), 'error')
        return
    end

    local addedDuration = recipe.duration * amount
    if job.totalDuration + addedDuration > MAX_TOTAL_DURATION then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    if not RemoveRecipeInputs(src, recipe, amount) then
        Framework.Notify(src, Locale('verarbeiter_not_enough_items'), 'error')
        return
    end

    local previousAmount = job.amount
    local previousDuration = job.totalDuration
    job.amount = job.amount + amount
    job.totalDuration = job.totalDuration + addedDuration
    job.busy = true

    local affected = SafeQuery(MySQL.update,
        'UPDATE forge_farming_jobs SET amount = ?, total_duration = ? WHERE id = ?',
        { job.amount, job.totalDuration, job.id }
    )
    job.busy = nil

    if not affected then
        job.amount = previousAmount
        job.totalDuration = previousDuration
        RefundRecipeInputs(src, recipe, amount)
        Framework.Notify(src, Locale('error_database'), 'error')
        return
    end

    SendDiscordWebhook(Config.Webhooks.verarbeiten, 'Verarbeitung erweitert', 3447003, {
        { name = 'Spieler', value = identifier, inline = true },
        { name = 'Rezept', value = recipe.label, inline = true },
        { name = 'Zusaetzliche Menge', value = tostring(amount), inline = true },
    })

    Framework.Notify(src, Locale('verarbeiter_job_added', amount, recipe.label), 'success')
end)

RegisterNetEvent('forge_farming:verarbeiter:collectJob')
AddEventHandler('forge_farming:verarbeiter:collectJob', function(pointId)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local job = FindPlayerJobAtPoint(identifier, pointId)
    if not job or job.status ~= 'ready' or job.busy then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local point = GetFarmPoint(pointId)
    if not point then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end
    if not IsPlayerNearPoint(src, point) then
        Framework.Notify(src, Locale('error_too_far'), 'error')
        return
    end

    local recipe = GetJobRecipe(job)
    if not recipe then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local totalOutput = recipe.outputAmount * job.amount
    if Config.VerarbeiterCanCarryCheck and not Framework.CanCarryItem(src, recipe.outputItem, totalOutput) then
        Framework.Notify(src, Locale('error_inventory_full'), 'error')
        return
    end

    job.status = 'collecting'
    job.busy = true

    local affected = SafeQuery(MySQL.update,
        "UPDATE forge_farming_jobs SET status = 'collected' WHERE id = ?",
        { job.id }
    )
    if not affected then
        job.status = 'ready'
        job.busy = nil
        Framework.Notify(src, Locale('error_database'), 'error')
        return
    end

    if not Framework.AddItem(src, recipe.outputItem, totalOutput) then
        SafeQuery(MySQL.update, "UPDATE forge_farming_jobs SET status = 'ready' WHERE id = ?", { job.id })
        job.status = 'ready'
        job.busy = nil
        Framework.Notify(src, Locale('error_inventory_full'), 'error')
        return
    end

    ActiveJobs[job.id] = nil

    SendDiscordWebhook(Config.Webhooks.verarbeiten, 'Auftrag abgeholt', 3066993, {
        { name = 'Spieler', value = identifier, inline = true },
        { name = 'Item', value = recipe.outputItem, inline = true },
        { name = 'Menge', value = tostring(totalOutput), inline = true },
    })

    Framework.Notify(src, Locale('verarbeiter_collect_success', totalOutput, recipe.outputItem), 'success')
end)

local function ResolveCollectRuns(recipe, finishedRuns, amountInput)
    local collectRuns = finishedRuns
    if type(amountInput) == 'number' and amountInput > 0 and amountInput == amountInput then
        collectRuns = math.min(math.floor(amountInput), finishedRuns)
    end

    local cap = Config.CollectMaxPerAction and Config.CollectMaxPerAction[recipe.outputItem]
    if not cap and Config.CollectWeaponsSingle
        and string.match(recipe.outputItem or '', '^[Ww][Ee][Aa][Pp][Oo][Nn]_') then
        cap = 1
    end
    if type(cap) == 'number' and cap > 0 then
        collectRuns = math.min(collectRuns, cap)
    end
    return collectRuns
end

local function CollectFinishedRuns(src, identifier, job, recipe, amountInput)
    if job.status == 'running' then
        TickJob(job)
    end

    local finishedRuns = CountFinishedRuns(job, recipe, job.accumulatedMs)
    local collectRuns = finishedRuns > 0 and ResolveCollectRuns(recipe, finishedRuns, amountInput) or 0
    if collectRuns <= 0 then
        Framework.Notify(src, Locale('verarbeiter_nothing_ready'), 'error')
        return
    end

    local output = recipe.outputAmount * collectRuns
    if Config.VerarbeiterCanCarryCheck and not Framework.CanCarryItem(src, recipe.outputItem, output) then
        Framework.Notify(src, Locale('error_inventory_full'), 'error')
        return
    end

    local previous = {
        amount = job.amount,
        accumulatedMs = job.accumulatedMs,
        totalDuration = job.totalDuration,
        status = job.status,
    }

    local newAmount = job.amount - collectRuns
    local newAccumulated = math.max(0, job.accumulatedMs - collectRuns * recipe.duration)
    local newTotal = recipe.duration * newAmount
    local newStatus = (newAmount <= 0 and 'collected') or ((newAccumulated >= newTotal) and 'ready' or 'running')

    local affected = SafeQuery(MySQL.update,
        'UPDATE forge_farming_jobs SET amount = ?, total_duration = ?, accumulated_ms = ?, status = ? WHERE id = ?',
        { math.max(newAmount, 0), newTotal, newAccumulated, newStatus, job.id }
    )
    if not affected then
        Framework.Notify(src, Locale('error_database'), 'error')
        return
    end

    if not Framework.AddItem(src, recipe.outputItem, output) then
        SafeQuery(MySQL.update,
            'UPDATE forge_farming_jobs SET amount = ?, total_duration = ?, accumulated_ms = ?, status = ? WHERE id = ?',
            { previous.amount, previous.totalDuration, previous.accumulatedMs, previous.status, job.id }
        )
        Framework.Notify(src, Locale('error_inventory_full'), 'error')
        return
    end

    job.amount = newAmount
    job.accumulatedMs = newAccumulated
    job.totalDuration = newTotal
    job.lastTickAt = os.time()
    if newAmount <= 0 then
        ActiveJobs[job.id] = nil
    else
        job.status = newStatus
    end

    SendDiscordWebhook(Config.Webhooks.verarbeiten, 'Fertige abgeholt', 3066993, {
        { name = 'Spieler', value = identifier, inline = true },
        { name = 'Item', value = recipe.outputItem, inline = true },
        { name = 'Menge', value = tostring(output), inline = true },
    })

    Framework.Notify(src, Locale('verarbeiter_collect_success', output, recipe.outputItem), 'success')
end

RegisterNetEvent('forge_farming:verarbeiter:collectFinished')
AddEventHandler('forge_farming:verarbeiter:collectFinished', function(pointId, amountInput)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local job = FindPlayerJobAtPoint(identifier, pointId)
    if not job or job.busy or job.status == 'collecting' then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local point = GetFarmPoint(pointId)
    if not point then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end
    if not IsPlayerNearPoint(src, point) then
        Framework.Notify(src, Locale('error_too_far'), 'error')
        return
    end

    local recipe = GetJobRecipe(job)
    if not recipe then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    job.busy = true
    local ok, err = pcall(CollectFinishedRuns, src, identifier, job, recipe, amountInput)
    job.busy = nil
    if not ok then
        DebugPrint('collectFinished failed:', err)
    end
end)

AddEventHandler('forge_farming:playerLoaded', function(src)
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    for _, job in pairs(ActiveJobs) do
        if job.playerIdentifier == identifier then
            local recipe = GetJobRecipe(job)
            local label = recipe and recipe.label or '?'
            if job.status == 'ready' then
                Framework.Notify(src, Locale('verarbeiter_ready_on_join', label), 'success')
            elseif job.status == 'running' then
                Framework.Notify(src, Locale('verarbeiter_continues_on_join', label), 'info')
            end
        end
    end
end)
