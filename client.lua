-- client.lua
local RESOURCE_NAME = GetCurrentResourceName()

Config = Config or {}
if Config.Debug == nil then Config.Debug = true end

local dprint        = Config.dprint or function() end

local wheelEntity   = nil
local isSpinning    = false
local showCarEntity = nil
local cashierPed    = nil   -- NPC that handles chip cash-out

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function loadModel(hash)
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(hash) do
            Wait(0)
            if GetGameTimer() > timeout then
                print(("[az_luckywheel] Model load timeout for %s"):format(hash))
                return false
            end
        end
    end
    return true
end

local function help(msg)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

-- 🔔 NUI notification helper (uses slots index.html)
local function wheelNotify(data)
    if not data then return end

    SendNUIMessage({
        action     = "slots_notify",
        type       = data.type or "win",      -- win | loss | jackpot
        bet        = data.bet or 0,
        amount     = data.amount or 0,
        multiplier = data.multiplier or 0,
        details    = data.details or {}
    })
end

local function wheelNotifyText(notifyType, text)
    wheelNotify({
        type   = notifyType or "win",
        bet    = 0,
        amount = 0,
        multiplier = 0,
        details = { text or "" }
    })
end

---------------------------------------------------------------------
-- Audio bank (casino wheel sounds)
---------------------------------------------------------------------

CreateThread(function()
    if not Config.WheelPlaySound then return end
    -- harmless if it fails, it just won't play sounds
    RequestScriptAudioBank("DLC_VW_Casino_Lucky_Wheel_Sounds", false, -1)
end)

---------------------------------------------------------------------
-- Wheel spawn
---------------------------------------------------------------------

CreateThread(function()
    local model = joaat("vw_prop_vw_luckywheel_02a")
    if not loadModel(model) then return end

    local pos = Config.WheelCoords
    wheelEntity = CreateObject(model, pos.x, pos.y, pos.z, false, false, true)
    SetEntityHeading(wheelEntity, Config.WheelHeading or 0.0)
    SetModelAsNoLongerNeeded(model)

    dprint("Lucky wheel spawned at", pos.x, pos.y, pos.z)
end)

---------------------------------------------------------------------
-- Cashier NPC (for chip cash-out)
---------------------------------------------------------------------

CreateThread(function()
    if not Config.ChipNPC or not Config.ChipNPC.coords then return end

    local data  = Config.ChipNPC
    local model = data.pedModel or `s_m_y_casino_01`
    local pos   = data.coords

    if type(model) == "string" then
        model = joaat(model)
    end

    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(model) do
            Wait(0)
            if GetGameTimer() > timeout then
                print("[az_luckywheel] Failed to load chip NPC model")
                return
            end
        end
    end

    cashierPed = CreatePed(
        4, model,
        pos.x, pos.y, pos.z - 1.0, pos.w,
        false, true
    )

    SetBlockingOfNonTemporaryEvents(cashierPed, true)
    SetEntityInvincible(cashierPed, true)
    FreezeEntityPosition(cashierPed, true)

    -- idle stance
    TaskStartScenarioInPlace(cashierPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)

    SetModelAsNoLongerNeeded(model)
end)

---------------------------------------------------------------------
-- Podium / showcase vehicle
---------------------------------------------------------------------

local function deleteShowCar()
    if showCarEntity and DoesEntityExist(showCarEntity) then
        DeleteEntity(showCarEntity)
    end
    showCarEntity = nil
end

local function spawnShowCar(modelName)
    deleteShowCar()
    if not modelName or modelName == "" then return end
    if not Config.ShowCarPlatform then return end

    local pos  = Config.ShowCarPlatform
    local hash = joaat(modelName)

    if not loadModel(hash) then
        dprint("Failed to load show car model:", modelName)
        return
    end

    showCarEntity = CreateVehicle(hash, pos.x, pos.y, pos.z, pos.w, false, false)
    SetVehicleOnGroundProperly(showCarEntity)
    SetVehicleDoorsLocked(showCarEntity, 2)
    SetEntityInvincible(showCarEntity, true)
    FreezeEntityPosition(showCarEntity, true)
    SetVehicleDirtLevel(showCarEntity, 0.0)
    SetVehicleEngineOn(showCarEntity, false, true, false)
    SetModelAsNoLongerNeeded(hash)

    dprint("Showcase car spawned:", modelName)
end

RegisterNetEvent("az_luckywheel:updateShowCar", function(modelName)
    spawnShowCar(modelName)
end)

