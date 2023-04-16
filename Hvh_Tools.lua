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
local menu               = MenuLib.Create("Hvh_tools", MenuFlags.AutoSize)
menu.Style.TitleBg       = { 125, 155, 255, 255 }
menu.Style.Outline       = true
menu:AddComponent(MenuLib.Label("                 Anty Aim"), ItemFlags.FullWidth)
local RandomToggle       = menu:AddComponent(MenuLib.Checkbox("Random Yaw", true))
local RandomPitchToogle  = menu:AddComponent(MenuLib.Checkbox("Random Pitch", true))
local RandomPitchtype    = menu:AddComponent(MenuLib.Checkbox("Random Pitch type", true))
local downPitch          = menu:AddComponent(MenuLib.Checkbox("Allow Down", false))
local mdelay             = menu:AddComponent(MenuLib.Slider("Speed", 1, 250, 1))
local Antioverlap        = menu:AddComponent(MenuLib.Checkbox("anti overlap", true))
local atenemy            = menu:AddComponent(MenuLib.Checkbox("at enemy", true))
local offset             = menu:AddComponent(MenuLib.Slider("offset", -180, 180, -2))
--local mmVisuals          = menu:AddComponent(MenuLib.Checkbox("Indicators", false))
local FakeLagToggle      = menu:AddComponent(MenuLib.Checkbox("Random Fake Lag", true))

local MinFakeLag         = menu:AddComponent(MenuLib.Slider("Fake Lag Min Value", 1, 329, 329))
local MaxFakeLag         = menu:AddComponent(MenuLib.Slider("Fake Lag Max Value", 2, 330, 330))

local JitterToggle       = menu:AddComponent(MenuLib.Checkbox("(Yaw) Jitter", false))
local JitterReal         = menu:AddComponent(MenuLib.Slider("Real Angle Jitter", -180, 180, 140))
local JitterFake         = menu:AddComponent(MenuLib.Slider("Fake Angle Jitter", -180, 180, 170))

local OffsetSpinToggle   = menu:AddComponent(MenuLib.Checkbox("(Yaw) Offset Spin", false))
local RealOffset         = menu:AddComponent(MenuLib.Slider("Real Angle Offset", 0, 180, 65))

local SemiSpinToggle     = menu:AddComponent(MenuLib.Checkbox("(Yaw) Semi Spin (broken)", false))
local SemiSpinOffset     = menu:AddComponent(MenuLib.Slider("Spin Angle", -179, 180, 50))
local SemiSpinRealOffset = menu:AddComponent(MenuLib.Slider("Real Angle Offset", -180, 180, 50))

--menu:AddComponent(MenuLib.Label("                 Resolver(soon)"), ItemFlags.FullWidth)
--local BruteforceYaw       = menu:AddComponent(MenuLib.Checkbox("Bruteforce Yaw", false))

tick_count               = 0
local pitch = 0





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

    local options = {
        AimPos      = 1,
        AimFov      = 360
    }

    for _, entity in pairs(players) do
        if not entity then goto continue end
        if not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then goto continue end

        -- FOV Check
        local player = WPlayer.FromEntity(entity)
        local aimPos = player:GetHitboxPos(options.AimPos)
        local angles = Math.PositionAngles(me:GetEyePos(), aimPos)
        local fov = Math.AngleFov(angles, engine.GetViewAngles())
        if fov > options.AimFov then goto continue end

        -- Visiblity Check
        if not Helpers.VisPos(entity, me:GetEyePos(), aimPos) then goto continue end

        -- Add valid target
        if fov < lastFov then
            lastFov = fov
            target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
        end
        ::continue::
    end
    return target
end

-- Returns the best target (lowest fov)
---@param me WPlayer
local function GetClosestTarget(pLocal, pLocalOrigin)
    local players = entities.FindByClass("CTFPlayer")
    local closestPlayer = nil
    local closestDistance = math.huge

    for _, entity in pairs(players) do
        if not entity or not entity:IsAlive() or entity:GetTeamNumber() == pLocal:GetTeamNumber() then
            goto continue
        end

        local vPlayerOrigin = entity:GetAbsOrigin()
        local distanceX = math.abs(vPlayerOrigin.x - pLocalOrigin.x)
        local distanceY = math.abs(vPlayerOrigin.y - pLocalOrigin.y)
        local distanceZ = math.abs(vPlayerOrigin.z - pLocalOrigin.z)
        local distance = math.sqrt(distanceX * distanceX + distanceY * distanceY + distanceZ * distanceZ)

        if distance < closestDistance and distance <= 2000 then
            closestPlayer = entity
            closestDistance = distance
        end

        ::continue::
    end

    return closestPlayer
