--!strict
-- Full-Map Auto-Build Engine V14 (Fast-Cluster & Dedicated Force-Fire Engine)
-- Features: 14.5-Stud Spherical Greedy Clustering, Continuous TSP Chaining,
-- Wire-Speed Dispatch, Rapid Sweep, and Dedicated Point-Blank Force-Fire Engine.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("remotes")
local BuildRemote = Remotes:WaitForChild("build")
local BuildsFolder = Workspace:WaitForChild("builds")

local StatsFolder = LocalPlayer:WaitForChild("stats")
local ScoreObj = StatsFolder:FindFirstChild("Score") :: NumberValue?

-- ============================================================================
-- USER CONFIGURATION
-- ============================================================================
local CONFIG = {
    -- AutoRun:
    --   true  -> Automatically executes placements in-game immediately.
    --   false -> Only scans and exports payload.
    AutoRun = true,

    -- Speed Mode:
    --   "Fast"   -> Pipelined wire-speed (~20-25s for 580 parts, 40 parts/sec).
    --   "Normal" -> Balanced speed (~40s for 580 parts).
    --   "Safe"   -> Conservative rate (~1-2 mins for 580 parts).
    SpeedMode = "Fast", -- "Fast" | "Normal" | "Safe"

    -- MaxParts:
    --   0 = ALL available parts in workspace.builds.
    MaxParts = 0,

    -- AvoidOverlapping:
    --   true -> Skips placing if position is already occupied in workspace.builds.
    AvoidOverlapping = true,

    -- Safety Guards:
    AnchorWhileBuilding = true,
    FlingProtection = true,   -- Zeroes runaway velocity if physics flings you
    HealthWatchdog = true,    -- Warns on monster attacks

    -- ExcludeBasicTurret:
    ExcludeBasicTurret = true,

    -- Backup:
    BackupFilePath = "auto_build_runner.txt",
}

-- ============================================================================
-- SPEED PROFILES & SPHERICAL CLUSTER TUNING (V15 True Wire-Speed)
-- ============================================================================
local SPEED_PROFILES = {
    ["Fast"] = {
        ClusterSeedRadius = 14.0, -- Seed expansion radius for balanced centroids
        MaxBuildRange = 14.5,     -- Strict spherical boundary (server limit: 16.0)
        PlacementDelay = 0.018,   -- True wire-speed stream dispatch (~55 parts/sec)
        RepositionWait = 0.06,    -- Settle time upon cluster hop
        ClusterFlushWait = 0.04,  -- Brief socket flush between clusters
        MaxForceAttempts = 4,     -- Dedicated point-blank Force-Fire attempts per stubborn part
    },
    ["Normal"] = {
        ClusterSeedRadius = 13.5,
        MaxBuildRange = 14.0,
        PlacementDelay = 0.028,   -- ~35 parts/sec
        RepositionWait = 0.08,
        ClusterFlushWait = 0.06,
        MaxForceAttempts = 4,
    },
    ["Safe"] = {
        ClusterSeedRadius = 12.0,
        MaxBuildRange = 13.0,
        PlacementDelay = 0.045,   -- ~22 parts/sec
        RepositionWait = 0.12,
        ClusterFlushWait = 0.08,
        MaxForceAttempts = 4,
    },
}

local activeProfile = SPEED_PROFILES[CONFIG.SpeedMode] or SPEED_PROFILES["Fast"]
local GRID_CELL_SIZE = 1.5

type BuildItem = {
    category: string,
    cframe: CFrame,
}

-- ============================================================================
-- TELEMETRY & DIAGNOSTICS
-- ============================================================================

local frameTimes = table.create(30, 0.016)
local frameIndex = 1

RunService.RenderStepped:Connect(function(dt: number)
    frameTimes[frameIndex] = dt
    frameIndex = (frameIndex % 30) + 1
end)

