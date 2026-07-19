ConsumablesCreatorService = {}

local Service = {}
Service.__index = Service

function ConsumablesCreatorService.New(options)
    return setmetatable({
        registry = options.registry,
        hasPermission = options.hasPermission,
        logger = options.logger or function() end,
        busy = false,
    }, Service)
end

local function runMutation(self, source, mutation)
    if not self.hasPermission(source) then return false, 'no_permission' end
    if self.busy then return false, 'creator_busy' end
    self.busy = true
    local success, ok, errorCode = pcall(mutation)
    self.busy = false
    if not success then
        self.logger(('consumables: creator mutation failed: %s'):format(tostring(ok)))
        return false, 'internal_error'
    end
    return ok, errorCode
end

function Service:Create(source, itemName, definition)
    return runMutation(self, source, function()
        return self.registry:Create(itemName, definition)
    end)
end

function Service:Update(source, itemName, definition)
    return runMutation(self, source, function()
        return self.registry:Update(itemName, definition)
    end)
end

function Service:Delete(source, itemName)
    return runMutation(self, source, function()
        return self.registry:Delete(itemName)
    end)
end
