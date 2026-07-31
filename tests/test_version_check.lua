local output = {}
local requestedUrls = {}

Config = {
    VersionCheck = {
        Enabled = true,
        Repository = 'ForgeCode-2026/FarmingCreator-X-Hex',
        Branch = 'main',
        DelayMs = 0,
        MaxChangelogLines = 40,
    },
}

function GetCurrentResourceName()
    return 'farming_creator'
end

function GetResourceMetadata()
    return '1.4.0'
end

function CreateThread(callback)
    callback()
end

function Wait()
end

function PerformHttpRequest(url, callback)
    requestedUrls[#requestedUrls + 1] = url
    if url:match('fxmanifest%.lua$') then
        callback(200, "fx_version 'cerulean'\nversion '1.5.0'")
        return
    end
    callback(200, [[
## [1.5.0] - 2026-08-01

- Neue HUD-Integration

---

## [1.4.0] - 2026-07-22

- Bereits installiert
]])
end

print = function(message)
    output[#output + 1] = tostring(message)
end

local function Contains(lines, fragment)
    for _, line in ipairs(lines) do
        if line:find(fragment, 1, true) then return true end
    end
    return false
end

dofile('server/version_utils.lua')
dofile('server/version_check.lua')

assert(#requestedUrls == 2, 'Versionspruefung muss Manifest und Changelog laden')
assert(Contains(requestedUrls, '/main/fxmanifest.lua'), 'Manifest-URL ist falsch')
assert(Contains(requestedUrls, '/main/CHANGELOG.md'), 'Changelog-URL ist falsch')
assert(Contains(output, 'UPDATE VERFUEGBAR'), 'Update-Kopfzeile fehlt')
assert(Contains(output, 'Installierte Version: 1.4.0 | Neueste Version: 1.5.0'),
    'Versionsvergleich fehlt')
assert(Contains(output, '## [1.5.0]'), 'Neuer Changelog-Abschnitt fehlt')
assert(not Contains(output, '## [1.4.0]'), 'Installierter Changelog-Abschnitt wurde ausgegeben')

io.write('PASS test_version_check\n')
