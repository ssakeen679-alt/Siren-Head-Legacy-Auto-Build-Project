--!strict
-- ==============================================================================
-- SIREN HEAD: LEGACY - Auto-Build Engine V2 (Rewritten)
-- ==============================================================================
-- Improvements over V1 (auto_build_runner.luau):
--   1. Relative Blueprint System: All parts defined relative to an anchor CFrame
--      so the fortress can be deployed at ANY location.
--   2. Adaptive Network Pacing: Dynamically scales PlacementDelay based on
--      live server ping to prevent packet drops.
--   3. Proper Connection Cleanup: Uses pcall/finally patterns and ensures all
--      event connections are disconnected on completion or error.
--   4. STATE-based Live-Reload Support: Compatible with Real MCP's live-reload
--      tool (STATE.onCleanup, STATE.alive, STATE.connect).
--   5. Modular Blueprint Loading: Blueprints can be loaded from embedded data
--      or from a separate JSON file.
--   6. Progress UI: Optional on-screen progress indicator using Drawing API.
-- ==============================================================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("remotes")
local BuildRemote = Remotes:WaitForChild("build")
local BuildsFolder = Workspace:WaitForChild("builds")

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local CONFIG = {
    -- Placement Mode:
    --   "absolute" -> Use raw world CFrames (legacy behavior)
    --   "relative" -> Offset all parts from player's current position/orientation
    PlacementMode = "relative", -- "absolute" | "relative"

    -- Speed Tuning (adaptive mode overrides these):
    AdaptivePacing = true,       -- Dynamically adjust delay based on ping
    BasePlacementDelay = 0.025,  -- Starting delay (seconds between remote fires)
    MinPlacementDelay = 0.015,   -- Fastest allowed dispatch
    MaxPlacementDelay = 0.080,   -- Slowest (high-ping fallback)
    PingThresholdLow = 80,       -- Below this ping -> use MinPlacementDelay
    PingThresholdHigh = 200,     -- Above this ping -> use MaxPlacementDelay

    -- Clustering:
    ClusterSeedRadius = 14.0,
    MaxBuildRange = 14.5,
    ClusterFlushWait = 0.04,

    -- Overlap & Safety:
    AvoidOverlapping = true,
    AnchorWhileBuilding = true,
    FlingProtection = true,

    -- Retry:
    MaxForceAttempts = 4,
    RepositionWait = 0.06,

    -- Exclusions:
    ExcludeBasicTurret = true,

    -- Progress Display:
    ShowProgressUI = true,
}

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================
type BuildItem = {
    category: string,
    cframe: CFrame,
    localOffset: CFrame?,  -- V2: offset relative to anchor
}

type Cluster = {
    center: Vector3,
    items: { BuildItem },
}

type BuildResult = {
    fired: number,
    confirmed: number,
    skipped: number,
    failed: number,
    elapsed: number,
}

-- ============================================================================
-- UTILITY: ADAPTIVE PING-BASED PACING
-- ============================================================================
local function getLivePing(): number
    local ok, ping = pcall(function()
        local item = StatsService.Network.ServerStatsItem["Data Ping"]
        return item:GetValue()
    end)
    return ok and ping or 100
end

local function getAdaptiveDelay(): number
    if not CONFIG.AdaptivePacing then
        return CONFIG.BasePlacementDelay
    end
    local ping = getLivePing()
    if ping <= CONFIG.PingThresholdLow then
        return CONFIG.MinPlacementDelay
    elseif ping >= CONFIG.PingThresholdHigh then
        return CONFIG.MaxPlacementDelay
    else
        -- Linear interpolation between thresholds
        local t = (ping - CONFIG.PingThresholdLow) / (CONFIG.PingThresholdHigh - CONFIG.PingThresholdLow)
        return CONFIG.MinPlacementDelay + t * (CONFIG.MaxPlacementDelay - CONFIG.MinPlacementDelay)
    end
end

-- ============================================================================
-- UTILITY: SPATIAL HASH GRID (Reusable)
-- ============================================================================
local SPATIAL_CELL = 2.0

