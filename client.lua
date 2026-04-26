local robbedPeds = {}
local isRobbing = false
local currentRobbery = nil

local allowedWeaponHashes = {}
local blacklistedModelHashes = {}

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:client] %s'):format(Config.ResourceName, message))
    end
end

local function Notify(message, status, duration)
    status = status or 'info'
    duration = duration or 5000

    if Config.Notify.useDistortionzNotify and GetResourceState('distortionz_notify') == 'started' then
        local ok = pcall(function()
            exports['distortionz_notify']:Notify(message, status, duration)
        end)

        if ok then return end

        ok = pcall(function()
            exports['distortionz_notify']:Send(message, status, duration)
        end)

        if ok then return end

        ok = pcall(function()
            TriggerEvent('distortionz_notify:client:notify', message, status, duration)
        end)

        if ok then return end
    end

    lib.notify({
        title = Config.Notify.title,
        description = message,
        type = status,
        duration = duration
    })
end

RegisterNetEvent('distortionz_robped:client:notify', function(message, status, duration)
    Notify(message, status, duration)
end)

local function LoadAnimDict(dict)
    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 8000

    while not HasAnimDictLoaded(dict) do
        Wait(25)

        if GetGameTimer() > timeout then
            DebugPrint(('Anim dict timeout: %s'):format(dict))
            return false
        end
    end

    return true
end

local function AddHash(hashTable, name)
    if not name or name == '' then return end

    hashTable[joaat(name)] = true

    if GetHashKey then
        hashTable[GetHashKey(name)] = true
    end
end

local function BuildHashes()
    for _, weaponName in ipairs(Config.AllowedWeapons or {}) do
        AddHash(allowedWeaponHashes, weaponName)
    end

    for _, modelName in ipairs(Config.BlacklistedPedModels or {}) do
        AddHash(blacklistedModelHashes, modelName)
    end
end

local function IsPedRobbedRecently(ped)
    if not DoesEntityExist(ped) then return true end

    local state = Entity(ped).state

    if state and state.distortionz_robbed == true then
        return true
    end

    local pedKey = tostring(ped)
    local expires = robbedPeds[pedKey]

    if not expires then return false end

    if GetGameTimer() >= expires then
        robbedPeds[pedKey] = nil
        return false
    end

    return true
end

local function MarkPedRobbed(ped)
    if not Config.Robbery.markPedRobbed then return end
    if not DoesEntityExist(ped) then return end

    local pedKey = tostring(ped)
    local duration = (Config.Robbery.robbedPedCooldown or 900) * 1000

    robbedPeds[pedKey] = GetGameTimer() + duration

    pcall(function()
        Entity(ped).state:set('distortionz_robbed', true, true)
    end)

    CreateThread(function()
        Wait(duration)

        if DoesEntityExist(ped) then
            pcall(function()
                Entity(ped).state:set('distortionz_robbed', false, true)
            end)
        end
    end)
end

local function HasAllowedWeapon()
    if not Config.Robbery.requireWeapon then return true end

    local playerPed = PlayerPedId()
    local selectedWeapon = GetSelectedPedWeapon(playerPed)

    if not selectedWeapon or selectedWeapon == 0 then
        return false
    end

    local unarmedHash = joaat('WEAPON_UNARMED')

    if selectedWeapon == unarmedHash then
        return false
    end

    if GetHashKey and selectedWeapon == GetHashKey('WEAPON_UNARMED') then
        return false
    end

    -- Main fix: allow any weapon the player actually has equipped.
    -- This prevents valid guns from being rejected just because the weapon name is missing from Config.AllowedWeapons.
    if Config.Robbery.allowAnyWeapon ~= false then
        return true
    end

    return allowedWeaponHashes[selectedWeapon] == true
end

