local function AssertEqual(actual, expected, message)
    assert(actual == expected, ('%s: erwartet %s, erhalten %s'):format(
        message, tostring(expected), tostring(actual)))
end

local function Contains(lines, fragment)
    for _, line in ipairs(lines) do
        if line:find(fragment, 1, true) then return true end
    end
    return false
end

dofile('server/version_utils.lua')

AssertEqual(VersionUtils.Compare('1.4.0', '1.5.0'), -1, 'Aeltere Version')
AssertEqual(VersionUtils.Compare('1.5.0', '1.5.0'), 0, 'Gleiche Version')
AssertEqual(VersionUtils.Compare('2.0.0', '1.99.99'), 1, 'Neuere Major-Version')
AssertEqual(VersionUtils.Compare('ungueltig', '1.0.0'), nil, 'Ungueltige Version')

AssertEqual(
    VersionUtils.ExtractManifestVersion("fx_version 'cerulean'\nversion '1.5.0'"),
    '1.5.0',
    'Manifest-Version')
AssertEqual(
    VersionUtils.ExtractManifestVersion("version 'ungueltig'"),
    nil,
    'Ungueltige Manifest-Version')

assert(
    VersionUtils.IsSafeGithubTarget('ForgeCode-2026/FarmingCreator-X-Hex', 'main'),
    'Gueltiges GitHub-Ziel wurde abgelehnt')
assert(
    VersionUtils.IsSafeGithubTarget('owner/repository.name', 'release/1.5'),
    'Gueltiger Release-Branch wurde abgelehnt')
assert(
    not VersionUtils.IsSafeGithubTarget('../repository', 'main'),
    'Repository-Traversal wurde akzeptiert')
assert(
    not VersionUtils.IsSafeGithubTarget('owner/repository', '../main'),
    'Branch-Traversal wurde akzeptiert')

local changelog = [[
## [1.5.0] - 2026-08-01

### Added

- Neue HUD-Integration

---

## [1.4.0] - 2026-07-22

- Vorherige Version

---

## [1.3.0] - 2026-07-21

- Bereits installiert
]]

local lines = VersionUtils.CollectChangelog(changelog, '1.3.0', 40)
assert(Contains(lines, '## [1.5.0]'), 'Version 1.5.0 fehlt')
assert(Contains(lines, '## [1.4.0]'), 'Version 1.4.0 fehlt')
assert(not Contains(lines, '## [1.3.0]'), 'Installierte Version darf nicht erscheinen')

local limitedLines = VersionUtils.CollectChangelog(changelog, '1.3.0', 2)
AssertEqual(#limitedLines, 2, 'Changelog-Limit')

print('PASS test_version_utils')
