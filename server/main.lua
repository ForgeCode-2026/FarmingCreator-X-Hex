FarmProjects = {}
FarmPoints = {}
RecipeProjectIndex = {}

local VALID_POINT_TYPES = { sammler = true, verarbeiter = true, verkaeufer = true }
local VALID_PLACEMENT_MODES = { marker = true, npc = true }
local VALID_PAYOUT_ACCOUNTS = { cash = true, bank = true, black_money = true }

local function DecodeJsonColumn(value)
    if type(value) == 'table' then
        return value
    end
    if type(value) == 'string' and value ~= '' then
        return json.decode(value) or {}
    end
    return {}
end

local function NormalizeSellPrices(sellPrices)
    if type(sellPrices) ~= 'table' then
        return {}
    end
    for _, entry in ipairs(sellPrices) do
        if type(entry) == 'table' and type(entry.price) == 'number' then
            if entry.minPrice == nil then entry.minPrice = entry.price end
            if entry.maxPrice == nil then entry.maxPrice = entry.price end
        end
    end
    return sellPrices
end

function GetFarmProject(projectId)
    return FarmProjects[projectId]
end

function GetFarmPoint(pointId)
    return FarmPoints[pointId]
end

function SyncFarmDataToClient(target)
    target = target or -1
    TriggerClientEvent('forge_farming:sync:projects', target, FarmProjects)
    TriggerClientEvent('forge_farming:sync:points', target, FarmPoints)
end

function SendDiscordWebhook(url, title, color, fields)
    if not url or url == '' then
        return
    end

    local payload = json.encode({
        embeds = {
            {
                title = title,
                color = color,
                fields = fields,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            },
        },
    })

    PerformHttpRequest(url, function() end, 'POST', payload, {
        ['Content-Type'] = 'application/json',
    })
end

local function IsNonEmptyString(value)
    return type(value) == 'string' and value ~= ''
end

local function IsValidSellPrices(sellPrices)
    if sellPrices == nil then
        return true
    end
    if type(sellPrices) ~= 'table' then
        return false
    end
    for _, entry in ipairs(sellPrices) do
        if type(entry) ~= 'table'
            or not IsNonEmptyString(entry.item)
            or type(entry.minPrice) ~= 'number'
            or type(entry.maxPrice) ~= 'number'
            or entry.minPrice < 0
            or entry.maxPrice < entry.minPrice then
            return false
        end
    end
    return true
end

local function IsValidProjectData(data)
    if type(data) ~= 'table' then
        return false
    end
    if not IsNonEmptyString(data.label) or not IsNonEmptyString(data.rawItem) then
        return false
    end
    if type(data.rawMinAmount) ~= 'number'
        or type(data.rawMaxAmount) ~= 'number'
        or type(data.gatherDuration) ~= 'number' then
        return false
    end
    if data.rawMinAmount < 0 or data.rawMaxAmount < data.rawMinAmount or data.gatherDuration <= 0 then
        return false
    end
    return IsValidSellPrices(data.sellPrices)
end

local function IsValidRecipeData(data)
    if type(data) ~= 'table' then
        return false
    end
    if not IsNonEmptyString(data.label) or not IsNonEmptyString(data.outputItem) then
        return false
    end
    if type(data.outputAmount) ~= 'number' or type(data.duration) ~= 'number' then
        return false
    end
    if data.outputAmount <= 0 or data.duration <= 0 then
        return false
    end
    if type(data.inputs) ~= 'table' or #data.inputs == 0 then
        return false
    end
    for _, input in ipairs(data.inputs) do
        if type(input) ~= 'table'
            or not IsNonEmptyString(input.item)
            or type(input.amount) ~= 'number'
            or input.amount <= 0 then
            return false
        end
    end
    return true
end

local function IsValidMarkerColor(color)
    if color == nil then
        return true
    end
    if type(color) ~= 'table' then
        return false
    end
    for _, channel in ipairs({ 'r', 'g', 'b', 'a' }) do
        if color[channel] ~= nil and type(color[channel]) ~= 'number' then
            return false
        end
    end
    return true
