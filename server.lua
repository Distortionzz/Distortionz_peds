local QBCore = exports['qb-core']:GetCoreObject()

local ActiveDeliveries = {}
local Cooldowns = {}

local function NotifyClient(src, message, notifyType, duration, title, soundEnabled)
    if not src or not message then return end

    notifyType = notifyType or "primary"
    duration = tonumber(duration) or 5000
    title = title or "Distortionz Underground"

    if notifyType == "inform" then
        notifyType = "info"
    end

    if GetResourceState("distortionz_notify") == "started" then
        TriggerClientEvent("distortionz_notify:client:notify", src, {
            title = title,
            message = message,
            type = notifyType,
            duration = duration,
            sound = soundEnabled
        })
        return
    end

    TriggerClientEvent("ox_lib:notify", src, {
        title = title,
        description = message,
        type = notifyType,
        duration = duration
    })
end

local function GetIdentifier(src)
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and Player.PlayerData and Player.PlayerData.citizenid then
        return Player.PlayerData.citizenid
    end

    return tostring(src)
end

local function GetRepLevel(rep)
    local selected = Config.Reputation.levels[1]

    for _, data in ipairs(Config.Reputation.levels) do
        if rep >= data.minRep then
            selected = data
        end
    end

    return selected.level, selected.label
end

local function GetPlayerRepData(Player)
    local metadataName = Config.Reputation.metadataName
    local metadata = Player.PlayerData.metadata or {}
    local rep = metadata[metadataName]

    if type(rep) ~= "number" then
        rep = 0
    end

    local level, label = GetRepLevel(rep)

    return {
        rep = rep,
        level = level,
        label = label
    }
end

local function AddPlayerRep(Player, amount)
    if not Config.Reputation.enabled then return end

    amount = tonumber(amount) or 0

    if amount <= 0 then return end

    local current = GetPlayerRepData(Player)
    local newRep = current.rep + amount

    Player.Functions.SetMetaData(Config.Reputation.metadataName, newRep)
end

local function HasCooldown(src, name)
    local identifier = GetIdentifier(src)
    Cooldowns[identifier] = Cooldowns[identifier] or {}

    local now = os.time()
    local expires = Cooldowns[identifier][name]

    if expires and expires > now then
        return true, expires - now
    end

    return false, 0
end

local function SetCooldown(src, name, seconds)
    local identifier = GetIdentifier(src)
    Cooldowns[identifier] = Cooldowns[identifier] or {}
    Cooldowns[identifier][name] = os.time() + seconds
end

local function GetCooldowns(src)
    local deliveryActive, deliveryRemaining = HasCooldown(src, "delivery")
    local sellActive, sellRemaining = HasCooldown(src, "sell")
    local blackmarketActive, blackmarketRemaining = HasCooldown(src, "blackmarket")

    return {
        delivery = deliveryActive and deliveryRemaining or 0,
        sell = sellActive and sellRemaining or 0,
        blackmarket = blackmarketActive and blackmarketRemaining or 0
    }
end

