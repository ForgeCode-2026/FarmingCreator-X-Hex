local RESOURCE = GetCurrentResourceName()
local REPO = 'ForgeCode-2026/FarmingCreator-X-Hex'

local function ParseVersion(text)
    local major, minor, patch = tostring(text):match('(%d+)%.(%d+)%.(%d+)')
    if not major then return nil end
    return tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)
end

local function FetchRepoFile(path, callback)
    local url = ('https://api.github.com/repos/%s/contents/%s?ref=main'):format(REPO, path)
    PerformHttpRequest(url, function(status, body)
        if status == 200 and type(body) == 'string' and #body > 0 then
            callback(body)
        else
            callback(nil)
        end
    end, 'GET', '', {
        ['Accept'] = 'application/vnd.github.raw+json',
        ['User-Agent'] = RESOURCE
    })
end

local function PrintChangelogSince(changelog, currentScore)
    local printing = false
    local printed = 0
    for line in changelog:gmatch('[^\r\n]+') do
        local header = line:match('^## %[(%d+%.%d+%.%d+)%]')
        if header then
            local score = ParseVersion(header)
            printing = score ~= nil and score > currentScore
            if printing then
                print(('^3[%s] %s^7'):format(RESOURCE, line))
                printed = printed + 1
            end
        elseif printing and line:match('%S') and not line:match('^---') then
            print(('^3[%s]   %s^7'):format(RESOURCE, line))
            printed = printed + 1
        end
        if printed >= 40 then break end
    end
end

local function CheckVersion()
    local currentText = GetResourceMetadata(RESOURCE, 'version', 0)
    local currentScore = ParseVersion(currentText)
    if not currentScore then return end

    FetchRepoFile('fxmanifest.lua', function(manifest)
        if not manifest then
            print(('^3[%s] Versionspruefung nicht moeglich (GitHub nicht erreichbar).^7'):format(RESOURCE))
            return
        end

        local latestText = manifest:match("version%s+'([%d%.]+)'")
        local latestScore = latestText and ParseVersion(latestText)
        if not latestScore then return end

        if latestScore <= currentScore then
            print(('^2[%s] Version %s ist aktuell.^7'):format(RESOURCE, currentText))
            return
        end

        print(('^1[%s] ================= UPDATE VERFUEGBAR =================^7'):format(RESOURCE))
        print(('^1[%s] Installierte Version: %s | Neueste Version: %s^7'):format(RESOURCE, currentText, latestText))
        print(('^1[%s] Download: https://github.com/%s^7'):format(RESOURCE, REPO))

        FetchRepoFile('CHANGELOG.md', function(changelog)
            if changelog then
                print(('^3[%s] Aenderungen seit Version %s:^7'):format(RESOURCE, currentText))
                PrintChangelogSince(changelog, currentScore)
            end
            print(('^1[%s] =====================================================^7'):format(RESOURCE))
        end)
    end)
end

CreateThread(function()
    Wait(5000)
    CheckVersion()
end)
