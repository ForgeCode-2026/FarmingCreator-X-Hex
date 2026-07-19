ConsumablesStore = {}

local Store = {}
Store.__index = Store

local CREATE_CONSUMABLES_TABLE = [[
CREATE TABLE IF NOT EXISTS `forge_farming_consumables` (
    `item_name` VARCHAR(50) NOT NULL,
    `definition` JSON NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`item_name`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci
]]

local CREATE_META_TABLE = [[
CREATE TABLE IF NOT EXISTS `forge_farming_meta` (
    `meta_key` VARCHAR(64) NOT NULL,
    `meta_value` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`meta_key`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci
]]

function ConsumablesStore.New(mysql, codec)
    return setmetatable({ mysql = mysql, codec = codec }, Store)
end

function Store:EnsureTables()
    local success = pcall(function()
        self.mysql.query.await(CREATE_CONSUMABLES_TABLE)
        self.mysql.query.await(CREATE_META_TABLE)
    end)
    if not success then return false, 'database_error' end
    return true, nil
end

function Store:GetMeta(key)
    local success, value = pcall(function()
        return self.mysql.scalar.await(
            'SELECT `meta_value` FROM `forge_farming_meta` WHERE `meta_key` = ?', { key })
    end)
    if not success then return nil, 'database_error' end
    return value, nil
end

function Store:WriteInitialSeed(items, markerKey, markerValue)
    local success, committed = pcall(function()
        local queries = {}
        for name, definition in pairs(items) do
            queries[#queries + 1] = {
                query = 'INSERT IGNORE INTO `forge_farming_consumables`'
                    .. ' (`item_name`, `definition`) VALUES (?, ?)',
                values = { name, self.codec.encode(definition) },
            }
        end
        queries[#queries + 1] = {
            query = 'INSERT IGNORE INTO `forge_farming_meta`'
                .. ' (`meta_key`, `meta_value`) VALUES (?, ?)',
            values = { markerKey, markerValue },
        }
        return self.mysql.transaction.await(queries)
    end)
    if not success or committed ~= true then return false, 'database_error' end
    return true, nil
end

function Store:LoadAll()
    local success, rows = pcall(function()
        return self.mysql.query.await(
            'SELECT `item_name`, `definition` FROM `forge_farming_consumables`')
    end)
    if not success then return nil, 'database_error' end
    local items, invalid = {}, {}
    for _, row in ipairs(rows or {}) do
        local decoded, definition = pcall(self.codec.decode, row.definition)
        if decoded and type(definition) == 'table' then
            items[row.item_name] = definition
        else
            invalid[#invalid + 1] = tostring(row.item_name)
        end
    end
    return items, invalid
end

function Store:Create(name, definition)
    local success = pcall(function()
        self.mysql.insert.await(
            'INSERT INTO `forge_farming_consumables` (`item_name`, `definition`) VALUES (?, ?)',
            { name, self.codec.encode(definition) })
    end)
    if not success then return false, 'database_error' end
    return true, nil
end

function Store:Update(name, definition)
    local success = pcall(function()
        return self.mysql.update.await(
            'UPDATE `forge_farming_consumables` SET `definition` = ? WHERE `item_name` = ?',
            { self.codec.encode(definition), name })
    end)
    if not success then return false, 'database_error' end
    return true, nil
end

function Store:Delete(name)
    local success = pcall(function()
        return self.mysql.update.await(
            'DELETE FROM `forge_farming_consumables` WHERE `item_name` = ?', { name })
    end)
    if not success then return false, 'database_error' end
    return true, nil
end
