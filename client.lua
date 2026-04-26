local QBCore = exports['qb-core']:GetCoreObject()

local spawnedPed = nil
local contactBlip = nil
local menuOpen = false
local nuiOpen = false
local contactTargetAdded = false

local activeDelivery = false
local deliveryDropoff = nil
local deliveryItem = nil
local deliveryItemLabel = nil
local deliveryBlip = nil
local deliveryReceiverPed = nil
local deliveryReceiverTargetAdded = false
local deliveryZoneTargetId = nil
local isDoingHandoff = false
local isDoingContactHandoff = false
local deliveryEndsAt = nil

local function NormalizeModel(model)
    if type(model) == "string" then
        return joaat(model)
    end

    return model
end

local function Notify(message, notifyType, duration, title, soundEnabled)
    if not message then return end

    notifyType = notifyType or "primary"
    duration = tonumber(duration) or 5000
    title = title or "Distortionz Underground"

    if notifyType == "inform" then
        notifyType = "info"
    end

    if GetResourceState("distortionz_notify") == "started" then
        exports["distortionz_notify"]:Notify(
            message,
            notifyType,
            duration,
            title,
            soundEnabled
        )
        return
    end

    lib.notify({
        title = title,
        description = message,
        type = notifyType,
        duration = duration
    })
end

local function MarkDistortionzPedProtected(ped, pedType)
    if not ped or ped == 0 then return end
    if not DoesEntityExist(ped) then return end

    Entity(ped).state:set('distortionz_protected_ped', true, true)
    Entity(ped).state:set('distortionz_contact_ped', true, true)

    if pedType and pedType ~= '' then
        Entity(ped).state:set(pedType, true, true)
    end
end

local function LoadModel(model)
    model = NormalizeModel(model)

    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(10)
    end

    return model
end

local function LoadAnimDict(animDict)
    if not animDict or animDict == "" then return false end

    RequestAnimDict(animDict)

    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end

    return true
end

local function PlayDeliveryCompleteSound()
    if not Config.Sounds or not Config.Sounds.deliveryCompleted then return end
    if not Config.Sounds.deliveryCompleted.enabled then return end

    PlaySoundFrontend(
        -1,
        Config.Sounds.deliveryCompleted.soundName,
        Config.Sounds.deliveryCompleted.soundSet,
        true
    )
end

local function StartPedScenario(ped, scenario)
    if not ped or not DoesEntityExist(ped) then return end
    if not scenario or scenario == "" then return end

    ClearPedTasks(ped)
    TaskStartScenarioInPlace(ped, scenario, 0, true)
end

local function CreateContactBlip()
    if not Config.Blip or not Config.Blip.enabled then return end
    if contactBlip and DoesBlipExist(contactBlip) then return end

    local coords = Config.Ped.coords

    contactBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(contactBlip, Config.Blip.sprite)
    SetBlipDisplay(contactBlip, 4)
    SetBlipScale(contactBlip, Config.Blip.scale)
    SetBlipColour(contactBlip, Config.Blip.color)
    SetBlipAsShortRange(contactBlip, Config.Blip.shortRange)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(contactBlip)
end

local function FaceEntityToEntity(entityOne, entityTwo)
    if not entityOne or not entityTwo then return end
    if not DoesEntityExist(entityOne) or not DoesEntityExist(entityTwo) then return end

    local entityOneCoords = GetEntityCoords(entityOne)
    local entityTwoCoords = GetEntityCoords(entityTwo)

    local heading = GetHeadingFromVector_2d(
        entityTwoCoords.x - entityOneCoords.x,
        entityTwoCoords.y - entityOneCoords.y
    )

    SetEntityHeading(entityOne, heading)
end

local function FormatSeconds(seconds)
    seconds = tonumber(seconds) or 0

    if seconds < 0 then
        seconds = 0
    end

    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60

    return string.format("%02d:%02d", minutes, secs)
end

local function GetActiveDeliverySeconds()
    if not activeDelivery or not deliveryEndsAt then
        return 0
    end

    local remaining = deliveryEndsAt - GetGameTimer()
    remaining = math.floor(remaining / 1000)

    if remaining < 0 then
        remaining = 0
    end

    return remaining
end