end




local function OnCreateMove(userCmd)
    local me = WPlayer.GetLocal()
    if not me then return end
    currentTarget = GetClosestTarget(me, me:GetAbsOrigin()) -- Get the best target
    local pWeapon = me:GetPropEntity("m_hActiveWeapon")
    local AimbotTarget = GetBestTarget(me)
    --userCmd:SetViewAngles(currentTarget.angles:Unpack())



    -- replace worldtime check
    tick_count = tick_count + 1
    local yaw = nil

    if atenemy:GetValue() and currentTarget and gui.GetValue("Anti Aim - Custom Yaw (Real)") ~= yaw then
        local targetPos = currentTarget:GetAbsOrigin()
        local playerPos = entities.GetLocalPlayer():GetAbsOrigin()
        local forwardVec = engine.GetViewAngles():Forward()
        local targetAngle = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
        local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
        local yaw = math.floor(targetAngle - viewAngle) + offset:GetValue()

        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end
    
        gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)
    end
    --local angles = Math.PositionAngles(me:GetEyePos(), currentTarget.pos)
    if RandomToggle:GetValue() == true then
        if not atenemy:GetValue() then
            if tick_count % mdelay:GetValue() == 0 then -- delay
                gui.SetValue("Anti Aim - Custom Yaw (Real)", math.random(-180, 180))
            end
        end
        if tick_count % mdelay:GetValue() == 0 then -- delay
            if Antioverlap:GetValue() then
                local YawFake = math.random(-180, 180)
                while math.abs(YawFake - gui.GetValue("Anti Aim - Custom Yaw (Real)")) <= 37 do
                    YawFake = math.random(-180, 180)
                end
                gui.SetValue("Anti Aim - Custom Yaw (Fake)", YawFake)
            else
                gui.SetValue("Anti Aim - Custom Yaw (Fake)", math.random(-180, 180))
            end
        end
    end

    if RandomPitchToogle:GetValue() then
        if tick_count % mdelay:GetValue() == 0 then     -- delay
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
        --gui.SetValue("Anti Aim - Custom Pitch (Real)", math.random(-90, 90 ))s

        if FakeLagToggle:GetValue() == true then
            gui.SetValue("Fake Lag Value (MS)", math.random(MinFakeLag:GetValue(), MaxFakeLag:GetValue())) -- Untested, but should work.
        end

        if JitterToggle:GetValue() == true then
            if gui.GetValue("Anti Aim - Custom Yaw (Real)") == JitterReal.Value then
                gui.SetValue("Anti Aim - Custom Yaw (Real)", JitterFake.Value)
                gui.SetValue("Anti Aim - Custom Yaw (Fake)", JitterReal.Value)
            else
                gui.SetValue("Anti Aim - Custom Yaw (Real)", JitterReal.Value)
                gui.SetValue("Anti Aim - Custom Yaw (Fake)", JitterFake.Value)
            end

            gui.SetValue("Anti Aim - Custom Yaw (Real)", -JitterReal.Value)
            gui.SetValue("Anti Aim - Custom Yaw (Fake)", -JitterFake.Value)
        end

        if OffsetSpinToggle:GetValue() == true then
            gui.SetValue("Anti Aim - Custom Yaw (fake)", gui.GetValue("Anti Aim - Custom Yaw (fake)") + 1)

            if (gui.GetValue("Anti Aim - Custom Yaw (fake)") == 180) then
                gui.SetValue("Anti Aim - Custom Yaw (fake)", -180)
            end

            gui.SetValue("Anti Aim - Custom Yaw (real)", gui.GetValue("Anti Aim - Custom Yaw (fake)") - RealOffset.Value)
        end

        if SemiSpinToggle:GetValue() == true then
            gui.SetValue("Anti Aim - Custom Yaw (fake)", gui.GetValue("Anti Aim - Custom Yaw (fake)") + 1)

            if (gui.GetValue("Anti Aim - Custom Yaw (fake)") == SemiSpinOffset.Value) then
                gui.SetValue("Anti Aim - Custom Yaw (fake)", (SemiSpinOffset.Value - 100))
            end

            gui.SetValue("Anti Aim - Custom Yaw (real)",
                gui.GetValue("Anti Aim - Custom Yaw (fake)") - SemiSpinRealOffset.Value)
        end
    end

    --if BruteforceYaw:GetValue() then
        
    --end
    ::continue::
end

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