local function IsBlacklistedPed(ped)
    if not DoesEntityExist(ped) then return true end

    local model = GetEntityModel(ped)

    if blacklistedModelHashes[model] then
        return true
    end

    local pedType = GetPedType(ped)

    if Config.BlacklistedPedTypes and Config.BlacklistedPedTypes[pedType] then
        return true
    end

    local protection = Config.Protection or {}

    if protection.blockProtectedDistortionzPeds ~= false then
        local state = Entity(ped).state

        if state then
            if state.distortionz_protected_ped == true then return true end
            if state.distortionz_contact_ped == true then return true end
            if state.distortionz_underground_contact_ped == true then return true end
            if state.distortionz_delivery_receiver_ped == true then return true end
            if state.distortionz_shop_ped == true then return true end
            if state.distortionz_boss_ped == true then return true end
            if state.distortionz_launder_ped == true then return true end
            if state.distortionz_assassin_boss == true then return true end
        end
    end

    if protection.blockedStateBags then
        local state = Entity(ped).state

        if state then
            for _, stateName in ipairs(protection.blockedStateBags) do
                if state[stateName] == true then
                    return true
                end
            end
        end
    end

    if protection.blockFrozenPeds and IsEntityPositionFrozen(ped) then
        return true
    end

    if protection.blockInvinciblePeds and GetEntityInvincible(ped) then
        return true
    end

    if protection.blockMissionEntities and IsEntityAMissionEntity(ped) then
        return true
    end

    return false
end


local function IsValidRobPed(ped, ignoreWeaponCheck)
    if isRobbing then return false end
    if not ped or ped == 0 then return false end
    if not DoesEntityExist(ped) then return false end

    local playerPed = PlayerPedId()

    if ped == playerPed then return false end

    if IsPedAPlayer(ped) and not Config.Robbery.allowPlayers then
        return false
    end

    if not Config.Robbery.allowAnimals and not IsPedHuman(ped) then
        return false
    end

    if IsPedDeadOrDying(ped, true) and not Config.Robbery.allowDeadPeds then
        return false
    end

    if IsPedInAnyVehicle(ped, false) then
        return false
    end

    if IsPedFleeing(ped) then
        return false
    end

    if IsPedInCombat(ped, playerPed) then
        return false
    end

    if IsPedRobbedRecently(ped) then
        return false
    end

    if IsBlacklistedPed(ped) then
        return false
    end

    if not ignoreWeaponCheck and not HasAllowedWeapon() then
        return false
    end

    return true
end

local function PlayPlayerRobAnimation()
    local playerPed = PlayerPedId()
    local anim = Config.Animations.player

    if not anim or not anim.dict or not anim.anim then return end

    if LoadAnimDict(anim.dict) then
        TaskPlayAnim(
            playerPed,
            anim.dict,
            anim.anim,
            8.0,
            -8.0,
            -1,
            anim.flag or 49,
            0.0,
            false,
            false,
            false
        )
    end
end

local function StopPlayerRobAnimation()
    ClearPedTasks(PlayerPedId())
end