CreateThread(function()
    -- ask server which car should be on the podium when we join
    Wait(1000)
    TriggerServerEvent("az_luckywheel:requestShowCar")
end)

---------------------------------------------------------------------
-- Prize vehicle spawning (for winners)
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:spawnPrizeVehicle", function(modelName)
    local pos = Config.PrizeVehicleSpawn
    if not pos then
        dprint("PrizeVehicleSpawn not set in config.")
        return
    end

    local hash = joaat(modelName or "italirsx")
    if not loadModel(hash) then
        dprint("Failed to load prize vehicle model:", modelName)
        return
    end

    local ped = PlayerPedId()
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, pos.w or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDirtLevel(veh, 0.0)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(hash)

    dprint("Prize vehicle spawned for player:", modelName)
    -- hook your own "save owned vehicle" event here if you want
end)

---------------------------------------------------------------------
-- Spin animation (client-side rotation)
---------------------------------------------------------------------

local function spinWheelToIndex(index, cb)
    if not wheelEntity or not DoesEntityExist(wheelEntity) then
        dprint("Wheel entity missing, cannot spin")
        if cb then cb() end
        return
    end

    isSpinning = true

    -- 20 segments -> 18 degrees each
    local segmentCount = 20
    local segmentAngle = 360.0 / segmentCount

    index = index or math.random(1, segmentCount)
    local winAngle   = (index - 1) * segmentAngle
    local totalAngle = winAngle + (360.0 * 8.0) -- 8 full spins
    local halfAngle  = totalAngle / 2.0

    local speedIntCnt = 1.0
    local rollAngle   = totalAngle

    CreateThread(function()
        while speedIntCnt > 0 do
            local rot = GetEntityRotation(wheelEntity, 1)
            if rollAngle > halfAngle then
                speedIntCnt = speedIntCnt + 1.0
            else
                speedIntCnt = speedIntCnt - 1.0
                if speedIntCnt < 0.0 then
                    speedIntCnt = 0.0
                end
            end

            local rollSpeed = speedIntCnt / 10.0
            local newY      = rot.y - rollSpeed

            rollAngle = rollAngle - rollSpeed

            SetEntityHeading(wheelEntity, Config.WheelHeading or 0.0)
            SetEntityRotation(wheelEntity, 0.0, newY, Config.WheelHeading or 0.0, 2, true)

            Wait(0)
        end

        isSpinning = false
        if cb then cb() end
    end)
end

---------------------------------------------------------------------
-- Player interaction / controls (spin)
---------------------------------------------------------------------

CreateThread(function()
    local promptShown = false

    while true do
        Wait(0)

        if not wheelEntity or not DoesEntityExist(wheelEntity) then
            Wait(1000)
        else
            local ped     = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local dist    = #(pcoords - Config.WheelCoords)

            if dist < 3.0 then
                if not isSpinning then
                    help("Press ~INPUT_CONTEXT~ to spin the ~p~Lucky Wheel~s~")
                    promptShown = true
                    if IsControlJustPressed(0, 38) then -- E
                        TriggerServerEvent("az_luckywheel:requestSpin")
                    end
                end
            else
                if promptShown then
                    ClearAllHelpMessages()
                    promptShown = false
                end
                Wait(250)
            end
        end
    end
end)

---------------------------------------------------------------------
-- Cashier interaction (press E to redeem chips)
---------------------------------------------------------------------

