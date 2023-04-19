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


menu:AddComponent(MenuLib.Label("                 Misc"), ItemFlags.FullWidth)
local mslowwalk            = menu:AddComponent(MenuLib.Slider("Speed adjsutment", 1, 200, 100))

local MinFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Min", 1, 329, 3))
local MaxFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Max", 2, 330, 2))

menu:AddComponent(MenuLib.Label("                 Anty Aim"), ItemFlags.FullWidth)
local mmVisuals         = menu:AddComponent(MenuLib.Checkbox("indicators", true))
local mmIndicator       = menu:AddComponent(MenuLib.Slider("Indicator Size", 10, 100, 50))

local RandomPitchtype   = menu:AddComponent(MenuLib.Checkbox("Jitter Pitch type", true))
local RandomToggle      = menu:AddComponent(MenuLib.Checkbox("Jitter Yaw", true))
--local Antioverlap       = menu:AddComponent(MenuLib.Checkbox("Anti Overlap", true))
local msafe_angles      = menu:AddComponent(MenuLib.Checkbox("Safe Angles", true))
local downPitch         = menu:AddComponent(MenuLib.Checkbox("Allow Down", false))
local atenemy           = menu:AddComponent(MenuLib.Checkbox("At enemy", true))

--local mdelay            = menu:AddComponent(MenuLib.Slider("Jitter Speed", 1, 100, 1))
local mHeadSize           = menu:AddComponent(MenuLib.Slider("Angle Distance", 1, 60, 30))
local Jitter_Range_Real   = menu:AddComponent(MenuLib.Slider("Jitter range Real", 30, 180, 180))


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
local Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2

local Jitter_Min_Real = -Jitter_Range_Real1
local Jitter_Max_Real = Jitter_Range_Real1

local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer
local Helpers = lnxLib.TF2.Helpers

local currentTarget = nil

-- Returns the best target (lowest fov)
---@param me WPlayer
---@return AimTarget? target
local function GetBestTarget(me)
    local players = entities.FindByClass("CTFPlayer")
    local target = nil
    local lastFov = math.huge

    local options = { -- options for aim position and field of view
    AimPos = 1,
    AimFov = 360
}

    for _, entity in pairs(players) do -- iterate through all players
        if not entity then goto continue end -- skip if entity is invalid
        if not entity:IsAlive() then goto continue end -- skip if entity is dead
        if entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then goto continue end -- skip if entity is on the same team as the local player

        -- FOV Check
        local player = WPlayer.FromEntity(entity) -- convert entity to player object
        local aimPos = player:GetHitboxPos(options.AimPos) -- get aim position from player hitbox
        local angles = Math.PositionAngles(me:GetEyePos(), aimPos) -- get angle between local player's eye position and aim position
        local fov = Math.AngleFov(angles, engine.GetViewAngles()) -- calculate field of view between aim angle and local player's view angle
        if fov > options.AimFov then goto continue end -- skip if fov is larger than the maximum allowed fov

        -- Visiblity Check
        if not Helpers.VisPos(entity, me:GetEyePos(), aimPos) then goto continue end -- skip if aim position is not visible from local player's eye position

        -- Add valid target
        if fov < lastFov then -- if fov is lower than the last fov found, this is a better target
            lastFov = fov -- update last fov value
            target = { entity = entity, pos = aimPos, angles = angles, factor = fov } -- save target information
        end
        ::continue:: -- continue to the next player
    end
    return target -- return the best target found, or nil if no valid target found
end

-- Returns the closest player
---@param me WPlayer
local function GetClosestTarget(pLocal, pLocalOrigin)
    local players = entities.FindByClass("CTFPlayer")
    local closestPlayer = nil
    local closestDistance = math.huge

    -- Loop through all players
    for _, entity in pairs(players) do
        -- Skip invalid players
        if not entity or not entity:IsAlive() or entity:GetTeamNumber() == pLocal:GetTeamNumber() then
            goto continue
        end

        -- Calculate distance to player
        local vPlayerOrigin = entity:GetAbsOrigin()
        local distance = (vPlayerOrigin - pLocalOrigin):Length()

        -- Check if player is closer than the current closest player
        if distance < closestDistance and distance <= 2000 then
            closestPlayer = entity
            closestDistance = distance
        end

        ::continue::
    end

    return closestPlayer
end

local angleTable = {}

function createAngleTable(Jitter_Min_Real, Jitter_Max_Real, dist)
    local numPoints = math.floor((Jitter_Max_Real - Jitter_Min_Real) / dist) + 1
    local stepSize = (Jitter_Max_Real - Jitter_Min_Real) / (numPoints - 1)
    for i = 1, numPoints do
        local angle = Jitter_Min_Real + (i - 1) * stepSize
        if msafe_angles:GetValue() then
            if angle ~= 90 and angle ~= -90 and angle ~= 0 then
                table.insert(angleTable, angle)
            end
        else
            table.insert(angleTable, angle)
        end
    end
