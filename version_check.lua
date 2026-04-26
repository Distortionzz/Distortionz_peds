local function TrimVersion(version)
    if not version then return '0.0.0' end

    version = tostring(version)
    version = version:gsub('^v', '')
    version = version:gsub('^V', '')

    return version
end

local function SplitVersion(version)
    local parts = {}

    for part in TrimVersion(version):gmatch('[^.]+') do
        parts[#parts + 1] = tonumber(part) or 0
    end

    return parts
end

local function IsVersionNewer(remoteVersion, currentVersion)
    local remoteParts = SplitVersion(remoteVersion)
    local currentParts = SplitVersion(currentVersion)

    local maxParts = math.max(#remoteParts, #currentParts)

    for i = 1, maxParts do
        local remotePart = remoteParts[i] or 0
        local currentPart = currentParts[i] or 0

        if remotePart > currentPart then
            return true
        elseif remotePart < currentPart then
            return false
        end
    end

    return false
end

local function VersionCheck()
    if not Config.VersionCheck or not Config.VersionCheck.enabled then
        return
    end

    local resourceName = GetCurrentResourceName()
    local currentVersion = Config.CurrentVersion or GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'
    local versionUrl = Config.VersionCheck.url

    if not versionUrl or versionUrl == '' then
        print('^1Version check failed:^7 missing version URL.')
        return
    end

    PerformHttpRequest(versionUrl, function(statusCode, response)
        if statusCode ~= 200 then
            print(('^1Version check failed.^7 HTTP status: ^1%s^7'):format(statusCode or 'unknown'))
            return
        end

        if not response or response == '' then
            print('^1Version check failed:^7 empty response body.')
            return
        end

        local success, data = pcall(json.decode, response)

        if not success or not data then
            print('^1Version check failed:^7 invalid JSON response.')
            return
        end

        local latestVersion = data.version or data.latest or '0.0.0'
        local changelog = data.changelog or 'No changelog provided.'
        local download = data.download or 'No download URL provided.'

        if IsVersionNewer(latestVersion, currentVersion) then
            print('^1============================================================^7')
            print(('^1Outdated version detected!^7 Current: ^1v%s^7 | Latest: ^2v%s^7'):format(
                TrimVersion(currentVersion),
                TrimVersion(latestVersion)
            ))
            print(('^3Changelog:^7 %s'):format(changelog))
            print(('^5Download:^7 %s'):format(download))
            print('^1============================================================^7')
        else
            print(('^2You are running the latest version.^7 v%s'):format(TrimVersion(currentVersion)))
        end
    end, 'GET')
end

CreateThread(function()
    Wait(2500)

    if Config.VersionCheck and Config.VersionCheck.checkOnStart then
        VersionCheck()
    end
end)