local function GetRandomDeliveryItem(level)
    local available = {}

    for _, item in ipairs(Config.Delivery.items) do
        if level >= (item.requiredLevel or 0) then
            available[#available + 1] = item
        end
    end

    if #available < 1 then
        available = Config.Delivery.items
    end

    local randomIndex = math.random(1, #available)
    return available[randomIndex]
end

local function GetRandomDropoff()
    local randomIndex = math.random(1, #Config.Delivery.dropoffs)
    return randomIndex, Config.Delivery.dropoffs[randomIndex]
end

local function ApplyPayoutBonus(baseAmount, level)
    if not Config.Reputation.enabled then
        return baseAmount
    end

    local bonus = Config.Reputation.payoutBonusPerLevel or 0.0
    local multiplier = 1.0 + ((level or 0) * bonus)

    return math.floor(baseAmount * multiplier)
end

local function PayPlayer(Player, src, amount, reason)
    if Config.PayAccount == "markedbills" then
        Player.Functions.AddItem("markedbills", 1, false, {
            worth = amount
        })
    else
        Player.Functions.AddMoney(Config.PayAccount, amount, reason)
    end
end

local function RemoveDeliveryItem(Player, src, itemName)
    local item = Player.Functions.GetItemByName(itemName)

    if item and item.amount > 0 then
        Player.Functions.RemoveItem(itemName, 1)
    end
end

local function AlertPolice(coords, message)
    if not Config.PoliceAlerts.enabled then return end

    local players = QBCore.Functions.GetQBPlayers()

    for _, Player in pairs(players) do
        local job = Player.PlayerData.job

        if job and job.name and Config.PoliceAlerts.jobs[job.name] and job.onduty then
            local target = Player.PlayerData.source

            NotifyClient(target, message or "Suspicious activity reported.", "police", 7500, "Dispatch")
            TriggerClientEvent("distortionz_peds:client:createPoliceBlip", target, coords, Config.PoliceAlerts.blip.label)
        end
    end
end

local function TryPoliceAlert(chance, coords, message)
    if not Config.PoliceAlerts.enabled then return end

    chance = tonumber(chance) or 0

    if chance <= 0 then return end

    local roll = math.random(1, 100)

    if roll <= chance then
        AlertPolice(coords, message)
    end
end

QBCore.Functions.CreateCallback("distortionz_peds:server:getPlayerRep", function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        cb({
            rep = 0,
            level = 0,
            label = "Unknown",
            cooldowns = {
                delivery = 0,
                sell = 0,
                blackmarket = 0
            }
        })
        return
    end

    local repData = GetPlayerRepData(Player)
    repData.cooldowns = GetCooldowns(src)

    cb(repData)
end)

QBCore.Functions.CreateCallback("distortionz_peds:server:getSellInventory", function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local counts = {}

    if not Player then
        cb(counts)
        return
    end

    for itemName, _ in pairs(Config.SellItems) do
        local item = Player.Functions.GetItemByName(itemName)
        counts[itemName] = item and item.amount or 0
    end

    cb(counts)
end)

QBCore.Functions.CreateCallback("distortionz_peds:server:getItemAmount", function(source, cb, itemName)
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then
        cb(0)
        return
    end

    if not itemName or not Config.SellItems[itemName] then
        cb(0)
        return
    end

    local item = Player.Functions.GetItemByName(itemName)

    cb(item and item.amount or 0)
end)

RegisterNetEvent("distortionz_peds:server:sellItem", function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local onCooldown, remaining = HasCooldown(src, "sell")

    if onCooldown then
        NotifyClient(src, "Slow down. Wait " .. remaining .. " seconds.", "error", 4000)
        return
    end

    local itemData = Config.SellItems[itemName]

    if not itemData then
        print("[distortionz_peds] Exploit attempt: invalid sell item from " .. src .. " item=" .. tostring(itemName))
        NotifyClient(src, "This contact is not buying that item.", "error", 5000)
        return
    end

    amount = tonumber(amount)

    if not amount or amount <= 0 then
        NotifyClient(src, "Invalid amount.", "error", 5000)
        return
    end

    amount = math.floor(amount)

    local item = Player.Functions.GetItemByName(itemName)

    if not item or item.amount < amount then
        NotifyClient(src, "You do not have enough " .. itemData.label .. " to sell.", "error", 5000)
        return
    end

    local repData = GetPlayerRepData(Player)
    local totalPayout = 0

    for i = 1, amount do
        totalPayout = totalPayout + math.random(itemData.minPrice, itemData.maxPrice)
    end

    totalPayout = ApplyPayoutBonus(totalPayout, repData.level)

    Player.Functions.RemoveItem(itemName, amount)

    PayPlayer(Player, src, totalPayout, "sold-underground-market-items")
    AddPlayerRep(Player, Config.Reputation.gains.sellItem * amount)
    SetCooldown(src, "sell", Config.Cooldowns.sell)

    if itemData.highValue then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        TryPoliceAlert(Config.PoliceAlerts.sellHighValueChance, coords, "Suspicious sale reported.")
    end

    local message = "You sold " .. amount .. "x " .. itemData.label .. " for $" .. totalPayout .. "."

    if Config.PayAccount == "markedbills" then
        message = "You sold " .. amount .. "x " .. itemData.label .. " for marked bills worth $" .. totalPayout .. "."
    end

    NotifyClient(src, message, "success", 5000)
end)

RegisterNetEvent("distortionz_peds:server:buyBlackMarketItem", function(itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local onCooldown, remaining = HasCooldown(src, "blackmarket")

    if onCooldown then
        NotifyClient(src, "Wait " .. remaining .. " seconds.", "error", 4000)
        return
    end

    if not Config.BlackMarket.enabled then
        NotifyClient(src, "Black market is closed.", "error", 5000)
        return
    end

    local itemData = Config.BlackMarket.items[itemName]

    if not itemData then
        print("[distortionz_peds] Exploit attempt: invalid black market item from " .. src .. " item=" .. tostring(itemName))
        NotifyClient(src, "That item is not available.", "error", 5000)
        return
    end

    local repData = GetPlayerRepData(Player)

    if repData.level < itemData.requiredLevel then
        NotifyClient(src, "You are not trusted enough.", "error", 5000)
        return
    end

    if Player.PlayerData.money.cash < itemData.price then
        NotifyClient(src, "You need $" .. itemData.price .. " cash.", "error", 5000)
        return
    end

    if not QBCore.Shared.Items[itemName] then
        NotifyClient(src, "Missing item in inventory data: " .. itemName, "error", 7000)
        return
    end

    Player.Functions.RemoveMoney("cash", itemData.price, "black-market-purchase")

    local added = Player.Functions.AddItem(itemName, itemData.amount)

    if not added then
        Player.Functions.AddMoney("cash", itemData.price, "black-market-refund")
        NotifyClient(src, "Not enough inventory space.", "error", 5000)
        return
    end

    AddPlayerRep(Player, Config.Reputation.gains.buyBlackMarket)
    SetCooldown(src, "blackmarket", Config.Cooldowns.blackMarketBuy)

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    TryPoliceAlert(Config.PoliceAlerts.blackMarketBuyChance, coords, "Suspicious black market activity reported.")

    NotifyClient(src, "You bought " .. itemData.amount .. "x " .. itemData.label .. " for $" .. itemData.price .. ".", "success", 5000)
end)

RegisterNetEvent("distortionz_peds:server:startDelivery", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    if not Config.Delivery.enabled then
        NotifyClient(src, "No delivery work is available right now.", "error", 5000)
        return
    end

    local onCooldown, remaining = HasCooldown(src, "delivery")

    if onCooldown then
        NotifyClient(src, "No work right now. Come back in " .. remaining .. " seconds.", "error", 5000)
        return
    end

    if ActiveDeliveries[src] and not Config.Delivery.allowMultipleActiveDeliveries then
        NotifyClient(src, "You already have an active delivery.", "error", 5000)
        return
    end

    local repData = GetPlayerRepData(Player)
    local deliveryItem = GetRandomDeliveryItem(repData.level)
    local dropoffIndex, dropoffCoords = GetRandomDropoff()
    local payout = math.random(deliveryItem.minPay, deliveryItem.maxPay)
    payout = ApplyPayoutBonus(payout, repData.level)

    if not QBCore.Shared.Items[deliveryItem.item] then
        NotifyClient(src, "Delivery item is missing from inventory data: " .. deliveryItem.item, "error", 7000)
        return
    end

    local added = Player.Functions.AddItem(deliveryItem.item, 1, false, {
        delivery = true,
        contact = "underground",
        dropoff = dropoffIndex
    })

    if not added then
        NotifyClient(src, "You do not have enough inventory space.", "error", 5000)
        return
    end

    ActiveDeliveries[src] = {
        item = deliveryItem.item,
        label = deliveryItem.label,
        payout = payout,
        dropoffIndex = dropoffIndex,
        dropoff = dropoffCoords,
        startedAt = os.time(),
        expiresAt = os.time() + Config.Delivery.timeLimitSeconds
    }

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    TryPoliceAlert(Config.PoliceAlerts.startDeliveryChance, coords, "Suspicious package handoff reported.")

    TriggerClientEvent("distortionz_peds:client:deliveryStarted", src, {
        item = deliveryItem.item,
        label = deliveryItem.label,
        dropoff = dropoffCoords,
        timeLimit = Config.Delivery.timeLimitSeconds
    })

    NotifyClient(src, "The contact says: Take this and do not ask questions.", "primary", 6000)
end)

RegisterNetEvent("distortionz_peds:server:completeDelivery", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local delivery = ActiveDeliveries[src]

    if not delivery then
        NotifyClient(src, "You do not have an active delivery.", "error", 5000)
        TriggerClientEvent("distortionz_peds:client:deliveryFailed", src)
        return
    end

    if delivery.expiresAt and os.time() > delivery.expiresAt then
        RemoveDeliveryItem(Player, src, delivery.item)
        ActiveDeliveries[src] = nil
        SetCooldown(src, "delivery", Config.Cooldowns.delivery)

        NotifyClient(src, "You took too long. Job failed.", "error", 6000)
        TriggerClientEvent("distortionz_peds:client:deliveryFailed", src)
        return
    end

    local ped = GetPlayerPed(src)

    if ped and ped ~= 0 then
        local playerCoords = GetEntityCoords(ped)
        local dropCoords = vector3(delivery.dropoff.x, delivery.dropoff.y, delivery.dropoff.z)
        local distance = #(playerCoords - dropCoords)

        if distance > Config.Delivery.serverCompleteDistance then
            print("[distortionz_peds] Exploit attempt: delivery complete too far src=" .. src .. " distance=" .. distance)
            NotifyClient(src, "You are too far from the drop-off.", "error", 5000)
            return
        end
    end

    local item = Player.Functions.GetItemByName(delivery.item)

    if not item or item.amount < 1 then
        ActiveDeliveries[src] = nil
        SetCooldown(src, "delivery", Config.Cooldowns.delivery)

        NotifyClient(src, "You lost the delivery item. Job failed.", "error", 6000)
        TriggerClientEvent("distortionz_peds:client:deliveryFailed", src)
        return
    end

    Player.Functions.RemoveItem(delivery.item, 1)

    PayPlayer(Player, src, delivery.payout, "completed-underground-delivery")
    AddPlayerRep(Player, Config.Reputation.gains.completeDelivery)
    SetCooldown(src, "delivery", Config.Cooldowns.delivery)

    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(playerPed)
    TryPoliceAlert(Config.PoliceAlerts.completeDeliveryChance, coords, "Suspicious drop-off reported.")

    local message = "Delivery complete. You earned $" .. delivery.payout .. "."

    if Config.PayAccount == "markedbills" then
        message = "Delivery complete. You received marked bills worth $" .. delivery.payout .. "."
    end

    NotifyClient(src, message, "cash", 7000)

    ActiveDeliveries[src] = nil
    TriggerClientEvent("distortionz_peds:client:deliveryCompleted", src)
end)

RegisterNetEvent("distortionz_peds:server:cancelDelivery", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local delivery = ActiveDeliveries[src]

    if not delivery then
        NotifyClient(src, "You do not have an active delivery.", "error", 5000)
        return
    end

    if Config.Delivery.removeItemOnCancel then
        RemoveDeliveryItem(Player, src, delivery.item)
    end

    ActiveDeliveries[src] = nil
    SetCooldown(src, "delivery", Config.Cooldowns.delivery)

    NotifyClient(src, "You cancelled the delivery.", "warning", 5000)
    TriggerClientEvent("distortionz_peds:client:deliveryFailed", src)
end)

RegisterNetEvent("distortionz_peds:server:failDelivery", function(reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local delivery = ActiveDeliveries[src]

    if not delivery then return end

    if Config.Delivery.removeItemOnFail then
        RemoveDeliveryItem(Player, src, delivery.item)
    end

    ActiveDeliveries[src] = nil
    SetCooldown(src, "delivery", Config.Cooldowns.delivery)

    NotifyClient(src, reason or "Delivery failed.", "error", 6000)
    TriggerClientEvent("distortionz_peds:client:deliveryFailed", src)
end)

AddEventHandler("playerDropped", function()
    local src = source

    if ActiveDeliveries[src] then
        ActiveDeliveries[src] = nil
    end
end)