local RESOURCE_NAME = GetCurrentResourceName()

Config = Config or {}
local dprint = Config.dprint or function() end

local fw = exports['Az-Framework']  -- ⬅ same style as slots

local pendingSpins = {}   -- [src] = { spinId = n, prize = prizeTable }
local lastSpin    = {}    -- [src] = os.time()
local spinCounter = 0

-- current podium/showcase model (string model name)
local currentShowCarModel = Config.DefaultShowCarModel or "italirsx"

---------------------------------------------------------------------
-- Az-Framework money helpers (same pattern as slots)
---------------------------------------------------------------------

local function takeCash(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end  -- nothing to take

    local ok, err = pcall(function()
        fw:deductMoney(src, amount)
    end)

    if not ok then
        dprint(("takeCash failed for %s: %s"):format(src, tostring(err)))
        return false
    end

    dprint(("takeCash OK for %s: -%d"):format(src, amount))
    return true
end

local function giveCash(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end

    local ok, err = pcall(function()
        fw:addMoney(src, amount)
    end)

    if not ok then
        dprint(("giveCash failed for %s: %s"):format(src, tostring(err)))
        return
    end

    dprint(("giveCash OK for %s: +%d"):format(src, amount))
end

---------------------------------------------------------------------
-- Chip storage via KVP (per license)
---------------------------------------------------------------------

local function getLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == "license:" then
            return id:sub(9)
        end
    end
    return nil
end

local function chipKey(license)
    return ("chips:%s"):format(license)
end

local function getChipsByLicense(license)
    if not license then return 0 end
    local key = chipKey(license)
    -- ONLY use Int KVP to avoid your GetResourceKvpString wrapper / bad cast
    local amount = GetResourceKvpInt(key)
    return amount or 0
end

local function setChipsByLicense(license, amount)
    if not license then return end
    local key = chipKey(license)
    SetResourceKvpInt(key, math.floor(amount))
end

local function addChipsBySrc(src, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local license = getLicense(src)
    if not license then
        dprint(("addChips: no license for %d"):format(src))
        return
    end

    local old = getChipsByLicense(license)
    local new = old + amount
    setChipsByLicense(license, new)

    dprint(("Chips for %d (%s): %d -> %d"):format(src, license, old, new))
end

---------------------------------------------------------------------
-- Prize rolling
---------------------------------------------------------------------

local function rollPrize()
    local totalWeight = 0
    for _, p in ipairs(Config.Prizes) do
        totalWeight = totalWeight + (p.weight or 1)
    end

    local roll = math.random(1, totalWeight)
    local cur  = 0
    for _, p in ipairs(Config.Prizes) do
        cur = cur + (p.weight or 1)
        if roll <= cur then
            return p
        end
    end

    return Config.Prizes[1]
end

---------------------------------------------------------------------
-- Spin cost via Az-Framework
---------------------------------------------------------------------

local function tryChargeForSpin(src)
    local cost = Config.SpinCost or 0
    if cost <= 0 then
        return true
    end

    dprint(("Charging spin cost %d from %d via Az-Framework"):format(cost, src))
    local ok = takeCash(src, cost)
    if not ok then
        dprint(("Spin cost charge FAILED for %d"):format(src))
    end
    return ok
end

---------------------------------------------------------------------
-- Grant prize to player
---------------------------------------------------------------------

local function grantPrize(src, prize)
    if not prize then return end

    local typ = prize.type
    dprint(("Granting prize to %d: %s (%s)"):format(src, prize.label or "?", typ or "?"))

    if typ == "money" then
        local amount = prize.amount or 0
        giveCash(src, amount)

    elseif typ == "chips" then
        local amount = prize.amount or 0
        if amount > 0 then
            addChipsBySrc(src, amount)
        end

    elseif typ == "item" then
        -- hook your inventory here
        dprint(("Give item %s x%d to %d (implement AddItem here)"):format(
            tostring(prize.item), prize.amount or 1, src))

    elseif typ == "vehicle" then
        local model = prize.vehicle or currentShowCarModel or Config.DefaultShowCarModel or "italirsx"

        dprint(("Vehicle prize: model %s for %d – spawning at prize coords, hook into garage as needed"):format(
            tostring(model), src))

        TriggerClientEvent("az_luckywheel:spawnPrizeVehicle", src, model)

    elseif typ == "clothing" then
        dprint(("Give clothing set %s to %d"):format(tostring(prize.set), src))

    elseif typ == "nothing" then
        dprint(("Player %d landed on 'Nothing' (should not happen with your config)"):format(src))
    end

    TriggerClientEvent("chat:addMessage", src, {
        color = { 180, 120, 255 },
        multiline = true,
        args = { "Lucky Wheel", ("You received: ^5%s^7"):format(prize.label or "Unknown prize") }
    })
end

---------------------------------------------------------------------
-- Spin request / confirm
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:requestSpin", function()
    local src = source

    local now  = os.time()
    local last = lastSpin[src] or 0
    local cd   = Config.SpinCooldown or 0
    if cd > 0 and (now - last) < cd then
        TriggerClientEvent("az_luckywheel:spinDenied", src, "cooldown")
        return
    end

    if pendingSpins[src] then
        TriggerClientEvent("az_luckywheel:spinDenied", src, "busy")
        return
    end

    if not tryChargeForSpin(src) then
        TriggerClientEvent("az_luckywheel:spinDenied", src, "not_enough")
        return
    end

    local prize = rollPrize()
    local index = prize.index or 1

    spinCounter = spinCounter + 1
    local spinId = spinCounter

    pendingSpins[src] = {
        spinId = spinId,
        prize  = prize,
    }
    lastSpin[src] = now

    dprint(("Player %d spinning wheel – prize index %d (%s), spinId %d"):format(
        src, index, prize.label or "?", spinId))

    TriggerClientEvent("az_luckywheel:spin", src, {
        index  = index,
        label  = prize.label or "Prize",
        spinId = spinId
    })
end)

RegisterNetEvent("az_luckywheel:confirmPrize", function(spinId)
    local src  = source
    local pend = pendingSpins[src]
    if not pend or pend.spinId ~= spinId then
        dprint(("confirmPrize mismatch/expired for %d (spinId %s)"):format(src, tostring(spinId)))
        return
    end

    pendingSpins[src] = nil
    grantPrize(src, pend.prize)
end)

---------------------------------------------------------------------
-- Chip redemption via NPC → cash (Az-Framework)
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:redeemChips", function()
    local src = source
    local license = getLicense(src)
    if not license then
        dprint(("redeemChips: no license for %d"):format(src))
        TriggerClientEvent("chat:addMessage", src, {
            color = { 255, 50, 50 },
            args = { "Lucky Wheel", "Could not find your account ID. Try relogging." }
        })
        return
    end

    local chips = getChipsByLicense(license)
    if chips <= 0 then
        TriggerClientEvent("chat:addMessage", src, {
            color = { 255, 255, 0 },
            args = { "Lucky Wheel", "You don't have any chips to redeem." }
        })
        return
    end

    local rate = Config.ChipCashRate or 1
    local cash = math.floor(chips * rate)

    setChipsByLicense(license, 0)
    giveCash(src, cash)

    dprint(("Redeemed %d chips for %d cash for %d"):format(chips, cash, src))

    TriggerClientEvent("chat:addMessage", src, {
        color = { 120, 255, 120 },
        args = { "Lucky Wheel", ("Redeemed ^3%d^7 chips for ^2$%d^7."):format(chips, cash) }
    })
end)

---------------------------------------------------------------------
-- Podium / showcase vehicle: /luckywheelcar <model>
---------------------------------------------------------------------

RegisterCommand("luckywheelcar", function(source, args)
    local src = source

    -- Simple ACE permission; adjust if you have your own staff system
    if src ~= 0 and not IsPlayerAceAllowed(src, "az.luckywheel.admin") then
        TriggerClientEvent("chat:addMessage", src, {
            color = { 255, 50, 50 },
            args = { "Lucky Wheel", "You don't have permission to use this command." }
        })
        return
    end

    local model = args[1]
    if not model or model == "" then
        if src ~= 0 then
            TriggerClientEvent("chat:addMessage", src, {
                color = { 255, 255, 0 },
                args = { "Lucky Wheel", "Usage: /luckywheelcar <vehicleModel>" }
            })
        else
            print("[az_luckywheel] Usage: luckywheelcar <vehicleModel>")
        end
        return
    end

    currentShowCarModel = model
    dprint(("Showcase / podium car set to '%s'"):format(model))

    TriggerClientEvent("az_luckywheel:updateShowCar", -1, model)

    if src ~= 0 then
        TriggerClientEvent("chat:addMessage", src, {
            color = { 120, 255, 120 },
            args = { "Lucky Wheel", ("Showcase car set to ^2%s^7."):format(model) }
        })
    end
end, true)

---------------------------------------------------------------------
-- Sync podium car to new clients
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:requestShowCar", function()
    local src = source
    if currentShowCarModel then
        TriggerClientEvent("az_luckywheel:updateShowCar", src, currentShowCarModel)
    end
end)

---------------------------------------------------------------------
-- Clean up when player drops
---------------------------------------------------------------------

AddEventHandler("playerDropped", function()
    local src = source
    pendingSpins[src] = nil
    lastSpin[src]     = nil
end)
