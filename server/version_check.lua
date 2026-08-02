local RESOURCE = GetCurrentResourceName()
local SETTINGS = Config.VersionCheck or {}
local REPOSITORY = SETTINGS.Repository or 'ForgeCode-2026/FarmingCreator-X-Hex'
local BRANCH = SETTINGS.Branch or 'main'

local function FetchRepoFile(path, callback)
    if not VersionUtils.IsSafeGithubTarget(REPOSITORY, BRANCH) then
        callback(nil, 'invalid_target')
        return
    end

    local url = ('https://raw.githubusercontent.com/%s/%s/%s'):format(
        REPOSITORY, BRANCH, path)
    PerformHttpRequest(url, function(status, body)
        if status == 200 and type(body) == 'string' and #body > 0 then
            callback(body, nil)
        else
            callback(nil, ('http_%s'):format(tostring(status)))
        end
    end, 'GET', '', {
        ['User-Agent'] = RESOURCE
    })
end

local function PrintChangelogSince(changelog, currentVersion)
    local limit = tonumber(SETTINGS.MaxChangelogLines) or 40
    local lines = VersionUtils.CollectChangelog(changelog, currentVersion, limit)
    for _, line in ipairs(lines) do
        print(('^3[%s] %s^7'):format(RESOURCE, line))
    end
end

local function CheckVersion()
    local currentText = GetResourceMetadata(RESOURCE, 'version', 0)
    if not VersionUtils.Parse(currentText) then
        print(('^3[%s] Lokale Version ist ungueltig.^7'):format(RESOURCE))
        return
    end

    FetchRepoFile('fxmanifest.lua', function(manifest, fetchError)
        if not manifest then
            print(('^3[%s] Versionspruefung nicht moeglich (%s).^7'):format(
                RESOURCE, fetchError or 'GitHub nicht erreichbar'))
            return
        end

        local latestText = VersionUtils.ExtractManifestVersion(manifest)
        local comparison = latestText and VersionUtils.Compare(currentText, latestText)
        if comparison == nil then
            print(('^3[%s] GitHub-Manifest enthaelt keine gueltige Version.^7'):format(RESOURCE))
            return
        end

        if comparison >= 0 then
            print(('^2[%s] Version %s ist aktuell.^7'):format(RESOURCE, currentText))
            return
        end

        print(('^1[%s] ================= UPDATE VERFUEGBAR =================^7'):format(RESOURCE))
        print(('^1[%s] Installierte Version: %s | Neueste Version: %s^7'):format(RESOURCE, currentText, latestText))
        print(('^1[%s] Download: https://github.com/%s^7'):format(RESOURCE, REPOSITORY))

        FetchRepoFile('CHANGELOG.md', function(changelog)
            if changelog then
                print(('^3[%s] Aenderungen seit Version %s:^7'):format(RESOURCE, currentText))
                PrintChangelogSince(changelog, currentText)
            else
                print(('^3[%s] Changelog konnte nicht geladen werden.^7'):format(RESOURCE))
            end
            print(('^1[%s] =====================================================^7'):format(RESOURCE))
        end)
    end)
end

if SETTINGS.Enabled ~= false then
    CreateThread(function()
        Wait(math.max(0, tonumber(SETTINGS.DelayMs) or 5000))
        CheckVersion()
    end)
end
