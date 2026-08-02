CreatorAccess = {}

local function ValidateRegistration(commandName, options)
    if type(commandName) ~= 'string' or commandName == '' then
        error('CreatorAccess commandName must be a non-empty string')
    end
    if type(options) ~= 'table' then
        error('CreatorAccess options must be a table')
    end
    if type(options.open) ~= 'function' then
        error('CreatorAccess options.open must be a function')
    end
    if type(options.deniedMessage) ~= 'string' or options.deniedMessage == '' then
        error('CreatorAccess options.deniedMessage must be a non-empty string')
    end
    if options.isReady ~= nil and type(options.isReady) ~= 'function' then
        error('CreatorAccess options.isReady must be a function')
    end
end

function CreatorAccess.RegisterCommand(commandName, options)
    ValidateRegistration(commandName, options)

    RegisterCommand(commandName, function(commandSource)
        local source = tonumber(commandSource)
        if not source or source <= 0 then return end
        if options.isReady and not options.isReady() then return end

        if not Framework.HasPermission(source) then
            Framework.Notify(source, options.deniedMessage, 'error')
            return
        end

        options.open(source)
    end, false)
end
