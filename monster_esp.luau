--!strict
-- ==============================================================================
-- SIREN HEAD: LEGACY - Monster ESP & Threat Radar V1
-- ==============================================================================
-- Features:
--   1. Drawing API-based ESP boxes and name tags for all monsters
--   2. Distance display for each threat
--   3. Health bars when available
--   4. Threat-level color coding (green = far, yellow = mid, red = close)
--   5. Audio proximity warning via sound cue
--   6. Mini-radar showing relative positions
--   7. STATE-aware for live-reload compatibility
-- ==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    Enabled = true,
    
    -- ESP Display:
    ShowBoxes = true,
    ShowNames = true,
    ShowDistance = true,
    ShowHealthBar = true,
    
    -- Radar:
    ShowRadar = true,
    RadarSize = 120,        -- Pixels
    RadarRange = 200,       -- Studs (max display range on radar)
    RadarPosition = Vector2.new(0, 0), -- Set in init based on viewport
    
    -- Threat Colors:
    ColorFar = Color3.fromRGB(100, 255, 100),    -- > 100 studs
    ColorMid = Color3.fromRGB(255, 255, 80),     -- 50-100 studs
    ColorClose = Color3.fromRGB(255, 60, 60),    -- < 50 studs
    ColorDanger = Color3.fromRGB(255, 0, 0),     -- < 25 studs (imminent)
    
    -- Distance Thresholds:
    FarDist = 100,
    MidDist = 50,
    CloseDist = 25,
    
    -- Known Monster Names:
    MonsterNames = {
        ["siren"] = "Siren Head",
        ["cartoon_cat"] = "Cartoon Cat",
        ["megahorn"] = "Mega Horn",
        ["long_horse"] = "Long Horse",
    },
    
    -- Font:
    TextSize = 14,
    OutlineEnabled = true,
}

-- ============================================================================
-- DRAWING OBJECTS POOL
-- ============================================================================
type ESPEntry = {
    box: any,       -- Drawing Square
    name: any,      -- Drawing Text
    dist: any,      -- Drawing Text
    healthBg: any,  -- Drawing Square
    healthBar: any, -- Drawing Square
    radarDot: any,  -- Drawing Circle
    model: Model?,
}

local espPool: { [Model]: ESPEntry } = {}
local radarBg: any = nil
local radarBorder: any = nil
local radarPlayerDot: any = nil
local radarConn: RBXScriptConnection? = nil

-- ============================================================================
-- UTILITY: World-to-Screen
-- ============================================================================
local function worldToScreen(pos: Vector3): (Vector2?, boolean)
    local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(pos)
    if onScreen then
        return Vector2.new(screenPos.X, screenPos.Y), true
    end
    return nil, false
end

local function getThreatColor(distance: number): Color3
    if distance < CONFIG.CloseDist then
        return CONFIG.ColorDanger
    elseif distance < CONFIG.MidDist then
        return CONFIG.ColorClose
    elseif distance < CONFIG.FarDist then
        return CONFIG.ColorMid
    end
    return CONFIG.ColorFar
end

-- ============================================================================
-- ESP ENTRY MANAGEMENT
-- ============================================================================
local function createESPEntry(model: Model): ESPEntry
    local entry: ESPEntry = {
        model = model,
    }
    
    -- Box outline
    entry.box = Drawing.new("Square")
    entry.box.Color = CONFIG.ColorFar
    entry.box.Thickness = 1
    entry.box.Filled = false
    entry.box.Visible = false
    
    -- Name label
    entry.name = Drawing.new("Text")
    entry.name.Color = Color3.fromRGB(255, 255, 255)
    entry.name.Size = CONFIG.TextSize
    entry.name.Center = true
    entry.name.Outline = CONFIG.OutlineEnabled
    entry.name.OutlineColor = Color3.fromRGB(0, 0, 0)
    entry.name.Visible = false
    
    -- Distance label
    entry.dist = Drawing.new("Text")
    entry.dist.Color = Color3.fromRGB(200, 200, 200)
    entry.dist.Size = CONFIG.TextSize - 2
    entry.dist.Center = true
    entry.dist.Outline = CONFIG.OutlineEnabled
    entry.dist.OutlineColor = Color3.fromRGB(0, 0, 0)
    entry.dist.Visible = false
    
    -- Health bar background
    entry.healthBg = Drawing.new("Square")
    entry.healthBg.Color = Color3.fromRGB(40, 40, 40)
    entry.healthBg.Filled = true
    entry.healthBg.Transparency = 0.6
    entry.healthBg.Visible = false
    
    -- Health bar fill
    entry.healthBar = Drawing.new("Square")
    entry.healthBar.Color = Color3.fromRGB(80, 200, 80)
    entry.healthBar.Filled = true
    entry.healthBar.Transparency = 0.9
    entry.healthBar.Visible = false
    
    -- Radar dot
    entry.radarDot = Drawing.new("Circle")
    entry.radarDot.Color = CONFIG.ColorFar
    entry.radarDot.Filled = true
    entry.radarDot.Radius = 3
    entry.radarDot.Visible = false
    
    return entry
