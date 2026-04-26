local QBCore = exports['qb-core']:GetCoreObject()

local PlayerCooldowns = {}
local ActiveDeliveries = {}
local SourceKeys = {}
local LastPoliceAlerts = {}

math.randomseed(os.time())

local function DebugPrint(message)
    if not Config.Debug then return end
    print(("[distortionz_peds] %s"):format(message))
end

local function GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

local function GetPlayerKey(source)
    local Player = GetPlayer(source)

    if Player and Player.PlayerData and Player.PlayerData.citizenid then
        SourceKeys[source] = Player.PlayerData.citizenid
        return Player.PlayerData.citizenid
    end

    return SourceKeys[source] or tostring(source)
end

local function ServerNotify(source, message, notifyType, duration, title)
    if not source or not message then return end

    notifyType = notifyType or "primary"
    duration = tonumber(duration) or 5000
    title = title or "Distortionz Underground"

    if notifyType == "inform" then
        notifyType = "info"
    end

    if GetResourceState("ox_lib") == "started" then
        TriggerClientEvent("ox_lib:notify", source, {
            title = title,
            description = message,
            type = notifyType,
            duration = duration
        })
        return
    end

    TriggerClientEvent("QBCore:Notify", source, message, notifyType, duration)
end

local function IsOxInventoryStarted()
    return GetResourceState("ox_inventory") == "started"
end

local function GetItemCount(source, itemName)
    if not source or not itemName then return 0 end

    if IsOxInventoryStarted() then
        return tonumber(exports.ox_inventory:GetItemCount(source, itemName)) or 0
    end

    local Player = GetPlayer(source)
    if not Player then return 0 end

    local item = Player.Functions.GetItemByName(itemName)
    if not item then return 0 end

    return tonumber(item.amount) or 0
end

local function CanCarryItem(source, itemName, amount, metadata)
    if not source or not itemName then return false end

    amount = tonumber(amount) or 1
    metadata = metadata or {}

    if amount <= 0 then return false end

    if IsOxInventoryStarted() then
        local success = exports.ox_inventory:CanCarryItem(source, itemName, amount, metadata)
        return success == true
    end

    return true
end

local function AddItem(source, itemName, amount, metadata)
    if not source or not itemName then return false end

    amount = tonumber(amount) or 1
    metadata = metadata or {}

    if amount <= 0 then return false end

    if IsOxInventoryStarted() then
        return exports.ox_inventory:AddItem(source, itemName, amount, metadata) == true
    end

    local Player = GetPlayer(source)
    if not Player then return false end

    return Player.Functions.AddItem(itemName, amount, false, metadata) == true
end

local function RemoveItem(source, itemName, amount, metadata)
    if not source or not itemName then return false end

    amount = tonumber(amount) or 1
    metadata = metadata or {}

    if amount <= 0 then return false end

    if IsOxInventoryStarted() then
        return exports.ox_inventory:RemoveItem(source, itemName, amount, metadata) == true
    end

    local Player = GetPlayer(source)
    if not Player then return false end

    return Player.Functions.RemoveItem(itemName, amount) == true
end

local function AddMoney(source, account, amount, reason)
    local Player = GetPlayer(source)
    if not Player then return false end

    amount = tonumber(amount) or 0
    account = account or "cash"
    reason = reason or "distortionz-peds"

    if amount <= 0 then return false end

    return Player.Functions.AddMoney(account, amount, reason) == true
end

local function RemoveMoney(source, account, amount, reason)
    local Player = GetPlayer(source)
    if not Player then return false end

    amount = tonumber(amount) or 0
    account = account or "cash"
    reason = reason or "distortionz-peds"

    if amount <= 0 then return false end

    local currentMoney = 0

    if Player.PlayerData and Player.PlayerData.money and Player.PlayerData.money[account] then
        currentMoney = tonumber(Player.PlayerData.money[account]) or 0
    end

    if currentMoney < amount then
        return false
    end

    return Player.Functions.RemoveMoney(account, amount, reason) == true
end

