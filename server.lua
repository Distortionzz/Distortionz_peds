print('[distortionz_robped] server.lua is loading...')

local activeRobberies = {}
local cooldowns = {}

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:server] %s'):format(Config.ResourceName, message))
    end
end

local function Notify(src, message, status, duration)
    TriggerClientEvent('distortionz_robped:client:notify', src, message, status or 'info', duration or 5000)
end

local function GetPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)

        if ok and player then
            return player
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)

        if ok and QBCore then
            return QBCore.Functions.GetPlayer(src)
        end
    end

    return nil
end

local function GetCitizenId(src)
    local player = GetPlayer(src)

    if not player then
        return ('source:%s'):format(src)
    end

    if player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end

    if player.citizenid then
        return player.citizenid
    end

    return ('source:%s'):format(src)
end

local function GetPlayerJob(src)
    local player = GetPlayer(src)

    if not player then return nil end

    if player.PlayerData and player.PlayerData.job and player.PlayerData.job.name then
        return player.PlayerData.job.name
    end

    if player.job and player.job.name then
        return player.job.name
    end

    return nil
end

local function AddCash(src, amount)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return false end

    if GetResourceState('qbx_core') == 'started' then
        local player = GetPlayer(src)

        if player and player.Functions and player.Functions.AddMoney then
            local ok, result = pcall(function()
                return player.Functions.AddMoney('cash', amount, 'distortionz-robped')
            end)

            if ok then return result ~= false end
        end

        local ok, result = pcall(function()
            return exports.qbx_core:AddMoney(src, 'cash', amount, 'distortionz-robped')
        end)

        if ok then return result ~= false end
    end

    if GetResourceState('qb-core') == 'started' then
        local player = GetPlayer(src)

        if player and player.Functions and player.Functions.AddMoney then
            local ok, result = pcall(function()
                return player.Functions.AddMoney('cash', amount, 'distortionz-robped')
            end)

            if ok then return result ~= false end
        end
    end

    return false
end

local function AddItem(src, item, amount)
    amount = math.floor(tonumber(amount) or 0)

    if not item or item == '' or amount <= 0 then
        return false
    end

    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, item, amount)
    end)

    if not ok then
        print(('[%s] Failed to add item %s x%s to source %s'):format(Config.ResourceName, item, amount, src))
        return false
    end

    return added ~= false
end

local function IsOnCooldown(citizenId)
    local expires = cooldowns[citizenId]

    if not expires then return false, 0 end

    local now = os.time()

    if now >= expires then
        cooldowns[citizenId] = nil
        return false, 0
    end

    return true, expires - now
end

local function SetCooldown(citizenId)
    cooldowns[citizenId] = os.time() + (Config.Robbery.cooldown or 90)
end

local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60

    if minutes <= 0 then
        return ('%ss'):format(remainingSeconds)
    end

    return ('%sm %ss'):format(minutes, remainingSeconds)
end

local function GenerateRobberyId(src)
    return ('dzrobped_%s_%s_%s'):format(src, os.time(), math.random(1000, 9999))
end

local function AlertPolice(coords)
    if not Config.Police or not Config.Police.enabled then return end

    local roll = math.random(1, 100)

    if roll > (Config.Police.alertChance or 80) then return end

    for _, playerId in ipairs(GetPlayers()) do
        local playerSrc = tonumber(playerId)
        local job = GetPlayerJob(playerSrc)

        if job and Config.Police.jobs[job] then
            TriggerClientEvent('distortionz_robped:client:policeAlert', playerSrc, {
                coords = coords,
                message = '911 call: civilian robbery reported nearby.'
            })
        end
    end
end

local function RollChance(chance)
    return math.random(1, 100) <= (tonumber(chance) or 0)
end

local function RollWeightedItem(pool)
    local totalWeight = 0

    for _, itemData in ipairs(pool or {}) do
        totalWeight = totalWeight + (tonumber(itemData.chance) or 0)
    end

    if totalWeight <= 0 then return nil end

    local roll = math.random(1, totalWeight)
    local current = 0

    for _, itemData in ipairs(pool or {}) do
        current = current + (tonumber(itemData.chance) or 0)

        if roll <= current then
            return itemData
        end
    end

    return nil
end