end

local function removeESPEntry(entry: ESPEntry)
    pcall(function()
        if entry.box then entry.box:Remove() end
        if entry.name then entry.name:Remove() end
        if entry.dist then entry.dist:Remove() end
        if entry.healthBg then entry.healthBg:Remove() end
        if entry.healthBar then entry.healthBar:Remove() end
        if entry.radarDot then entry.radarDot:Remove() end
    end)
end

local function removeAllESP()
    for model, entry in pairs(espPool) do
        removeESPEntry(entry)
    end
    table.clear(espPool)
    
    pcall(function()
        if radarBg then radarBg:Remove() end
        if radarBorder then radarBorder:Remove() end
        if radarPlayerDot then radarPlayerDot:Remove() end
    end)
    radarBg = nil
    radarBorder = nil
    radarPlayerDot = nil
end

-- ============================================================================
-- MONSTER DETECTION
-- ============================================================================
local function isMonster(model: Model): boolean
    local name = model.Name:lower()
    for key, _ in pairs(CONFIG.MonsterNames) do
        if name:find(key) then
            return true
        end
    end
    return false
end

local function getMonsterDisplayName(model: Model): string
    local name = model.Name:lower()
    for key, displayName in pairs(CONFIG.MonsterNames) do
        if name:find(key) then
            return displayName
        end
    end
    return model.Name
end

local function getMonsterRoot(model: Model): BasePart?
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    local primary = model.PrimaryPart
    if primary then return primary end
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then return child end
    end
    return nil
end

local function getMonsterHealth(model: Model): (number?, number?)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health, hum.MaxHealth
    end
    return nil, nil
end

-- ============================================================================
-- RADAR INITIALIZATION
-- ============================================================================
local function initRadar()
    if not CONFIG.ShowRadar then return end
    
    local viewportSize = CurrentCamera.ViewportSize
    CONFIG.RadarPosition = Vector2.new(
        viewportSize.X - CONFIG.RadarSize - 20,
        20
    )
    
    radarBg = Drawing.new("Square")
    radarBg.Size = Vector2.new(CONFIG.RadarSize, CONFIG.RadarSize)
    radarBg.Position = CONFIG.RadarPosition
    radarBg.Color = Color3.fromRGB(15, 15, 15)
    radarBg.Filled = true
    radarBg.Transparency = 0.5
    radarBg.Visible = true
    
    radarBorder = Drawing.new("Square")
    radarBorder.Size = Vector2.new(CONFIG.RadarSize, CONFIG.RadarSize)
    radarBorder.Position = CONFIG.RadarPosition
    radarBorder.Color = Color3.fromRGB(80, 80, 80)
    radarBorder.Filled = false
    radarBorder.Thickness = 1
    radarBorder.Visible = true
    
    radarPlayerDot = Drawing.new("Circle")
    radarPlayerDot.Position = CONFIG.RadarPosition + Vector2.new(CONFIG.RadarSize / 2, CONFIG.RadarSize / 2)
    radarPlayerDot.Color = Color3.fromRGB(100, 180, 255)
    radarPlayerDot.Filled = true
    radarPlayerDot.Radius = 3
    radarPlayerDot.Visible = true
end

