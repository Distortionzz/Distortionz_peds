local QBCore = exports['qb-core']:GetCoreObject()

local spawnedPed = nil
local contactBlip = nil
local menuOpen = false

local activeDelivery = false
local deliveryDropoff = nil
local deliveryItem = nil
local deliveryItemLabel = nil
local deliveryBlip = nil
local deliveryReceiverPed = nil
local isDoingHandoff = false
local isDoingContactHandoff = false
local deliveryEndsAt = nil

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 230)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)

    local factor = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 135)

    ClearDrawOrigin()
end

local function LoadModel(model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(10)
    end
end

local function LoadAnimDict(animDict)
    RequestAnimDict(animDict)

    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
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
    if not scenario then return end

    ClearPedTasks(ped)
    TaskStartScenarioInPlace(ped, scenario, 0, true)
end

local function CreateContactBlip()
    if not Config.Blip.enabled then return end

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

local function DeleteDeliveryReceiverPed()
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

    if Config.Delivery.blip.usePersonalWaypoint then
        SetNewWaypoint(coords.x, coords.y)
    end
end

local function GetRandomReceiverModel()
    local models = Config.Delivery.receiverPed.models

    if models and #models > 0 then
        return models[math.random(1, #models)]
    end

    return `a_m_m_eastsa_02`
end

local function CreateDeliveryReceiverPed(coords)
    if not Config.Delivery.receiverPed.enabled then return end

    DeleteDeliveryReceiverPed()

    local model = GetRandomReceiverModel()
    LoadModel(model)

    deliveryReceiverPed = CreatePed(
        4,
        model,
        coords.x,
        coords.y,
        coords.z - 1.0,
        coords.w,
        false,
        true
    )

    SetEntityAsMissionEntity(deliveryReceiverPed, true, true)
    SetBlockingOfNonTemporaryEvents(deliveryReceiverPed, true)
    SetPedDiesWhenInjured(deliveryReceiverPed, false)
    SetPedCanRagdollFromPlayerImpact(deliveryReceiverPed, false)

    if Config.Delivery.receiverPed.invincible then
        SetEntityInvincible(deliveryReceiverPed, true)
    end

    if Config.Delivery.receiverPed.freeze then
        FreezeEntityPosition(deliveryReceiverPed, true)
    end

    StartPedScenario(deliveryReceiverPed, Config.Delivery.receiverPed.scenario)

    SetModelAsNoLongerNeeded(model)
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

local function GetDeliveryPromptCoords()
    if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) and Config.Delivery.prompt.usePedHeadPosition then
        local headCoords = GetPedBoneCoords(deliveryReceiverPed, 31086, 0.0, 0.0, Config.Delivery.prompt.headOffset or 0.18)
        return headCoords.x, headCoords.y, headCoords.z
    end

    if deliveryDropoff then
        return deliveryDropoff.x, deliveryDropoff.y, deliveryDropoff.z + 1.1
    end

    return 0.0, 0.0, 0.0
end

local function GetMenuVersionText()
    local scriptName = Config.Script and Config.Script.name or "Distortionz Underground"
    local scriptVersion = Config.Script and Config.Script.version or "Unknown"

    return scriptName .. " | v" .. scriptVersion
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

local function OpenIllegalMenu()
    if menuOpen then return end
    menuOpen = true

    QBCore.Functions.TriggerCallback("distortionz_peds:server:getPlayerRep", function(repData)
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
        local deliveryText = GetCooldownText(cooldowns, "delivery", "Ready for work.")
        local miniMarketText = GetCooldownText(cooldowns, "sell", "Ready to sell valuables.")
        local blackMarketText = GetCooldownText(cooldowns, "blackmarket", "Market is open.")

        if activeDelivery then
            local remaining = 0

            if deliveryEndsAt then
                remaining = deliveryEndsAt - GetGameTimer()
                remaining = math.floor(remaining / 1000)
            end

            deliveryText = "Active delivery. Time left: " .. FormatSeconds(remaining)
        end

        exports['qb-menu']:openMenu({
            {
                header = "Underground Contact",
                txt = GetMenuVersionText() .. " | Rep: " .. repData.label .. " (" .. repData.rep .. ")",
                isMenuHeader = true
            },
            {
                header = "Mini Market",
                txt = miniMarketText,
                icon = "fas fa-store",
                disabled = (cooldowns.sell or 0) > 0,
                params = {
                    event = "distortionz_peds:client:openSellMenu"
                }
            },
            {
                header = "Suspicious Delivery",
                txt = deliveryText,
                icon = "fas fa-box",
                disabled = activeDelivery or isDoingContactHandoff or ((cooldowns.delivery or 0) > 0),
                params = {
                    event = "distortionz_peds:client:startSuspiciousDelivery"
                }
            },
            {
                header = "Cancel Delivery",
                txt = activeDelivery and "Cancel your current job." or "No active delivery.",
                icon = "fas fa-ban",
                disabled = not activeDelivery,
                params = {
                    event = "distortionz_peds:client:cancelDelivery"
                }
            },
            {
                header = "Black Market",
                txt = blackMarketText,
                icon = "fas fa-user-secret",
                disabled = (cooldowns.blackmarket or 0) > 0,
                params = {
                    event = "distortionz_peds:client:openBlackMarket"
                }
            },
            {
                header = "Street Work",
                txt = "More street jobs coming soon.",
                icon = "fas fa-map-location-dot",
                params = {
                    event = "distortionz_peds:client:streetWork"
                }
            },
            {
                header = "Leave",
                txt = "Walk away.",
                icon = "fas fa-xmark",
                params = {
                    event = "qb-menu:closeMenu"
                }
            }
        })

        SetTimeout(500, function()
            menuOpen = false
        end)
    end)
end

local function OpenSellMenu()
    QBCore.Functions.TriggerCallback("distortionz_peds:server:getSellInventory", function(inventoryCounts)
        local sellMenu = {
            {
                header = "Mini Market",
                txt = GetMenuVersionText(),
                isMenuHeader = true
            }
        }

        for itemName, itemData in pairs(Config.SellItems) do
            local playerAmount = 0

            if inventoryCounts and inventoryCounts[itemName] then
                playerAmount = inventoryCounts[itemName]
            end

            local menuText = "You have: " .. playerAmount .. " | $" .. itemData.minPrice .. " - $" .. itemData.maxPrice .. " each"

            sellMenu[#sellMenu + 1] = {
                header = itemData.label,
                txt = menuText,
                icon = "fas fa-dollar-sign",
                disabled = playerAmount <= 0,
                params = {
                    event = "distortionz_peds:client:sellItem",
                    args = {
                        item = itemName,
                        amountOwned = playerAmount
                    }
                }
            }
        end

        sellMenu[#sellMenu + 1] = {
            header = "Back",
            txt = "Return to underground contact menu.",
            icon = "fas fa-arrow-left",
            params = {
                event = "distortionz_peds:client:openIllegalMenu"
            }
        }

        sellMenu[#sellMenu + 1] = {
            header = "Close",
            txt = "Walk away.",
            icon = "fas fa-xmark",
            params = {
                event = "qb-menu:closeMenu"
            }
        }

        exports['qb-menu']:openMenu(sellMenu)
    end)
end

local function OpenBlackMarket()
    QBCore.Functions.TriggerCallback("distortionz_peds:server:getPlayerRep", function(repData)
        repData = repData or { level = 0, label = "Unknown", rep = 0 }

        local menu = {
            {
                header = "Black Market",
                txt = "Rep: " .. repData.label .. " | Level " .. repData.level,
                isMenuHeader = true
            }
        }

        for itemName, itemData in pairs(Config.BlackMarket.items) do
            local locked = repData.level < itemData.requiredLevel
            local txt = "$" .. itemData.price .. " | Required Level: " .. itemData.requiredLevel

            if locked then
                txt = "Locked | Required Level: " .. itemData.requiredLevel
            end

            menu[#menu + 1] = {
                header = itemData.label,
                txt = txt,
                icon = locked and "fas fa-lock" or "fas fa-cart-shopping",
                disabled = locked,
                params = {
                    event = "distortionz_peds:client:buyBlackMarketItem",
                    args = {
                        item = itemName
                    }
                }
            }
        end

        menu[#menu + 1] = {
            header = "Back",
            txt = "Return to underground contact menu.",
            icon = "fas fa-arrow-left",
            params = {
                event = "distortionz_peds:client:openIllegalMenu"
            }
        }

        menu[#menu + 1] = {
            header = "Close",
            txt = "Walk away.",
            icon = "fas fa-xmark",
            params = {
                event = "qb-menu:closeMenu"
            }
        }

        exports['qb-menu']:openMenu(menu)
    end)
end

local function PlayContactHandoffAnimation()
    if isDoingContactHandoff then return false end
    if not spawnedPed or not DoesEntityExist(spawnedPed) then return true end

    isDoingContactHandoff = true

    local playerPed = PlayerPedId()
    local animDict = Config.Delivery.contactHandoff.animDict
    local animName = Config.Delivery.contactHandoff.animName
    local duration = Config.Delivery.contactHandoff.duration

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

    QBCore.Functions.Notify(Config.Delivery.contactHandoff.text, "primary", duration)

    Wait(duration)

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)

    StartPedScenario(spawnedPed, Config.Ped.scenario)

    isDoingContactHandoff = false

    return true
end

local function StartHandoffAnimation()
    if isDoingHandoff then return end
    if not activeDelivery or not deliveryDropoff then return end

    isDoingHandoff = true

    local playerPed = PlayerPedId()
    local animDict = Config.Delivery.handoff.animDict
    local animName = Config.Delivery.handoff.animName
    local duration = Config.Delivery.handoff.duration

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

    QBCore.Functions.Notify(Config.Delivery.handoff.text, "primary", duration)

    Wait(duration)

    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)

    if deliveryReceiverPed and DoesEntityExist(deliveryReceiverPed) then
        ClearPedTasks(deliveryReceiverPed)

        if Config.Delivery.receiverPed.returnToScenarioAfterHandoff then
            StartPedScenario(deliveryReceiverPed, Config.Delivery.receiverPed.scenario)
        end
    end

    TriggerServerEvent("distortionz_peds:server:completeDelivery")