end

local function IsValidPointData(data)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then
        return false
    end
    if not VALID_POINT_TYPES[data.type] or not VALID_PLACEMENT_MODES[data.placementMode] then
        return false
    end

    local coords = data.coords
    if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
        return false
    end
    if coords.heading ~= nil and type(coords.heading) ~= 'number' then
        return false
    end

    if data.placementMode == 'npc' and not IsNonEmptyString(data.pedModel) then
        return false
    end
    if data.payoutAccount ~= nil and not VALID_PAYOUT_ACCOUNTS[data.payoutAccount] then
        return false
    end
    if data.markerType ~= nil and type(data.markerType) ~= 'number' then
        return false
    end
    if data.markerRadius ~= nil and type(data.markerRadius) ~= 'number' then
        return false
    end
    if data.markerHeightOffset ~= nil and type(data.markerHeightOffset) ~= 'number' then
        return false
    end
    return IsValidMarkerColor(data.markerColor)
end

local function NormalizePointData(data)
    local color = data.markerColor or Config.DefaultMarkerColor
    local payoutAccount = data.payoutAccount or ''
    if data.type == 'verkaeufer' and payoutAccount == '' then
        payoutAccount = Config.DefaultPayoutAccount
    end

    local isSammler = data.type == 'sammler'
    local placementMode = isSammler and 'marker' or data.placementMode
    local pedModel = isSammler and '' or (data.pedModel or '')

    return {
        type = data.type,
        coords = {
            x = data.coords.x,
            y = data.coords.y,
            z = data.coords.z,
            heading = data.coords.heading or 0.0,
        },
        placementMode = placementMode,
        markerType = isSammler and 1 or (data.markerType or Config.DefaultMarkerType),
        markerColor = {
            r = color.r or 0,
            g = color.g or 0,
            b = color.b or 0,
            a = color.a or 0,
        },
        markerRadius = data.markerRadius or Config.DefaultMarkerRadius,
        markerHeightOffset = data.markerHeightOffset or 0.0,
        pedModel = pedModel,
        payoutAccount = payoutAccount,
        showBlip = data.showBlip == nil or data.showBlip == true,
        policeAlert = data.policeAlert == true,
        blipSprite = type(data.blipSprite) == 'number' and data.blipSprite or nil,
        blipColor = type(data.blipColor) == 'number' and data.blipColor or nil,
    }
end

local function EnsureCreatorPermission(src)
    if Framework.HasPermission(src) then
        return true
    end
    Framework.Notify(src, Locale('error_no_permission'), 'error')
    return false
end

local function LoadProjects()
    local rows = MySQL.query.await('SELECT * FROM forge_farming_projects', {}) or {}
    for _, row in ipairs(rows) do
        FarmProjects[row.id] = {
            id = row.id,
            label = row.label,
            rawItem = row.raw_item,
            rawMinAmount = row.raw_min_amount,
            rawMaxAmount = row.raw_max_amount,
            gatherDuration = row.gather_duration,
            sellPrices = NormalizeSellPrices(DecodeJsonColumn(row.sell_prices)),
            recipes = {},
        }
    end
end

local function LoadRecipes()
    local rows = MySQL.query.await('SELECT * FROM forge_farming_recipes', {}) or {}
    for _, row in ipairs(rows) do
        local project = FarmProjects[row.project_id]
        if project then
            project.recipes[row.id] = {
                id = row.id,
                label = row.label,
                inputs = DecodeJsonColumn(row.inputs),
                outputItem = row.output_item,
                outputAmount = row.output_amount,
                duration = row.duration,
            }
            RecipeProjectIndex[row.id] = row.project_id
        end
    end
end

