ConsumablesRegistry = {}

local SEED_MARKER = 'consumables_initial_seed_complete'

local Registry = {}
Registry.__index = Registry

function ConsumablesRegistry.New(store, schema, presets, seedItems, logger)
    return setmetatable({
        store = store,
        schema = schema,
        presets = presets,
        seedItems = seedItems,
        logger = logger or function() end,
        items = {},
        ready = false,
    }, Registry)
end

local function mirrorToConfig(self)
    if type(Config) == 'table' then
        Config.Items = self.schema.Copy(self.items)
    end
end

local function logInvalidItems(self, errors, source)
    for name, errorCode in pairs(errors) do
        self.logger(('consumables: skipping invalid %s item %s (%s)')
            :format(source, tostring(name), tostring(errorCode)))
    end
end

local function ensureSeeded(self)
    local marker, metaError = self.store:GetMeta(SEED_MARKER)
    if metaError then return false end
    if marker ~= nil then return true end
    local seeds, seedErrors = self.schema.NormalizeSnapshot(self.seedItems, self.presets)
    logInvalidItems(self, seedErrors, 'seed')
    local written = self.store:WriteInitialSeed(seeds, SEED_MARKER, '1')
    return written == true
end

local function loadItems(self)
    local rows, loadInfo = self.store:LoadAll()
    if rows == nil then return false end
    for _, name in ipairs(loadInfo or {}) do
        self.logger(('consumables: skipping undecodable stored item %s'):format(tostring(name)))
    end
    local items, errors = self.schema.NormalizeSnapshot(rows, self.presets)
    logInvalidItems(self, errors, 'stored')
    self.items = items
    return true
end

function Registry:Initialize()
    local ok = self.store:EnsureTables()
    if not ok then
        self.logger('consumables: creating tables failed')
        return false
    end
    if not ensureSeeded(self) then
        self.logger('consumables: initial seed failed')
        return false
    end
    if not loadItems(self) then
        self.logger('consumables: loading stored items failed')
        return false
    end
    mirrorToConfig(self)
    self.ready = true
    return true
end

function Registry:IsReady()
    return self.ready
end

function Registry:Get(itemName)
    local name = self.schema.NormalizeItemName(itemName)
    if not name then return nil end
    return self.schema.Copy(self.items[name])
end

function Registry:Snapshot()
    return self.schema.Copy(self.items)
end

local function validateWrite(self, itemName, definition)
    if not self.ready then return nil, nil, 'not_ready' end
    local name, nameError = self.schema.NormalizeItemName(itemName)
    if not name then return nil, nil, nameError end
    local normalized, definitionError = self.schema.NormalizeDefinition(definition, self.presets)
    if not normalized then return nil, nil, definitionError end
    return name, normalized, nil
end

function Registry:Create(itemName, definition)
    local name, normalized, validationError = validateWrite(self, itemName, definition)
    if validationError then return false, validationError end
    if self.items[name] then return false, 'duplicate_item' end
    local success, storeError = self.store:Create(name, normalized)
    if not success then return false, storeError or 'database_error' end
    self.items[name] = normalized
    mirrorToConfig(self)
    return true, nil
end

function Registry:Update(itemName, definition)
    local name, normalized, validationError = validateWrite(self, itemName, definition)
    if validationError then return false, validationError end
    if not self.items[name] then return false, 'unknown_item' end
    local success, storeError = self.store:Update(name, normalized)
    if not success then return false, storeError or 'database_error' end
    self.items[name] = normalized
    mirrorToConfig(self)
    return true, nil
end

function Registry:Delete(itemName)
    if not self.ready then return false, 'not_ready' end
    local name, nameError = self.schema.NormalizeItemName(itemName)
    if not name then return false, nameError end
    if not self.items[name] then return false, 'unknown_item' end
    local success, storeError = self.store:Delete(name)
    if not success then return false, storeError or 'database_error' end
    self.items[name] = nil
    mirrorToConfig(self)
    return true, nil
end
