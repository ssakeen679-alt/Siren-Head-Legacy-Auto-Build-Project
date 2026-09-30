--!strict
-- ==============================================================================
-- SIREN HEAD: LEGACY - Enhanced Infinite Stamina V2
-- ==============================================================================
-- Improvements over V1:
--   1. Uses Real MCP's gc-scan pattern (if available) for reliable table discovery
--   2. Applies to ALL character classes (default, Soldier, custom future ones)
--   3. Adds optional speed multiplier override
--   4. STATE-aware for live-reload compatibility
--   5. Periodic re-application watchdog (handles runtime table reconstruction)
-- ==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CONFIG = {
    -- Stamina overrides:
    Drain = 0,           -- 0 = no stamina loss while sprinting
    Stamina = 999999,    -- Massive stamina pool
    Regen = 999999,      -- Instant regeneration
    
    -- Optional speed override (nil = don't touch):
    SpeedMultiplier = nil, -- Set to e.g. 2.0 for double sprint speed
    
    -- Watchdog interval (seconds):
    RecheckInterval = 5.0,
    
    -- Debug output:
    Verbose = false,
}

-- ============================================================================
-- CORE: GC Table Patching
-- ============================================================================
local function findAndPatchStaminaTables(): number
    local ok, configs = pcall(function()
        return filtergc("table", {
            Keys = { "stamina", "drain", "regen", "multiplier" }
        })
    end)
    
    if not ok or not configs then
        -- Fallback: scan all tables manually via getgc
        local ok2, allTables = pcall(function()
            return getgc(true)
        end)
        if not ok2 or not allTables then
            if CONFIG.Verbose then
                warn("[Stamina V2] Neither filtergc nor getgc available!")
            end
            return 0
        end
        
        configs = {}
        for _, obj in ipairs(allTables) do
            if type(obj) == "table" then
                if rawget(obj, "stamina") and rawget(obj, "drain") and rawget(obj, "regen") then
                    table.insert(configs, obj)
                end
            end
        end
    end
    
    local count = 0
    for _, t in ipairs(configs) do
        if rawget(t, "drain") ~= nil and rawget(t, "stamina") ~= nil then
            -- Only patch if not already patched (avoid redundant writes)
            local needsPatch = false
            if t.drain ~= CONFIG.Drain then needsPatch = true end
            if t.stamina ~= CONFIG.Stamina then needsPatch = true end
            if t.regen ~= CONFIG.Regen then needsPatch = true end
            if CONFIG.SpeedMultiplier and t.multiplier ~= CONFIG.SpeedMultiplier then
                needsPatch = true
            end
            
            if needsPatch then
                t.drain = CONFIG.Drain
                t.stamina = CONFIG.Stamina
                t.regen = CONFIG.Regen
                if CONFIG.SpeedMultiplier then
                    t.multiplier = CONFIG.SpeedMultiplier
                end
                count += 1
                
                if CONFIG.Verbose then
                    -- Identify which class this belongs to
                    local className = "unknown"
                    for key, val in pairs(t) do
                        if type(key) == "string" and key ~= "stamina" and key ~= "drain" 
                           and key ~= "regen" and key ~= "multiplier" then
                            className = key
                            break
                        end
                    end
                    print(string.format("[Stamina V2] Patched config table (class: %s)", className))
                end
            end
        end
    end
    
    return count
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================
local localPlayer = Players.LocalPlayer
local heartbeatConn: RBXScriptConnection? = nil
local charAddedConn: RBXScriptConnection? = nil
local lastCheckTime = 0

-- Initial patch
local initialPatched = findAndPatchStaminaTables()
print(string.format("[Stamina V2] ✓ Unlimited stamina active! Patched %d config tables.", initialPatched))

-- Respawn handler
charAddedConn = localPlayer.CharacterAdded:Connect(function()
    task.wait(1.5) -- Allow sprint LocalScript to reinitialize
    local rePatched = findAndPatchStaminaTables()
    print(string.format("[Stamina V2] Character respawned → re-applied (%d tables).", rePatched))
end)

-- Periodic watchdog (catches runtime table reconstruction)
heartbeatConn = RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastCheckTime >= CONFIG.RecheckInterval then
        lastCheckTime = now
        local patched = findAndPatchStaminaTables()
        if patched > 0 and CONFIG.Verbose then
            print(string.format("[Stamina V2] Watchdog: re-patched %d tables", patched))
        end
    end
end)

-- STATE cleanup for live-reload compatibility
if STATE then
    STATE.onCleanup(function()
        if heartbeatConn then heartbeatConn:Disconnect() end
        if charAddedConn then charAddedConn:Disconnect() end
        print("[Stamina V2] Cleaned up for reload.")
    end)
end