local function LoadPoints()
    local rows = MySQL.query.await('SELECT * FROM forge_farming_points', {}) or {}
    for _, row in ipairs(rows) do
        FarmPoints[row.id] = {
            id = row.id,
            projectId = row.project_id,
            type = row.type,
            coords = { x = row.x, y = row.y, z = row.z, heading = row.heading },
            placementMode = row.placement_mode,
            markerType = row.marker_type,
            markerColor = {
                r = row.marker_color_r,
                g = row.marker_color_g,
                b = row.marker_color_b,
                a = row.marker_color_a,
            },
            markerRadius = row.marker_radius,
            markerHeightOffset = row.marker_height_offset,
            pedModel = row.ped_model,
            payoutAccount = row.payout_account,
            showBlip = row.show_blip == 1 or row.show_blip == true,
            policeAlert = row.police_alert == 1 or row.police_alert == true,
            blipSprite = row.blip_sprite,
            blipColor = row.blip_color,
            createdBy = row.created_by,
            createdAt = row.created_at,
        }
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    FarmProjects = {}
    FarmPoints = {}
    RecipeProjectIndex = {}

    LoadProjects()
    LoadRecipes()
    LoadPoints()

    SyncFarmDataToClient()
end)

RegisterNetEvent('forge_farming:requestSync')
AddEventHandler('forge_farming:requestSync', function()
    SyncFarmDataToClient(source)
end)

RegisterNetEvent('forge_farming:creator:createProject')
AddEventHandler('forge_farming:creator:createProject', function(data)
    local src = source
    DebugPrint('createProject empfangen von source', src, 'label =', data and data.label)
    if not EnsureCreatorPermission(src) then
        DebugPrint('createProject abgelehnt: keine Berechtigung')
        return
    end

    if not IsValidProjectData(data) then
        DebugPrint('createProject abgelehnt: IsValidProjectData lieferte false')
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local sellPrices = data.sellPrices or {}
    local insertId = MySQL.insert.await(
        'INSERT INTO forge_farming_projects (label, raw_item, raw_min_amount, raw_max_amount, gather_duration, sell_prices) VALUES (?, ?, ?, ?, ?, ?)',
        { data.label, data.rawItem, data.rawMinAmount, data.rawMaxAmount, data.gatherDuration, json.encode(sellPrices) }
    )
    if not insertId then
        DebugPrint('createProject fehlgeschlagen: MySQL.insert.await lieferte kein insertId (DB-Verbindung/Schema pruefen)')
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end
    DebugPrint('createProject erfolgreich, neue id =', insertId)

    FarmProjects[insertId] = {
        id = insertId,
        label = data.label,
        rawItem = data.rawItem,
        rawMinAmount = data.rawMinAmount,
        rawMaxAmount = data.rawMaxAmount,
        gatherDuration = data.gatherDuration,
        sellPrices = sellPrices,
        recipes = {},
    }

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_project_created', data.label), 'success')
end)

RegisterNetEvent('forge_farming:creator:updateProject')
AddEventHandler('forge_farming:creator:updateProject', function(projectId, data)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local project = GetFarmProject(projectId)
    if not project or not IsValidProjectData(data) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local sellPrices = data.sellPrices or {}
    MySQL.update.await(
        'UPDATE forge_farming_projects SET label = ?, raw_item = ?, raw_min_amount = ?, raw_max_amount = ?, gather_duration = ?, sell_prices = ? WHERE id = ?',
        { data.label, data.rawItem, data.rawMinAmount, data.rawMaxAmount, data.gatherDuration, json.encode(sellPrices), projectId }
    )

    project.label = data.label
    project.rawItem = data.rawItem
    project.rawMinAmount = data.rawMinAmount
    project.rawMaxAmount = data.rawMaxAmount
    project.gatherDuration = data.gatherDuration
    project.sellPrices = sellPrices

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_project_updated', data.label), 'success')
end)