local function GetCooldownText(cooldowns, name, readyText)
    local value = 0

    if cooldowns and cooldowns[name] then
        value = tonumber(cooldowns[name]) or 0
    end

    if value > 0 then
        return "Cooldown: " .. FormatSeconds(value)
    end

    return readyText
end

local function GetTargetConfig()
    return Config.Target or {}
end

local function GetMenuVersionText()
    local scriptName = Config.Script and Config.Script.name or "Distortionz Underground"
    local scriptVersion = Config.Script and Config.Script.version or "Unknown"

    return scriptName .. " | v" .. scriptVersion
end

local function RemoveDeliveryReceiverTarget()
    if not deliveryReceiverTargetAdded then return end

    if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) and GetResourceState("ox_target") == "started" then
        exports.ox_target:removeLocalEntity(deliveryReceiverPed, {
            "distortionz_peds_delivery_handoff"
        })
    end

    deliveryReceiverTargetAdded = false
end

local function RemoveDeliveryZoneTarget()
    if not deliveryZoneTargetId then return end

    if GetResourceState("ox_target") == "started" then
        exports.ox_target:removeZone(deliveryZoneTargetId)
    end

    deliveryZoneTargetId = nil
end

local function DeleteDeliveryReceiverPed()
    RemoveDeliveryReceiverTarget()
    RemoveDeliveryZoneTarget()

    if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) then
        DeleteEntity(deliveryReceiverPed)
    end

    deliveryReceiverPed = nil
end

local function ClearDelivery()
    activeDelivery = false
    deliveryDropoff = nil
    deliveryItem = nil
    deliveryItemLabel = nil
    deliveryEndsAt = nil
    isDoingHandoff = false
    isDoingContactHandoff = false

    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
    end

    deliveryBlip = nil

    DeleteDeliveryReceiverPed()
end

local function CreateDeliveryBlip(coords)
    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
    end

    if Config.Delivery.blip.clearPersonalWaypointOnStart then
        SetWaypointOff()
    end

    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(deliveryBlip, Config.Delivery.blip.sprite)
    SetBlipDisplay(deliveryBlip, 4)
    SetBlipScale(deliveryBlip, Config.Delivery.blip.scale)
    SetBlipColour(deliveryBlip, Config.Delivery.blip.color)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, Config.Delivery.blip.color)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Delivery.blip.label)
    EndTextCommandSetBlipName(deliveryBlip)

    -- Keep this disabled when you only want the delivery route GPS.
    -- SetNewWaypoint creates GTA's purple personal waypoint route.
    if Config.Delivery.blip.usePersonalWaypoint then
        SetNewWaypoint(coords.x, coords.y)
    end
end

local function GetRandomReceiverModel()
    local receiverConfig = Config.Delivery.receiverPed or {}
    local models = receiverConfig.models

    if models and #models > 0 then
        return models[math.random(1, #models)]
    end

    return `a_m_m_eastsa_02`
end

local function CompleteDeliveryFromTarget()
    if not activeDelivery then
        Notify("You do not have an active delivery.", "error", 5000)
        return
    end

    if isDoingHandoff or isDoingContactHandoff then
        return
    end

    if Config.Delivery.handoff and Config.Delivery.handoff.enabled then
        CreateThread(function()
            if isDoingHandoff then return end
            if not activeDelivery or not deliveryDropoff then return end

            isDoingHandoff = true

            local playerPed = PlayerPedId()
            local animDict = Config.Delivery.handoff.animDict
            local animName = Config.Delivery.handoff.animName
            local duration = tonumber(Config.Delivery.handoff.duration) or 3000

            if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) then
                ClearPedTasks(deliveryReceiverPed)

                FaceEntityToEntity(deliveryReceiverPed, playerPed)
                FaceEntityToEntity(playerPed, deliveryReceiverPed)

                TaskTurnPedToFaceEntity(playerPed, deliveryReceiverPed, 800)
                TaskTurnPedToFaceEntity(deliveryReceiverPed, playerPed, 800)
            end

            Wait(800)

            if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) then
                FaceEntityToEntity(deliveryReceiverPed, playerPed)
                FaceEntityToEntity(playerPed, deliveryReceiverPed)
            end

            LoadAnimDict(animDict)

            FreezeEntityPosition(playerPed, true)

            if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) then
                TaskPlayAnim(deliveryReceiverPed, animDict, animName, 8.0, -8.0, duration, 0, 0, false, false, false)
            end

            TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, duration, 0, 0, false, false, false)

            Notify(Config.Delivery.handoff.text or "Handing off package...", "primary", duration)

            Wait(duration)

            ClearPedTasks(playerPed)
            FreezeEntityPosition(playerPed, false)

            if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) then
                ClearPedTasks(deliveryReceiverPed)

                if Config.Delivery.receiverPed and Config.Delivery.receiverPed.returnToScenarioAfterHandoff then
                    StartPedScenario(deliveryReceiverPed, Config.Delivery.receiverPed.scenario)
                end
            end

            TriggerServerEvent("distortionz_peds:server:completeDelivery")
        end)
    else
        TriggerServerEvent("distortionz_peds:server:completeDelivery")
    end
