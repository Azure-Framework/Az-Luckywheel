Config = Config or {}

-- Debug
Config.Debug = true
Config.DebugIndexLabels  = true
Config.DebugLabelRadius  = 1.55
Config.DebugLabelZOffset = 0.35

-- Wheel object
Config.WheelCoords  = vector3(977.97, 50.3, 73.97)
Config.WheelHeading = 327.794

-- Where the ped stands for the spin animation
Config.PlayerStandPos     = vector3(976.974, 50.331, 74.681)
Config.PlayerStandHeading = 332.747

-- Podium showcase vehicle (what players see in the casino)
Config.ShowCarPlatform = vector4(963.847, 47.632, 75.568, 201.719)

-- Where the player’s prize vehicle actually spawns
Config.PrizeVehicleSpawn = vector4(920.887, 53.165, 80.894, 330.512)



-- Play wheel spin sound?
Config.WheelPlaySound = true


-- Default model if no /luckywheelcar has been set yet
Config.DefaultShowCarModel = "italirsx"

-- CHIP → CASH exchange rate (NPC)
Config.ChipCashRate = 1        -- 1 chip = $1
Config.ChipNPC = {
    coords   = vector4(977.891, 38.230, 74.882, 38.522),
    pedModel = "s_m_y_casino_01"
}

-- Cooldown between spins per player (seconds)
Config.SpinCooldown = 60

-- Cost per spin. If you don't want a cost, keep 0.
Config.SpinCost = 0

-- 20 segments, 18 degrees each (0–19)
-- NO "nothing" entries – every index pays something.
Config.Prizes = {
    -- index  label                                 type       extra                    weight
    { index =  1, label = "$5,000 Cash",               type = "money",   amount =  5000,      weight = 40 },
    { index =  2, label = "Small Chips (1,000)",       type = "chips",   amount =  1000,      weight = 35 },
    { index =  3, label = "Medium Chips (5,000)",      type = "chips",   amount =  5000,      weight = 25 },

    { index =  5, label = "Bonus Cash ($1,000)",       type = "money",   amount =  1000,      weight = 30 },
    { index =  6, label = "$10,000 Cash",              type = "money",   amount = 10000,      weight = 25 },
    { index =  7, label = "Vehicle Token (Small)",     type = "item",    item   = "veh_token_s", amount = 1, weight = 8  },

    { index =  9, label = "Bonus Chips (2,000)",       type = "chips",   amount =  2000,      weight = 30 },
    { index = 10, label = "Big Chips (15,000)",        type = "chips",   amount = 15000,      weight = 10 },
    { index = 11, label = "$25,000 Cash",              type = "money",   amount = 25000,      weight = 8  },
    { index = 12, label = "Bonus Cash ($3,000)",       type = "money",   amount =  3000,      weight = 30 },

    { index = 14, label = "Small Cash ($2,500)",       type = "money",   amount =  2500,      weight = 40 },
    { index = 15, label = "Medium Chips (8,000)",      type = "chips",   amount =  8000,      weight = 20 },
    { index = 16, label = "Bonus Chips (4,000)",       type = "chips",   amount =  4000,      weight = 30 },

    -- 18 = JACKPOT VEHICLE – uses current podium model if vehicle is nil
    { index = 18, label = "JACKPOT VEHICLE",           type = "vehicle", vehicle = nil,       weight = 1  },

    { index = 19, label = "Big Cash ($50,000)",        type = "money",   amount = 50000,      weight = 4  },
    { index = 20, label = "Huge Chips (20,000)",       type = "chips",   amount = 20000,      weight = 30 },
}


-- SECURITY GUARDS (STATIC PEDS)
-- Add/remove/edit these to match your casino entrances, doors, etc.
Config.SecurityGuards = {
    {
        coords   = vector4(959.155, 45.402, 75.317, 118.213),
        model    = "s_m_m_highsec_01",
        scenario = "WORLD_HUMAN_GUARD_STAND",
        weapon   = "WEAPON_PISTOL"   -- set to nil for unarmed
    },
    {
        coords   = vector4(973.32, 57.80, 74.07, 240.0),
        model    = "s_m_m_highsec_02",
        scenario = "WORLD_HUMAN_GUARD_STAND",
        weapon   = "WEAPON_PISTOL"
    },
    {
        coords   = vector4(978.10, 40.85, 74.88, 330.0), -- near Chip NPC
        model    = "s_m_m_highsec_01",
        scenario = "WORLD_HUMAN_GUARD_STAND",
        weapon   = "WEAPON_PISTOL"
    },
    {
        coords   = vector4(968.260, 49.662, 75.322, 287.152), -- near Chip NPC
        model    = "s_m_m_highsec_01",
        scenario = "WORLD_HUMAN_GUARD_STAND",
        weapon   = "WEAPON_PISTOL"
    },
}

-- AMBIENT CASINO PEDS (CUSTOMERS)
Config.CasinoAmbient = {
    Enabled         = true,

    -- XYZH center used for radius spawning
    Center          = vector4(973.600, 44.953, 74.476, 328.097),
    Radius          = 25.0,   -- spawn radius around Center (X/Y/Z)
    MaxPeds         = 18,     -- max ambient peds alive at once

    -- Distance from Center where peds are cleaned up
    DespawnDistance = 140.0,

    -- How often to try to spawn new peds (ms)
    SpawnInterval   = 20000,

    -- Where to find "slot" & "bar" scenarios
    SlotArea        = vector3(981.514, 56.066, 74.476),
    BarArea         = vector3(964.081, 34.010, 74.872),

    -- Ped models used for ambient customers
    Models = {
        "s_m_y_casino_01",
        "s_f_y_casino_01",
        "a_f_y_bevhills_03",
        "a_m_y_business_01",
        "a_m_y_vinewood_01"
    },

    -- Behavior weights (the higher, the more common)
    Behaviors = {
        slots  = 45,  -- go sit / use nearest scenario (slot area)
        wander = 35,  -- wander around casino
        drink  = 20,  -- go to bar area and use drinking/party scenario
    }
}



-- Helper for server/client debug
local function dprint(...)
    if not Config.Debug then return end
    local n = select("#", ...)
    local args = {}
    for i = 1, n do
        args[i] = tostring(select(i, ...))
    end
    print(("^3[az_luckywheel]^7 %s"):format(table.concat(args, " ")))
end

Config.dprint = dprint


