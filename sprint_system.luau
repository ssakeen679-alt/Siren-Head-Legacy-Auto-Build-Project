local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionUtility_m = require(ReplicatedStorage.modules.ContextActionUtility)
local CameraShaker_m = require(ReplicatedStorage.modules.CameraShaker)
local LocalPlayer = game:GetService("Players").LocalPlayer
local v1 = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = v1:WaitForChild("Humanoid")
local HumanoidRootPart = v1:WaitForChild("HumanoidRootPart")
local v2 = Humanoid:LoadAnimation(script:WaitForChild("run"))
local Parent = script.Parent
local Bar = Parent:WaitForChild("bar")
local Back = Parent:WaitForChild("back")
local Size = Bar.Size
local CurrentCamera = workspace.CurrentCamera
local Parent_1 = Parent.Parent
local Name = Parent_1:WaitForChild("name")
local CharacterWalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
local JumpPower = Humanoid.JumpPower
local t = {
    default = { stamina = 100, drain = 9, regen = 12, multiplier = 1.5 },
    Soldier = { stamina = 150, drain = 6, regen = 15, multiplier = 1.75 }
}
local Default = t.default
local _ = CharacterWalkSpeed * Default.multiplier
local v4 = UserInputService.TouchEnabled

if v4 then
    v4 = not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
end

local v5 = false
local v6 = false
local v7 = false
local v8 = 0
local v9 = true
local t_1 = {}
local _ = Default.stamina
local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad)
_G.sprint_toggled = false
CameraShaker_m.new(Enum.RenderPriority.Camera.Value, function(arg1) -- line: 66
    -- upvalues:
    --  [1] CurrentCamera (copy)

    local v10 = CurrentCamera
    v10.CFrame *= arg1
end):Start()

if ({ siren = true, long_horse = true, cartoon_cat = true, megahorn = true })[v1.Name] then
    for _, val in next, Parent:GetChildren() do
        if val:IsA("GuiObject") then
            val.Position = val.Position + UDim2.fromScale(0, 0.07)
        end
    end

    return
end

if v1:FindFirstChild("AI") then
    Parent:Destroy()

    return
end

local t_4 = { obj = Back, prop = "BackgroundTransparency" }
local t_5 = { obj = Bar, prop = "BackgroundTransparency" }
local t_3 = { t_4, t_5 }
local g_next_1 = next
local descendants, v17 = Parent:GetDescendants()

for _, val_1 in g_next_1, descendants, v17 do
    if val_1.Name == "dirt" then
        table.insert(t_3, { obj = val_1, prop = "ImageTransparency" })
    elseif val_1:IsA("UIStroke") then
        table.insert(t_3, { obj = val_1, prop = "Transparency" })
    end
end

for _, val_2 in next, t_3 do
    val_2.shown = val_2.obj[val_2.prop]
    val_2.obj[val_2.prop] = 1
end

local function fade_bar(arg2) -- line: 129
    -- upvalues:
    --  [1] t_1 (copy)
    --  [2] t_3 (copy)
    --  [3] TweenService (copy)
    --  [4] tweenInfo (copy)

    for _, val_3 in next, t_1 do
        val_3:Cancel()
    end

    table.clear(t_1)

    for _, val_4 in next, t_3 do
        local t_8 = {}
        local v18 = arg2 and val_4.shown or 1
        local v19 = TweenService
        local Obj = val_4.obj
        local v20 = tweenInfo
        t_8[val_4.prop] = v18
        local v21 = v19:Create(Obj, v20, t_8)
        table.insert(t_1, v21)
        v21:Play()
    end
end

local _ = function() --[[ start ]] -- line: 145
    -- upvalues:
    --  [1] v2 (copy)

    _G.sprint_toggled = true

    if v2.Length > 0 and not v2.IsPlaying then
        v2:Play()
    end
end

function v17() --[[ stop ]] -- line: 154
    -- upvalues:
    --  [1] v2 (copy)

    _G.sprint_toggled = false
    v2:Stop()
end

local function mobile() -- line: 161
    -- upvalues:
    --  [1] v6 (ref)

    v6 = not v6
end

local _ = function() --[[ in_ui ]] -- line: 168
    -- upvalues:
    --  [1] Parent_1 (copy)

    local Shop = Parent_1:FindFirstChild("shop")

    return if Parent_1:FindFirstChild("menu") == nil then if Shop == nil then false else Shop.Enabled else true
end

UserInputService.InputBegan:Connect(function(input) -- line: 176
    -- upvalues:
    --  [1] v6 (ref)

    if input.KeyCode == Enum.KeyCode.ButtonL3 then
        v6 = not v6
    end
end)