end

CreateThread(function()
    CreateContactBlip()

    LoadModel(Config.Ped.model)

    local coords = Config.Ped.coords

    spawnedPed = CreatePed(
        4,
        Config.Ped.model,
        coords.x,
        coords.y,
        coords.z - 1.0,
        coords.w,
        false,
        true
    )

    SetEntityAsMissionEntity(spawnedPed, true, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    SetPedDiesWhenInjured(spawnedPed, false)
    SetPedCanPlayAmbientAnims(spawnedPed, true)
    SetPedCanRagdollFromPlayerImpact(spawnedPed, false)
    SetEntityInvincible(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)

    StartPedScenario(spawnedPed, Config.Ped.scenario)

    SetModelAsNoLongerNeeded(Config.Ped.model)
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local coords = Config.Ped.coords
        local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))

        if distance <= Config.DrawDistance then
            sleep = 0

            if distance <= Config.InteractionDistance then
                if isDoingContactHandoff then
                    DrawText3D(coords.x, coords.y, coords.z + 1.0, "Working...")
                else
                    DrawText3D(coords.x, coords.y, coords.z + 1.0, "[E] Talk to Underground Contact")
                end

                if IsControlJustPressed(0, 38) and not isDoingContactHandoff then
                    OpenIllegalMenu()
                end
            end
        end

        Wait(sleep)
    end
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

                if Config.Delivery.marker.enabled then
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

                if distance <= Config.Delivery.completeDistance and not isDoingHandoff then
                    local textX, textY, textZ = GetDeliveryPromptCoords()
                    DrawText3D(textX, textY, textZ, "[E] Hand off " .. deliveryItemLabel)

                    if IsControlJustPressed(0, 38) then
                        if Config.Delivery.handoff.enabled then
                            StartHandoffAnimation()
                        else
                            TriggerServerEvent("distortionz_peds:server:completeDelivery")
                        end
                    end
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
        Wait(0)

        if isDoingHandoff or isDoingContactHandoff then
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
    end