local function MakePedComply(ped)
    if not DoesEntityExist(ped) then return end

    ClearPedTasksImmediately(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanRagdoll(ped, true)

    TaskHandsUp(
        ped,
        Config.Robbery.pedHandsUpTime or 10000,
        PlayerPedId(),
        -1,
        true
    )
end

local function PedAfterRobberyReaction(ped)
    if not DoesEntityExist(ped) then return end

    SetBlockingOfNonTemporaryEvents(ped, false)

    local playerPed = PlayerPedId()

    if Config.Robbery.pedFightBack and math.random(1, 100) <= (Config.Robbery.pedFightBackChance or 0) then
        GiveWeaponToPed(ped, joaat('WEAPON_KNIFE'), 1, false, true)
        TaskCombatPed(ped, playerPed, 0, 16)
        return
    end

    if Config.Robbery.pedFleeAfterRobbery and math.random(1, 100) <= (Config.Robbery.pedFleeChance or 0) then
        TaskSmartFleePed(ped, playerPed, 120.0, -1, false, false)
        return
    end

    ClearPedTasks(ped)
    TaskWanderStandard(ped, 10.0, 10)
end

local function StartDistanceAndPedCheck(ped, robberyId)
    CreateThread(function()
        while isRobbing and currentRobbery and currentRobbery.robberyId == robberyId do
            Wait(500)

            if not DoesEntityExist(ped) then
                isRobbing = false
                currentRobbery = nil
                TriggerServerEvent('distortionz_robped:server:cancelRobbery', robberyId)
                Notify('The civilian got away.', 'error')
                return
            end

            if Config.Robbery.cancelIfPedDies and IsPedDeadOrDying(ped, true) then
                isRobbing = false
                currentRobbery = nil
                TriggerServerEvent('distortionz_robped:server:cancelRobbery', robberyId)
                Notify('The civilian died. Robbery cancelled.', 'error')
                return
            end

            if Config.Robbery.cancelIfPlayerMovesAway then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local pedCoords = GetEntityCoords(ped)
                local dist = #(playerCoords - pedCoords)

                if dist > (Config.Robbery.maxDistance or 4.0) then
                    isRobbing = false
                    currentRobbery = nil
                    TriggerServerEvent('distortionz_robped:server:cancelRobbery', robberyId)
                    Notify('You moved too far away. Robbery cancelled.', 'error')
                    return
                end
            end
        end
    end)
end

local function RobPed(ped)
    if isRobbing then
        Notify('You are already robbing someone.', 'warning')
        return
    end

    if not DoesEntityExist(ped) then
        Notify('Invalid civilian.', 'error')
        return
    end

    if not HasAllowedWeapon() then
        Notify('You need to threaten them with a weapon.', 'error')
        return
    end

    if not IsValidRobPed(ped) then
        Notify('You cannot rob this person.', 'error')
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local result = lib.callback.await('distortionz_robped:server:startRobbery', false, {
        coords = {
            x = playerCoords.x,
            y = playerCoords.y,
            z = playerCoords.z
        }
    })

    if not result then
        Notify('Robbery failed to start.', 'error')
        return
    end

    if not result.success then
        Notify(result.message or 'You cannot rob right now.', result.status or 'error')
        return
    end

    local robberyId = result.robberyId

    isRobbing = true
    currentRobbery = {
        robberyId = robberyId,
        ped = ped
    }

    MarkPedRobbed(ped)
    MakePedComply(ped)
    PlayPlayerRobAnimation()
    StartDistanceAndPedCheck(ped, robberyId)

    Notify('Keep them under control while you search their pockets.', 'info', 5000)

    local success = lib.progressCircle({
        duration = Config.Robbery.duration,
        label = 'Robbing civilian...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = false,
            sprint = true
        }
    })

    StopPlayerRobAnimation()

    if not currentRobbery or currentRobbery.robberyId ~= robberyId then
        PedAfterRobberyReaction(ped)
        return
    end

    if not success then
        isRobbing = false
        currentRobbery = nil

        TriggerServerEvent('distortionz_robped:server:cancelRobbery', robberyId)

        PedAfterRobberyReaction(ped)
        Notify('Robbery cancelled.', 'error')
        return
    end

    isRobbing = false
    currentRobbery = nil

    TriggerServerEvent('distortionz_robped:server:finishRobbery', robberyId)

    PedAfterRobberyReaction(ped)
end

RegisterNetEvent('distortionz_robped:client:policeAlert', function(alertData)
    local coords = alertData.coords

    Notify(alertData.message or 'Civilian robbery reported.', 'warning', 7500)

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, Config.Police.alertBlip.sprite)
    SetBlipColour(blip, Config.Police.alertBlip.color)
    SetBlipScale(blip, Config.Police.alertBlip.scale)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Police.alertBlip.label or 'Civilian Robbery')
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        Wait((Config.Police.alertBlip.duration or 60) * 1000)

        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isRobbing then
        StopPlayerRobAnimation()
    end

    pcall(function()
        exports.ox_target:removeGlobalPed('distortionz_robped_rob_civilian')
    end)
end)

CreateThread(function()
    BuildHashes()

    if GetResourceState('ox_target') ~= 'started' then
        print(('[%s] ox_target is not started. Rob Ped target was not registered.'):format(Config.ResourceName))
        return
    end

    exports.ox_target:addGlobalPed({
        {
            name = 'distortionz_robped_rob_civilian',
            icon = Config.Target.icon,
            label = Config.Target.label,
            distance = Config.Target.distance,
            canInteract = function(entity)
                -- Show the target on valid civilians even when the player does not have a weapon out.
                -- RobPed() still checks the weapon and sends a notification if the player tries without one.
                return IsValidRobPed(entity, true)
            end,
            onSelect = function(data)
                if not data or not data.entity then return end
                RobPed(data.entity)
            end
        }
    })

    DebugPrint('Global ped target registered.')
end)