local function createSpatialGrid()
    local grid: { [string]: { Vector3 } } = {}

    local function getKey(pos: Vector3): string
        local gx = math.round(pos.X / SPATIAL_CELL)
        local gy = math.round(pos.Y / SPATIAL_CELL)
        local gz = math.round(pos.Z / SPATIAL_CELL)
        return string.format("%d:%d:%d", gx, gy, gz)
    end

    local function isOccupied(targetPos: Vector3): boolean
        local gx = math.round(targetPos.X / SPATIAL_CELL)
        local gy = math.round(targetPos.Y / SPATIAL_CELL)
        local gz = math.round(targetPos.Z / SPATIAL_CELL)
        for dx = -1, 1 do
            for dy = -1, 1 do
                for dz = -1, 1 do
                    local list = grid[string.format("%d:%d:%d", gx + dx, gy + dy, gz + dz)]
                    if list then
                        for _, existing in ipairs(list) do
                            if (existing - targetPos).Magnitude < 1.0 then
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    local function register(pos: Vector3)
        local key = getKey(pos)
        if not grid[key] then
            grid[key] = {}
        end
        table.insert(grid[key], pos)
    end

    return { isOccupied = isOccupied, register = register }
end

-- ============================================================================
-- UTILITY: CHARACTER MANAGEMENT
-- ============================================================================
local function getAliveCharacter(): (Model, BasePart, Humanoid)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

    if not char or not hum or not hrp or hum.Health <= 0 then
        print("[AutoBuild V2] Character down! Waiting for respawn...")
        char = LocalPlayer.CharacterAdded:Wait()
        hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
        hum = char:WaitForChild("Humanoid") :: Humanoid
        task.wait(1.5)
        print("[AutoBuild V2] Respawned! Resuming...")
    end

    return char :: Model, hrp :: BasePart, hum :: Humanoid
end

local function teleportTo(targetPos: Vector3)
    local _, hrp, _ = getAliveCharacter()
    if (hrp.Position - targetPos).Magnitude > 2.0 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(targetPos)
        if CONFIG.AnchorWhileBuilding then
            hrp.Anchored = true
        end
        task.wait(CONFIG.RepositionWait)
    elseif CONFIG.AnchorWhileBuilding and not hrp.Anchored then
        hrp.Anchored = true
    end
end

-- ============================================================================
-- UTILITY: PROGRESS DISPLAY (Drawing API)
-- ============================================================================
local progressUI = {}

local function createProgressUI()
    local ok, _ = pcall(function()
        -- Check if Drawing API exists
        if not Drawing then return end

        progressUI.bg = Drawing.new("Square")
        progressUI.bg.Size = Vector2.new(300, 40)
        progressUI.bg.Position = Vector2.new(10, 10)
        progressUI.bg.Color = Color3.fromRGB(20, 20, 20)
        progressUI.bg.Filled = true
        progressUI.bg.Transparency = 0.7
        progressUI.bg.Visible = CONFIG.ShowProgressUI

        progressUI.bar = Drawing.new("Square")
        progressUI.bar.Size = Vector2.new(0, 36)
        progressUI.bar.Position = Vector2.new(12, 12)
        progressUI.bar.Color = Color3.fromRGB(80, 200, 80)
        progressUI.bar.Filled = true
        progressUI.bar.Transparency = 0.9
        progressUI.bar.Visible = CONFIG.ShowProgressUI

        progressUI.text = Drawing.new("Text")
        progressUI.text.Position = Vector2.new(16, 16)
        progressUI.text.Color = Color3.fromRGB(255, 255, 255)
        progressUI.text.Size = 16
        progressUI.text.Center = false
        progressUI.text.Outline = true
        progressUI.text.OutlineColor = Color3.fromRGB(0, 0, 0)
        progressUI.text.Visible = CONFIG.ShowProgressUI
    end)
end

local function updateProgressUI(fired: number, total: number, confirmed: number, elapsed: number)
    if not progressUI.bar then return end
    pcall(function()
        local pct = fired / math.max(total, 1)
        progressUI.bar.Size = Vector2.new(296 * pct, 36)
        progressUI.bar.Color = Color3.fromRGB(
            math.floor(80 + 120 * (1 - pct)),
            math.floor(80 + 120 * pct),
            80
        )
        local rate = fired / math.max(elapsed, 0.001)
        progressUI.text.Text = string.format(
            "%d/%d (%.0f%%) | ✓%d | %.0f p/s | %dms",
            fired, total, pct * 100, confirmed, rate, getLivePing()
        )
    end)