local function GetStoredRep(Player)
    if not Player or not Player.PlayerData then return 0 end

    local metadata = Player.PlayerData.metadata or {}
    local rep = metadata.distortionz_peds_rep or metadata.distortionzRep or 0

    return math.max(0, math.floor(tonumber(rep) or 0))
end

local function SetStoredRep(Player, rep)
    if not Player then return end

    rep = math.max(0, math.floor(tonumber(rep) or 0))

    if Player.Functions and Player.Functions.SetMetaData then
        Player.Functions.SetMetaData("distortionz_peds_rep", rep)
    end
end

local function GetRepLevel(rep)
    rep = tonumber(rep) or 0

    local level = 0
    local label = "Unknown"

    if Config.Reputation and Config.Reputation.levels then
        for levelNumber, levelData in pairs(Config.Reputation.levels) do
            local minRep = tonumber(levelData.minRep) or 0

            if rep >= minRep and tonumber(levelNumber) >= level then
                level = tonumber(levelNumber)
                label = levelData.label or label
            end
        end

        return level, label
    end

    local pointsPerLevel = Config.Reputation and tonumber(Config.Reputation.pointsPerLevel) or 500
    level = math.floor(rep / pointsPerLevel)

    return level, label
end

local function GetRepData(source)
    local Player = GetPlayer(source)

    if not Player then
        return {
            level = 0,
            label = "Unknown",
            rep = 0,
            cooldowns = {
                sell = 0,
                delivery = 0,
                blackmarket = 0
            }
        }
    end

    local rep = GetStoredRep(Player)
    local level, label = GetRepLevel(rep)

    return {
        level = level,
        label = label,
        rep = rep,
        cooldowns = {
            sell = 0,
            delivery = 0,
            blackmarket = 0
        }
    }
end

local function AddRep(source, amount)
    if not Config.Reputation or Config.Reputation.enabled == false then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return end

    local Player = GetPlayer(source)
    if not Player then return end

    local currentRep = GetStoredRep(Player)
    local newRep = math.max(0, currentRep + amount)

    SetStoredRep(Player, newRep)

    DebugPrint(("Added %s rep to %s. New rep: %s"):format(amount, source, newRep))
end

local function GetCooldownBucket(source)
    local key = GetPlayerKey(source)

    PlayerCooldowns[key] = PlayerCooldowns[key] or {
        sell = 0,
        delivery = 0,
        blackmarket = 0
    }

    return PlayerCooldowns[key]
end

local function GetCooldownRemaining(source, cooldownName)
    local bucket = GetCooldownBucket(source)
    local expiresAt = tonumber(bucket[cooldownName]) or 0
    local remaining = expiresAt - os.time()

    if remaining < 0 then
        remaining = 0
    end

    return remaining
end

local function SetCooldown(source, cooldownName, seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return end

    local bucket = GetCooldownBucket(source)
    bucket[cooldownName] = os.time() + seconds
end

local function GetAllCooldowns(source)
    return {
        sell = GetCooldownRemaining(source, "sell"),
        delivery = GetCooldownRemaining(source, "delivery"),
        blackmarket = GetCooldownRemaining(source, "blackmarket")
    }
end

local function RollChance(chance)
    chance = tonumber(chance) or 0

    if chance <= 0 then return false end
    if chance >= 100 then return true end

    return math.random(1, 100) <= chance
end

local function GetSourceCoords(source)
    local ped = GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)

    if not coords then
        return nil
    end

    return vector3(coords.x, coords.y, coords.z)
end

local function IsPolicePlayer(Player)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return false end

    local jobName = Player.PlayerData.job.name
    if not jobName then return false end

    local jobs = Config.PoliceAlerts and Config.PoliceAlerts.jobs or {}

    return jobs[jobName] == true
end

