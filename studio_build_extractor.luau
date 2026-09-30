--!strict
-- ==============================================================================
-- ROBLOX STUDIO BUILD EXTRACTOR & ALL-IN-ONE RUNNER GENERATOR
-- ==============================================================================
-- Run this in Roblox Studio Command Bar.
-- It reads 'workspace.builds', extracts all positions into ultra-compact arrays,
-- and outputs a SINGLE self-contained, copy-pasteable script in ServerScriptService.MasterBuildRunner
-- ==============================================================================

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local Selection = game:GetService("Selection")

local BuildsFolder = Workspace:FindFirstChild("builds")
if not BuildsFolder then
    error("[StudioExporter] Could not find 'workspace.builds'! Make sure the folder exists.")
end

local EXCLUDE_BASIC_TURRET = true

print("================================================================================")
print("[StudioExporter] Scanning 'workspace.builds' in Roblox Studio...")
print("================================================================================")

type CompactItem = {
    c: string,
    x: number,
    y: number,
    z: number,
    rx: number,
    ry: number,
    rz: number,
}

local allItems: { CompactItem } = {}
local totalFound = 0
local excludedCount = 0

for _, obj in ipairs(BuildsFolder:GetChildren()) do
    local name = obj.Name
    if EXCLUDE_BASIC_TURRET and name == "Basic Turret" then
        excludedCount += 1
    else
        local cf: CFrame?
        if obj:IsA("Model") then
            cf = obj.PrimaryPart and obj.PrimaryPart.CFrame or obj:GetPivot()
        elseif obj:IsA("BasePart") then
            cf = obj.CFrame
        end

        if cf then
            totalFound += 1
            local rx, ry, rz = cf:ToEulerAnglesXYZ()
            table.insert(allItems, {
                c = name,
                x = math.round(cf.Position.X * 100) / 100,
                y = math.round(cf.Position.Y * 100) / 100,
                z = math.round(cf.Position.Z * 100) / 100,
                rx = math.round(rx * 1000) / 1000,
                ry = math.round(ry * 1000) / 1000,
                rz = math.round(rz * 1000) / 1000,
            })
        end
    end
end

print(string.format("[StudioExporter] Scan complete: %d valid parts found (Excluded: %d).", totalFound, excludedCount))

-- ==============================================================================
-- GENERATE ALL-IN-ONE COMBINED SCRIPT
-- ==============================================================================
local b = {}
local function w(s: string) table.insert(b, s) end

w("-- ==============================================================================")
w(string.format("-- ALL-IN-ONE BUILD RUNNER (Exported from Studio at %s)", os.date("%Y-%m-%d %H:%M:%S")))
w(string.format("-- Contains %d parts embedded directly into this single script.", totalFound))
w("-- Features: V15 True Wire-Speed Stream Pipelining (~55 parts/sec), Rapid Sweep, Dedicated Force-Fire.")
w("-- ==============================================================================")
w("")
w("local Workspace = game:GetService(\"Workspace\")")
w("local Players = game:GetService(\"Players\")")
w("local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")")
w("local StatsService = game:GetService(\"Stats\")")
w("local RunService = game:GetService(\"RunService\")")
w("")
w("local LocalPlayer = Players.LocalPlayer")
w("local Remotes = ReplicatedStorage:WaitForChild(\"remotes\")")
w("local BuildRemote = Remotes:WaitForChild(\"build\")")
w("local BuildsFolder = Workspace:WaitForChild(\"builds\")")
w("")
w("local CONFIG = {")
w("    AvoidOverlapping = true,")
w("    ClusterSeedRadius = 14.0,  -- Seed expansion radius for balanced centroids")
w("    MaxBuildRange = 14.5,      -- Strict spherical boundary (server limit: 16.0)")
w("    RepositionWait = 0.06,     -- Replication settle time on cluster hop (snappy)")
w("    PlacementDelay = 0.018,    -- True wire-speed stream dispatch (~55 parts/sec)")
w("    ClusterFlushWait = 0.04,   -- Brief socket flush between clusters")
w("    MaxForceAttempts = 4,      -- Dedicated point-blank Force-Fire attempts per stubborn part")
w("    AnchorWhileBuilding = true,")
w("}")
w("")
w("type BuildItem = { category: string, cframe: CFrame }")
w("")
w("-- Embedded Compact Build Data [Category, X, Y, Z, RotX, RotY, RotZ]")
w("local RAW_BUILD_DATA = {")

