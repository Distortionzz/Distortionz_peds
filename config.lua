Config = {}

Config.Debug = false

Config.ResourceName = 'distortionz_robped'
Config.CurrentVersion = '1.0.1'

Config.VersionCheck = {
    enabled = true,
    url = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_RobPed/main/version.json',
    checkOnStart = true
}

Config.Notify = {
    title = 'Ped Robbery',
    useDistortionzNotify = true
}

Config.Target = {
    icon = 'fa-solid fa-hand-holding-dollar',
    label = 'Rob Civilian',
    distance = 3.5
}

Config.Robbery = {
    duration = 8000,
    cooldown = 90,
    maxDistance = 4.0,

    requireWeapon = true,
    allowAnyWeapon = true,


    markPedRobbed = true,
    robbedPedCooldown = 15 * 60,

    allowDeadPeds = false,
    allowPlayers = false,
    allowAnimals = false,

    cancelIfPedDies = true,
    cancelIfPlayerMovesAway = true,

    noRewardChance = 15,

    pedHandsUpTime = 10000,
    pedFleeAfterRobbery = true,
    pedFleeChance = 35,

    pedFightBack = true,
    pedFightBackChance = 10
}

Config.Protection = {
    blockProtectedDistortionzPeds = true,

    -- Keep these false so normal ambient/scenario peds can still be robbed.
    blockFrozenPeds = false,
    blockInvinciblePeds = false,
    blockMissionEntities = false,

    blockedStateBags = {
        'distortionz_protected_ped',
        'distortionz_contact_ped',
        'distortionz_underground_contact_ped',
        'distortionz_delivery_receiver_ped',
        'distortionz_shop_ped',
        'distortionz_boss_ped',
        'distortionz_launder_ped',
        'distortionz_assassin_boss'
    }
}

Config.AllowedWeapons = {
    -- This list is only used when Config.Robbery.allowAnyWeapon = false.
    -- With allowAnyWeapon = true, any equipped weapon except unarmed will work.

    -- Pistols
    'WEAPON_PISTOL',
    'WEAPON_PISTOL_MK2',
    'WEAPON_COMBATPISTOL',
    'WEAPON_APPISTOL',
    'WEAPON_PISTOL50',
    'WEAPON_SNSPISTOL',
    'WEAPON_SNSPISTOL_MK2',
    'WEAPON_HEAVYPISTOL',
    'WEAPON_VINTAGEPISTOL',
    'WEAPON_MARKSMANPISTOL',
    'WEAPON_REVOLVER',
    'WEAPON_REVOLVER_MK2',
    'WEAPON_DOUBLEACTION',
    'WEAPON_CERAMICPISTOL',
    'WEAPON_NAVYREVOLVER',
    'WEAPON_GADGETPISTOL',
    'WEAPON_STUNGUN',
    'WEAPON_STUNGUN_MP',

    -- SMGs
    'WEAPON_MICROSMG',
    'WEAPON_MINISMG',
    'WEAPON_SMG',
    'WEAPON_SMG_MK2',
    'WEAPON_ASSAULTSMG',
    'WEAPON_COMBATPDW',
    'WEAPON_MACHINEPISTOL',

    -- Shotguns
    'WEAPON_PUMPSHOTGUN',
    'WEAPON_PUMPSHOTGUN_MK2',
    'WEAPON_SAWNOFFSHOTGUN',
    'WEAPON_ASSAULTSHOTGUN',
    'WEAPON_BULLPUPSHOTGUN',
    'WEAPON_HEAVYSHOTGUN',
    'WEAPON_DBSHOTGUN',
    'WEAPON_AUTOSHOTGUN',
    'WEAPON_COMBATSHOTGUN',

    -- Rifles
    'WEAPON_ASSAULTRIFLE',
    'WEAPON_ASSAULTRIFLE_MK2',
    'WEAPON_CARBINERIFLE',
    'WEAPON_CARBINERIFLE_MK2',
    'WEAPON_ADVANCEDRIFLE',
    'WEAPON_SPECIALCARBINE',
    'WEAPON_SPECIALCARBINE_MK2',
    'WEAPON_BULLPUPRIFLE',
    'WEAPON_BULLPUPRIFLE_MK2',
    'WEAPON_COMPACTRIFLE',
    'WEAPON_MILITARYRIFLE',
    'WEAPON_HEAVYRIFLE',
    'WEAPON_TACTICALRIFLE',

    -- Melee
    'WEAPON_KNIFE',
    'WEAPON_DAGGER',
    'WEAPON_BAT',
    'WEAPON_CROWBAR',
    'WEAPON_SWITCHBLADE',
    'WEAPON_MACHETE',
    'WEAPON_BOTTLE',
    'WEAPON_HAMMER',
    'WEAPON_WRENCH',
    'WEAPON_HATCHET',
    'WEAPON_BATTLEAXE',
    'WEAPON_POOLCUE'
}

Config.BlacklistedPedModels = {
    -- Police / emergency examples
    's_m_y_cop_01',
    's_f_y_cop_01',
    's_m_y_sheriff_01',
    's_f_y_sheriff_01',
    's_m_y_hwaycop_01',
    's_m_m_paramedic_01',
    's_m_y_fireman_01',

    -- Common shop / service peds you may not want robbed
    's_m_m_doctor_01',
    's_m_m_highsec_01'
}

Config.BlacklistedPedTypes = {
    -- Keep this mostly empty unless needed.
    -- Ped types can vary depending on server/game natives.
}

Config.Rewards = {
    cash = {
        enabled = true,
        chance = 70,
        min = 25,
        max = 250
    },

    dirtyMoney = {
        enabled = true,
        chance = 35,
        item = 'black_money',
        min = 100,
        max = 750
    },

    items = {
        enabled = true,
        chance = 45,

        pool = {
            { item = 'phone', min = 1, max = 1, chance = 20 },
            { item = 'lockpick', min = 1, max = 1, chance = 12 },
            { item = 'goldchain', min = 1, max = 2, chance = 15 },
            { item = 'watch', min = 1, max = 1, chance = 18 },
            { item = 'ring', min = 1, max = 1, chance = 10 },
            { item = 'lighter', min = 1, max = 1, chance = 25 }
        }
    }
}

Config.Police = {
    enabled = true,
    alertChance = 80,

    jobs = {
        police = true,
        sheriff = true,
        state = true
    },

    alertBlip = {
        sprite = 161,
        color = 1,
        scale = 1.1,
        duration = 60,
        label = 'Civilian Robbery'
    }
}

Config.Animations = {
    player = {
        dict = 'random@shop_robbery',
        anim = 'robbery_action_b',
        flag = 49
    },

    pedHandsUp = {
        time = 10000
    }
}