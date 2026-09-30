--!strict
-- ==============================================================================
-- SIREN HEAD: LEGACY - Auto-Loot & Resource Farmer V1
-- ==============================================================================
-- Automates the scavenging loop:
--   1. Finds all loot crates (workspace.crates) and berry bushes (workspace.harvest)
--   2. Pathfinds to nearest unlooted resource
--   3. Triggers interaction via proximity prompt / stomp remote
--   4. Collects money vaults when in range
--   5. STATE-aware for live-reload
-- ==============================================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    Enabled = true,
    
    -- What to farm:
    FarmCrates = true,
    FarmBerries = true,
    FarmVaults = true,
    
    -- Movement:
    TeleportMode = true,         -- true = instant teleport, false = walk
    TeleportHeight = 5.0,       -- Hover above ground when teleporting
    InteractionDelay = 1.2,     -- Wait time after each interaction (seconds)
    TravelDelay = 0.15,         -- Delay between teleport hops
    
    -- Safety:
    SafeHealthThreshold = 30,   -- Pause farming if health drops below this
    MonsterProximityCheck = true, -- Pause if monster is within range
    MonsterDangerRange = 40,    -- Studs
    
    -- UI:
    ShowProgress = true,
}

-- ============================================================================
-- MONSTER NAMES (for safety checks)
-- ============================================================================
local MONSTER_NAMES = {
    siren = true,
    cartoon_cat = true,
    megahorn = true,
    long_horse = true,
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function getCharacter(): (Model?, BasePart?, Humanoid?)
    local char = LocalPlayer.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil, nil, nil end
    return char, hrp :: BasePart, hum
end

local function isMonsterNearby(playerPos: Vector3): boolean
    if not CONFIG.MonsterProximityCheck then return false end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local name = player.Character.Name:lower()
            for key, _ in pairs(MONSTER_NAMES) do
                if name:find(key) then
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root and root:IsA("BasePart") then
                        if (root.Position - playerPos).Magnitude < CONFIG.MonsterDangerRange then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") then
            local name = child.Name:lower()
            for key, _ in pairs(MONSTER_NAMES) do
                if name:find(key) then
                    local root = child:FindFirstChild("HumanoidRootPart")
                    if root and root:IsA("BasePart") then
                        if (root.Position - playerPos).Magnitude < CONFIG.MonsterDangerRange then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

local function teleportTo(pos: Vector3)
    local _, hrp, _ = getCharacter()
    if not hrp then return end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, CONFIG.TeleportHeight, 0))
    task.wait(CONFIG.TravelDelay)
end

-- ============================================================================
-- RESOURCE DISCOVERY
-- ============================================================================
type Resource = {
    instance: Instance,
    position: Vector3,
    kind: string, -- "crate" | "berry" | "vault"
}

local function discoverResources(): { Resource }
    local resources: { Resource } = {}
    
    if CONFIG.FarmCrates then
        local cratesFolder = Workspace:FindFirstChild("crates")
        if cratesFolder then
            for _, crate in ipairs(cratesFolder:GetChildren()) do
                if crate:IsA("Model") or crate:IsA("BasePart") then
                    local pos: Vector3
                    if crate:IsA("Model") then
                        pos = crate.PrimaryPart and crate.PrimaryPart.Position or crate:GetPivot().Position
                    else
                        pos = crate.Position
                    end
                    table.insert(resources, {
                        instance = crate,
                        position = pos,
                        kind = "crate",
                    })
                end
            end
        end
    end
    
    if CONFIG.FarmBerries then
        local harvestFolder = Workspace:FindFirstChild("harvest")
        if harvestFolder then
            local berryFolder = harvestFolder:FindFirstChild("berry")
            if berryFolder then
                for _, berry in ipairs(berryFolder:GetChildren()) do
                    if berry:IsA("Model") or berry:IsA("BasePart") then
                        local pos: Vector3
                        if berry:IsA("Model") then
                            pos = berry.PrimaryPart and berry.PrimaryPart.Position or berry:GetPivot().Position
                        else
                            pos = berry.Position
                        end
                        table.insert(resources, {
                            instance = berry,
                            position = pos,
                            kind = "berry",
                        })
                    end
                end
            end
        end
    end
    
    if CONFIG.FarmVaults then
        local moneyFolder = Workspace:FindFirstChild("money")
        if moneyFolder then
            for _, vault in ipairs(moneyFolder:GetChildren()) do
                if vault:IsA("Model") or vault:IsA("BasePart") then
                    local pos: Vector3
                    if vault:IsA("Model") then
                        pos = vault.PrimaryPart and vault.PrimaryPart.Position or vault:GetPivot().Position
                    else
                        pos = vault.Position
                    end
                    table.insert(resources, {
                        instance = vault,
                        position = pos,
                        kind = "vault",
                    })
                end
            end
        end
    end
    
    return resources