local function SendPoliceAlert(source, alertType, coords, label, chance)
    if not Config.PoliceAlerts or Config.PoliceAlerts.enabled == false then return end

    chance = tonumber(chance) or 0

    if not RollChance(chance) then
        return
    end

    local cooldownSeconds = tonumber(Config.PoliceAlerts.cooldownSeconds) or 45
    local now = os.time()
    local lastAlert = LastPoliceAlerts[alertType] or 0

    if now - lastAlert < cooldownSeconds then
        return
    end

    LastPoliceAlerts[alertType] = now

    coords = coords or GetSourceCoords(source)
    if not coords then return end

    label = label or Config.PoliceAlerts.blip.label or "Suspicious Activity"

    local players = QBCore.Functions.GetQBPlayers()

    for targetSource, Player in pairs(players) do
        if IsPolicePlayer(Player) then
            local playerSource = Player.PlayerData.source or targetSource
            TriggerClientEvent("distortionz_peds:client:createPoliceBlip", playerSource, coords, label)
        end
    end
end

local function CanReceiveReward(source, amount, forceDirtyMoney)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    if forceDirtyMoney == true then
        local dirtyMoneyItem = Config.Money and Config.Money.dirtyMoneyItem or "black_money"
        return CanCarryItem(source, dirtyMoneyItem, amount)
    end

    if Config.Money and Config.Money.rewardType == "item" then
        local dirtyMoneyItem = Config.Money.dirtyMoneyItem or "black_money"
        return CanCarryItem(source, dirtyMoneyItem, amount)
    end

    return true
end

local function GiveReward(source, amount, reason, forceDirtyMoney)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end

    reason = reason or "distortionz-peds-reward"

    if forceDirtyMoney == true then
        local dirtyMoneyItem = Config.Money and Config.Money.dirtyMoneyItem or "black_money"
        return AddItem(source, dirtyMoneyItem, amount)
    end

    if Config.Money and Config.Money.rewardType == "item" then
        local dirtyMoneyItem = Config.Money.dirtyMoneyItem or "black_money"
        return AddItem(source, dirtyMoneyItem, amount)
    end

    local account = Config.Money and Config.Money.account or "cash"
    return AddMoney(source, account, amount, reason)
end

local function RemoveBlackMarketPayment(source, price)
    price = math.floor(tonumber(price) or 0)

    if price <= 0 then
        return true
    end

    local paymentType = Config.Money and Config.Money.blackMarketPaymentType or "cash"

    if paymentType == "item" then
        local paymentItem = Config.Money.blackMarketPaymentItem or "black_money"

        if GetItemCount(source, paymentItem) < price then
            return false
        end

        return RemoveItem(source, paymentItem, price)
    end

    return RemoveMoney(source, paymentType, price, "distortionz-blackmarket-purchase")
end