end

local function GetDeliveryTargetLabel()
    if deliveryItemLabel and deliveryItemLabel ~= "" then
        return "Hand Off " .. deliveryItemLabel
    end

    return "Hand Off Package"
end

local function AddDeliveryReceiverTarget()
    if deliveryReceiverTargetAdded then return true end
    if not deliveryReceiverPed or not DoesEntityExist(deliveryReceiverPed) then return false end

    if GetResourceState("ox_target") ~= "started" then
        print("[distortionz_peds] ox_target is not started. Delivery handoff target was not added.")
        return false
    end

    local targetConfig = GetTargetConfig()

    exports.ox_target:addLocalEntity(deliveryReceiverPed, {
        {
            name = "distortionz_peds_delivery_handoff",
            icon = targetConfig.deliveryIcon or "fa-solid fa-box",
            label = GetDeliveryTargetLabel(),
            distance = targetConfig.deliveryDistance or Config.Delivery.completeDistance or 2.0,
            canInteract = function()
                return activeDelivery and not isDoingHandoff and not isDoingContactHandoff
            end,
            onSelect = function()
                CompleteDeliveryFromTarget()
            end
        }
    })

    deliveryReceiverTargetAdded = true
    return true
end

local function AddDeliveryZoneTarget(coords)
    RemoveDeliveryZoneTarget()

    if GetResourceState("ox_target") ~= "started" then
        print("[distortionz_peds] ox_target is not started. Delivery zone target was not added.")
        return false
    end

    local targetConfig = GetTargetConfig()
    local radius = targetConfig.deliveryDistance or Config.Delivery.completeDistance or 2.0

    deliveryZoneTargetId = exports.ox_target:addSphereZone({
        name = "distortionz_peds_delivery_handoff_zone",
        coords = vector3(coords.x, coords.y, coords.z),
        radius = radius,
        debug = false,
        options = {
            {
                name = "distortionz_peds_delivery_handoff_zone_option",
                icon = targetConfig.deliveryIcon or "fa-solid fa-box",
                label = GetDeliveryTargetLabel(),
                distance = radius,
                canInteract = function()
                    return activeDelivery and not isDoingHandoff and not isDoingContactHandoff
                end,
                onSelect = function()
                    CompleteDeliveryFromTarget()
                end
            }
        }
    })

    return deliveryZoneTargetId ~= nil
end

local function CreateDeliveryReceiverPed(coords)
    local receiverConfig = Config.Delivery.receiverPed or {}

    DeleteDeliveryReceiverPed()

    if receiverConfig.enabled == false then
        AddDeliveryZoneTarget(coords)
        return
    end

    local model = LoadModel(GetRandomReceiverModel())

    deliveryReceiverPed = CreatePed(
        4,
        model,
        coords.x,
        coords.y,
        coords.z - 1.0,
        coords.w or 0.0,
        false,
        true
    )

    SetEntityAsMissionEntity(deliveryReceiverPed, true, true)
    SetBlockingOfNonTemporaryEvents(deliveryReceiverPed, true)
    SetPedDiesWhenInjured(deliveryReceiverPed, false)
    SetPedCanPlayAmbientAnims(deliveryReceiverPed, true)
    SetPedCanPlayAmbientBaseAnims(deliveryReceiverPed, true)
    SetPedCanRagdollFromPlayerImpact(deliveryReceiverPed, false)

    MarkDistortionzPedProtected(deliveryReceiverPed, 'distortionz_delivery_receiver_ped')

    if receiverConfig.invincible then
        SetEntityInvincible(deliveryReceiverPed, true)
    end

    if receiverConfig.freeze then
        FreezeEntityPosition(deliveryReceiverPed, true)
    end

    StartPedScenario(deliveryReceiverPed, receiverConfig.scenario)
    AddDeliveryReceiverTarget()

    SetModelAsNoLongerNeeded(model)