end)

RegisterNetEvent("distortionz_peds:client:openIllegalMenu", function()
    OpenIllegalMenu()
end)

RegisterNetEvent("distortionz_peds:client:openSellMenu", function()
    OpenSellMenu()
end)

RegisterNetEvent("distortionz_peds:client:openBlackMarket", function()
    OpenBlackMarket()
end)

RegisterNetEvent("distortionz_peds:client:buyBlackMarketItem", function(data)
    if not data or not data.item then return end
    TriggerServerEvent("distortionz_peds:server:buyBlackMarketItem", data.item)
end)

RegisterNetEvent("distortionz_peds:client:sellItem", function(data)
    if not data or not data.item then return end

    local itemName = data.item
    local itemData = Config.SellItems[itemName]

    if not itemData then
        QBCore.Functions.Notify("This contact is not buying that item.", "error", 5000)
        return
    end

    QBCore.Functions.TriggerCallback("distortionz_peds:server:getItemAmount", function(amountOwned)
        amountOwned = tonumber(amountOwned) or 0

        if amountOwned <= 0 then
            QBCore.Functions.Notify("You do not have any " .. itemData.label .. " to sell.", "error", 5000)
            OpenSellMenu()
            return
        end

        local dialog = exports['qb-input']:ShowInput({
            header = "Sell " .. itemData.label,
            submitText = "Sell Items",
            inputs = {
                {
                    text = "Amount owned: " .. amountOwned,
                    name = "amount",
                    type = "number",
                    isRequired = true
                }
            }
        })

        if not dialog or not dialog.amount then
            return
        end

        local amount = tonumber(dialog.amount)

        if not amount or amount <= 0 then
            QBCore.Functions.Notify("Invalid amount.", "error", 5000)
            return
        end

        amount = math.floor(amount)

        if amount > amountOwned then
            QBCore.Functions.Notify("You only have " .. amountOwned .. "x " .. itemData.label .. ".", "error", 5000)
            return
        end

        TriggerServerEvent("distortionz_peds:server:sellItem", itemName, amount)
    end, itemName)
end)