local function GiveRobberyRewards(src)
    local rewardMessages = {}
    local gotReward = false

    if RollChance(Config.Robbery.noRewardChance or 0) then
        return {
            gotReward = false,
            message = 'The civilian had nothing worth taking.'
        }
    end

    if Config.Rewards.cash.enabled and RollChance(Config.Rewards.cash.chance) then
        local amount = math.random(Config.Rewards.cash.min, Config.Rewards.cash.max)

        if AddCash(src, amount) then
            gotReward = true
            rewardMessages[#rewardMessages + 1] = ('$%s cash'):format(amount)
        end
    end

    if Config.Rewards.dirtyMoney.enabled and RollChance(Config.Rewards.dirtyMoney.chance) then
        local amount = math.random(Config.Rewards.dirtyMoney.min, Config.Rewards.dirtyMoney.max)
        local item = Config.Rewards.dirtyMoney.item

        if AddItem(src, item, amount) then
            gotReward = true
            rewardMessages[#rewardMessages + 1] = ('$%s dirty money'):format(amount)
        end
    end

    if Config.Rewards.items.enabled and RollChance(Config.Rewards.items.chance) then
        local itemData = RollWeightedItem(Config.Rewards.items.pool)

        if itemData then
            local amount = math.random(itemData.min or 1, itemData.max or 1)

            if AddItem(src, itemData.item, amount) then
                gotReward = true
                rewardMessages[#rewardMessages + 1] = ('%sx %s'):format(amount, itemData.item)
            end
        end
    end

    if not gotReward then
        return {
            gotReward = false,
            message = 'The civilian had nothing useful.'
        }
    end

    return {
        gotReward = true,
        message = ('You stole: %s.'):format(table.concat(rewardMessages, ', '))
    }
end

lib.callback.register('distortionz_robped:server:startRobbery', function(src, data)
    if activeRobberies[src] then
        return {
            success = false,
            status = 'warning',
            message = 'You are already robbing someone.'
        }
    end

    local citizenId = GetCitizenId(src)
    local onCooldown, remaining = IsOnCooldown(citizenId)

    if onCooldown then
        return {
            success = false,
            status = 'warning',
            message = ('You need to lay low for %s.'):format(FormatTime(remaining))
        }
    end

    local robberyId = GenerateRobberyId(src)
    local duration = math.floor((Config.Robbery.duration or 8000) / 1000)

    activeRobberies[src] = {
        robberyId = robberyId,
        citizenId = citizenId,
        startedAt = os.time(),
        finishesAt = os.time() + duration
    }

    local coords = data and data.coords or nil

    if coords then
        AlertPolice(coords)
    end

    DebugPrint(('Started robbery for source %s | %s'):format(src, robberyId))

    return {
        success = true,
        robberyId = robberyId
    }
end)

RegisterNetEvent('distortionz_robped:server:finishRobbery', function(robberyId)
    local src = source
    local robbery = activeRobberies[src]

    if not robbery then
        Notify(src, 'No active robbery found.', 'error')
        return
    end

    if robbery.robberyId ~= robberyId then
        Notify(src, 'Robbery verification failed.', 'error')
        return
    end

    if os.time() < robbery.finishesAt - 2 then
        activeRobberies[src] = nil
        SetCooldown(robbery.citizenId)
        Notify(src, 'Robbery completed too quickly. Nothing was taken.', 'error')
        return
    end

    local reward = GiveRobberyRewards(src)

    activeRobberies[src] = nil
    SetCooldown(robbery.citizenId)

    if reward.gotReward then
        Notify(src, reward.message, 'success', 7000)
    else
        Notify(src, reward.message, 'warning', 6000)
    end

    DebugPrint(('Finished robbery for source %s | reward: %s'):format(src, reward.message))
end)

RegisterNetEvent('distortionz_robped:server:cancelRobbery', function(robberyId)
    local src = source
    local robbery = activeRobberies[src]

    if not robbery then return end

    if robbery.robberyId ~= robberyId then return end

    activeRobberies[src] = nil
    SetCooldown(robbery.citizenId)

    DebugPrint(('Cancelled robbery for source %s'):format(src))
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeRobberies[src] = nil
end)

CreateThread(function()
    Wait(1000)
    print(('[%s] Server callbacks loaded successfully.'):format(Config.ResourceName))
end)