repeat
    task.wait(1)
until LocalPlayer:GetAttribute("loaded") and not Parent_1:FindFirstChild("menu")

if v4 then
    ContextActionUtility_m:BindAction("Sprint", mobile, true)
    ContextActionUtility_m:SetTitle("Sprint", "Sprint")
end

local v24 = t[LocalPlayer:GetAttribute("team")] or t.default
local v25 = CharacterWalkSpeed * v24.multiplier
local Stamina_1 = v24.stamina
local v26 = Stamina_1
local _, _, _
local v30, v31, v32, v33, v34, v35, v36, v37

while true do
    local v28 = math.min(RunService.Heartbeat:Wait(), 0.1)

    if Name.Value == "" then
        if not v1:GetAttribute("frozen") then
            local Shop_1 = Parent_1:FindFirstChild("shop")

            if if Parent_1:FindFirstChild("menu") == nil then if Shop_1 ~= nil then Shop_1.Enabled else false else true then
                Humanoid.WalkSpeed = 0
                Humanoid.JumpPower = 0
            elseif Humanoid.WalkSpeed == 0 then
                Humanoid.WalkSpeed = CharacterWalkSpeed
                Humanoid.JumpPower = JumpPower
            end

            if UserInputService.KeyboardEnabled then
                v5 = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            end

            v30 = if not (HumanoidRootPart.Velocity.Magnitude < 1) then 0 else v8 + v28
            v31 = v7 or (v1:GetAttribute("frozen") or (Humanoid.Sit or (Humanoid.WalkSpeed <= 0 or (HumanoidRootPart.Anchored or CurrentCamera.CameraType == Enum.CameraType.Scriptable))))
            v32 = if v5 then not v31 and v30 < 0.35 else v6 and (not v31 and v30 < 0.35)

            if v32 and not _G.sprint_toggled then
                _G.sprint_toggled = true

                if v2.Length > 0 and not v2.IsPlaying then
                    v2:Play()
                end
            elseif not v32 and _G.sprint_toggled then
                _G.sprint_toggled = false
                v2:Stop()
            end

            if Humanoid.WalkSpeed > 0 and (v32 or Humanoid.WalkSpeed > CharacterWalkSpeed + 0.01) then
                v33 = v32 and v25 or CharacterWalkSpeed
                v34 = if not v32 then 0.3 else 0.55
                v35 = (v25 - CharacterWalkSpeed) / v34 * v28
                Humanoid.WalkSpeed = math.clamp(
                    Humanoid.WalkSpeed + math.clamp(v33 - Humanoid.WalkSpeed, -v35, v35),
                    CharacterWalkSpeed,
                    v25
                )
            end

            if v2.Length > 0 then
                v36 = if Humanoid.FloorMaterial ~= Enum.Material.Air then 1 else 0.25
                v2:AdjustSpeed(v36)
            end

            v37 = math.clamp(
                (Humanoid.WalkSpeed - CharacterWalkSpeed) / (v25 - CharacterWalkSpeed),
                0,
                1
            )

            if v32 then
                v26 -= v24.drain * v37 * v28
            elseif Stamina_1 > v26 then
                v26 += v24.regen * v28
            end

            v26 = math.clamp(v26, 0, Stamina_1)

            if v26 <= 0 then
                _ = true
                _ = false
            elseif v26 >= Stamina_1 * 0.35 then
                _ = false
            end

            Bar.Size = UDim2.fromScale(Size.X.Scale * (v26 / Stamina_1), Size.Y.Scale)

            if Stamina_1 > v26 and v9 then
                _ = false
                fade_bar(true)
                continue
            end

            if not (Stamina_1 <= v26) then
                continue
            end

            if v9 then
                continue
            end

            _ = true
            fade_bar(false)
        else
            Humanoid.WalkSpeed = 0
            Humanoid.JumpPower = 0

            if Humanoid.WalkSpeed == 0 then
                Humanoid.WalkSpeed = CharacterWalkSpeed
                Humanoid.JumpPower = JumpPower
            end

            if UserInputService.KeyboardEnabled then
                v5 = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            end

            v30 = if not (HumanoidRootPart.Velocity.Magnitude < 1) then 0 else v8 + v28
            v31 = v7 or (v1:GetAttribute("frozen") or (Humanoid.Sit or (Humanoid.WalkSpeed <= 0 or (HumanoidRootPart.Anchored or CurrentCamera.CameraType == Enum.CameraType.Scriptable))))
            v32 = if v5 then not v31 and v30 < 0.35 else v6 and (not v31 and v30 < 0.35)

            if v32 and not _G.sprint_toggled then
                _G.sprint_toggled = true

                if v2.Length > 0 and not v2.IsPlaying then
                    v2:Play()
                end
            elseif not v32 and _G.sprint_toggled then
                _G.sprint_toggled = false
                v2:Stop()
            end

            if Humanoid.WalkSpeed > 0 and (v32 or Humanoid.WalkSpeed > CharacterWalkSpeed + 0.01) then
                v33 = v32 and v25 or CharacterWalkSpeed
                v34 = if not v32 then 0.3 else 0.55
                v35 = (v25 - CharacterWalkSpeed) / v34 * v28
                Humanoid.WalkSpeed = math.clamp(
                    Humanoid.WalkSpeed + math.clamp(v33 - Humanoid.WalkSpeed, -v35, v35),
                    CharacterWalkSpeed,
                    v25
                )
            end

            if v2.Length > 0 then
                v36 = if Humanoid.FloorMaterial ~= Enum.Material.Air then 1 else 0.25
                v2:AdjustSpeed(v36)
            end

            v37 = math.clamp(
                (Humanoid.WalkSpeed - CharacterWalkSpeed) / (v25 - CharacterWalkSpeed),
                0,
                1
            )

            if v32 then
                v26 -= v24.drain * v37 * v28
            elseif Stamina_1 > v26 then
                v26 += v24.regen * v28
            end

            v26 = math.clamp(v26, 0, Stamina_1)

            if v26 <= 0 then
                _ = true
                _ = false
            elseif v26 >= Stamina_1 * 0.35 then
                _ = false
            end

            Bar.Size = UDim2.fromScale(Size.X.Scale * (v26 / Stamina_1), Size.Y.Scale)

            if Stamina_1 > v26 and v9 then
                _ = false
                fade_bar(true)
                continue
            end

            if not (Stamina_1 <= v26) then
                continue
            end

            if v9 then
                continue
            end

            _ = true
            fade_bar(false)
        end
    else
        Humanoid.WalkSpeed = 0
        Humanoid.JumpPower = 0

        if Humanoid.WalkSpeed == 0 then
            Humanoid.WalkSpeed = CharacterWalkSpeed
            Humanoid.JumpPower = JumpPower
        end

        if UserInputService.KeyboardEnabled then
            v5 = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        end

        v30 = if not (HumanoidRootPart.Velocity.Magnitude < 1) then 0 else v8 + v28
        v31 = v7 or (v1:GetAttribute("frozen") or (Humanoid.Sit or (Humanoid.WalkSpeed <= 0 or (HumanoidRootPart.Anchored or CurrentCamera.CameraType == Enum.CameraType.Scriptable))))
        v32 = if v5 then not v31 and v30 < 0.35 else v6 and (not v31 and v30 < 0.35)

        if v32 and not _G.sprint_toggled then
            _G.sprint_toggled = true

            if v2.Length > 0 and not v2.IsPlaying then
                v2:Play()
            end
        elseif not v32 and _G.sprint_toggled then
            _G.sprint_toggled = false
            v2:Stop()
        end

        if Humanoid.WalkSpeed > 0 and (v32 or Humanoid.WalkSpeed > CharacterWalkSpeed + 0.01) then
            v33 = v32 and v25 or CharacterWalkSpeed
            v34 = if not v32 then 0.3 else 0.55
            v35 = (v25 - CharacterWalkSpeed) / v34 * v28
            Humanoid.WalkSpeed = math.clamp(
                Humanoid.WalkSpeed + math.clamp(v33 - Humanoid.WalkSpeed, -v35, v35),
                CharacterWalkSpeed,
                v25
            )
        end

        if v2.Length > 0 then
            v36 = if Humanoid.FloorMaterial ~= Enum.Material.Air then 1 else 0.25
            v2:AdjustSpeed(v36)
        end

        v37 = math.clamp(
            (Humanoid.WalkSpeed - CharacterWalkSpeed) / (v25 - CharacterWalkSpeed),
            0,
            1
        )

        if v32 then
            v26 -= v24.drain * v37 * v28
        elseif Stamina_1 > v26 then
            v26 += v24.regen * v28
        end

        v26 = math.clamp(v26, 0, Stamina_1)

        if v26 <= 0 then
            _ = true
            _ = false
        elseif v26 >= Stamina_1 * 0.35 then
            _ = false
        end

        Bar.Size = UDim2.fromScale(Size.X.Scale * (v26 / Stamina_1), Size.Y.Scale)

        if Stamina_1 > v26 and v9 then
            _ = false
            fade_bar(true)
            continue
        end

        if not (Stamina_1 <= v26) then
            continue
        end

        if v9 then
            continue
        end

        _ = true
        fade_bar(false)
    end
end