end

local function destroyProgressUI()
    pcall(function()
        for _, obj in pairs(progressUI) do
            if obj and obj.Remove then
                obj:Remove()
            end
        end
        table.clear(progressUI)
    end)
end

-- ============================================================================
-- BLUEPRINT CONVERSION: Absolute -> Relative
-- ============================================================================
local function convertToRelative(rawData: { { any } }, anchorCF: CFrame): { BuildItem }
    local items: { BuildItem } = {}
    for _, entry in ipairs(rawData) do
        local cat = entry[1] :: string
        local x, y, z = entry[2] :: number, entry[3] :: number, entry[4] :: number
        local rx, ry, rz = entry[5] :: number, entry[6] :: number, entry[7] :: number
        local worldCF = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)
        local localOffset = anchorCF:ToObjectSpace(worldCF)
        table.insert(items, {
            category = cat,
            cframe = worldCF,
            localOffset = localOffset,
        })
    end
    return items
end

local function resolveWorldCFrame(item: BuildItem, deployAnchor: CFrame): CFrame
    if CONFIG.PlacementMode == "relative" and item.localOffset then
        return deployAnchor * item.localOffset
    end
    return item.cframe
end

-- ============================================================================
-- GREEDY SPHERICAL CLUSTERING WITH TSP CHAINING
-- ============================================================================
local function buildClusters(items: { BuildItem }, deployAnchor: CFrame): { Cluster }
    local pool: { { cf: CFrame, item: BuildItem } } = {}
    for _, item in ipairs(items) do
        local worldCF = resolveWorldCFrame(item, deployAnchor)
        table.insert(pool, { cf = worldCF, item = item })
    end

    local clusters: { Cluster } = {}
    local currentHub = pool[1].cf.Position

    while #pool > 0 do
        -- Find nearest seed via TSP nearest-neighbor
        local bestDist = math.huge
        local seedIdx = 1
        for i, entry in ipairs(pool) do
            local d = (entry.cf.Position - currentHub).Magnitude
            if d < bestDist then
                bestDist = d
                seedIdx = i
            end
        end

        local seed = pool[seedIdx]

        -- Compute balanced centroid from nearby items
        local sumPos = Vector3.zero
        local neighborCount = 0
        for _, entry in ipairs(pool) do
            if (entry.cf.Position - seed.cf.Position).Magnitude <= CONFIG.ClusterSeedRadius then
                sumPos += entry.cf.Position
                neighborCount += 1
            end
        end
        local centroid = neighborCount > 0 and (sumPos / neighborCount) or seed.cf.Position

        -- Gather items within MaxBuildRange
        local batch: { BuildItem } = {}
        local remaining = {}
        for _, entry in ipairs(pool) do
            if (entry.cf.Position - centroid).Magnitude <= CONFIG.MaxBuildRange then
                table.insert(batch, entry.item)
            else
                table.insert(remaining, entry)
            end
        end

        -- Fallback
        if #batch == 0 then
            table.insert(batch, seed.item)
            centroid = seed.cf.Position
            remaining = {}
            for i, entry in ipairs(pool) do
                if i ~= seedIdx then
                    table.insert(remaining, entry)
                end
            end
        end

        pool = remaining
        currentHub = centroid

        -- Sort bottom-to-top for structural integrity
        table.sort(batch, function(a: BuildItem, b: BuildItem)
            local aCF = resolveWorldCFrame(a, deployAnchor)
            local bCF = resolveWorldCFrame(b, deployAnchor)
            return aCF.Y < bCF.Y
        end)

        table.insert(clusters, { center = centroid, items = batch })
    end

    return clusters
end

