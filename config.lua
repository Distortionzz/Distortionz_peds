Config = {}

Config.Debug = false

Config.Script = {
    name = "Distortionz Underground",
    version = "1.4.1",
}

-- ─── Version checker ────────────────────────────────────────────────
Config.VersionCheck = {
    enabled      = true,
    checkOnStart = true,
    url          = 'https://raw.githubusercontent.com/Distortionzz/distortionz_peds/main/version.json',
}
Config.CurrentVersion = '1.4.2'

Config.Framework = {
    core = "qb-core",
    useQboxBridge = true
}

Config.Inventory = {
    resource = "ox_inventory"
}

Config.Money = {
    rewardType = "item",
    account = "cash",
    dirtyMoneyItem = "black_money",
    blackMarketPaymentType = "cash",
    blackMarketPaymentItem = "black_money"
}

Config.InteractionDistance = 2.0

Config.Ped = {
    model = `g_m_m_chigoon_02`,
    coords = vector4(707.69, -966.93, 30.41, 270.0),
    scenario = "WORLD_HUMAN_SMOKING"
}

Config.Blip = {
    enabled = true,
    sprite = 514,
    color = 1,
    scale = 0.72,
    shortRange = true,
    label = "Underground Contact"
}

Config.Target = {
    enabled = true,
    icon = "fa-solid fa-user-secret",
    label = "Talk to Underground Contact",
    distance = 2.0,

    deliveryIcon = "fa-solid fa-box",
    deliveryDistance = 2.2
}

Config.Sounds = {
    deliveryCompleted = {
        enabled = true,
        soundName = "LOCAL_PLYR_CASH_COUNTER_COMPLETE",
        soundSet = "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS"
    }
}

Config.Reputation = {
    enabled = true,
    pointsPerLevel = 500,

    levels = {
        [0] = {
            label = "Unknown",
            minRep = 0
        },
        [1] = {
            label = "Runner",
            minRep = 500
        },
        [2] = {
            label = "Trusted",
            minRep = 1000
        },
        [3] = {
            label = "Connected",
            minRep = 1500
        },
        [4] = {
            label = "Plugged In",
            minRep = 2000
        },
        [5] = {
            label = "Underworld",
            minRep = 3000
        }
    },

    gains = {
        sellLowValue = 8,
        sellHighValue = 18,
        deliveryComplete = 35,
        blackMarketPurchase = 5
    },

    losses = {
        deliveryFailed = 15,
        deliveryCancelled = 5
    }
}

Config.Cooldowns = {
    sell = 8,
    delivery = 180,
    blackmarket = 15
}

Config.SellItems = {
    rolex = {
        label = "Rolex Watch",
        minPrice = 300,
        maxPrice = 525,
        highValue = false,
        policeAlertChance = 7
    },

    diamond_ring = {
        label = "Diamond Ring",
        minPrice = 650,
        maxPrice = 1050,
        highValue = true,
        policeAlertChance = 14
    },

    goldchain = {
        label = "Gold Chain",
        minPrice = 420,
        maxPrice = 760,
        highValue = false,
        policeAlertChance = 10
    },
    ["10kgoldchain"] = {
        label = "10K Gold Chain",
        minPrice = 800,
        maxPrice = 1300,
        highValue = true,
        policeAlertChance = 16
    },

    tablet = {
        label = "Tablet",
        minPrice = 180,
        maxPrice = 340,
        highValue = false,
        policeAlertChance = 5
    },

    laptop = {
        label = "Laptop",
        minPrice = 320,
        maxPrice = 620,
        highValue = false,
        policeAlertChance = 8
    },

    cryptostick = {
        label = "Crypto Stick",
        minPrice = 900,
        maxPrice = 1600,
        highValue = true,
        policeAlertChance = 18
    }
}

Config.BlackMarket = {
    enabled = true,

    items = {
        weapon_pistol = {
            label = "Pistol",
            category = "Weapons",
            price = 15000,
            amount = 1,
            requiredLevel = 2,
            metadata = {}
        },

        weapon_snspistol = {
            label = "SNS Pistol",
            category = "Weapons",
            price = 9500,
            amount = 1,
            requiredLevel = 1,
            metadata = {}
        },

        pistol_ammo = {
            label = "Pistol Ammo",
            category = "Ammo",
            price = 650,
            amount = 3,
            requiredLevel = 1,
            metadata = {}
        },

        armor = {
            label = "Body Armor",
            category = "Gear",
            price = 4500,
            amount = 1,
            requiredLevel = 2,
            metadata = {}
        },

        lockpick = {
            label = "Lockpick",
            category = "Tools",
            price = 350,
            amount = 2,
            requiredLevel = 0,
            metadata = {}
        },

        advancedlockpick = {
            label = "Advanced Lockpick",
            category = "Tools",
            price = 1200,
            amount = 1,
            requiredLevel = 1,
            metadata = {}
        },

        thermite = {
            label = "Thermite",
            category = "Tools",
            price = 2500,
            amount = 1,
            requiredLevel = 3,
            metadata = {}
        }
    }
}

