ActiveJobs = {}

local TICK_INTERVAL_MS = 30000

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
        if job.playerIdentifier == identifier
            and (job.status == 'running' or job.status == 'ready') then
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

    MySQL.update.await('DELETE FROM forge_farming_jobs WHERE point_id = ?', { pointId })

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

local function HasRequiredInputs(src, recipe, amount)
    for _, input in ipairs(recipe.inputs) do
        if Framework.GetItemCount(src, input.item) < input.amount * amount then
            return false
        end
    end
    return true
end

local function RemoveRecipeInputs(src, recipe, amount)
    for _, input in ipairs(recipe.inputs) do
        Framework.RemoveItem(src, input.item, input.amount * amount)
    end
end

local function RefundRecipeInputs(src, recipe, amount)
    for _, input in ipairs(recipe.inputs) do
        Framework.AddItem(src, input.item, input.amount * amount)
    end
end

local function ComputeMaxCraftable(src, recipe)
    local maxAmount = nil
    for _, input in ipairs(recipe.inputs) do
        local possible = math.floor(Framework.GetItemCount(src, input.item) / input.amount)
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

    local rows = MySQL.query.await(
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

    MySQL.update.await(
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
            if job and job.status == 'running' then
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
    }
    ActiveJobs[reservationId] = job

    local insertId = MySQL.insert.await(
        "INSERT INTO forge_farming_jobs (player_identifier, point_id, recipe_id, amount, total_duration, accumulated_ms, status) VALUES (?, ?, ?, ?, ?, 0, 'running')",
        { identifier, pointId, recipeId, amount, totalDuration }
    )

    ActiveJobs[reservationId] = nil
    if not insertId then
        return nil
    end

    job.id = insertId
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

    RemoveRecipeInputs(src, recipe, amount)

    local job = CreateJob(identifier, pointId, recipeId, amount, recipe.duration * amount)
    if not job then
        RefundRecipeInputs(src, recipe, amount)
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
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
    if not job or job.status ~= 'running' then
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

    RemoveRecipeInputs(src, recipe, amount)

    job.amount = job.amount + amount
    job.totalDuration = job.totalDuration + (recipe.duration * amount)

    MySQL.update.await(
        'UPDATE forge_farming_jobs SET amount = ?, total_duration = ? WHERE id = ?',
        { job.amount, job.totalDuration, job.id }
    )

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
    if not job or job.status ~= 'ready' then
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
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    job.status = 'collecting'

    if not Framework.AddItem(src, recipe.outputItem, totalOutput) then
        job.status = 'ready'
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    MySQL.update.await(
        "UPDATE forge_farming_jobs SET status = 'collected' WHERE id = ?",
        { job.id }
    )
    ActiveJobs[job.id] = nil

    SendDiscordWebhook(Config.Webhooks.verarbeiten, 'Auftrag abgeholt', 3066993, {
        { name = 'Spieler', value = identifier, inline = true },
        { name = 'Item', value = recipe.outputItem, inline = true },
        { name = 'Menge', value = tostring(totalOutput), inline = true },
    })

    Framework.Notify(src, Locale('verarbeiter_collect_success', totalOutput, recipe.outputItem), 'success')
end)

RegisterNetEvent('forge_farming:verarbeiter:collectFinished')
AddEventHandler('forge_farming:verarbeiter:collectFinished', function(pointId, amountInput)
    local src = source
    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local job = FindPlayerJobAtPoint(identifier, pointId)
    if not job then
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

    if job.status == 'running' then
        TickJob(job)
    end

    local finishedRuns = CountFinishedRuns(job, recipe, job.accumulatedMs)
    if finishedRuns <= 0 then
        Framework.Notify(src, Locale('verarbeiter_nothing_ready'), 'error')
        return
    end

    local collectRuns
    if amountInput == 'max' or amountInput == nil then
        collectRuns = finishedRuns
    elseif type(amountInput) == 'number' and amountInput > 0 then
        collectRuns = math.min(math.floor(amountInput), finishedRuns)
    else
        collectRuns = finishedRuns
    end

    local cap = Config.CollectMaxPerAction and Config.CollectMaxPerAction[recipe.outputItem]
    if not cap and Config.CollectWeaponsSingle
        and string.match(recipe.outputItem or '', '^[Ww][Ee][Aa][Pp][Oo][Nn]_') then
        cap = 1
    end
    if type(cap) == 'number' and cap > 0 then
        collectRuns = math.min(collectRuns, cap)
    end

    if collectRuns <= 0 then
        Framework.Notify(src, Locale('verarbeiter_nothing_ready'), 'error')
        return
    end

    local output = recipe.outputAmount * collectRuns
    if Config.VerarbeiterCanCarryCheck and not Framework.CanCarryItem(src, recipe.outputItem, output) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    if not Framework.AddItem(src, recipe.outputItem, output) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    job.amount = job.amount - collectRuns
    job.accumulatedMs = math.max(0, job.accumulatedMs - collectRuns * recipe.duration)
    job.totalDuration = recipe.duration * job.amount
    job.lastTickAt = os.time()

    if job.amount <= 0 then
        MySQL.update.await("UPDATE forge_farming_jobs SET status = 'collected' WHERE id = ?", { job.id })
        ActiveJobs[job.id] = nil
    else
        job.status = (job.accumulatedMs >= job.totalDuration) and 'ready' or 'running'
        MySQL.update.await(
            'UPDATE forge_farming_jobs SET amount = ?, total_duration = ?, accumulated_ms = ?, status = ? WHERE id = ?',
            { job.amount, job.totalDuration, job.accumulatedMs, job.status, job.id }
        )
    end

    SendDiscordWebhook(Config.Webhooks.verarbeiten, 'Fertige abgeholt', 3066993, {
        { name = 'Spieler', value = identifier, inline = true },
        { name = 'Item', value = recipe.outputItem, inline = true },
        { name = 'Menge', value = tostring(output), inline = true },
    })

    Framework.Notify(src, Locale('verarbeiter_collect_success', output, recipe.outputItem), 'success')
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
