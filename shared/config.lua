Config = {}

Config.Framework = 'esx'

Config.MaxPlacementDistance = 10.0

Config.InteractionDistance = 3.0

Config.DefaultMarkerType = 1
Config.DefaultMarkerColor = { r = 0, g = 155, b = 255, a = 120 }
Config.DefaultMarkerRadius = 1.5

Config.FloatingMarkerZOffset = 1.0

Config.DefaultPayoutAccount = 'cash'

Config.Locale = 'de'

Config.Debug = true

function DebugPrint(...)
    if not Config.Debug then return end
    print('^3[Forge Farming Debug]^7', ...)
end