end

local function BuildMenuPayload(repData, inventoryCounts)
    repData = repData or {
        level = 0,
        label = "Unknown",
        rep = 0,
        cooldowns = {
            delivery = 0,
            sell = 0,
            blackmarket = 0
        }
    }

    local cooldowns = repData.cooldowns or {}
    local sellItems = {}
    local blackMarketItems = {}

    for itemName, itemData in pairs(Config.SellItems or {}) do
        local playerAmount = 0

        if inventoryCounts and inventoryCounts[itemName] then
            playerAmount = tonumber(inventoryCounts[itemName]) or 0
        end

        sellItems[#sellItems + 1] = {
            name = itemName,
            label = itemData.label or itemName,
            minPrice = itemData.minPrice or 0,
            maxPrice = itemData.maxPrice or 0,
            highValue = itemData.highValue == true,
            owned = playerAmount
        }
    end

    table.sort(sellItems, function(a, b)
        return a.label < b.label
    end)

    if Config.BlackMarket and Config.BlackMarket.items then
        for itemName, itemData in pairs(Config.BlackMarket.items) do
            local requiredLevel = tonumber(itemData.requiredLevel) or 0
            local locked = (tonumber(repData.level) or 0) < requiredLevel

            blackMarketItems[#blackMarketItems + 1] = {
                name = itemName,
                label = itemData.label or itemName,
                price = itemData.price or 0,
                amount = itemData.amount or 1,
                requiredLevel = requiredLevel,
                locked = locked,
                category = itemData.category or "General"
            }
        end
    end

    table.sort(blackMarketItems, function(a, b)
        if a.requiredLevel == b.requiredLevel then
            return a.label < b.label
        end

        return a.requiredLevel < b.requiredLevel
    end)

    local deliveryReadyText = GetCooldownText(cooldowns, "delivery", "Ready for work.")
    local sellReadyText = GetCooldownText(cooldowns, "sell", "Ready to sell valuables.")
    local blackMarketReadyText = GetCooldownText(cooldowns, "blackmarket", "Market is open.")

    if activeDelivery then
        deliveryReadyText = "Active delivery. Time left: " .. FormatSeconds(GetActiveDeliverySeconds())
    end

    return {
        script = {
            name = Config.Script and Config.Script.name or "Distortionz Underground",
            version = Config.Script and Config.Script.version or "Unknown",
            menuVersion = GetMenuVersionText()
        },
        rep = {
            level = repData.level or 0,
            label = repData.label or "Unknown",
            value = repData.rep or 0
        },
        cooldowns = cooldowns,
        statusText = {
            delivery = deliveryReadyText,
            sell = sellReadyText,
            blackmarket = blackMarketReadyText
        },
        activeDelivery = activeDelivery,
        delivery = {
            item = deliveryItem,
            label = deliveryItemLabel,
            secondsLeft = GetActiveDeliverySeconds(),
            difficulty = activeDelivery and "Medium" or "Unknown",
            payout = activeDelivery and "Pending" or 0
        },
        busy = isDoingContactHandoff or isDoingHandoff,
        sellItems = sellItems,
        blackMarketItems = blackMarketItems
    }
end

local function SendUndergroundPayload(actionName, payload)
    SendNUIMessage({
        action = actionName or "setData",
        payload = payload
    })
end

local function RefreshUndergroundUi(actionName)
    QBCore.Functions.TriggerCallback("distortionz_peds:server:getPlayerRep", function(repData)
        QBCore.Functions.TriggerCallback("distortionz_peds:server:getSellInventory", function(inventoryCounts)
            SendUndergroundPayload(actionName or "setData", BuildMenuPayload(repData, inventoryCounts))
        end)
    end)
end

local function CloseUndergroundUi()
    nuiOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = "close"
    })
end