RegisterNetEvent('forge_farming:creator:deleteProject')
AddEventHandler('forge_farming:creator:deleteProject', function(projectId)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local project = GetFarmProject(projectId)
    if not project then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    MySQL.update.await('DELETE FROM forge_farming_projects WHERE id = ?', { projectId })

    for recipeId in pairs(project.recipes) do
        RecipeProjectIndex[recipeId] = nil
    end
    FarmProjects[projectId] = nil

    for pointId, point in pairs(FarmPoints) do
        if point.projectId == projectId then
            FarmPoints[pointId] = nil
        end
    end

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_project_deleted'), 'success')
end)

RegisterNetEvent('forge_farming:creator:createRecipe')
AddEventHandler('forge_farming:creator:createRecipe', function(projectId, data)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local project = GetFarmProject(projectId)
    if not project or not IsValidRecipeData(data) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local insertId = MySQL.insert.await(
        'INSERT INTO forge_farming_recipes (project_id, label, inputs, output_item, output_amount, duration) VALUES (?, ?, ?, ?, ?, ?)',
        { projectId, data.label, json.encode(data.inputs), data.outputItem, data.outputAmount, data.duration }
    )
    if not insertId then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    project.recipes[insertId] = {
        id = insertId,
        label = data.label,
        inputs = data.inputs,
        outputItem = data.outputItem,
        outputAmount = data.outputAmount,
        duration = data.duration,
    }
    RecipeProjectIndex[insertId] = projectId

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_recipe_created', data.label), 'success')
end)

RegisterNetEvent('forge_farming:creator:updateRecipe')
AddEventHandler('forge_farming:creator:updateRecipe', function(recipeId, data)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local projectId = RecipeProjectIndex[recipeId]
    local project = projectId and FarmProjects[projectId]
    local recipe = project and project.recipes[recipeId]
    if not recipe or not IsValidRecipeData(data) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    MySQL.update.await(
        'UPDATE forge_farming_recipes SET label = ?, inputs = ?, output_item = ?, output_amount = ?, duration = ? WHERE id = ?',
        { data.label, json.encode(data.inputs), data.outputItem, data.outputAmount, data.duration, recipeId }
    )

    recipe.label = data.label
    recipe.inputs = data.inputs
    recipe.outputItem = data.outputItem
    recipe.outputAmount = data.outputAmount
    recipe.duration = data.duration

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_recipe_updated', data.label), 'success')
end)

local function GetActiveJobsErrorText()
    local text = Locale('error_recipe_has_active_jobs')
    if text == 'error_recipe_has_active_jobs' then
        return Locale('error_invalid_input')
    end
    return text
end

RegisterNetEvent('forge_farming:creator:deleteRecipe')
AddEventHandler('forge_farming:creator:deleteRecipe', function(recipeId)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local projectId = RecipeProjectIndex[recipeId]
    local project = projectId and FarmProjects[projectId]
    if not project or not project.recipes[recipeId] then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local result = MySQL.query.await(
        'SELECT COUNT(*) as cnt FROM forge_farming_jobs WHERE recipe_id = ? AND status != ?',
        { recipeId, 'collected' }
    )
    local activeJobs = result and result[1] and result[1].cnt or 0
    if activeJobs > 0 then
        Framework.Notify(src, GetActiveJobsErrorText(), 'error')
        return
    end

    MySQL.update.await('DELETE FROM forge_farming_recipes WHERE id = ?', { recipeId })

    project.recipes[recipeId] = nil
    RecipeProjectIndex[recipeId] = nil

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_recipe_deleted'), 'success')
end)