local function getLiveFPS(): number
    local total = 0
    for _, dt in ipairs(frameTimes) do
        total += dt
    end
    return math.round(#frameTimes / math.max(total, 0.0001))
end

local function getLivePing(): number
    local pingItem = StatsService.Network.ServerStatsItem:FindFirstChild("Data Ping")
    if pingItem then
        return math.round(pingItem:GetValue())
    end
    return 0
end

local function getLiveMemoryMB(): number
    return math.round(StatsService:GetTotalMemoryUsageMb())
end

local function getPlayerHealth(): (number, number)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        return math.round(hum.Health), math.round(hum.MaxHealth)
    end
    return 0, 100
end

-- ============================================================================
-- HELPER FUNCTIONS & RECOVERY
-- ============================================================================

local function getAliveCharacter(): (Model, BasePart, Humanoid)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

    if not char or not hum or not hrp or hum.Health <= 0 then
        print("[AutoBuild:WATCHDOG] Character down! Waiting for respawn...")
        char = LocalPlayer.CharacterAdded:Wait()
        hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
        hum = char:WaitForChild("Humanoid") :: Humanoid
        task.wait(1.5)
        print("[AutoBuild:WATCHDOG] Respawned! Resuming Fast Pipeline...")
    end

    return char, hrp, hum
end

local function getGridKey(pos: Vector3): string
    local gx = math.round(pos.X / GRID_CELL_SIZE)
    local gy = math.round(pos.Y / GRID_CELL_SIZE)
    local gz = math.round(pos.Z / GRID_CELL_SIZE)
    return string.format("%d:%d:%d", gx, gy, gz)
end

local function getFormattedCFrame(cframe: CFrame): string
    local c = {cframe:GetComponents()}
    return string.format(
        "CFrame.new(%.2f, %.2f, %.2f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f, %.3f)",
        c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]
    )
end

local function ensureAtPos(targetPos: Vector3)
    local _, hrp, hum = getAliveCharacter()

    if CONFIG.FlingProtection and hrp.AssemblyLinearVelocity.Magnitude > 40 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    if CONFIG.HealthWatchdog and hum.Health < hum.MaxHealth * 0.4 then
        warn(string.format("[AutoBuild:WATCHDOG] DANGER: Health is %d/%d HP!", 
            math.round(hum.Health), math.round(hum.MaxHealth)))
    end

    if (hrp.Position - targetPos).Magnitude > 2.0 then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(targetPos)

        if CONFIG.AnchorWhileBuilding then
            hrp.Anchored = true
        end

        task.wait(activeProfile.RepositionWait)
    elseif CONFIG.AnchorWhileBuilding and not hrp.Anchored then
        hrp.Anchored = true
    end
end

type Cluster = {
    center: Vector3,
    items: { BuildItem }
}