end

-- ============================================================================
-- INTERACTION
-- ============================================================================
local function interactWithResource(resource: Resource): boolean
    local instance = resource.instance
    if not instance.Parent then return false end
    
    local prompts = {}
    if instance:IsA("Model") then
        for _, desc in ipairs(instance:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                table.insert(prompts, desc)
            end
        end
    elseif instance:IsA("BasePart") then
        for _, child in ipairs(instance:GetChildren()) do
            if child:IsA("ProximityPrompt") and child.Enabled then
                table.insert(prompts, child)
            end
        end
    end
    
    if #prompts > 0 then
        for _, prompt in ipairs(prompts) do
            pcall(function()
                fireproximityprompt(prompt)
            end)
        end
        return true
    end
    
    if resource.kind == "crate" then
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("remotes")
            if remotes then
                local stomp = remotes:FindFirstChild("stomp")
                if stomp and stomp:IsA("RemoteEvent") then
                    stomp:FireServer(instance)
                end
            end
        end)
        return true
    end
    
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("remotes")
        if remotes then
            local pickup = remotes:FindFirstChild("pickup")
            if pickup and pickup:IsA("RemoteEvent") then
                pickup:FireServer(instance)
            end
        end
    end)
    
    return true
end

-- ============================================================================
-- MAIN FARM LOOP
-- ============================================================================
local function startFarming()
    local resources = discoverResources()
    
    if #resources == 0 then
        print("[AutoLoot] No resources found!")
        return
    end
    
    print(string.format("[AutoLoot] Found %d resources. Starting farm loop...", #resources))
    
    local _, hrp, hum = getCharacter()
    if not hrp or not hum then
        print("[AutoLoot] No character!")
        return
    end
    
    local farmed = 0
    local skipped = 0
    local startTime = os.clock()
    
    local remaining = table.clone(resources)
    local currentPos = hrp.Position
    
    while #remaining > 0 and CONFIG.Enabled do
        local _, currentHrp, currentHum = getCharacter()
        if not currentHrp or not currentHum then
            print("[AutoLoot] Character lost! Waiting for respawn...")
            LocalPlayer.CharacterAdded:Wait()
            task.wait(2)
            _, currentHrp, currentHum = getCharacter()
            if not currentHrp then break end
            currentPos = currentHrp.Position
        end
        
        if currentHum and currentHum.Health < CONFIG.SafeHealthThreshold then
            print("[AutoLoot] Low health! Pausing...")
            repeat task.wait(1) until not currentHum or currentHum.Health > CONFIG.SafeHealthThreshold + 20
        end
        
        if isMonsterNearby(currentPos) then
            print("[AutoLoot] ⚠ Monster nearby! Pausing...")
            repeat task.wait(0.5) until not isMonsterNearby(currentPos)
            print("[AutoLoot] Monster cleared. Resuming...")
        end
        
        local bestIdx = 1
        local bestDist = math.huge
        for i, res in ipairs(remaining) do
            if res.instance.Parent then
                local d = (res.position - currentPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestIdx = i
                end
            end
        end
        
        local target = remaining[bestIdx]
        table.remove(remaining, bestIdx)
        
        if not target.instance.Parent then
            skipped += 1
            continue
        end
        
        if CONFIG.TeleportMode then
            teleportTo(target.position)
        end
        
        local success = interactWithResource(target)
        if success then
            farmed += 1
            currentPos = target.position
        end
        
        task.wait(CONFIG.InteractionDelay)
        
        if CONFIG.ShowProgress and farmed % 10 == 0 then
            local elapsed = os.clock() - startTime
            print(string.format("[AutoLoot] Progress: %d/%d farmed | %d skipped | %.0fs elapsed",
                farmed, #resources, skipped, elapsed))
        end
        
        if STATE and not STATE.alive() then
            print("[AutoLoot] Reload detected, stopping.")
            break
        end
    end
    
    pcall(function()
        local _, hrp2, _ = getCharacter()
        if hrp2 then hrp2.Anchored = false end
    end)
    
    local elapsed = os.clock() - startTime
    print("="..string.rep("=", 78))
    print(string.format("[AutoLoot] ✓ Complete! Farmed: %d | Skipped: %d | Time: %.1fs", farmed, skipped, elapsed))
    print("="..string.rep("=", 78))
end

-- ============================================================================
-- ENTRY POINT
-- ============================================================================
print("[AutoLoot] Loaded. Starting resource scan...")
startFarming()

if STATE then
    STATE.onCleanup(function()
        CONFIG.Enabled = false
        print("[AutoLoot] Cleaned up for reload.")
    end)
end
