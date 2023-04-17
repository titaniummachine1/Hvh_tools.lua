--[[local function Draw_aa()
gui.SetValue("Anti Aim - Custom Yaw (Real)", math.random(-180, 180 ))
gui.SetValue("Anti Aim - Custom Yaw (Fake)", math.random(-180, 180 ))
gui.SetValue("Anti Aim - Custom Pitch (Real)", math.random(-90, 90 ))
end]]
--callbacks.Register( "Draw", "Draw_aa", Draw_aa )

--[[
    HVh_Tools for lmaobox
    Author: github.com/titaniummachine1
    credits for Muqa for aa help
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
menu:AddComponent(MenuLib.Label("                 Anty Aim"), ItemFlags.FullWidth)
local RandomToggle      = menu:AddComponent(MenuLib.Checkbox("Jitter Yaw", true))
local RandomPitchToogle = menu:AddComponent(MenuLib.Checkbox("Jitter Pitch", true))
local RandomPitchtype   = menu:AddComponent(MenuLib.Checkbox("Random Pitch type", true))
local downPitch         = menu:AddComponent(MenuLib.Checkbox("Allow Down", false))
local Antioverlap       = menu:AddComponent(MenuLib.Checkbox("anti Overlap", true))
local atenemy           = menu:AddComponent(MenuLib.Checkbox("At enemy", true))
local mdelay             = menu:AddComponent(MenuLib.Slider("Static Speed", 1, 200, 10))
--local mHeadShield        = menu:AddComponent(MenuLib.Checkbox("head Shield", true))
local moffset_Real      = menu:AddComponent(MenuLib.Slider("offset Real", -90, 90, 0))
local offset_fov_Real   = menu:AddComponent(MenuLib.Slider("Jitter range Real", 0, 90, 90))
local moffset_Fake      = menu:AddComponent(MenuLib.Slider("offset Fake", -90, 90, 0))
local offset_fov_Fake   = menu:AddComponent(MenuLib.Slider("Jitter range Fake", 0, 90, 90))

local FakeLagToggle     = menu:AddComponent(MenuLib.Checkbox("Random Fake Lag", true))

local MinFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Min Value", 1, 329, 190))
local MaxFakeLag        = menu:AddComponent(MenuLib.Slider("Fake Lag Max Value", 2, 330, 330))
--menu:AddComponent(MenuLib.Label("                 Resolver(soon)"), ItemFlags.FullWidth)
--local BruteforceYaw       = menu:AddComponent(MenuLib.Checkbox("Bruteforce Yaw", false))
tick_count                = 0
    local delay = mdelay:GetValue()
local pitch               = 0
local offset_Jitter_Range_Real = offset_fov_Real:GetValue() / 2
local offset_Jitter_Range_Fake = offset_fov_Fake:GetValue() / 2

local Jitter_Min_Real = -offset_Jitter_Range_Real
local Jitter_Max_Real = offset_Jitter_Range_Real
local Jitter_Min_Fake = -offset_Jitter_Range_Fake
local Jitter_Max_Fake = offset_Jitter_Range_Fake

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

function randomizeValue(minVal, maxVal, dist)
    local numPoints = math.floor((maxVal - minVal) / dist) + 1
    local randomValue = math.random(-numPoints, numPoints) * dist
    return randomValue
  end  

local function OnCreateMove(userCmd)
    local me = WPlayer.GetLocal()
    if not me then return end
    currentTarget = GetClosestTarget(me, me:GetAbsOrigin()) -- Get the best target
    local pWeapon = me:GetPropEntity("m_hActiveWeapon")
    local AimbotTarget = GetBestTarget(me)
    --userCmd:SetViewAngles(currentTarget.angles:Unpack())

    -- replace worldtime check
    --tick_count = tick_count + 1
    local yaw_real = nil
    local yaw_Fake = nil

    --gui.GetValue("Anti Aim - Custom Yaw (Real)") ~= yaw_real
    if FakeLagToggle:GetValue() == true then
        gui.SetValue("Fake Lag Value (MS)", math.random(MinFakeLag:GetValue(), MaxFakeLag:GetValue())) -- Untested, but should work.
    end

    if atenemy:GetValue() and currentTarget and RandomToggle:GetValue() == true then
        local targetPos = currentTarget:GetAbsOrigin()
        local playerPos = entities.GetLocalPlayer():GetAbsOrigin()
        local forwardVec = engine.GetViewAngles():Forward()
        local targetAngle = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
        local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
        
        local offset_Real = moffset_Real:GetValue()
        local offset_Fake = moffset_Fake:GetValue()
        local pointDist   = 30

        local jitter_Real = gui.SetValue("Anti Aim - Custom Yaw (Real)", randomizeValue(Jitter_Min_Fake, Jitter_Max_Fake, pointDist))
        local yaw = math.floor(targetAngle - viewAngle) + offset_Real + jitter_Real
        
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end
        
        gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)
        
        local jitter_Fake = gui.SetValue("Anti Aim - Custom Yaw (Real)", randomizeValue(Jitter_Min_Fake, Jitter_Max_Fake, pointDist))
        yaw = math.floor(targetAngle - viewAngle) + offset_Fake - jitter_Fake
        
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end
        
        gui.SetValue("Anti Aim - Custom Yaw (Fake)", yaw)
    end
    if tick_count % delay == 0 then     -- delay
    --local angles = Math.PositionAngles(me:GetEyePos(), currentTarget.pos)
    if RandomToggle:GetValue() == true then
            if not atenemy:GetValue() then
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
    if RandomPitchToogle:GetValue() then
        --[[if FakeAngle == RealAngle then
                RealAngle = somethingElse
                end]]
        if downPitch:GetValue() then
            pitch = math.random(-65, 90)
        else
            pitch = math.random(65, 90)
        end
        if pitch == gui.GetValue("Anti Aim - Custom Pitch (Real)") then pitch = pitch end
    
        if RandomPitchtype:GetValue() then
            local number = math.random(1, 3)
            if downPitch == true then number = math.random(1, 5) end
    
            if number == 1 then
                gui.SetValue("Anti Aim - Pitch", 1)
            elseif number == 2 then
                gui.SetValue("Anti Aim - Pitch", 4)
            elseif number == 3 then
                if not downPitch:GetValue() then pitch = -pitch end
                gui.SetValue("Anti Aim - Pitch", "Custom")
                gui.SetValue("Anti Aim - Custom Pitch (Real)", pitch)
            elseif number == 4 then
                gui.SetValue("Anti Aim - Pitch", 2)
            else
                gui.SetValue("Anti Aim - Pitch", 3)
            end
        else
            if not downPitch:GetValue() then pitch = -pitch end
            gui.SetValue("Anti Aim - Pitch", "Custom")
            gui.SetValue("Anti Aim - Custom Pitch (Real)", pitch)
        end
    end
end
::continue::
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
local function OnDraw()
    --[[if not mmVisuals:GetValue() then return end
    if not currentTarget then return end

    local me = WPlayer.GetLocal()
    if not me then return end
    draw.SetFont( myfont )
        draw.Color( 255, 255, 255, 255 )
        local w, h = draw.GetScreenSize()
        local screenPos = { w / 2 - 15, h / 2 + 35}

        local screenPos = client.WorldToScreen(me:GetAbsOrigin())
        if screenPos ~= nil then
            local direction = Vector3(math.cos(math.rad(angle)), math.sin(math.rad(angle)), 0)
            local endPoint = me:GetAbsOrigin() + direction * 100 -- Adjust the length of the line as needed
            local screenPos1 = client.WorldToScreen(endPoint)
            if screenPos1 ~= nil then
                draw.Line(screenPos[1], screenPos[2], screenPos1[1], screenPos1[2])
            end
        end]]
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
