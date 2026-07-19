Config.ESXAdminGroups = { 'admin', 'superadmin' }

Config.QBPermissionLevel = 'admin'

Config.Webhooks = {
    sammeln = '',
    verarbeiten = '',
    verkaufen = '',
}

Config.BoostWindows = {
    { from = '18:00', to = '20:00', multiplier = 2 },
}

Config.ProcessingContinuesOffline = false

Config.MaxParallelProcessingJobs = 1

Config.VerarbeiterCanCarryCheck = true

Config.CollectMaxPerAction = {
}

Config.CollectWeaponsSingle = true

Config.BoostStartAnnounce = 'Farming-Boost aktiv: %dx Ausbeute an allen Sammel-Punkten!'
Config.BoostEndAnnounce = 'Der %dx Farming-Boost ist vorbei.'

Config.PoliceAlert = {
    chance = 100,
}

function SendPoliceAlert(source, coords, data)

end