CreateThread(function()
    if not Config.ChipNPC or not Config.ChipNPC.coords then return end

    local pos = Config.ChipNPC.coords

    while true do
        local sleep = 1000
        local ped   = PlayerPedId()
        local pPos  = GetEntityCoords(ped)
        local dist  = #(pPos - vector3(pos.x, pos.y, pos.z))

        if dist < 3.0 then
            sleep = 0

            -- simple 3D text above NPC
            local on, sx, sy = World3dToScreen2d(pos.x, pos.y, pos.z + 1.0)
            if on then
                SetTextScale(0.35, 0.35)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(255, 255, 255, 215)
                SetTextCentre(true)
                SetTextEntry("STRING")
                AddTextComponentString("Press ~INPUT_CONTEXT~ to ~g~cash out chips~s~")
                DrawText(sx, sy)
            end

            if IsControlJustPressed(0, 38) then -- E
                TriggerServerEvent("az_luckywheel:redeemChips")
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Net events from server (spin start / denied)
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:spin", function(data)
    if isSpinning then return end

    local prizeIndex = data.index or 1
    local prizeLabel = data.label or "Prize"
    local spinId     = data.spinId

    -- FIXED POSITION: snap player to stand pos + heading, but use real ground Z
    local ped     = PlayerPedId()
    local stand   = Config.PlayerStandPos
    local heading = Config.PlayerStandHeading or 0.0

    ClearPedTasksImmediately(ped)

    -- figure out real ground Z at the stand location
    local groundZ = stand.z
    local success, gz = GetGroundZFor_3dCoord(stand.x, stand.y, stand.z + 2.0, 0)
    if success then
        groundZ = gz
    end

    -- move ped to ground at stand position
    SetEntityCoordsNoOffset(ped, stand.x, stand.y, groundZ, false, false, false)
    SetEntityHeading(ped, heading)

    -- small wait to let physics settle
    Wait(100)

    -- now lock them in place for the animation
    FreezeEntityPosition(ped, true)

    local dict      = "anim_casino_a@amb@casino@games@lucky7wheel@male"
    local animEnter = "enter_right_to_baseidle"
    local animIdle  = "enter_to_armraisedidle"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end

    TaskPlayAnim(ped, dict, animEnter, 8.0, -8.0, -1, 0, 0.0, false, false, false)
    Wait(1000)
    TaskPlayAnim(ped, dict, animIdle, 8.0, -8.0, -1, 0, 0.0, false, false, false)

    -- play wheel spin sound at the wheel position
    if Config.WheelPlaySound and Config.WheelCoords then
        local p = Config.WheelCoords
        PlaySoundFromCoord(
            -1,
            "DLC_VW_LUCKY_WHEEL_SPIN",
            p.x, p.y, p.z,
            "dlc_vw_casino_lucky_wheel_sounds",
            0, 0, 0
        )
    end

    -- spin the wheel
    spinWheelToIndex(prizeIndex, function()
        FreezeEntityPosition(ped, false)

        -- 🔔 UI toast instead of GTA feed
        wheelNotifyText("win", ("Lucky Wheel: %s"):format(prizeLabel))

        TriggerServerEvent("az_luckywheel:confirmPrize", spinId)
    end)
end)

RegisterNetEvent("az_luckywheel:spinDenied", function(reason)
    local msg = "You cannot spin right now."
    if reason == "cooldown" then
        msg = "You recently spun the wheel. Please wait a bit."
    elseif reason == "not_enough" then
        msg = "You don't have enough money/chips to spin."
    elseif reason == "busy" then
        msg = "The wheel is already spinning."
    end

    -- 🔔 NUI "loss" toast
    wheelNotify({
        type       = "loss",
        bet        = 0,
        amount     = 0,
        multiplier = 0,
        details    = { msg }
    })
end)

---------------------------------------------------------------------
-- NPC reaction when chips are redeemed
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:npcReact", function()
    if not cashierPed or not DoesEntityExist(cashierPed) then return end

    CreateThread(function()
        -- stop idle
        ClearPedTasksImmediately(cashierPed)

        -- happy cheering animation / scenario
        TaskStartScenarioInPlace(cashierPed, "WORLD_HUMAN_CHEERING", 0, true)
        Wait(4000)

        -- back to idle
        ClearPedTasksImmediately(cashierPed)
        TaskStartScenarioInPlace(cashierPed, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
    end)
end)

---------------------------------------------------------------------
-- Generic notify from server (prizes, chip cash-out, etc.)
---------------------------------------------------------------------

RegisterNetEvent("az_luckywheel:notify", function(data)
    wheelNotify(data)
end)

---------------------------------------------------------------------
-- Debug: draw 3D text for segment indices (1–20)
---------------------------------------------------------------------

local function draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)
end

CreateThread(function()
    if not Config.Debug or not Config.DebugIndexLabels then return end

    local segCount  = 20
    local segAngle  = 360.0 / segCount
    local radius    = Config.DebugLabelRadius or 1.35
    local zOffset   = Config.DebugLabelZOffset or 0.05
    local angOffset = 0.0

    while true do
        Wait(0)

        if wheelEntity and DoesEntityExist(wheelEntity) then
            for i = 1, segCount do
                local angleDeg = (i - 0.5) * segAngle + angOffset
                local angleRad = math.rad(angleDeg)

                local localX = math.sin(angleRad) * radius
                local localY = 0.0
                local localZ = math.cos(angleRad) * radius

                local wx, wy, wz = table.unpack(GetOffsetFromEntityInWorldCoords(
                    wheelEntity,
                    localX,
                    localY,
                    localZ
                ))

                draw3DText(wx, wy, wz + zOffset, tostring(i))
            end
        else
            Wait(1000)
        end
    end
end)
