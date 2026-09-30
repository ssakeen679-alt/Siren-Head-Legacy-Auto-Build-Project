local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local v1 = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Parent = script.Parent
local Toggle = Parent:WaitForChild("toggle")
local Nv = Lighting:WaitForChild("nv")
local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad)
local v2 = UserInputService.TouchEnabled

if v2 then
    v2 = not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled
end

local v3 = false
local t = {}

local _ = function() --[[ cancel_tweens ]] -- line: 20
    -- upvalues:
    --  [1] t (copy)

    for _, val in next, t do
        val:Cancel()
    end
end

local function toggle_on() -- line: 27
    -- upvalues:
    --  [1] t (copy)
    --  [2] Toggle (copy)
    --  [3] TweenService (copy)
    --  [4] Nv (copy)
    --  [5] tweenInfo (copy)

    for _, val_1 in next, t do
        val_1:Cancel()
    end

    script:WaitForChild("toggle"):Play()
    Toggle.BackgroundColor3 = Color3.fromRGB(89, 127, 83)
    local v5 = TweenService:Create(Nv, tweenInfo, { Brightness = 0.1 })
    v5:Play()
    table.insert(t, v5)
    local v6 = TweenService:Create(Nv, tweenInfo, { Saturation = -1 })
    v6:Play()
    table.insert(t, v6)
    local v10 = TweenService:Create(Nv, tweenInfo, { TintColor = Color3.fromRGB(176, 255, 192) })
    v10:Play()
    table.insert(t, v10)
end

local function toggle_off() -- line: 47
    -- upvalues:
    --  [1] t (copy)
    --  [2] Toggle (copy)
    --  [3] TweenService (copy)
    --  [4] Nv (copy)
    --  [5] tweenInfo (copy)

    for _, val_2 in next, t do
        val_2:Cancel()
    end

    script:WaitForChild("toggle"):Play()
    Toggle.BackgroundColor3 = Color3.fromRGB(127, 62, 63)
    local v12 = TweenService:Create(Nv, tweenInfo, { Brightness = 0 })
    v12:Play()
    table.insert(t, v12)
    local v13 = TweenService:Create(Nv, tweenInfo, { Saturation = 0 })
    v13:Play()
    table.insert(t, v13)
    local v17 = TweenService:Create(Nv, tweenInfo, { TintColor = Color3.fromRGB(255, 255, 255) })
    v17:Play()
    table.insert(t, v17)
end

local _ = function() --[[ handle_toggle ]] -- line: 67
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] v3 (ref)
    --  [3] toggle_on (copy)
    --  [4] toggle_off (copy)

    if not Parent.Enabled then
        return
    end

    v3 = not v3

    if v3 then
        toggle_on()

        return
    end

    toggle_off()
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent) -- line: 85
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] v3 (ref)
    --  [3] toggle_on (copy)
    --  [4] toggle_off (copy)

    if gameProcessedEvent then
        return
    end

    if input.KeyCode == Enum.KeyCode.T then
        if not Parent.Enabled then
            return
        end

        v3 = not v3

        if v3 then
            toggle_on()

            return
        end

        toggle_off()
    end
end)
Toggle.MouseButton1Click:Connect(function() -- line: 97
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] v3 (ref)
    --  [3] toggle_on (copy)
    --  [4] toggle_off (copy)

    if not Parent.Enabled then
        return
    end

    v3 = not v3

    if v3 then
        toggle_on()

        return
    end

    toggle_off()
end)
v1.ChildAdded:Connect(function(child) -- line: 102
    -- upvalues:
    --  [1] Parent (copy)

    if child.Name == "night_vision" then
        Parent.Enabled = true
    end
end)

if v1:FindFirstChild("night_vision") then
    Parent.Enabled = true
end

Toggle:WaitForChild("TextLabel").Visible = not v2
Nv.Brightness = 0
Nv.Saturation = 0
Nv.TintColor = Color3.fromRGB(255, 255, 255)