Config.Delivery = {
    enabled = true,
    itemRequired = false,
    itemRemoveOnStart = false,
    timeLimitSeconds = 900,
    completeDistance = 2.2,
    failOnDeath = true,
    removePackageOnCancel = true,
    removePackageOnFail = true,

    payout = {
        min = 1500,
        max = 3500,
        useDirtyMoney = true
    },

    difficulty = {
        label = "Medium"
    },

    items = {
        {
            item = "markedbills",
            label = "Suspicious Package",
            amount = 1,
            payoutMin = 1500,
            payoutMax = 3000,
            difficulty = "Low Risk"
        },
        {
            item = "cryptostick",
            label = "Encrypted Drive",
            amount = 1,
            payoutMin = 2600,
            payoutMax = 4600,
            difficulty = "Medium Risk"
        },
        {
            item = "electronickit",
            label = "Sealed Electronics",
            amount = 1,
            payoutMin = 3400,
            payoutMax = 6200,
            difficulty = "High Risk"
        }
    },

    dropoffs = {
        vector4(1241.42, -344.41, 69.08, 256.0),
        vector4(-1156.21, -1567.82, 4.43, 126.0),
        vector4(334.67, -1978.31, 24.17, 320.0),
        vector4(-46.02, -1758.94, 29.42, 48.0),
        vector4(964.22, -1856.89, 31.18, 175.0),
        vector4(1692.14, 3760.91, 34.70, 225.0),
        vector4(-3154.13, 1125.54, 20.86, 245.0),
        vector4(173.41, -1317.89, 29.35, 65.0),
        vector4(-709.84, -904.21, 19.21, 88.0),
        vector4(1165.91, -323.54, 69.21, 104.0)
    },

    receiverPed = {
        enabled = true,
        models = {
            `a_m_m_eastsa_02`,
            `a_m_m_soucent_03`,
            `g_m_y_mexgoon_02`,
            `g_m_y_famdnf_01`,
            `a_m_y_stwhi_02`
        },
        scenario = "WORLD_HUMAN_STAND_IMPATIENT",
        invincible = true,
        freeze = true,
        returnToScenarioAfterHandoff = true
    },

    blip = {
        sprite = 501,
        color = 1,
        scale = 0.8,
        label = "Suspicious Drop-Off",
        usePersonalWaypoint = false, -- false = only use the delivery blip route GPS; no purple personal waypoint
        clearPersonalWaypointOnStart = true -- clears any old purple waypoint when the delivery starts
    },

    marker = {
        enabled = false, -- disabled: removes the floating red marker at the delivery handoff
        type = 2,
        scale = {
            x = 0.35,
            y = 0.35,
            z = 0.35
        },
        color = {
            r = 239,
            g = 68,
            b = 68,
            a = 170
        }
    },

    contactHandoff = {
        enabled = true,
        animDict = "mp_common",
        animName = "givetake1_a",
        duration = 2200,
        text = "The contact quietly hands you the package."
    },

    handoff = {
        enabled = true,
        animDict = "mp_common",
        animName = "givetake1_a",
        duration = 2600,
        text = "Handing off the package..."
    }
}

Config.PoliceAlerts = {
    enabled = true,

    jobs = {
        police = true,
        sheriff = true,
        state = true
    },

    cooldownSeconds = 45,

    chances = {
        sell = 10,
        highValueSell = 18,
        deliveryStart = 8,
        deliveryComplete = 14,
        blackMarket = 5
    },

    messages = {
        sell = "Suspicious street sale reported.",
        deliveryStart = "Suspicious package movement reported.",
        deliveryComplete = "Suspicious handoff reported.",
        blackMarket = "Possible illegal weapon transaction reported."
    },

    blip = {
        sprite = 161,
        color = 1,
        scale = 1.15,
        label = "Suspicious Activity",
        time = 60000
    }
}

Config.Notifications = {
    titles = {
        main = "Distortionz Underground",
        delivery = "Suspicious Delivery",
        market = "Black Market"
    }
}