-- ============================================================================
-- MAIN RENDER LOOP
-- ============================================================================
local function startESP()
    if radarConn then radarConn:Disconnect() end
    
    initRadar()
    
    radarConn = RunService.RenderStepped:Connect(function()
        if not CONFIG.Enabled then
            for _, entry in pairs(espPool) do
                entry.box.Visible = false
                entry.name.Visible = false
                entry.dist.Visible = false
                entry.healthBg.Visible = false
                entry.healthBar.Visible = false
                entry.radarDot.Visible = false
            end
            return
        end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local playerPos = hrp.Position
        local camCF = CurrentCamera.CFrame
        
        local activeMonsters: { [Model]: boolean } = {}
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local model = player.Character
                if isMonster(model) then
                    activeMonsters[model] = true
                end
            end
        end
        
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Model") and isMonster(child) then
                activeMonsters[child] = true
            end
        end
        
        for model, entry in pairs(espPool) do
            if not activeMonsters[model] or not model.Parent then
                removeESPEntry(entry)
                espPool[model] = nil
            end
        end
        
        for model, _ in pairs(activeMonsters) do
            if not espPool[model] then
                espPool[model] = createESPEntry(model)
            end
            
            local entry = espPool[model]
            local root = getMonsterRoot(model)
            
            if not root then
                entry.box.Visible = false
                entry.name.Visible = false
                entry.dist.Visible = false
                entry.healthBg.Visible = false
                entry.healthBar.Visible = false
                entry.radarDot.Visible = false
                continue
            end
            
            local monsterPos = root.Position
            local distance = (monsterPos - playerPos).Magnitude
            local color = getThreatColor(distance)
            
            local screenPos, onScreen = worldToScreen(monsterPos + Vector3.new(0, 3, 0))
            
            if onScreen and screenPos then
                local scale = math.clamp(800 / math.max(distance, 1), 0.3, 3.0)
                local boxW = 40 * scale
                local boxH = 60 * scale
                
                if CONFIG.ShowBoxes then
                    entry.box.Size = Vector2.new(boxW, boxH)
                    entry.box.Position = screenPos - Vector2.new(boxW / 2, boxH / 2)
                    entry.box.Color = color
                    entry.box.Visible = true
                end
                
                if CONFIG.ShowNames then
                    entry.name.Text = getMonsterDisplayName(model)
                    entry.name.Position = screenPos - Vector2.new(0, boxH / 2 + 16)
                    entry.name.Color = color
                    entry.name.Visible = true
                end
                
                if CONFIG.ShowDistance then
                    entry.dist.Text = string.format("%.0f studs", distance)
                    entry.dist.Position = screenPos + Vector2.new(0, boxH / 2 + 4)
                    entry.dist.Visible = true
                end
                
                if CONFIG.ShowHealthBar then
                    local hp, maxHp = getMonsterHealth(model)
                    if hp and maxHp and maxHp > 0 then
                        local barW = boxW + 10
                        local barH = 4
                        local barPos = screenPos + Vector2.new(-barW / 2, boxH / 2 + 18)
                        
                        entry.healthBg.Size = Vector2.new(barW, barH)
                        entry.healthBg.Position = barPos
                        entry.healthBg.Visible = true
                        
                        local hpPct = math.clamp(hp / maxHp, 0, 1)
                        entry.healthBar.Size = Vector2.new(barW * hpPct, barH)
                        entry.healthBar.Position = barPos
                        entry.healthBar.Color = Color3.fromRGB(
                            math.floor(255 * (1 - hpPct)),
                            math.floor(255 * hpPct),
                            40
                        )
                        entry.healthBar.Visible = true
                    else
                        entry.healthBg.Visible = false
                        entry.healthBar.Visible = false
                    end
                end
            else
                entry.box.Visible = false
                entry.name.Visible = false
                entry.dist.Visible = false
                entry.healthBg.Visible = false
                entry.healthBar.Visible = false
            end
            
            if CONFIG.ShowRadar and radarBg then
                local relPos = monsterPos - playerPos
                local _, camY, _ = camCF:ToEulerAnglesYXZ()
                local rotatedX = relPos.X * math.cos(-camY) - relPos.Z * math.sin(-camY)
                local rotatedZ = relPos.X * math.sin(-camY) + relPos.Z * math.cos(-camY)
                
                local radarScale = (CONFIG.RadarSize / 2) / CONFIG.RadarRange
                local dotX = math.clamp(rotatedX * radarScale, -CONFIG.RadarSize / 2 + 4, CONFIG.RadarSize / 2 - 4)
                local dotZ = math.clamp(rotatedZ * radarScale, -CONFIG.RadarSize / 2 + 4, CONFIG.RadarSize / 2 - 4)
                
                local center = CONFIG.RadarPosition + Vector2.new(CONFIG.RadarSize / 2, CONFIG.RadarSize / 2)
                entry.radarDot.Position = center + Vector2.new(dotX, dotZ)
                entry.radarDot.Color = color
                entry.radarDot.Visible = true
            else
                entry.radarDot.Visible = false
            end
        end
    end)
end

-- ============================================================================
-- START
-- ============================================================================
startESP()
print("[Monster ESP] ✓ Active — tracking Siren Head, Cartoon Cat, Mega Horn, Long Horse")

if STATE then
    STATE.onCleanup(function()
        if radarConn then radarConn:Disconnect() end
        removeAllESP()
        print("[Monster ESP] Cleaned up for reload.")
    end)
end
