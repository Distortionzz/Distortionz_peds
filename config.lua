Config = {}

Config.Script = {
    name = "Distortionz Underground",
    version = "1.3.3"
}

Config.VersionCheck = {
    enabled = true,
    resourceName = "Distortionz_peds",
    currentVersion = "1.3.3",
    githubVersionUrl = "https://raw.githubusercontent.com/Distortionzz/Distortionz_peds/main/version.json"
}

Config.Ped = {
    model = `a_m_m_skater_01`,
    coords = vector4(497.94, -629.18, 24.75, 303.06),
    scenario = "WORLD_HUMAN_SMOKING"
}

Config.Blip = {
    enabled = true,
    sprite = 280,
    color = 1,
    scale = 0.75,
    label = "Underground Contact",
    shortRange = true
}

Config.InteractionDistance = 2.0
Config.DrawDistance = 10.0

-- Payment options: "cash", "bank", "markedbills"
Config.PayAccount = "cash"

Config.Sounds = {
    deliveryCompleted = {
        enabled = true,
        soundName = "Text_Arrive_Tone",
        soundSet = "Phone_SoundSet_Default"
    }
}

Config.Reputation = {
    enabled = true,
    metadataName = "undergroundrep",

    levels = {
        { level = 0, label = "Unknown", minRep = 0 },
        { level = 1, label = "Runner", minRep = 100 },
        { level = 2, label = "Trusted", minRep = 300 },
        { level = 3, label = "Plugged In", minRep = 650 },
        { level = 4, label = "Heavy Mover", minRep = 1100 },
        { level = 5, label = "Underground VIP", minRep = 1750 }
    },

    gains = {
        sellItem = 2,
        completeDelivery = 25,
        buyBlackMarket = 5
    },

    payoutBonusPerLevel = 0.05
}

Config.Cooldowns = {
    delivery = 300,
    sell = 5,
    blackMarketBuy = 3
}

Config.PoliceAlerts = {
    enabled = true,

    jobs = {
        police = true,
        sheriff = true
    },

    startDeliveryChance = 10,
    completeDeliveryChance = 15,
    sellHighValueChance = 12,
    blackMarketBuyChance = 8,

    blip = {
        sprite = 161,
        color = 1,
        scale = 1.0,
        label = "Suspicious Activity",
        time = 45000
    }
}

Config.SellItems = {
    rolex = { label = "Golden Watch", minPrice = 300, maxPrice = 650, highValue = true },
    diamond_ring = { label = "Diamond Ring", minPrice = 450, maxPrice = 900, highValue = true },
    diamond = { label = "Diamond", minPrice = 550, maxPrice = 1100, highValue = true },
    goldchain = { label = "Golden Chain", minPrice = 175, maxPrice = 400, highValue = false },
    tenkgoldchain = { label = "10k Gold Chain", minPrice = 350, maxPrice = 700, highValue = true },
    goldbar = { label = "Gold Bar", minPrice = 1200, maxPrice = 2500, highValue = true },

    iphone = { label = "iPhone", minPrice = 250, maxPrice = 600, highValue = false },
    samsungphone = { label = "Samsung S10", minPrice = 200, maxPrice = 500, highValue = false },
    laptop = { label = "Laptop", minPrice = 350, maxPrice = 800, highValue = true },
    tablet = { label = "Tablet", minPrice = 200, maxPrice = 500, highValue = false },
    radioscanner = { label = "Radio Scanner", minPrice = 400, maxPrice = 900, highValue = true },
    pinger = { label = "Pinger", minPrice = 300, maxPrice = 700, highValue = false },
    cryptostick = { label = "Crypto Stick", minPrice = 700, maxPrice = 1600, highValue = true },

    bank_card = { label = "Bank Card", minPrice = 75, maxPrice = 160, highValue = false },
    security_card_01 = { label = "Security Card A", minPrice = 300, maxPrice = 750, highValue = true },
    security_card_02 = { label = "Security Card B", minPrice = 400, maxPrice = 950, highValue = true }
}

Config.BlackMarket = {
    enabled = true,

    items = {
        lockpick = { label = "Lockpick", price = 250, amount = 1, requiredLevel = 0 },
        advancedlockpick = { label = "Advanced Lockpick", price = 850, amount = 1, requiredLevel = 1 },
        phone = { label = "Phone", price = 700, amount = 1, requiredLevel = 1 },
        radio = { label = "Radio", price = 1200, amount = 1, requiredLevel = 2 },
        electronickit = { label = "Electronic Kit", price = 1800, amount = 1, requiredLevel = 3 },
        radioscanner = { label = "Radio Scanner", price = 2500, amount = 1, requiredLevel = 4 }
    }
}

Config.Delivery = {
    enabled = true,
    allowMultipleActiveDeliveries = false,

    completeDistance = 3.0,
    serverCompleteDistance = 12.0,

    timeLimitSeconds = 900,

    failOnDeath = true,
    removeItemOnCancel = true,
    removeItemOnFail = true,

    marker = {
        enabled = false,
        type = 2,
        scale = vector3(0.25, 0.25, 0.25),
        color = {
            r = 255,
            g = 40,
            b = 40,
            a = 140
        }
    },

    prompt = {
        usePedHeadPosition = true,
        headOffset = 0.18
    },

    blip = {
        sprite = 514,
        color = 1,
        scale = 0.85,
        label = "Drop-Off Location",
        usePersonalWaypoint = false
    },

    contactHandoff = {
        enabled = true,
        duration = 2500,
        animDict = "mp_common",
        animName = "givetake1_a",
        text = "Taking the package..."
    },

    receiverPed = {
        enabled = true,
        models = {
            `a_m_m_eastsa_02`,
            `a_m_m_business_01`,
            `a_m_y_business_02`,
            `a_m_y_stwhi_02`,
            `a_m_m_soucent_03`
        },
        scenario = "WORLD_HUMAN_STAND_MOBILE",
        returnToScenarioAfterHandoff = true,
        freeze = true,
        invincible = true
    },

    handoff = {
        enabled = true,
        duration = 2500,
        animDict = "mp_common",
        animName = "givetake1_a",
        text = "Handing off package..."
    },

    items = {
        { item = "bank_card", label = "Bank Card", minPay = 500, maxPay = 1000, requiredLevel = 0 },
        { item = "cryptostick", label = "Crypto Stick", minPay = 1200, maxPay = 2400, requiredLevel = 1 },
        { item = "iphone", label = "iPhone", minPay = 700, maxPay = 1400, requiredLevel = 0 },
        { item = "laptop", label = "Laptop", minPay = 1300, maxPay = 2800, requiredLevel = 2 },
        { item = "goldbar", label = "Gold Bar", minPay = 2500, maxPay = 5000, requiredLevel = 4 }
    },

    dropoffs = {
        vector4(1138.83, -322.4, 67.15, 7.51),
        vector4(417.38, -1832.74, 28.28, 293.21),
        vector4(130.84, -1961.07, 18.49, 227.59),
        vector4(-1004.81, -1003.13, 2.15, 26.59),
        vector4(-367.32, 192.51, 83.66, 86.0),
        vector4(244.96, 11.53, 84.1, 70.1),
        vector4(813.77, -120.92, 80.23, 343.09)
    }
}