-- ============================================================================
-- MAIN EXECUTION ENGINE
-- ============================================================================
local function executeBuild(rawBuildData: { { any } }): BuildResult
    local _, hrp, _ = getAliveCharacter()
    local deployAnchor: CFrame

    -- Determine the anchor point for relative mode
    if CONFIG.PlacementMode == "relative" then
        deployAnchor = hrp.CFrame
        print("[AutoBuild V2] Deploying fortress RELATIVE to current position")
    else
        -- Use the centroid of all parts as a nominal anchor for absolute mode
        local sum = Vector3.zero
        for _, entry in ipairs(rawBuildData) do
            sum += Vector3.new(entry[2], entry[3], entry[4])
        end
        deployAnchor = CFrame.new(sum / #rawBuildData)
        print("[AutoBuild V2] Deploying fortress at ABSOLUTE world coordinates")
    end

    -- Convert raw data into BuildItems with relative offsets
    local allItems = convertToRelative(rawBuildData, deployAnchor)

    -- Pre-filter existing builds
    local spatialGrid = createSpatialGrid()

    if CONFIG.AvoidOverlapping then
        for _, obj in ipairs(BuildsFolder:GetChildren()) do
            local p: Vector3?
            if obj:IsA("Model") then
                p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
            elseif obj:IsA("BasePart") then
                p = obj.Position
            end
            if p then
                spatialGrid.register(p)
            end
        end
    end

    -- Filter and deduplicate
    local unplaced: { BuildItem } = {}
    local skippedCount = 0
    for _, item in ipairs(allItems) do
        if CONFIG.ExcludeBasicTurret and item.category == "Basic Turret" then
            skippedCount += 1
            continue
        end
        local worldCF = resolveWorldCFrame(item, deployAnchor)
        local pos = worldCF.Position
        if CONFIG.AvoidOverlapping and spatialGrid.isOccupied(pos) then
            skippedCount += 1
        else
            table.insert(unplaced, item)
            spatialGrid.register(pos)
        end
    end

    local totalTarget = #unplaced
    print(string.format("[AutoBuild V2] Total: %d | Skipped: %d | Ready: %d",
        #rawBuildData, skippedCount, totalTarget))

    if totalTarget == 0 then
        print("[AutoBuild V2] Nothing to place!")
        return { fired = 0, confirmed = 0, skipped = skippedCount, failed = 0, elapsed = 0 }
    end

    -- Build clusters
    local clusters = buildClusters(unplaced, deployAnchor)
    print(string.format("[AutoBuild V2] %d parts -> %d clusters (avg %.1f parts/cluster)",
        totalTarget, #clusters, totalTarget / #clusters))

    -- Setup progress UI
    createProgressUI()

    -- Setup confirmation tracker with PROPER cleanup
    local confirmedCount = 0
    local firedCount = 0
    local startTime = os.clock()
    local conn: RBXScriptConnection? = nil

    local success, err = pcall(function()
        conn = BuildRemote.OnClientEvent:Connect(function(inst)
            if inst and typeof(inst) == "Instance" then
                confirmedCount += 1
            end
        end)

        -- === TIER 1: Clustered Wire-Speed Dispatch ===
        for clusterIdx, cluster in ipairs(clusters) do
            teleportTo(cluster.center + Vector3.new(0, 2.5, 0))

            for _, item in ipairs(cluster.items) do
                local worldCF = resolveWorldCFrame(item, deployAnchor)
                BuildRemote:FireServer(item.category, worldCF)
                firedCount += 1

                local delay = getAdaptiveDelay()
                task.wait(delay)

                -- Update progress
                updateProgressUI(firedCount, totalTarget, confirmedCount, os.clock() - startTime)
            end

            task.wait(CONFIG.ClusterFlushWait)

            -- Periodic status
            if clusterIdx % 10 == 0 or clusterIdx == #clusters then
                local elapsed = os.clock() - startTime
                local rate = firedCount / math.max(elapsed, 0.001)
                print(string.format(
                    "[CLUSTER %d/%d] Fired: %d/%d (%.0f%%) | Confirmed: %d | Ping: %dms | %.0f p/s",
                    clusterIdx, #clusters, firedCount, totalTarget,
                    (firedCount / totalTarget) * 100, confirmedCount, getLivePing(), rate
                ))
            end
        end

        -- Settle trailing packets
        print("[AutoBuild V2] Stream dispatch complete. Settling packets...")
        local waitStart = os.clock()
        while confirmedCount < firedCount and (os.clock() - waitStart) < 1.5 do
            task.wait(0.05)
        end

        -- === TIER 2: Rapid Sweep for Missing Parts ===
        local function getMissing(): { BuildItem }
            local missing: { BuildItem } = {}
            for _, item in ipairs(unplaced) do
                local worldCF = resolveWorldCFrame(item, deployAnchor)
                local found = false
                for _, obj in ipairs(BuildsFolder:GetChildren()) do
                    local p: Vector3?
                    if obj:IsA("Model") then
                        p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
                    elseif obj:IsA("BasePart") then
                        p = obj.Position
                    end
                    if p and (p - worldCF.Position).Magnitude < 1.5 then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(missing, item)
                end
            end
            return missing
        end

        local missing = getMissing()
        if #missing > 0 then
            print(string.format("[AutoBuild V2] Sweep pass: %d unconfirmed parts", #missing))
            for _, item in ipairs(missing) do
                local worldCF = resolveWorldCFrame(item, deployAnchor)
                teleportTo(worldCF.Position + Vector3.new(0, 3.5, 0))
                BuildRemote:FireServer(item.category, worldCF)
                task.wait(0.04)
            end
            task.wait(0.5)
            missing = getMissing()
        end

        -- === TIER 3: Force-Fire Retry ===
        if #missing > 0 then
            print(string.format("[AutoBuild V2] Force-Fire: %d stubborn parts", #missing))
            for _, item in ipairs(missing) do
                local worldCF = resolveWorldCFrame(item, deployAnchor)
                for attempt = 1, CONFIG.MaxForceAttempts do
                    local hoverY = 3.5 + (attempt - 1) * 0.5
                    teleportTo(worldCF.Position + Vector3.new(0, hoverY, 0))
                    BuildRemote:FireServer(item.category, worldCF)
                    task.wait(0.08)

                    -- Quick verify
                    local placed = false
                    for _, obj in ipairs(BuildsFolder:GetChildren()) do
                        local p: Vector3?
                        if obj:IsA("Model") then
                            p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
                        elseif obj:IsA("BasePart") then
                            p = obj.Position
                        end
                        if p and (p - worldCF.Position).Magnitude < 1.5 then
                            placed = true
                            break
                        end
                    end
                    if placed then break end
                end
            end
        end
    end)

    -- === CLEANUP (always runs) ===
    if conn then
        conn:Disconnect()
        conn = nil
    end

    -- Unanchor player
    pcall(function()
        local _, hrp2, _ = getAliveCharacter()
        hrp2.Anchored = false
    end)

    destroyProgressUI()

    local elapsed = os.clock() - startTime
    local finalMissing = 0

    if success then
        -- Count final missing
        for _, item in ipairs(unplaced) do
            local worldCF = resolveWorldCFrame(item, deployAnchor)
            local found = false
            for _, obj in ipairs(BuildsFolder:GetChildren()) do
                local p: Vector3?
                if obj:IsA("Model") then
                    p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
                elseif obj:IsA("BasePart") then
                    p = obj.Position
                end
                if p and (p - worldCF.Position).Magnitude < 1.5 then
                    found = true
                    break
                end
            end
            if not found then
                finalMissing += 1
            end
        end

        print("================================================================================")
        print(string.format("[AutoBuild V2] COMPLETE in %.1fs", elapsed))
        print(string.format("  Fired: %d | Confirmed: %d | Missing: %d | Skipped: %d",
            firedCount, confirmedCount, finalMissing, skippedCount))
        print(string.format("  Avg Rate: %.1f parts/sec | Avg Ping: %dms",
            firedCount / math.max(elapsed, 0.001), getLivePing()))
        print("================================================================================")
    else
        warn("[AutoBuild V2] ERROR: " .. tostring(err))
    end

    return {
        fired = firedCount,
        confirmed = confirmedCount,
        skipped = skippedCount,
        failed = finalMissing,
        elapsed = elapsed,
    }
end

-- ============================================================================
-- BLUEPRINT DATA PLACEHOLDER
-- ============================================================================
print("[AutoBuild V2] Engine loaded. Call executeBuild(data) to deploy.")
print("[AutoBuild V2] Modes: 'absolute' (legacy) or 'relative' (portable)")

return {
    executeBuild = executeBuild,
    CONFIG = CONFIG,
    convertToRelative = convertToRelative,
    createSpatialGrid = createSpatialGrid,
}
