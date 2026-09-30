--!strict
-- ==============================================================================
-- SIREN HEAD: LEGACY - Blueprint Exporter (Studio or In-Game)
-- ==============================================================================
-- Reads workspace.builds and exports BOTH:
--   1. Absolute coordinates (legacy format)
--   2. Relative offsets from a chosen anchor point
-- Outputs a portable .luau file that auto_build_v2.luau can load directly.
-- ==============================================================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local CONFIG = {
    ExcludeBasicTurret = true,
    
    -- Anchor mode:
    --   "player"   -> Use player's current HumanoidRootPart as anchor
    --   "centroid" -> Use the computed centroid of all builds as anchor
    --   "origin"   -> Use CFrame.identity as anchor (pure world coords)
    AnchorMode = "centroid",
    
    -- Output:
    OutputFileName = "blueprint_export",
    PrecisionDecimals = 2,
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function roundN(n: number, decimals: number): number
    local mult = 10 ^ decimals
    return math.round(n * mult) / mult
end

local function cfToCompact(cf: CFrame, decimals: number): string
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    return string.format("{%.2f, %.2f, %.2f, %.3f, %.3f, %.3f}",
        roundN(cf.Position.X, decimals),
        roundN(cf.Position.Y, decimals),
        roundN(cf.Position.Z, decimals),
        roundN(rx, 3), roundN(ry, 3), roundN(rz, 3)
    )
end

-- ============================================================================
-- SCAN workspace.builds
-- ============================================================================
local BuildsFolder = Workspace:FindFirstChild("builds")
if not BuildsFolder then
    error("[BlueprintExporter] workspace.builds not found!")
end

print("="..string.rep("=", 78))
print("[BlueprintExporter] Scanning workspace.builds...")
print("="..string.rep("=", 78))

type BuildEntry = {
    name: string,
    cframe: CFrame,
}

local entries: { BuildEntry } = {}
local excludedCount = 0

for _, obj in ipairs(BuildsFolder:GetChildren()) do
    local name = obj.Name
    if CONFIG.ExcludeBasicTurret and name == "Basic Turret" then
        excludedCount += 1
        continue
    end
    
    local cf: CFrame?
    if obj:IsA("Model") then
        cf = obj.PrimaryPart and obj.PrimaryPart.CFrame or obj:GetPivot()
    elseif obj:IsA("BasePart") then
        cf = obj.CFrame
    end
    
    if cf then
        table.insert(entries, { name = name, cframe = cf })
    end
end

print(string.format("[BlueprintExporter] Found %d structures (%d excluded)", #entries, excludedCount))

if #entries == 0 then
    warn("[BlueprintExporter] No structures to export!")
    return
end

-- ============================================================================
-- COMPUTE ANCHOR
-- ============================================================================
local anchorCF: CFrame

if CONFIG.AnchorMode == "player" then
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        anchorCF = hrp.CFrame
    else
        warn("[BlueprintExporter] No character found, falling back to centroid")
        CONFIG.AnchorMode = "centroid"
    end
end

if CONFIG.AnchorMode == "centroid" then
    local sum = Vector3.zero
    for _, entry in ipairs(entries) do
        sum += entry.cframe.Position
    end
    anchorCF = CFrame.new(sum / #entries)
elseif CONFIG.AnchorMode == "origin" then
    anchorCF = CFrame.identity
end

print(string.format("[BlueprintExporter] Anchor: %s at (%.1f, %.1f, %.1f)",
    CONFIG.AnchorMode, anchorCF.Position.X, anchorCF.Position.Y, anchorCF.Position.Z))

-- ============================================================================
-- GENERATE OUTPUT
-- ============================================================================
local lines: { string } = {}

table.insert(lines, "-- ==============================================================================")
table.insert(lines, string.format("-- SIREN HEAD: LEGACY - Exported Blueprint (%d parts)", #entries))
table.insert(lines, string.format("-- Anchor Mode: %s", CONFIG.AnchorMode))
table.insert(lines, string.format("-- Anchor Position: (%.2f, %.2f, %.2f)",
    anchorCF.Position.X, anchorCF.Position.Y, anchorCF.Position.Z))
table.insert(lines, string.format("-- Exported: %s", os.date("%Y-%m-%d %H:%M:%S")))
table.insert(lines, "-- ==============================================================================")
table.insert(lines, "")

-- Category breakdown
local catCounts: { [string]: number } = {}
for _, entry in ipairs(entries) do
    catCounts[entry.name] = (catCounts[entry.name] or 0) + 1
end

table.insert(lines, "-- Structure Breakdown:")
local sortedCats: { string } = {}
for cat, _ in pairs(catCounts) do table.insert(sortedCats, cat) end
table.sort(sortedCats, function(a, b) return (catCounts[a] or 0) > (catCounts[b] or 0) end)
for _, cat in ipairs(sortedCats) do
    table.insert(lines, string.format("--   %s: %d", cat, catCounts[cat]))
end
table.insert(lines, "")

-- Absolute data (legacy format)
table.insert(lines, "-- Format: {Category, X, Y, Z, RotX, RotY, RotZ}")
table.insert(lines, "local RAW_BUILD_DATA = {")
for _, entry in ipairs(entries) do
    local rx, ry, rz = entry.cframe:ToEulerAnglesXYZ()
    table.insert(lines, string.format('    {"%s", %.2f, %.2f, %.2f, %.3f, %.3f, %.3f},',
        entry.name,
        roundN(entry.cframe.Position.X, CONFIG.PrecisionDecimals),
        roundN(entry.cframe.Position.Y, CONFIG.PrecisionDecimals),
        roundN(entry.cframe.Position.Z, CONFIG.PrecisionDecimals),
        roundN(rx, 3), roundN(ry, 3), roundN(rz, 3)
    ))
end
table.insert(lines, "}")
table.insert(lines, "")

-- Relative data (V2 format)
table.insert(lines, "-- Relative offsets from anchor (for auto_build_v2.luau portable mode)")
table.insert(lines, "-- Format: {Category, dX, dY, dZ, RotX, RotY, RotZ}")
table.insert(lines, "local RELATIVE_BUILD_DATA = {")
for _, entry in ipairs(entries) do
    local localCF = anchorCF:ToObjectSpace(entry.cframe)
    local rx, ry, rz = localCF:ToEulerAnglesXYZ()
    table.insert(lines, string.format('    {"%s", %.2f, %.2f, %.2f, %.3f, %.3f, %.3f},',
        entry.name,
        roundN(localCF.Position.X, CONFIG.PrecisionDecimals),
        roundN(localCF.Position.Y, CONFIG.PrecisionDecimals),
        roundN(localCF.Position.Z, CONFIG.PrecisionDecimals),
        roundN(rx, 3), roundN(ry, 3), roundN(rz, 3)
    ))
end
table.insert(lines, "}")
table.insert(lines, "")
table.insert(lines, "return { absolute = RAW_BUILD_DATA, relative = RELATIVE_BUILD_DATA }")

local output = table.concat(lines, "\n")

local ok = pcall(function()
    writefile(CONFIG.OutputFileName .. ".luau", output)
end)

if ok then
    print(string.format("[BlueprintExporter] ✓ Saved to %s.luau (%d bytes, %d parts)",
        CONFIG.OutputFileName, #output, #entries))
else
    print("[BlueprintExporter] writefile unavailable, outputting to console:")
    print(output)
end

print("="..string.rep("=", 78))
