VersionUtils = {}

local VERSION_FIELDS = { 'major', 'minor', 'patch' }

function VersionUtils.Parse(value)
    local major, minor, patch = tostring(value or ''):match(
        '^%s*(%d+)%.(%d+)%.(%d+)%s*$')
    if not major then return nil end
    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch),
    }
end

function VersionUtils.Compare(left, right)
    local leftVersion = VersionUtils.Parse(left)
    local rightVersion = VersionUtils.Parse(right)
    if not leftVersion or not rightVersion then return nil end

    for _, field in ipairs(VERSION_FIELDS) do
        if leftVersion[field] < rightVersion[field] then return -1 end
        if leftVersion[field] > rightVersion[field] then return 1 end
    end
    return 0
end

function VersionUtils.ExtractManifestVersion(manifest)
    if type(manifest) ~= 'string' then return nil end
    for line in manifest:gmatch('[^\r\n]+') do
        local version = line:match("^%s*version%s+['\"]([^'\"]+)['\"]%s*$")
        if VersionUtils.Parse(version) then return version end
    end
    return nil
end

function VersionUtils.IsSafeGithubTarget(repository, branch)
    if type(repository) ~= 'string' or type(branch) ~= 'string' then return false end
    if repository:find('..', 1, true) or branch:find('..', 1, true) then return false end
    if not repository:match('^[%w%._%-]+/[%w%._%-]+$') then return false end
    return branch:match('^[%w%._%/%-]+$') ~= nil
        and not branch:match('^/')
        and not branch:match('/$')
end

function VersionUtils.CollectChangelog(changelog, currentVersion, limit)
    if type(changelog) ~= 'string' or not VersionUtils.Parse(currentVersion) then return {} end
    local maxLines = math.max(0, math.floor(tonumber(limit) or 40))
    local lines = {}
    local includeSection = false

    for line in changelog:gmatch('[^\r\n]+') do
        local headerVersion = line:match('^## %[(%d+%.%d+%.%d+)%]')
        if headerVersion then
            includeSection = VersionUtils.Compare(headerVersion, currentVersion) == 1
        end
        if includeSection and line:match('%S') and not line:match('^%-%-%-$') then
            lines[#lines + 1] = line
            if #lines >= maxLines then break end
        end
    end
    return lines
end