local function GetRandomDeliveryItem()
    local items = Config.Delivery and Config.Delivery.items or {}

    if not items or #items <= 0 then
        return {
            item = "markedbills",
            label = "Suspicious Package",
            amount = 1,
            payoutMin = Config.Delivery.payout.min or 1500,
            payoutMax = Config.Delivery.payout.max or 3500,
            difficulty = Config.Delivery.difficulty.label or "Medium"
        }
    end

    return items[math.random(1, #items)]
end

local function GetRandomDropoff()
    local dropoffs = Config.Delivery and Config.Delivery.dropoffs or {}

    if not dropoffs or #dropoffs <= 0 then
        return nil
    end

    return dropoffs[math.random(1, #dropoffs)]
end

local function GetDeliveryData(source)
    local key = GetPlayerKey(source)
    return ActiveDeliveries[key]
end

local function SetDeliveryData(source, data)
    local key = GetPlayerKey(source)
    ActiveDeliveries[key] = data
end

local function ClearDeliveryData(source)
    local key = GetPlayerKey(source)
    ActiveDeliveries[key] = nil
end

local function FailDelivery(source, reason, removePackage)
    local delivery = GetDeliveryData(source)

    if not delivery then
        return
    end

    if removePackage == true and delivery.packageRemovedOnStart ~= true then
        if GetItemCount(source, delivery.item) >= delivery.amount then
            RemoveItem(source, delivery.item, delivery.amount)
        end
    end

    ClearDeliveryData(source)

    local losses = Config.Reputation and Config.Reputation.losses or {}
    AddRep(source, -(losses.deliveryFailed or 0))

    ServerNotify(source, reason or "Delivery failed.", "error", 6000, "Suspicious Delivery")
    TriggerClientEvent("distortionz_peds:client:deliveryFailed", source)
end

local function CompleteDelivery(source)
    local delivery = GetDeliveryData(source)

    if not delivery then
        ServerNotify(source, "You do not have an active delivery.", "error", 5000, "Suspicious Delivery")
        return
    end

    if os.time() >= delivery.expiresAt then
        FailDelivery(source, "You took too long. Job failed.", Config.Delivery.removePackageOnFail == true)
        return
    end

    local sourceCoords = GetSourceCoords(source)

    if not sourceCoords then
        ServerNotify(source, "Could not verify your location.", "error", 5000, "Suspicious Delivery")
        return
    end

    local dropoffCoords = vector3(delivery.dropoff.x, delivery.dropoff.y, delivery.dropoff.z)
    local distance = #(sourceCoords - dropoffCoords)
    local allowedDistance = (Config.Delivery.completeDistance or 2.2) + 5.0

    if distance > allowedDistance then
        ServerNotify(source, "You are too far from the drop-off.", "error", 5000, "Suspicious Delivery")
        return
    end

    if delivery.packageRemovedOnStart ~= true then
        if GetItemCount(source, delivery.item) < delivery.amount then
            FailDelivery(source, "You lost the package. Job failed.", false)
            return
        end
    end

    local payout = math.random(delivery.payoutMin, delivery.payoutMax)
    local useDirtyMoney = Config.Delivery.payout and Config.Delivery.payout.useDirtyMoney == true

    if not CanReceiveReward(source, payout, useDirtyMoney) then
        ServerNotify(source, "You cannot carry the payout.", "error", 5000, "Suspicious Delivery")
        return
    end

    if delivery.packageRemovedOnStart ~= true then
        if not RemoveItem(source, delivery.item, delivery.amount) then
            ServerNotify(source, "Failed to remove the package.", "error", 5000, "Suspicious Delivery")
            return
        end
    end

    if not GiveReward(source, payout, "distortionz-delivery-payout", useDirtyMoney) then
        ServerNotify(source, "Failed to pay you.", "error", 5000, "Suspicious Delivery")
        return
    end

    ClearDeliveryData(source)

    local gains = Config.Reputation and Config.Reputation.gains or {}
    AddRep(source, gains.deliveryComplete or 0)

    local alertChance = Config.PoliceAlerts and Config.PoliceAlerts.chances and Config.PoliceAlerts.chances.deliveryComplete or 0
    local alertMessage = Config.PoliceAlerts and Config.PoliceAlerts.messages and Config.PoliceAlerts.messages.deliveryComplete or "Suspicious handoff reported."

    SendPoliceAlert(source, "deliveryComplete", sourceCoords, alertMessage, alertChance)

    ServerNotify(source, ("Delivery complete. You received $%s."):format(payout), "success", 7000, "Suspicious Delivery")
    TriggerClientEvent("distortionz_peds:client:deliveryCompleted", source)
end

QBCore.Functions.CreateCallback("distortionz_peds:server:getPlayerRep", function(source, cb)
    local repData = GetRepData(source)
    repData.cooldowns = GetAllCooldowns(source)

    cb(repData)
end)

QBCore.Functions.CreateCallback("distortionz_peds:server:getSellInventory", function(source, cb)
    local inventoryCounts = {}

    for itemName, _ in pairs(Config.SellItems or {}) do
        inventoryCounts[itemName] = GetItemCount(source, itemName)
    end

    cb(inventoryCounts)
end)

QBCore.Functions.CreateCallback("distortionz_peds:server:getItemAmount", function(source, cb, itemName)
    if not itemName then
        cb(0)
        return
    end

    cb(GetItemCount(source, itemName))
end)

RegisterNetEvent("distortionz_peds:server:sellItem", function(itemName, amount)
    local source = source
    local Player = GetPlayer(source)

    if not Player then return end

    amount = math.floor(tonumber(amount) or 0)

    if not itemName or amount <= 0 then
        ServerNotify(source, "Invalid sale amount.", "error", 5000)
        return
    end

    local itemData = Config.SellItems and Config.SellItems[itemName]

    if not itemData then
        ServerNotify(source, "This contact is not buying that item.", "error", 5000)
        return
    end

    local cooldown = GetCooldownRemaining(source, "sell")

    if cooldown > 0 then
        ServerNotify(source, ("You need to wait %s seconds before selling again."):format(cooldown), "error", 5000)
        return
    end

    local owned = GetItemCount(source, itemName)

    if owned < amount then
        ServerNotify(source, ("You only have %sx %s."):format(owned, itemData.label or itemName), "error", 5000)
        return
    end

    local minPrice = tonumber(itemData.minPrice) or 0
    local maxPrice = tonumber(itemData.maxPrice) or minPrice

    if maxPrice < minPrice then
        maxPrice = minPrice
    end

    local priceEach = math.random(minPrice, maxPrice)
    local payout = priceEach * amount

    if not CanReceiveReward(source, payout, false) then
        ServerNotify(source, "You cannot carry the payout.", "error", 5000)
        return
    end

    if not RemoveItem(source, itemName, amount) then
        ServerNotify(source, "Failed to remove item.", "error", 5000)
        return
    end

    if not GiveReward(source, payout, "distortionz-sell-payout", false) then
        ServerNotify(source, "Failed to pay you.", "error", 5000)
        return
    end

    local cooldownSeconds = Config.Cooldowns and tonumber(Config.Cooldowns.sell) or 8
    SetCooldown(source, "sell", cooldownSeconds)

    local gains = Config.Reputation and Config.Reputation.gains or {}
    local repGain = itemData.highValue and gains.sellHighValue or gains.sellLowValue

    AddRep(source, (repGain or 0) * amount)

    local alertChance = itemData.policeAlertChance

    if not alertChance then
        if itemData.highValue then
            alertChance = Config.PoliceAlerts and Config.PoliceAlerts.chances and Config.PoliceAlerts.chances.highValueSell or 0
        else
            alertChance = Config.PoliceAlerts and Config.PoliceAlerts.chances and Config.PoliceAlerts.chances.sell or 0
        end
    end

    local alertMessage = Config.PoliceAlerts and Config.PoliceAlerts.messages and Config.PoliceAlerts.messages.sell or "Suspicious street sale reported."
    SendPoliceAlert(source, "sell", GetSourceCoords(source), alertMessage, alertChance)

    ServerNotify(source, ("Sold %sx %s for $%s."):format(amount, itemData.label or itemName, payout), "success", 6000)
end)

RegisterNetEvent("distortionz_peds:server:buyBlackMarketItem", function(itemName)
    local source = source
    local Player = GetPlayer(source)

    if not Player then return end

    if not Config.BlackMarket or Config.BlackMarket.enabled == false then
        ServerNotify(source, "The black market is closed.", "error", 5000, "Black Market")
        return
    end

    if not itemName then
        ServerNotify(source, "Invalid black market item.", "error", 5000, "Black Market")
        return
    end

    local itemData = Config.BlackMarket.items and Config.BlackMarket.items[itemName]

    if not itemData then
        ServerNotify(source, "That item is not available.", "error", 5000, "Black Market")
        return
    end

    local cooldown = GetCooldownRemaining(source, "blackmarket")

    if cooldown > 0 then
        ServerNotify(source, ("You need to wait %s seconds before buying again."):format(cooldown), "error", 5000, "Black Market")
        return
    end

    local rep = GetStoredRep(Player)
    local level = GetRepLevel(rep)
    local requiredLevel = tonumber(itemData.requiredLevel) or 0

    if level < requiredLevel then
        ServerNotify(source, ("You need reputation level %s for this item."):format(requiredLevel), "error", 5000, "Black Market")
        return
    end

    local amount = tonumber(itemData.amount) or 1
    local price = tonumber(itemData.price) or 0
    local metadata = itemData.metadata or {}

    if not CanCarryItem(source, itemName, amount, metadata) then
        ServerNotify(source, "You cannot carry that item.", "error", 5000, "Black Market")
        return
    end

    if not RemoveBlackMarketPayment(source, price) then
        ServerNotify(source, "You do not have enough money.", "error", 5000, "Black Market")
        return
    end

    if not AddItem(source, itemName, amount, metadata) then
        ServerNotify(source, "Failed to give item.", "error", 5000, "Black Market")
        return
    end

    local cooldownSeconds = Config.Cooldowns and tonumber(Config.Cooldowns.blackmarket) or 15
    SetCooldown(source, "blackmarket", cooldownSeconds)

    local gains = Config.Reputation and Config.Reputation.gains or {}
    AddRep(source, gains.blackMarketPurchase or 0)

    local alertChance = Config.PoliceAlerts and Config.PoliceAlerts.chances and Config.PoliceAlerts.chances.blackMarket or 0
    local alertMessage = Config.PoliceAlerts and Config.PoliceAlerts.messages and Config.PoliceAlerts.messages.blackMarket or "Possible illegal transaction reported."

    SendPoliceAlert(source, "blackMarket", GetSourceCoords(source), alertMessage, alertChance)

    ServerNotify(source, ("Purchased %sx %s for $%s."):format(amount, itemData.label or itemName, price), "success", 6000, "Black Market")
end)

RegisterNetEvent("distortionz_peds:server:startDelivery", function()
    local source = source
    local Player = GetPlayer(source)

    if not Player then return end

    if not Config.Delivery or Config.Delivery.enabled == false then
        ServerNotify(source, "Delivery work is not available.", "error", 5000, "Suspicious Delivery")
        return
    end

    if GetDeliveryData(source) then
        ServerNotify(source, "You already have an active delivery.", "error", 5000, "Suspicious Delivery")
        return
    end

    local cooldown = GetCooldownRemaining(source, "delivery")

    if cooldown > 0 then
        ServerNotify(source, ("Come back in %s seconds."):format(cooldown), "error", 5000, "Suspicious Delivery")
        return
    end

    local deliveryItem = GetRandomDeliveryItem()
    local dropoff = GetRandomDropoff()

    if not dropoff then
        ServerNotify(source, "No delivery drop-offs are configured.", "error", 5000, "Suspicious Delivery")
        return
    end

    local itemName = deliveryItem.item
    local itemLabel = deliveryItem.label or itemName
    local itemAmount = tonumber(deliveryItem.amount) or 1

    if not itemName then
        ServerNotify(source, "Delivery item is not configured.", "error", 5000, "Suspicious Delivery")
        return
    end

    local packageRemovedOnStart = false

    if Config.Delivery.itemRequired == true then
        if GetItemCount(source, itemName) < itemAmount then
            ServerNotify(source, ("You need %sx %s to start this job."):format(itemAmount, itemLabel), "error", 5000, "Suspicious Delivery")
            return
        end

        if Config.Delivery.itemRemoveOnStart == true then
            if not RemoveItem(source, itemName, itemAmount) then
                ServerNotify(source, "Failed to take the package.", "error", 5000, "Suspicious Delivery")
                return
            end

            packageRemovedOnStart = true
        end
    else
        if not CanCarryItem(source, itemName, itemAmount) then
            ServerNotify(source, "You cannot carry the package.", "error", 5000, "Suspicious Delivery")
            return
        end

        if not AddItem(source, itemName, itemAmount) then
            ServerNotify(source, "Failed to give package.", "error", 5000, "Suspicious Delivery")
            return
        end
    end

    local payoutMin = tonumber(deliveryItem.payoutMin) or tonumber(Config.Delivery.payout.min) or 1500
    local payoutMax = tonumber(deliveryItem.payoutMax) or tonumber(Config.Delivery.payout.max) or payoutMin

    if payoutMax < payoutMin then
        payoutMax = payoutMin
    end

    local timeLimit = tonumber(Config.Delivery.timeLimitSeconds) or 900

    SetDeliveryData(source, {
        item = itemName,
        label = itemLabel,
        amount = itemAmount,
        payoutMin = payoutMin,
        payoutMax = payoutMax,
        difficulty = deliveryItem.difficulty or (Config.Delivery.difficulty and Config.Delivery.difficulty.label) or "Medium",
        dropoff = dropoff,
        startedAt = os.time(),
        expiresAt = os.time() + timeLimit,
        packageRemovedOnStart = packageRemovedOnStart
    })

    local cooldownSeconds = Config.Cooldowns and tonumber(Config.Cooldowns.delivery) or 180
    SetCooldown(source, "delivery", cooldownSeconds)

    local alertChance = Config.PoliceAlerts and Config.PoliceAlerts.chances and Config.PoliceAlerts.chances.deliveryStart or 0
    local alertMessage = Config.PoliceAlerts and Config.PoliceAlerts.messages and Config.PoliceAlerts.messages.deliveryStart or "Suspicious package movement reported."

    SendPoliceAlert(source, "deliveryStart", GetSourceCoords(source), alertMessage, alertChance)

    TriggerClientEvent("distortionz_peds:client:deliveryStarted", source, {
        item = itemName,
        label = itemLabel,
        amount = itemAmount,
        dropoff = dropoff,
        timeLimit = timeLimit,
        payoutMin = payoutMin,
        payoutMax = payoutMax,
        difficulty = deliveryItem.difficulty or (Config.Delivery.difficulty and Config.Delivery.difficulty.label) or "Medium"
    })
end)

RegisterNetEvent("distortionz_peds:server:cancelDelivery", function()
    local source = source
    local delivery = GetDeliveryData(source)

    if not delivery then
        ServerNotify(source, "You do not have an active delivery.", "error", 5000, "Suspicious Delivery")
        return
    end

    if Config.Delivery.removePackageOnCancel == true and delivery.packageRemovedOnStart ~= true then
        if GetItemCount(source, delivery.item) >= delivery.amount then
            RemoveItem(source, delivery.item, delivery.amount)
        end
    end

    ClearDeliveryData(source)

    local losses = Config.Reputation and Config.Reputation.losses or {}
    AddRep(source, -(losses.deliveryCancelled or 0))

    ServerNotify(source, "Delivery cancelled.", "error", 5000, "Suspicious Delivery")
    TriggerClientEvent("distortionz_peds:client:deliveryFailed", source)
end)

RegisterNetEvent("distortionz_peds:server:completeDelivery", function()
    local source = source
    CompleteDelivery(source)
end)

RegisterNetEvent("distortionz_peds:server:failDelivery", function(reason)
    local source = source
    FailDelivery(source, reason or "Delivery failed.", Config.Delivery.removePackageOnFail == true)
end)

AddEventHandler("playerDropped", function()
    local source = source
    local key = SourceKeys[source]

    if key then
        ActiveDeliveries[key] = nil
        SourceKeys[source] = nil
    end
end)

local function RunVersionCheck()
    if not Config.Script or Config.Script.versionCheck ~= true then return end
    if not Config.Script.versionUrl or Config.Script.versionUrl == "" then return end

    PerformHttpRequest(Config.Script.versionUrl, function(statusCode, response)
        if statusCode ~= 200 or not response then
            print("[distortionz_peds] Version check failed.")
            return
        end

        local success, decoded = pcall(function()
            return json.decode(response)
        end)

        if not success or type(decoded) ~= "table" then
            print("[distortionz_peds] Version check response was invalid.")
            return
        end

        local currentVersion = Config.Script.version or "Unknown"
        local latestVersion = decoded.version or decoded.latest or decoded.tag_name or "Unknown"

        if latestVersion == "Unknown" then
            print(("[distortionz_peds] Current version: %s"):format(currentVersion))
            return
        end

        if latestVersion ~= currentVersion then
            print(("^3[distortionz_peds]^7 Update available. Current: ^1%s^7 Latest: ^2%s^7"):format(currentVersion, latestVersion))

            if decoded.changelog then
                print(("^3[distortionz_peds]^7 Changelog: %s"):format(decoded.changelog))
            end
        else
            print(("^2[distortionz_peds]^7 You are running the latest version: %s"):format(currentVersion))
        end
    end, "GET")
end

CreateThread(function()
    Wait(2500)
    RunVersionCheck()
end)