local function OpenIllegalMenu(actionName)
    if menuOpen or nuiOpen then return end

    menuOpen = true
    nuiOpen = true

    SetNuiFocus(true, true)
    RefreshUndergroundUi(actionName or "open")

    SetTimeout(500, function()
        menuOpen = false
    end)
end

local function OpenSellMenu()
    if not nuiOpen then
        OpenIllegalMenu("openSell")
        return
    end

    RefreshUndergroundUi("openSell")
end

local function OpenBlackMarket()
    if not nuiOpen then
        OpenIllegalMenu("openBlackMarket")
        return
    end

    RefreshUndergroundUi("openBlackMarket")
end

local function RemoveContactTarget()
    if not contactTargetAdded then return end

    if spawnedPed and DoesEntityExist(spawnedPed) and GetResourceState("ox_target") == "started" then
        exports.ox_target:removeLocalEntity(spawnedPed, {
            "distortionz_peds_underground_contact"
        })
    end

    contactTargetAdded = false
end

local function AddContactTarget()
    if contactTargetAdded then return true end
    if not spawnedPed or not DoesEntityExist(spawnedPed) then return false end

    local targetConfig = GetTargetConfig()

    if targetConfig.enabled == false then return false end

    if GetResourceState("ox_target") ~= "started" then
        print("[distortionz_peds] ox_target is not started. Underground Contact target was not added.")
        return false
    end

    exports.ox_target:addLocalEntity(spawnedPed, {
        {
            name = "distortionz_peds_underground_contact",
            icon = targetConfig.icon or "fa-solid fa-user-secret",
            label = targetConfig.label or "Talk to Underground Contact",
            distance = targetConfig.distance or Config.InteractionDistance or 2.0,
            canInteract = function()
                return not isDoingContactHandoff and not isDoingHandoff and not nuiOpen
            end,
            onSelect = function()
                OpenIllegalMenu("open")
            end
        }
    })

    contactTargetAdded = true
    return true
end

local function PlayContactHandoffAnimation()
    if isDoingContactHandoff then return false end
    if not spawnedPed or not DoesEntityExist(spawnedPed) then return true end

    local handoffConfig = Config.Delivery.contactHandoff or {}

    isDoingContactHandoff = true

    local playerPed = PlayerPedId()
    local animDict = handoffConfig.animDict
    local animName = handoffConfig.animName
    local duration = tonumber(handoffConfig.duration) or 3000

    ClearPedTasks(spawnedPed)

    FaceEntityToEntity(spawnedPed, playerPed)
    FaceEntityToEntity(playerPed, spawnedPed)

    TaskTurnPedToFaceEntity(playerPed, spawnedPed, 800)
    TaskTurnPedToFaceEntity(spawnedPed, playerPed, 800)

    Wait(800)

    FaceEntityToEntity(spawnedPed, playerPed)
    FaceEntityToEntity(playerPed, spawnedPed)

    LoadAnimDict(animDict)

    FreezeEntityPosition(playerPed, true)

    TaskPlayAnim(spawnedPed, animDict, animName, 8.0, -8.0, duration, 0, 0, false, false, false)
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, duration, 0, 0, false, false, false)

    Notify(handoffConfig.text or "The contact hands you the package.", "primary", duration)

    Wait(duration)

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)

    StartPedScenario(spawnedPed, Config.Ped.scenario)

    isDoingContactHandoff = false

    return true
end

RegisterNUICallback("close", function(_, cb)
    CloseUndergroundUi()
    cb({ success = true })
end)

RegisterNUICallback("refreshData", function(_, cb)
    RefreshUndergroundUi("setData")
    cb({ success = true })
end)

RegisterNUICallback("startDelivery", function(_, cb)
    CloseUndergroundUi()
    TriggerEvent("distortionz_peds:client:startSuspiciousDelivery")
    cb({ success = true })
end)

RegisterNUICallback("cancelDelivery", function(_, cb)
    CloseUndergroundUi()
    TriggerEvent("distortionz_peds:client:cancelDelivery")
    cb({ success = true })
end)

RegisterNUICallback("sellItem", function(data, cb)
    data = data or {}

    local itemName = data.item
    local amount = tonumber(data.amount or 0) or 0

    if not itemName or amount <= 0 then
        cb({
            success = false,
            message = "Invalid sale amount."
        })
        return
    end

    amount = math.floor(amount)

    CloseUndergroundUi()
    TriggerServerEvent("distortionz_peds:server:sellItem", itemName, amount)

    cb({ success = true })
end)