RegisterNetEvent("distortionz_peds:client:startSuspiciousDelivery", function()
    if activeDelivery then
        QBCore.Functions.Notify("Finish your current delivery first.", "error", 5000)
        return
    end

    if isDoingContactHandoff then
        QBCore.Functions.Notify("Wait a second.", "error", 3000)
        return
    end

    if Config.Delivery.contactHandoff.enabled then
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
        QBCore.Functions.Notify("You do not have an active delivery.", "error", 5000)
        return
    end

    TriggerServerEvent("distortionz_peds:server:cancelDelivery")
    ClearDelivery()
end)

RegisterNetEvent("distortionz_peds:client:deliveryStarted", function(data)
    if not data or not data.dropoff or not data.item or not data.label then
        QBCore.Functions.Notify("Delivery data failed to load.", "error", 5000)
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

    QBCore.Functions.Notify("You received a " .. deliveryItemLabel .. ". Deliver it to the GPS location.", "success", 7000)
end)

RegisterNetEvent("distortionz_peds:client:deliveryCompleted", function()
    PlayDeliveryCompleteSound()
    ClearDelivery()
end)

RegisterNetEvent("distortionz_peds:client:deliveryFailed", function()
    ClearDelivery()
end)

RegisterNetEvent("distortionz_peds:client:blackMarketInfo", function()
    OpenBlackMarket()
end)

RegisterNetEvent("distortionz_peds:client:streetWork", function()
    QBCore.Functions.Notify("The contact says: More work is coming soon.", "primary", 5000)
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

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

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
end)