RegisterNetEvent('forge_farming:creator:createPoint')
AddEventHandler('forge_farming:creator:createPoint', function(projectId, data)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local project = GetFarmProject(projectId)
    if not project or not IsValidPointData(data) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local identifier = Framework.GetIdentifier(src)
    if not identifier then return end

    local point = NormalizePointData(data)
    local insertId = MySQL.insert.await(
        "INSERT INTO forge_farming_points (project_id, type, x, y, z, heading, placement_mode, marker_type, marker_color_r, marker_color_g, marker_color_b, marker_color_a, marker_radius, marker_height_offset, ped_model, payout_account, show_blip, police_alert, blip_sprite, blip_color, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, ?, ?, ?)",
        {
            projectId, point.type,
            point.coords.x, point.coords.y, point.coords.z, point.coords.heading,
            point.placementMode, point.markerType,
            point.markerColor.r, point.markerColor.g, point.markerColor.b, point.markerColor.a,
            point.markerRadius, point.markerHeightOffset,
            point.pedModel, point.payoutAccount, point.showBlip and 1 or 0, point.policeAlert and 1 or 0, point.blipSprite, point.blipColor, identifier,
        }
    )
    if not insertId then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    FarmPoints[insertId] = {
        id = insertId,
        projectId = projectId,
        type = point.type,
        coords = point.coords,
        placementMode = point.placementMode,
        markerType = point.markerType,
        markerColor = point.markerColor,
        markerRadius = point.markerRadius,
        markerHeightOffset = point.markerHeightOffset,
        pedModel = point.pedModel ~= '' and point.pedModel or nil,
        payoutAccount = point.payoutAccount ~= '' and point.payoutAccount or nil,
        showBlip = point.showBlip,
        policeAlert = point.policeAlert,
        blipSprite = point.blipSprite,
        blipColor = point.blipColor,
        createdBy = identifier,
        createdAt = os.date('%Y-%m-%d %H:%M:%S'),
    }

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_point_created'), 'success')
end)

RegisterNetEvent('forge_farming:creator:updatePoint')
AddEventHandler('forge_farming:creator:updatePoint', function(pointId, data)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    local cached = GetFarmPoint(pointId)
    if not cached or not IsValidPointData(data) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    local point = NormalizePointData(data)
    MySQL.update.await(
        "UPDATE forge_farming_points SET type = ?, x = ?, y = ?, z = ?, heading = ?, placement_mode = ?, marker_type = ?, marker_color_r = ?, marker_color_g = ?, marker_color_b = ?, marker_color_a = ?, marker_radius = ?, marker_height_offset = ?, ped_model = NULLIF(?, ''), payout_account = NULLIF(?, ''), show_blip = ?, police_alert = ?, blip_sprite = ?, blip_color = ? WHERE id = ?",
        {
            point.type,
            point.coords.x, point.coords.y, point.coords.z, point.coords.heading,
            point.placementMode, point.markerType,
            point.markerColor.r, point.markerColor.g, point.markerColor.b, point.markerColor.a,
            point.markerRadius, point.markerHeightOffset,
            point.pedModel, point.payoutAccount, point.showBlip and 1 or 0, point.policeAlert and 1 or 0, point.blipSprite, point.blipColor, pointId,
        }
    )

    cached.type = point.type
    cached.coords = point.coords
    cached.placementMode = point.placementMode
    cached.markerType = point.markerType
    cached.markerColor = point.markerColor
    cached.markerRadius = point.markerRadius
    cached.markerHeightOffset = point.markerHeightOffset
    cached.pedModel = point.pedModel ~= '' and point.pedModel or nil
    cached.payoutAccount = point.payoutAccount ~= '' and point.payoutAccount or nil
    cached.showBlip = point.showBlip
    cached.policeAlert = point.policeAlert
    cached.blipSprite = point.blipSprite
    cached.blipColor = point.blipColor

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_point_updated'), 'success')
end)

RegisterNetEvent('forge_farming:creator:deletePoint')
AddEventHandler('forge_farming:creator:deletePoint', function(pointId)
    local src = source
    if not EnsureCreatorPermission(src) then return end

    if not GetFarmPoint(pointId) then
        Framework.Notify(src, Locale('error_invalid_input'), 'error')
        return
    end

    if RemoveJobsForPoint then
        RemoveJobsForPoint(pointId)
    end

    MySQL.update.await('DELETE FROM forge_farming_points WHERE id = ?', { pointId })
    FarmPoints[pointId] = nil

    SyncFarmDataToClient()
    Framework.Notify(src, Locale('creator_point_deleted'), 'success')
end)