RegisterNUICallback("buyBlackMarketItem", function(data, cb)
    data = data or {}

    if not data.item then
        cb({
            success = false,
            message = "Invalid black market item."
        })
        return
    end

    CloseUndergroundUi()
    TriggerServerEvent("distortionz_peds:server:buyBlackMarketItem", data.item)

    cb({ success = true })
end)

RegisterNUICallback("streetWork", function(_, cb)
    CloseUndergroundUi()
    TriggerEvent("distortionz_peds:client:streetWork")
    cb({ success = true })
end)

CreateThread(function()
    CreateContactBlip()

    local model = LoadModel(Config.Ped.model)
    local coords = Config.Ped.coords

    spawnedPed = CreatePed(
        4,
        model,
        coords.x,
        coords.y,
        coords.z - 1.0,
        coords.w or 0.0,
        false,
        true
    )

    SetEntityAsMissionEntity(spawnedPed, true, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    SetPedDiesWhenInjured(spawnedPed, false)
    SetPedCanPlayAmbientAnims(spawnedPed, true)
    SetPedCanPlayAmbientBaseAnims(spawnedPed, true)
    SetPedCanRagdollFromPlayerImpact(spawnedPed, false)
    SetEntityInvincible(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)

    MarkDistortionzPedProtected(spawnedPed, 'distortionz_underground_contact_ped')

    StartPedScenario(spawnedPed, Config.Ped.scenario)
    AddContactTarget()

    SetModelAsNoLongerNeeded(model)
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if activeDelivery and deliveryDropoff then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local dropCoords = vector3(deliveryDropoff.x, deliveryDropoff.y, deliveryDropoff.z)
            local distance = #(playerCoords - dropCoords)

            if distance <= 35.0 then
                sleep = 0

                if Config.Delivery.marker and Config.Delivery.marker.enabled then
                    DrawMarker(
                        Config.Delivery.marker.type,
                        deliveryDropoff.x,
                        deliveryDropoff.y,
                        deliveryDropoff.z + 0.10,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        Config.Delivery.marker.scale.x,
                        Config.Delivery.marker.scale.y,
                        Config.Delivery.marker.scale.z,
                        Config.Delivery.marker.color.r,
                        Config.Delivery.marker.color.g,
                        Config.Delivery.marker.color.b,
                        Config.Delivery.marker.color.a,
                        false,
                        true,
                        2,
                        false,
                        nil,
                        nil,
                        false
                    )
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if activeDelivery and deliveryEndsAt then
            if GetGameTimer() >= deliveryEndsAt then
                TriggerServerEvent("distortionz_peds:server:failDelivery", "You took too long. Job failed.")
                ClearDelivery()
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if Config.Delivery.failOnDeath and activeDelivery then
            local playerPed = PlayerPedId()

            if IsEntityDead(playerPed) then
                TriggerServerEvent("distortionz_peds:server:failDelivery", "You died. Job failed.")
                ClearDelivery()
            end
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000

        if isDoingHandoff or isDoingContactHandoff then
            sleep = 0

            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
        end

        Wait(sleep)
    end
end)

RegisterNetEvent("distortionz_peds:client:openIllegalMenu", function()
    OpenIllegalMenu("open")
end)

RegisterNetEvent("distortionz_peds:client:openSellMenu", function()
    OpenSellMenu()
end)

RegisterNetEvent("distortionz_peds:client:openBlackMarket", function()
    OpenBlackMarket()
end)

RegisterNetEvent("distortionz_peds:client:sellItem", function(data)
    if not data or not data.item then return end

    local itemName = data.item
    local itemData = Config.SellItems[itemName]

    if not itemData then
        Notify("This contact is not buying that item.", "error", 5000)
        return
    end

    QBCore.Functions.TriggerCallback("distortionz_peds:server:getItemAmount", function(amountOwned)
        amountOwned = tonumber(amountOwned) or 0

        if amountOwned <= 0 then
            Notify("You do not have any " .. itemData.label .. " to sell.", "error", 5000)
            OpenSellMenu()
            return
        end

        local input = lib.inputDialog("Sell " .. itemData.label, {
            {
                type = "number",
                label = "Amount",
                description = "Amount owned: " .. amountOwned,
                required = true,
                min = 1,
                max = amountOwned
            }
        })

        if not input or not input[1] then
            return
        end

        local amount = tonumber(input[1])

        if not amount or amount <= 0 then
            Notify("Invalid amount.", "error", 5000)
            return
        end

        amount = math.floor(amount)

        if amount > amountOwned then
            Notify("You only have " .. amountOwned .. "x " .. itemData.label .. ".", "error", 5000)
            return
        end

        TriggerServerEvent("distortionz_peds:server:sellItem", itemName, amount)
    end, itemName)
end)

RegisterNetEvent("distortionz_peds:client:startSuspiciousDelivery", function()
    if activeDelivery then
        Notify("Finish your current delivery first.", "error", 5000)
        return
    end

    if isDoingContactHandoff then
        Notify("Wait a second.", "warning", 3000)
        return
    end

    if Config.Delivery.contactHandoff and Config.Delivery.contactHandoff.enabled then
        CreateThread(function()
            local finished = PlayContactHandoffAnimation()

            if finished then
                TriggerServerEvent("distortionz_peds:server:startDelivery")
            end
        end)
    else
        TriggerServerEvent("distortionz_peds:server:startDelivery")
    end
end)

RegisterNetEvent("distortionz_peds:client:cancelDelivery", function()
    if not activeDelivery then
        Notify("You do not have an active delivery.", "error", 5000)
        return
    end

    TriggerServerEvent("distortionz_peds:server:cancelDelivery")
    ClearDelivery()
end)

RegisterNetEvent("distortionz_peds:client:deliveryStarted", function(data)
    if not data or not data.dropoff or not data.item or not data.label then
        Notify("Delivery data failed to load.", "error", 5000)
        return
    end

    activeDelivery = true
    deliveryDropoff = data.dropoff
    deliveryItem = data.item
    deliveryItemLabel = data.label
    isDoingHandoff = false
    deliveryEndsAt = GetGameTimer() + ((data.timeLimit or Config.Delivery.timeLimitSeconds) * 1000)

    CreateDeliveryBlip(deliveryDropoff)
    CreateDeliveryReceiverPed(deliveryDropoff)

    Notify("You received a " .. deliveryItemLabel .. ". Deliver it to the GPS location.", "success", 7000)

    if nuiOpen then
        RefreshUndergroundUi("setData")
    end
end)

RegisterNetEvent("distortionz_peds:client:deliveryCompleted", function()
    PlayDeliveryCompleteSound()
    ClearDelivery()

    if nuiOpen then
        RefreshUndergroundUi("setData")
    end
end)

RegisterNetEvent("distortionz_peds:client:deliveryFailed", function()
    ClearDelivery()

    if nuiOpen then
        RefreshUndergroundUi("setData")
    end
end)

RegisterNetEvent("distortionz_peds:client:blackMarketInfo", function()
    OpenBlackMarket()
end)

RegisterNetEvent("distortionz_peds:client:streetWork", function()
    Notify("The contact says: More work is coming soon.", "info", 5000)
end)

RegisterNetEvent("distortionz_peds:client:createPoliceBlip", function(coords, label)
    if not coords then return end

    local alertBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(alertBlip, Config.PoliceAlerts.blip.sprite)
    SetBlipScale(alertBlip, Config.PoliceAlerts.blip.scale)
    SetBlipColour(alertBlip, Config.PoliceAlerts.blip.color)
    SetBlipAsShortRange(alertBlip, false)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label or Config.PoliceAlerts.blip.label)
    EndTextCommandSetBlipName(alertBlip)

    SetTimeout(Config.PoliceAlerts.blip.time, function()
        if DoesBlipExist(alertBlip) then
            RemoveBlip(alertBlip)
        end
    end)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    RemoveContactTarget()
    RemoveDeliveryReceiverTarget()
    RemoveDeliveryZoneTarget()

    if spawnedPed and DoesEntityExist(spawnedPed) then
        DeleteEntity(spawnedPed)
    end

    if contactBlip and DoesBlipExist(contactBlip) then
        RemoveBlip(contactBlip)
    end

    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
    end

    DeleteDeliveryReceiverPed()
    CloseUndergroundUi()
end)