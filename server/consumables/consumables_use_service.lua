ConsumablesUseService = {}

local Service = {}
Service.__index = Service

function ConsumablesUseService.New(options)
    return setmetatable({
        registry = options.registry,
        inventory = options.inventory,
        now = options.now,
        tokenFactory = options.tokenFactory,
        completionToleranceMs = options.completionToleranceMs or 0,
        defaultCooldownMs = options.defaultCooldownMs or 0,
        removeItem = options.removeItem ~= false,
        pendingUses = {},
        cooldowns = {},
    }, Service)
end

local function failure(errorCode)
    return { ok = false, error = errorCode }
end

local function isOnCooldown(self, source, itemName)
    local playerCooldowns = self.cooldowns[source]
    local cooldownEnd = playerCooldowns and playerCooldowns[itemName] or 0
    return self.now() < cooldownEnd
end

function Service:Begin(source, itemName)
    source = tonumber(source)
    if not source or source <= 0 then return failure('invalid_source') end
    local definition = self.registry:Get(itemName)
    if not definition then return failure('unknown_item') end
    if self.pendingUses[source] then return failure('already_using') end
    if isOnCooldown(self, source, itemName) then return failure('cooldown_active') end
    if self.inventory.GetCount(source, itemName) < 1 then return failure('missing_item') end

    local duration = math.max(0, definition.consume and definition.consume.duration or 0)
    local pending = {
        token = self.tokenFactory(),
        itemName = itemName,
        definition = definition,
        startedAt = self.now(),
        minimumDuration = math.max(0, duration - self.completionToleranceMs),
        completing = false,
    }
    self.pendingUses[source] = pending
    return {
        ok = true,
        token = pending.token,
        itemName = itemName,
        definition = definition,
        duration = duration,
    }
end

function Service:Cancel(source, token)
    local pending = self.pendingUses[source]
    if not pending or pending.token ~= token or pending.completing then
        return false
    end
    self.pendingUses[source] = nil
    return true
end

function Service:Expire(source, token)
    return self:Cancel(source, token)
end

local function removeExactlyOne(self, source, pending)
    if self.inventory.GetCount(source, pending.itemName) < 1 then return false end
    if not self.removeItem then return true end
    return self.inventory.Remove(source, pending.itemName) == true
end

function Service:Complete(source, token)
    local pending = self.pendingUses[source]
    if not pending or pending.token ~= token or pending.completing then
        return failure('invalid_token')
    end
    if self.now() - pending.startedAt < pending.minimumDuration then
        self.pendingUses[source] = nil
        return failure('too_fast')
    end
    pending.completing = true
    local removed = removeExactlyOne(self, source, pending)
    local owned = self.pendingUses[source] == pending
    if owned then
        self.pendingUses[source] = nil
    end
    if not removed then return failure('remove_failed') end
    if owned then
        self.cooldowns[source] = self.cooldowns[source] or {}
        self.cooldowns[source][pending.itemName] =
            self.now() + (pending.definition.cooldown or self.defaultCooldownMs)
    end
    return { ok = true, itemName = pending.itemName, definition = pending.definition }
end

function Service:Clear(source)
    self.pendingUses[source] = nil
    self.cooldowns[source] = nil
end