-- ============================================================================
-- MAIN ENGINE PIPELINE
-- ============================================================================
local function runAutoBuildV15()
    local initialScore = ScoreObj and ScoreObj.Value or 0
    print("================================================================================")
    print(string.format("[AutoBuild-V15] True Wire-Speed & Dedicated Force-Fire Engine | Mode: %s", CONFIG.SpeedMode))
    print(string.format(" - Cluster Radius: %.1f studs | Hop Settle: %.2fs | Dispatch Delay: %.3fs", 
        activeProfile.MaxBuildRange, activeProfile.RepositionWait, activeProfile.PlacementDelay))
    print(string.format(" - Ping: %d ms | Client FPS: %d | Memory: %d MB | Score: $%d", 
        getLivePing(), getLiveFPS(), getLiveMemoryMB(), initialScore))
    print("================================================================================")

    -- Step 1: Spatial Hash Bucket for exact Euclidean duplicate detection (1.0 stud threshold)
    local SPATIAL_CELL = 2.0
    local spatialGrid: { [string]: { Vector3 } } = {}

    local function isPositionOccupied(targetPos: Vector3): boolean
        local gx = math.round(targetPos.X / SPATIAL_CELL)
        local gy = math.round(targetPos.Y / SPATIAL_CELL)
        local gz = math.round(targetPos.Z / SPATIAL_CELL)
        for dx = -1, 1 do
            for dy = -1, 1 do
                for dz = -1, 1 do
                    local list = spatialGrid[string.format("%d:%d:%d", gx + dx, gy + dy, gz + dz)]
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

    local function registerPosition(pos: Vector3)
        local gx = math.round(pos.X / SPATIAL_CELL)
        local gy = math.round(pos.Y / SPATIAL_CELL)
        local gz = math.round(pos.Z / SPATIAL_CELL)
        local key = string.format("%d:%d:%d", gx, gy, gz)
        if not spatialGrid[key] then
            spatialGrid[key] = {}
        end
        table.insert(spatialGrid[key], pos)
    end

    -- Step 2: Scan workspace.builds and deduplicate identical overlapping models (< 1.0 studs)
    local rawQueue: { BuildItem } = {}
    local totalFound = 0
    local excludedCount = 0
    local duplicateCount = 0

    for _, model in ipairs(BuildsFolder:GetChildren()) do
        local name = model.Name
        if CONFIG.ExcludeBasicTurret and name == "Basic Turret" then
            excludedCount += 1
        else
            local cf: CFrame?
            if model:IsA("Model") then
                cf = model.PrimaryPart and model.PrimaryPart.CFrame or model:GetPivot()
            elseif model:IsA("BasePart") then
                cf = model.CFrame
            end

            if cf then
                totalFound += 1
                local pos = cf.Position
                if CONFIG.AvoidOverlapping and isPositionOccupied(pos) then
                    duplicateCount += 1
                else
                    table.insert(rawQueue, { category = name, cframe = cf })
                    registerPosition(pos)
                end
            end
        end
    end

    print(string.format("[AutoBuild] Scan: Found %d | Excluded: %d | Duplicates (Skipped): %d | Unique To Build: %d",
        totalFound, excludedCount, duplicateCount, #rawQueue))

    -- Step 3: Standalone Backup Export (Compact V12 format)
    local lines = {}
    table.insert(lines, '--!strict')
    table.insert(lines, string.format('-- Standalone Auto-Build Payload (Generated V12 Proximity-Pipelined on %s)', os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(lines, string.format('-- Total Parts: %d', #rawQueue))
    table.insert(lines, 'local RAW_BUILD_DATA = {')
    for _, item in ipairs(rawQueue) do
        local rx, ry, rz = item.cframe:ToEulerAnglesXYZ()
        table.insert(lines, string.format('    {"%s", %.2f, %.2f, %.2f, %.3f, %.3f, %.3f},',
            item.category,
            math.round(item.cframe.X * 100) / 100,
            math.round(item.cframe.Y * 100) / 100,
            math.round(item.cframe.Z * 100) / 100,
            math.round(rx * 1000) / 1000,
            math.round(ry * 1000) / 1000,
            math.round(rz * 1000) / 1000))
    end
    table.insert(lines, '}')
    local standaloneCode = table.concat(lines, "\n")

    if writefile then
        pcall(writefile, CONFIG.BackupFilePath, standaloneCode)
    end
    if setclipboard then
        pcall(setclipboard, standaloneCode)
    elseif toclipboard then
        pcall(toclipboard, standaloneCode)
    end

    if not CONFIG.AutoRun then
        print("[AutoBuild] AutoRun is FALSE. Payload saved. Done!")
        return
    end

    -- Step 4: Minecraft 3D Chunk Partitioning & Radial Outward Spiral
    local _, startHrp, _ = getAliveCharacter()
    local unplaced = rawQueue
    local totalTarget = #unplaced
    if CONFIG.MaxParts > 0 and CONFIG.MaxParts < totalTarget then
        while #unplaced > CONFIG.MaxParts do
            table.remove(unplaced)
        end
        totalTarget = #unplaced
    end

    print("\n================================================================================")
    print(string.format("[AutoBuild-V14] Launching High-Speed Spherical Cluster Engine (%s Mode) for %d parts...", CONFIG.SpeedMode, totalTarget))
    print("================================================================================")

    -- Step 4: Fast 14.5-Stud Spherical Greedy Clustering with Continuous TSP Chaining
    local unplacedPool = table.clone(unplaced)
    local clusterList: { Cluster } = {}
    local currentHub = unplacedPool[1].cframe.Position

    while #unplacedPool > 0 do
        -- 1. Find nearest seed to currentHub (continuous smooth flight path)
        local bestDist = math.huge
        local seedIdx = 1
        for i, item in ipairs(unplacedPool) do
            local d = (item.cframe.Position - currentHub).Magnitude
            if d < bestDist then
                bestDist = d
                seedIdx = i
            end
        end

        local seed = unplacedPool[seedIdx]

        -- 2. Gather neighbors within ClusterSeedRadius to compute balanced centroid
        local sumPos = Vector3.zero
        local neighborCount = 0
        for _, item in ipairs(unplacedPool) do
            if (item.cframe.Position - seed.cframe.Position).Magnitude <= activeProfile.ClusterSeedRadius then
                sumPos += item.cframe.Position
                neighborCount += 1
            end
        end
        local centroid = (neighborCount > 0) and (sumPos / neighborCount) or seed.cframe.Position

        -- 3. Gather all items within MaxBuildRange of centroid
        local batch: { BuildItem } = {}
        local remaining: { BuildItem } = {}
        for _, item in ipairs(unplacedPool) do
            if (item.cframe.Position - centroid).Magnitude <= activeProfile.MaxBuildRange then
                table.insert(batch, item)
            else
                table.insert(remaining, item)
            end
        end

        -- Fallback safety check
        if #batch == 0 then
            table.insert(batch, seed)
            centroid = seed.cframe.Position
            remaining = {}
            for i, item in ipairs(unplacedPool) do
                if i ~= seedIdx then
                    table.insert(remaining, item)
                end
            end
        end

        unplacedPool = remaining
        currentHub = centroid

        -- Sort items bottom-to-top (stable ground-up building)
        table.sort(batch, function(a: BuildItem, b: BuildItem)
            return a.cframe.Y < b.cframe.Y
        end)

        table.insert(clusterList, {
            center = centroid,
            items = batch,
        })
    end

    print(string.format("[AutoBuild-V14] Partitioned %d parts into %d Optimal Spherical Clusters (avg %.1f parts/cluster)",
        totalTarget, #clusterList, totalTarget / #clusterList))

    -- Step 5: True Wire-Speed Cluster Stream Dispatch
    local confirmedCount = 0
    local firedCount = 0
    local startTime = os.clock()

    local conn = BuildRemote.OnClientEvent:Connect(function(inst)
        if inst and inst:IsA("Instance") then
            confirmedCount += 1
        end
    end)

    for clusterIndex, cluster in ipairs(clusterList) do
        -- Reposition once to cluster centroid (elevated safely above floor)
        ensureAtPos(cluster.center + Vector3.new(0, 2.5, 0))

        -- Stream-dispatch all parts in this cluster at pure wire-speed (~55 parts/sec)
        for _, item in ipairs(cluster.items) do
            ensureAtPos(cluster.center + Vector3.new(0, 2.5, 0))

            if ScoreObj and ScoreObj.Value <= 0 and initialScore > 0 then
                warn(string.format("[AutoBuild:WATCHDOG] SCORE DEPLETED! Remaining: $%d. Halting.", ScoreObj.Value))
                break
            end

            BuildRemote:FireServer(item.category, item.cframe)
            firedCount += 1

            task.wait(activeProfile.PlacementDelay)
        end

        -- Clean socket flush between clusters
        task.wait(activeProfile.ClusterFlushWait)

        if clusterIndex % 10 == 0 or clusterIndex == #clusterList then
            local elapsed = os.clock() - startTime
            local percent = (firedCount / math.max(totalTarget, 1)) * 100
            local rate = (firedCount / math.max(elapsed, 0.001)) * 60
            print(string.format(
                "[CLUSTER #%d/%d | Dispatched: %d/%d (%.1f%%)] Confirmed: %d | Ping: %dms | Speed: %.0f p/m",
                clusterIndex, #clusterList, firedCount, totalTarget, percent,
                confirmedCount, getLivePing(), rate
            ))
        end
    end

    -- Settle trailing packets
    print("\n[AutoBuild-V15] Cluster stream dispatch complete! Waiting 1.0s for server replication...")
    local waitStart = os.clock()
    while (confirmedCount < firedCount) and (os.clock() - waitStart < 1.2) do
        task.wait(0.05)
    end

    -- Step 6: Physical Verification Helper
    local function getMissingItems(): { BuildItem }
        local missing: { BuildItem } = {}
        for _, item in ipairs(unplaced) do
            local found = false
            for _, obj in ipairs(BuildsFolder:GetChildren()) do
                local p: Vector3?
                if obj:IsA("Model") then
                    p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
                elseif obj:IsA("BasePart") then
                    p = obj.Position
                end
                if p and (p - item.cframe.Position).Magnitude < 1.5 then
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

    -- Step 7: Rapid Pre-Sweep for Any Missing Parts
    local missing = getMissingItems()
    if #missing > 0 then
        print(string.format("\n[AutoBuild-V14] Rapid Sweep Pass for %d unconfirmed parts...", #missing))
        table.sort(missing, function(a: BuildItem, b: BuildItem)
            return a.cframe.Y < b.cframe.Y
        end)
        for _, item in ipairs(missing) do
            ensureAtPos(item.cframe.Position + Vector3.new(0, 3.5, 0))
            BuildRemote:FireServer(item.category, item.cframe)
            task.wait(0.04)
        end
        task.wait(0.5)
        missing = getMissingItems()
    end

    -- Step 8: DEDICATED FORCE-FIRE ENGINE (If Dropped >= 2 Times)
    if #missing > 0 then
        print("================================================================================")
        print(string.format("[AutoBuild-V14:FORCE-FIRE] Triggering Dedicated Force-Fire Engine for %d stubborn parts...", #missing))
        print("================================================================================")

        local forceSuccess = 0
        local forceFailed = 0

        for idx, item in ipairs(missing) do
            local confirmed = false

            for attempt = 1, activeProfile.MaxForceAttempts do
                -- Teleport directly above the target part with dynamic height adjustments
                local hoverY = 3.5 + (attempt - 1) * 0.5
                ensureAtPos(item.cframe.Position + Vector3.new(0, hoverY, 0))

                BuildRemote:FireServer(item.category, item.cframe)

                -- Direct live polling of workspace.builds
                local pollStart = os.clock()
                while (os.clock() - pollStart < 0.25) do
                    for _, obj in ipairs(BuildsFolder:GetChildren()) do
                        local p: Vector3?
                        if obj:IsA("Model") then
                            p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
                        elseif obj:IsA("BasePart") then
                            p = obj.Position
                        end
                        if p and (p - item.cframe.Position).Magnitude < 1.5 then
                            confirmed = true
                            break
                        end
                    end
                    if confirmed then break end
                    task.wait(0.03)
                end

                if confirmed then
                    forceSuccess += 1
                    print(string.format("[Force-Fire #%d/%d] CONFIRMED '%s' at (%.1f, %.1f, %.1f) on attempt %d",
                        idx, #missing, item.category, item.cframe.Position.X, item.cframe.Position.Y, item.cframe.Position.Z, attempt))
                    break
                end
            end

            if not confirmed then
                forceFailed += 1
                warn(string.format("[Force-Fire:REJECTED] Part '%s' at (%.1f, %.1f, %.1f) could not be placed after %d force attempts.",
                    item.category, item.cframe.Position.X, item.cframe.Position.Y, item.cframe.Position.Z, activeProfile.MaxForceAttempts))
            end
        end

        print(string.format("[AutoBuild-V14:FORCE-FIRE] Completed! %d force-placed, %d rejected.", forceSuccess, forceFailed))
    end

    conn:Disconnect()

    -- Release anchor
    local _, finalHrp, _ = getAliveCharacter()
    if finalHrp and CONFIG.AnchorWhileBuilding then
        finalHrp.Anchored = false
    end

    -- Final Physical World Audit
    local finalMissing = getMissingItems()
    local finalPhysicalCount = totalTarget - #finalMissing
    local totalDuration = os.clock() - startTime
    local finalScore = ScoreObj and ScoreObj.Value or 0

    print("\n================================================================================")
    print(string.format("[AutoBuild-V15] MISSION FINISHED in %.2f seconds (%.2f minutes)!", totalDuration, totalDuration / 60))
    print(string.format(" - Target Parts:         %d", totalTarget))
    print(string.format(" - Total Dispatched:     %d", firedCount))
    print(string.format(" - Physically Confirmed: %d / %d (%.1f%%)", finalPhysicalCount, totalTarget, (finalPhysicalCount / math.max(totalTarget, 1)) * 100))
    print(string.format(" - Clusters Processed:   %d", #clusterList))
    print(string.format(" - Average Speed:        %.1f parts/sec (%.0f parts/min)", 
        finalPhysicalCount / math.max(totalDuration, 0.001), (finalPhysicalCount / math.max(totalDuration, 0.001)) * 60))
    print(string.format(" - Score Spent:          $%d (Remaining: $%d)", math.max(initialScore - finalScore, 0), finalScore))
    print("================================================================================")
end

-- Run
runAutoBuildV15()