for _, item in ipairs(allItems) do
    w(string.format('    {"%s", %.2f, %.2f, %.2f, %.3f, %.3f, %.3f},',
        item.c, item.x, item.y, item.z, item.rx, item.ry, item.rz))
end

w("}")
w("")
w([[
-- Telemetry helpers
local function getLivePing(): number
    local pingItem = StatsService.Network.ServerStatsItem:FindFirstChild("Data Ping")
    return pingItem and math.round(pingItem:GetValue()) or 0
end

local function getAliveCharacter(): (Model, BasePart, Humanoid)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

    if not char or not hum or not hrp or hum.Health <= 0 then
        print("[AllInOne:WATCHDOG] Character down! Waiting for respawn...")
        char = LocalPlayer.CharacterAdded:Wait()
        hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
        hum = char:WaitForChild("Humanoid") :: Humanoid
        task.wait(1.5)
        print("[AllInOne:WATCHDOG] Respawned! Resuming placement...")
    end

    return char, hrp, hum
end

local function ensureAtPos(targetPos: Vector3)
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

type Cluster = {
    center: Vector3,
    items: { BuildItem },
}

local function executeCombinedBuild()
    print("================================================================================")
    print(string.format("[AllInOne Runner] Initializing V14 Fast-Cluster & Force-Fire Engine for %d Parts...", #RAW_BUILD_DATA))
    print("================================================================================")

    -- Step 1: Spatial Hash Bucket for exact Euclidean duplicate detection (< 1.0 stud)
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

    if CONFIG.AvoidOverlapping then
        for _, obj in ipairs(BuildsFolder:GetChildren()) do
            local p: Vector3?
            if obj:IsA("Model") then
                p = obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position
            elseif obj:IsA("BasePart") then
                p = obj.Position
            end
            if p then
                registerPosition(p)
            end
        end
    end

    -- Step 2: Decode compact coordinates, pre-filter against world, and self-deduplicate
    local unplaced: { BuildItem } = {}
    local skippedOccupied = 0

    for _, entry in ipairs(RAW_BUILD_DATA) do
        local cat = entry[1] :: string
        local x, y, z = entry[2] :: number, entry[3] :: number, entry[4] :: number
        local rx, ry, rz = entry[5] :: number, entry[6] :: number, entry[7] :: number
        local pos = Vector3.new(x, y, z)
        local cf = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)

        if CONFIG.AvoidOverlapping and isPositionOccupied(pos) then
            skippedOccupied += 1
        else
            table.insert(unplaced, { category = cat, cframe = cf })
            registerPosition(pos)
        end
    end

    local totalTarget = #unplaced
    print(string.format("[AllInOne Runner] Total: %d | Occupied (Skipped): %d | Ready to Place: %d",
        #RAW_BUILD_DATA, skippedOccupied, totalTarget))

    if totalTarget == 0 then
        print("[AllInOne Runner] All parts already placed! Nothing to do.")
        return
    end

    -- Step 3: Fast 14.5-Stud Spherical Greedy Clustering with Continuous TSP Chaining
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
            if (item.cframe.Position - seed.cframe.Position).Magnitude <= CONFIG.ClusterSeedRadius then
                sumPos += item.cframe.Position
                neighborCount += 1
            end
        end
        local centroid = (neighborCount > 0) and (sumPos / neighborCount) or seed.cframe.Position

        -- 3. Gather all items within CONFIG.MaxBuildRange (14.5 studs) of centroid
        local batch: { BuildItem } = {}
        local remaining: { BuildItem } = {}
        for _, item in ipairs(unplacedPool) do
            if (item.cframe.Position - centroid).Magnitude <= CONFIG.MaxBuildRange then
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

    print(string.format("[AllInOne Runner] Partitioned %d parts into %d Optimal Spherical Clusters (avg %.1f parts/cluster)",
        totalTarget, #clusterList, totalTarget / #clusterList))
    print(string.format("[AllInOne Runner] Launching V14 High-Speed Execution for %d parts...", totalTarget))

    -- Step 4: True Wire-Speed Cluster Stream Dispatch
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

            BuildRemote:FireServer(item.category, item.cframe)
            firedCount += 1

            task.wait(CONFIG.PlacementDelay)
        end

        -- Clean socket flush between clusters
        task.wait(CONFIG.ClusterFlushWait)

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
    print("\n[AllInOne Runner] Cluster stream dispatch complete! Waiting 1.0s for server replication...")
    local waitStart = os.clock()
    while (confirmedCount < firedCount) and (os.clock() - waitStart < 1.2) do
        task.wait(0.05)
    end

    -- Step 5: Physical Verification Helper
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

    -- Step 6: Rapid Pre-Sweep for Any Missing Parts
    local missing = getMissingItems()
    if #missing > 0 then
        print(string.format("\n[AllInOne Runner] Rapid Sweep Pass for %d unconfirmed parts...", #missing))
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

    -- Step 7: DEDICATED FORCE-FIRE ENGINE (If Dropped >= 2 Times)
    if #missing > 0 then
        print("================================================================================")
        print(string.format("[AllInOne Runner:FORCE-FIRE] Triggering Dedicated Force-Fire Engine for %d stubborn parts...", #missing))
        print("================================================================================")

        local forceSuccess = 0
        local forceFailed = 0

        for idx, item in ipairs(missing) do
            local confirmed = false

            for attempt = 1, CONFIG.MaxForceAttempts do
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
                    item.category, item.cframe.Position.X, item.cframe.Position.Y, item.cframe.Position.Z, CONFIG.MaxForceAttempts))
            end
        end

        print(string.format("[AllInOne Runner:FORCE-FIRE] Completed! %d force-placed, %d rejected.", forceSuccess, forceFailed))
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

    print("================================================================================")
    print(string.format("[AllInOne Runner] COMPLETED in %.2f seconds (%.2f minutes)!", totalDuration, totalDuration / 60))
    print(string.format(" - Target Parts:         %d", totalTarget))
    print(string.format(" - Total Dispatched:     %d", firedCount))
    print(string.format(" - Physically Confirmed: %d / %d (%.1f%%)", finalPhysicalCount, totalTarget, (finalPhysicalCount / math.max(totalTarget, 1)) * 100))
    print(string.format(" - Clusters Processed:   %d", #clusterList))
    print(string.format(" - Average Speed:        %.1f parts/sec (%.0f parts/min)", 
        finalPhysicalCount / math.max(totalDuration, 0.001), (finalPhysicalCount / math.max(totalDuration, 0.001)) * 60))
    print("================================================================================")
end

executeCombinedBuild()
]])

local allInOneCode = table.concat(b, "\n")

-- Write directly to ServerScriptService.MasterBuildRunner in Studio
local runnerScript = ServerScriptService:FindFirstChild("MasterBuildRunner") :: Script?
if not runnerScript then
    runnerScript = Instance.new("Script")
    runnerScript.Name = "MasterBuildRunner"
    runnerScript.Parent = ServerScriptService
end
runnerScript.Source = allInOneCode

Selection:Set({ runnerScript })

print("================================================================================")
print("[StudioExporter] SUCCESS!")
print(" -> Created all-in-one script in 'ServerScriptService.MasterBuildRunner'")
print(string.format(" -> Embedded all %d parts directly into the runner using compact arrays.", totalFound))
print(string.format(" -> Total Script Size: ~%d KB (Well under Studio's 64 KB limit).", math.round(#allInOneCode / 1024)))
print(" -> The script is selected in your Explorer window—ready to copy or run!")
print("================================================================================")
