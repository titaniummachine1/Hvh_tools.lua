--[[
    HVh_Tools.lua for lmaobox
    Author: github.com/titaniummachine1
    credits:
    Muqa for aa help
    lmaobox for fixing cheat
    others... who inspired me
]]
---@alias AimTarget { entity : Entity, pos : Vector3, angles : EulerAngles, factor : number }

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.967, "LNXlib version is too old, please update it!")

local menuLoaded, MenuLib = pcall(require, "Menu")                               -- Load MenuLib
assert(menuLoaded, "MenuLib not found, please install it!")                      -- If not found, throw error
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!") -- If version is too old, throw error

--[[ Menu ]]
--
local menu         = MenuLib.Create("Hvh_tools", MenuFlags.AutoSize)
menu.Style.TitleBg = { 125, 155, 255, 255 }
menu.Style.Outline = true


menu:AddComponent(MenuLib.Label("                   [ Misc ]", ItemFlags.FullWidth))
local mslowwalk            = menu:AddComponent(MenuLib.Slider("Walk Speed", 1, 200, 17))
local mSKey            = menu:AddComponent(MenuLib.Keybind("Key", KEY_LSHIFT, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Seperator())

local MinFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Min", 1, 329, 3))
local MaxFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Max", 2, 330, 2))

local mLegJitter        = menu:AddComponent(MenuLib.Checkbox("Leg Jitter", true))
local mlgstrengh        = menu:AddComponent(MenuLib.Slider("Leg Jitter Strengh", 9, 47, 33))

local mmVisuals         = menu:AddComponent(MenuLib.Checkbox("indicators", true))
local mmIndicator       = menu:AddComponent(MenuLib.Slider("Indicator Size", 10, 100, 50))

menu:AddComponent(MenuLib.Label("                  [ Safety ]", ItemFlags.FullWidth))
local msafe_angles      = menu:AddComponent(MenuLib.Checkbox("Safe Angles", true))
local downPitch         = menu:AddComponent(MenuLib.Checkbox("Safe pitch", true))

menu:AddComponent(MenuLib.Label("                [ Anty Aim ]", ItemFlags.FullWidth))

local RandomPitchtype   = menu:AddComponent(MenuLib.Checkbox("Jitter Pitch type", true))
local RandomToggle      = menu:AddComponent(MenuLib.Checkbox("Jitter Yaw", true))

local mDelay            = menu:AddComponent(MenuLib.Slider("jitter Speed", 1, 66, 1))
local atenemy           = menu:AddComponent(MenuLib.Checkbox("At enemy", true))

local mHeadSize          = menu:AddComponent(MenuLib.Slider("Angle Distance", 1, 60, 37))
local Jitter_Range_Real  = menu:AddComponent(MenuLib.Slider("Jitter Range", 30, 180, 111))


--local mHeadShield        = menu:AddComponent(MenuLib.Checkbox("head Shield", true))

--menu:AddComponent(MenuLib.Label("                 Resolver(soon)"), ItemFlags.FullWidth)
--local BruteforceYaw       = menu:AddComponent(MenuLib.Checkbox("Bruteforce Yaw", false))
local tick_count                = 0
local pitch                     = 0
local targetAngle
local yaw_real = nil
local yaw_Fake = nil
local offset = 0
local jitter_Real = 0
local jitter_Fake = 0
local number = 0
local Got_Hit = false
local players = entities.FindByClass("CTFPlayer")

local TargetAngle

local Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2

local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer
local Helpers = lnxLib.TF2.Helpers

local currentTarget = nil


-- Returns the best target (lowest fov)
---@param me WPlayer
---@return AimTarget? target
local function GetBestTarget(me, pLocalOrigin, pLocal)
    -- Find all players in the game
    local players = entities.FindByClass("CTFPlayer")

    -- Initialize variables
    local target = nil
    local lastFov = math.huge
    local closestPlayer = nil
    local closestDistance = math.huge
    local options = {
        AimPos = 1,
        AimFov = 360
    }
    
    -- Loop through all players
    for _, entity in pairs(players) do
        -- Skip the local player
        if entity == pLocal then goto continue end
        
        -- Check if the player is a valid target
        local ValidTarget = entity and entity:IsAlive() and entity:GetTeamNumber() ~= me:GetTeamNumber()
        
        -- If the player is a valid target and is a scout or sniper class, continue
        if ValidTarget and (entity:GetPropInt("m_iClass") == 2 or entity:GetPropInt("m_iClass") == 8) then
            -- Calculate the distance between the player and the local player
            local distance = (entity:GetAbsOrigin() - me:GetAbsOrigin()):Length()
            
            -- If the player is closer than the closest distance so far, set them as the closest player
            if distance < closestDistance and distance < 2000 then
                closestPlayer = entity
                closestDistance = distance
            end
            
            -- Get the position of the target and the local player, as well as the forward vector of the local player's view
            local targetPos = entity:GetAbsOrigin()
            local playerPos = me:GetAbsOrigin()
            local forwardVec = engine.GetViewAngles():Forward()
            
            -- Calculate the angle between the target and the local player, as well as the angle between the local player's view and the horizontal plane
            local targetAngle1 = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
            local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
            local finalAngle = targetAngle1 - viewAngle
            
            -- Get the position of the target's hitbox that we want to aim for, as well as the angle we need to aim at to hit it
            local player = WPlayer.FromEntity(entity)
            local aimPos = player:GetHitboxPos(options.AimPos)
            local angles = Math.PositionAngles(engine.GetViewAngles():Forward(), aimPos)
            local fov = Math.AngleFov(angles, engine.GetViewAngles())
            local entityOrigin = entity:GetAbsOrigin()
            
            
            -- Define a function that checks if this target has a better FOV than the current target, and if so, sets it as the new target
            local function bestFov()
                if fov < lastFov then
                    lastFov = fov
                    target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
                end
            end
            
            -- If the target is not visible, prioritize based on FOV
            if not Helpers.VisPos(entityOrigin, me:GetEyePos(), aimPos) then
                bestFov()
            -- If the closest player is within 250 units, prioritize them over FOV
            elseif closestDistance <= 250 then
                target = closestPlayer
            -- Otherwise, prioritize based on FOV
            else
                bestFov()
            end
        end
        -- Continue to the next player
        ::continue::
    end

    if target == nil then return nil end
    return target
end


local function damageLogger(event)

    if (event:GetName() == 'player_hurt' ) then

        local localPlayer = entities.GetLocalPlayer();
        local victim = entities.GetByUserID(event:GetInt("attacker"))
        local health = event:GetInt("health")
        local attacker = entities.GetByUserID(event:GetInt("userid"))
        local damage = event:GetInt("damageamount")

        if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then
            return
        end

        --print("hit by " ..  victim:GetName() .. " or ID " .. victim:GetIndex())
    end
    Got_Hit = true
end

callbacks.Register("FireGameEvent", "exampledamageLogger", damageLogger)

local angleTable = {}

-- initialize angleTable and evaluationTable
local evaluationTable = {}

function createAngleTable(Jitter_Min_Real, Jitter_Max_Real, dist)
    local numPoints = math.floor((Jitter_Max_Real - Jitter_Min_Real) / dist) + 1
    local stepSize = (Jitter_Max_Real - Jitter_Min_Real) / (numPoints - 1)
    for i = 1, numPoints do
        local angle = Jitter_Min_Real + (i - 1) * stepSize
        local evaluation = 1 -- initialize evaluation to 1
        if msafe_angles:GetValue() then
            if angle ~= 90 and angle ~= -90 and angle ~= 0 and angle ~= 180 then
                table.insert(angleTable, angle)
                table.insert(evaluationTable, evaluation)
            end
        else
            evaluation = 0
            table.insert(angleTable, angle)
            table.insert(evaluationTable, evaluation)
        end
    end
end

function randomizeValue(jitterMin, jitterMax, dist, gotHit)
    if #angleTable == 0 then
        -- if all angles have been used, regenerate the table
        createAngleTable(jitterMin, jitterMax, dist)
    end

    -- update evaluationTable based on whether I got hit or not
    if gotHit then
        for i = 1, #evaluationTable do
            if evaluationTable[i] < 1 then
                evaluationTable[i] = evaluationTable[i] + 0.1
            elseif evaluationTable[i] > 1 then
                evaluationTable[i] = evaluationTable[i] - 0.1
            end
            if i == #evaluationTable then
                evaluationTable[i] = evaluationTable[i] - 0.1
            end
        end
    end

    -- sort angleTable by evaluationTable in descending order
    local sortedTable = {}
    for i = 1, #angleTable do
        sortedTable[i] = { angle = angleTable[i], evaluation = evaluationTable[i] }
    end
    table.sort(sortedTable, function(a, b) return a.evaluation > b.evaluation end)

    -- find the highest rated angles and randomize between them
    local highestRated = {}
    local highestRating = sortedTable[1].evaluation
    for i = 1, #sortedTable do
        if sortedTable[i].evaluation == highestRating then
            table.insert(highestRated, sortedTable[i].angle)
        else
            break
        end
    end

    local randomIndex = math.random(1, #highestRated)
    local randomValue = highestRated[randomIndex]

    -- update the evaluation of the  selected angle
    if gotHit then
        for i = 1, #angleTable do
            if angleTable[i] == randomValue then
                evaluationTable[i] = 2.0
            else
                evaluationTable[i] = evaluationTable[i] - 0.1
            end
        end
    else
        for i = 1, #angleTable do
            if angleTable[i] == randomValue then
                evaluationTable[i] = 2.0
                break
            end
        end
    end

    -- remove the selected angle from angleTable and evaluationTable
    for i = 1, #angleTable do
        if angleTable[i] == randomValue then
            table.remove(angleTable, i)
            table.remove(evaluationTable, i)
            break
        end
    end

    return randomValue
end






    --[[every 2 seconds it will update
        tick_count = tick_count + 1
        if tick_count % 132 == 0 then
            --variables
        end]]

local function updateYaw(Jitter_Real, Jitter_Fake)
    if currentTarget then
        local targetPos = currentTarget
    if targetPos == nil then goto continue end
    
        local playerPos = entities.GetLocalPlayer():GetAbsOrigin()
        local forwardVec = engine.GetViewAngles():Forward()

        targetAngle = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
        local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
        TargetAngle = math.floor(targetAngle - viewAngle)

        local yaw
        if not atenemy:GetValue() then
            yaw = Jitter_Fake
        else
            yaw = TargetAngle + Jitter_Fake
        end
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end

        Jitter_Fake1 = yaw - TargetAngle

        yaw = math.floor(yaw)
        
        gui.SetValue("Anti Aim - Custom Yaw (Fake)", yaw)

    
        if not atenemy then
            yaw = jitter_Real
        else
            yaw = TargetAngle - jitter_Real
        end
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end
        Jitter_Real1 = yaw - TargetAngle
        yaw = math.floor(yaw)
        gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)
    end
    ::continue::
end

-- OnTickUpdate
local function OnCreateMove(userCmd)
    local me = WPlayer.GetLocal()
    local pLocal = entities.GetLocalPlayer()
    if not pLocal then return end
    if not pLocal:IsAlive() then return end

    local pLocalOrigin = pLocal:GetAbsOrigin() + Vector3(0, 0, 75)

    local Jitter_Min_Real = -Jitter_Range_Real1
    local Jitter_Max_Real = Jitter_Range_Real1
    
    --pLocal:GetHitboxes()

    if mslowwalk:GetValue() ~= 100 and input.IsButtonDown(mSKey:GetValue()) then
        local slowwalk = mslowwalk:GetValue() * 0.01
        userCmd:SetForwardMove(userCmd:GetForwardMove()*slowwalk)
        userCmd:SetSideMove(userCmd:GetSideMove()*slowwalk)
        userCmd:SetUpMove(userCmd:GetUpMove()*slowwalk)
    end
    
    if userCmd.command_number % mDelay:GetValue() == 0 then                         -- Check if the command number is even. (Potentially inconsistent, but it works).
        updateYaw(jitter_Real, jitter_Fake)                                      -- Cycle between moving left and right   
    end

    --[[ Leg Jitter ]]-- (Messes with certain idle animations. See scout with mad milk / spycrab for a good example)
     if mLegJitter:GetValue() == true then                                -- If Leg Jitter is enabled,
        local vVelocity  = pLocal:EstimateAbsVelocity()
        if (userCmd.sidemove == 0) then  -- Check if we not currently moving 
            if userCmd.command_number % 2 == 0 then                         -- Check if the command number is even. (Potentially inconsistent, but it works).
                userCmd:SetSideMove(mlgstrengh:GetValue())
            else
                userCmd:SetSideMove(-mlgstrengh:GetValue())
            end
        elseif (userCmd.forwardmove == 0) then
            if userCmd.command_number % 2 == 0 then                         -- Check if the command number is even. (Potentially inconsistent, but it works).
                userCmd:SetForwardMove(mlgstrengh:GetValue())
            else
                userCmd:SetForwardMove(-mlgstrengh:GetValue())
            end
        end
    end

    Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2
    local currentTarget1 = GetBestTarget(me, pLocalOrigin) --GetClosestTarget(me, me:GetAbsOrigin()) -- Get the best target
        if #players > 0 and currentTarget1 then
            currentTarget = currentTarget1.entity:GetAbsOrigin()
        else
            currentTarget = pLocal:GetAbsOrigin()
        end
    local pWeapon = me:GetPropEntity("m_hActiveWeapon")
    local AimbotTarget = GetBestTarget(me)
    --userCmd:SetViewAngles(currentTarget.angles:Unpack())
    if MinFakeLag:GetValue() < MaxFakeLag:GetValue() then
        gui.SetValue("Fake Lag Value (MS)", math.random(MinFakeLag:GetValue(), MaxFakeLag:GetValue())) -- Untested, but should work.
    end

    -- replace worldtime check
    --tick_count = tick_count + 1
    --gui.GetValue("Anti Aim - Custom Yaw (Real)") ~= yaw_real

    --local angles = Math.PositionAngles(me:GetEyePos(), currentTarget.pos)
    if RandomToggle:GetValue() == true then
        local Head_size = mHeadSize:GetValue()
        Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2

        Jitter_Min_Real = -Jitter_Range_Real1
        Jitter_Max_Real = Jitter_Range_Real1
            if atenemy:GetValue() then
                jitter_Real = randomizeValue(Jitter_Min_Real, Jitter_Max_Real, Head_size)
                jitter_real1 = jitter_Real

                local Number1 = math.random(1, 3)
                jitter_Fake = 180
                jitter_Fake = jitter_Fake + Number1 * 90
               
            else
                jitter_Real = randomizeValue(Jitter_Min_Real * 2, Jitter_Max_Real * 2, Head_size)
                jitter_real1 = jitter_Real
                --gui.SetValue("Anti Aim - Custom Yaw (Real)", jitter_Real)
                

                local Number1 = math.random(1, 4)
                jitter_Fake = 180
                jitter_Fake = jitter_Fake + Number1 * 90
                
            end
            jitter_Real_Last = jitter_Real
        --[[if Antioverlap:GetValue() == true then
            local YawFake = math.random(-180, 180)
            while math.abs(YawFake - gui.GetValue("Anti Aim - Custom Yaw (Real)")) <= 37 do
                YawFake = math.random(-180, 180)
            end
            gui.SetValue("Anti Aim - Custom Yaw (Fake)", YawFake)
        end]]
    end
    if RandomPitchtype:GetValue() then
        local min = 1
        local max = 4

        -- TF_CLASS_SNIPER = 2,
        if downPitch:GetValue() == true then
            min = 1
            max = 2
        else
            min = 1
            max = 4
        end

        --[[    TF_CLASS_SCOUT = 1,

        if downPitch:GetValue() == true then
             min = 3
            max = 4
        else
            min = 1
            max = 2
        end

            TF_CLASS_SOLDIER = 3,
        if class  TF_CLASS_SOLDIER = 3,
            min = 1
            max = 2
        end

            -- TF_CLASS_DEMOMAN = 4,
        if downPitch:GetValue() == true then
            min = 1
            max = 2
        else
            min = 1
            max = 4
        end

            --TF_CLASS_MEDIC = 5,
         if downPitch:GetValue() == true then
            min = 3
            max = 4
        else
            min = 1
            max = 2
        end

            -- TF_CLASS_HEAVYWEAPONS = 6,
        if downPitch:GetValue() == true then
            min = 1
            max = 2
        else
            min = 1
            max = 4
        end

                TF_CLASS_PYRO = 7,
        if downPitch:GetValue() == true then
            min = 3
            max = 4
        else
            min = 1
            max = 2
        end

        if TF_CLASS_SPY = 8,
            min = 1
            max = 2
        
            min = 1
            max = 4
        end

            --TF_CLASS_ENGINEER = 9,
        if downPitch:GetValue() == true then
            min = 3
            max = 4
        else
            min = 1
            max = 2
        end
        ]]

        number = math.random(min, max)
        if number == 1 then
            gui.SetValue("Anti Aim - Pitch", 1)
        elseif number == 2 then
            gui.SetValue("Anti Aim - Pitch", 4)
        elseif number == 3 then
            gui.SetValue("Anti Aim - Pitch", 2)
        else
            gui.SetValue("Anti Aim - Pitch", 3)
        end
    else
        gui.SetValue("Anti Aim - Pitch", 1)
    end
end

    --gui.SetValue("Anti Aim - Custom Pitch (Real)", math.random(-90, 90 ))s

    --[[if mHeadShield:GetValue() then
            if userCmd:GetButtons(userCmd.buttons | IN_ZOOM) then
                offset1 = offset:GetValue() - 25
            elseif userCmd:GetButtons(userCmd.buttons | ~IN_ZOOM) then
                offset1 = offset:GetValue() - 7
            end

        end]]
    --if BruteforceYaw:GetValue() then

    --end
  

local myfont = draw.CreateFont("Verdana", 16, 800) -- Create a font for doDraw
local direction = Vector3(0, 0, 0)

local function OnDraw()
    if not mmVisuals:GetValue() then return end -- if not enabled return
    if engine.Con_IsVisible() or engine.IsGameUIVisible() then -- if in menus return
        return
    end

    local pLocal = entities.GetLocalPlayer()
    if not pLocal:IsAlive() then return end -- if not alive return
    
    draw.SetFont( myfont )
        
        local w, h = draw.GetScreenSize()
        local screenPos = { w / 2 - 15, h / 2 + 35}
        local yaw

        if targetAngle ~= nil then
            if not atenemy then
                yaw = Jitter_Real1
            else
                yaw = targetAngle + Jitter_Real1
            end
            
            if targetAngle then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
            end
        else
            yaw = gui.GetValue("Anti Aim - Custom Yaw (Real)")

            if targetAngle then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
            end
        end

        local center = pLocal:GetAbsOrigin()
        local range = mmIndicator:GetValue() -- Adjust the range of the line as needed
        
        -- Real
        draw.Color( 81, 255, 54, 255 )
        screenPos = client.WorldToScreen(center)
        if screenPos ~= nil then
            local endPoint = center + direction * range
            local screenPos1 = client.WorldToScreen(endPoint)
            if screenPos1 ~= nil then
                draw.Line(screenPos[1], screenPos[2], screenPos1[1], screenPos1[2])
            end
        end
        
        if targetAngle ~= nil then
            
            if not atenemy then
                yaw = Jitter_Fake1
            else
                yaw = targetAngle + Jitter_Fake1
            end

            if targetAngle then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
            end
        else
            yaw = gui.GetValue("Anti Aim - Custom Yaw (Real)")

            if targetAngle then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0) + yaw_public_real
            end
        end

        -- fake
        draw.Color( 255, 0, 0, 255 )
        screenPos = client.WorldToScreen(center)
        if screenPos ~= nil then
            local endPoint = center + direction * range
            local screenPos1 = client.WorldToScreen(endPoint)
            if screenPos1 ~= nil then
                draw.Line(screenPos[1], screenPos[2], screenPos1[1], screenPos1[2])
            end
        end
    end

--[[ Remove the menu when unloaded ]]
--
local function OnUnload()                                -- Called when the script is unloaded
    MenuLib.RemoveMenu(menu)                             -- Remove the menu
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
callbacks.Unregister("Unload", "MCT_Unload")         -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "LNX.Aimbot.Draw")

callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)
callbacks.Register("Unload", "MCT_Unload", OnUnload) -- Register the "Unload" callback
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)

--[[local function Draw_aa()
gui.SetValue("Anti Aim - Custom Yaw (Real)", math.random(-180, 180 ))
gui.SetValue("Anti Aim - Custom Yaw (Fake)", math.random(-180, 180 ))
gui.SetValue("Anti Aim - Custom Pitch (Real)", math.random(-90, 90 ))
end]]
--callbacks.Register( "Draw", "Draw_aa", Draw_aa )