end

function randomizeValue(Jitter_Min_Real, Jitter_Max_Real, dist)
    if #angleTable == 0 then
        -- if all angles have been used, regenerate the table
        createAngleTable(Jitter_Min_Real, Jitter_Max_Real, dist)
    end

    local numPoints = #angleTable
    local randomIndex = math.random(1, numPoints)
    local randomValue = angleTable[randomIndex]
    -- remove the randomly selected angle from the table and adjust the table
    table.remove(angleTable, randomIndex)

    return randomValue
end



    --[[every 2 seconds it will update
        tick_count = tick_count + 1
        if tick_count % 132 == 0 then
            --variables
        end]]

local function updateYaw(Jitter_Real, Jitter_Fake)
    if atenemy:GetValue() and currentTarget then
        
        local targetPos = currentTarget:GetAbsOrigin()
        local playerPos = entities.GetLocalPlayer():GetAbsOrigin()
        local forwardVec = engine.GetViewAngles():Forward()

        targetAngle = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
        local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
        local TargetAngle = math.floor(targetAngle - viewAngle)

        local yaw = TargetAngle + Jitter_Fake
        
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end

        yaw = math.floor(yaw)
        gui.SetValue("Anti Aim - Custom Yaw (Fake)", yaw)

        yaw = TargetAngle - jitter_Real
        
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end
        
        yaw = math.floor(yaw)
        gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)
    end
end


local function OnCreateMove(userCmd)
    local me = WPlayer.GetLocal()
    if not me then return end

    if mslowwalk:GetValue() ~= 100 then
        local slowwalk = mslowwalk:GetValue() * 0.01
        userCmd:SetForwardMove(userCmd:GetForwardMove()*slowwalk)
        userCmd:SetSideMove(userCmd:GetSideMove()*slowwalk)
        userCmd:SetUpMove(userCmd:GetUpMove()*slowwalk)
    end
    
    local Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2

    currentTarget = GetClosestTarget(me, me:GetAbsOrigin()) -- Get the best target
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
        Head_size = mHeadSize:GetValue()
        Jitter_Range_Real1 = Jitter_Range_Real:GetValue() / 2

        Jitter_Min_Real = -Jitter_Range_Real1
        Jitter_Max_Real = Jitter_Range_Real1
            if atenemy:GetValue() then
                    jitter_Real = randomizeValue(Jitter_Min_Real, Jitter_Max_Real, Head_size)

                local Number1 = math.random(1, 3)
                jitter_Fake = 0

                if Number1 == 1 then
                    jitter_Fake = 90
                elseif Number1 == 2 then
                    jitter_Fake = -90
                elseif Number1 == 3 then
                    jitter_Fake = 0
                end

                jitter_Real_Last = jitter_Real
            else
                gui.SetValue("Anti Aim - Custom Yaw (Real)", math.random(-180, 180))
            end
        
        --[[if Antioverlap:GetValue() == true then
            local YawFake = math.random(-180, 180)
            while math.abs(YawFake - gui.GetValue("Anti Aim - Custom Yaw (Real)")) <= 37 do
                YawFake = math.random(-180, 180)
            end
            gui.SetValue("Anti Aim - Custom Yaw (Fake)", YawFake)
        end]]
    end

    if atenemy:GetValue() then
        updateYaw(jitter_Real, jitter_Fake)
    end

        if RandomPitchtype:GetValue() then

            local number = math.random(1, 2)
            if downPitch == true then number = math.random(1, 4) end
    
            if number == 1 then
                gui.SetValue("Anti Aim - Pitch", 1)
            elseif number == 2 then
                gui.SetValue("Anti Aim - Pitch", 4)
              
            elseif number == 4 then
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

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end
    if not mmVisuals:GetValue() then return end

    local pLocal = entities.GetLocalPlayer()
    if not pLocal then return end
    
    draw.SetFont( myfont )
        
        local w, h = draw.GetScreenSize()
        local screenPos = { w / 2 - 15, h / 2 + 35}
        local yaw

        if targetAngle ~= nil then
            yaw = targetAngle + jitter_Real

            if targetAngle and atenemy:GetValue() then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
            end
        else
            yaw = gui.GetValue("Anti Aim - Custom Yaw (Real)")

            if targetAngle and atenemy:GetValue() then
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
            yaw = targetAngle + jitter_Fake

            if targetAngle and atenemy:GetValue() then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
            end
        else
            yaw = gui.GetValue("Anti Aim - Custom Yaw (Real)")

            if targetAngle and atenemy:GetValue() then
                direction = Vector3(math.cos(math.rad(yaw)), math.sin(math.rad(yaw)), 0)
            end
        end

        -- Real
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
