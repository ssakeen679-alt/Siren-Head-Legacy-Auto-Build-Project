-- ==============================================================================
-- SIREN HEAD: LEGACY - Unlimited Stamina Script (Real / UNC Exploit API)
-- ==============================================================================
-- Technical Mechanics:
-- The client sprint loop ('Players.<LocalPlayer>.PlayerGui.sprint.LocalScript')
-- references a static configuration table:
--   v11 = {
--       default = { stamina = 100, drain = 9, regen = 12, multiplier = 1.5 },
--       Soldier = { stamina = 150, drain = 6, regen = 15, multiplier = 1.75 }
--   }
-- During the Heartbeat step:
--   if sprinting then
--       currentStamina -= v22.drain * speedRatio * dt
--   end
--
-- By querying the Luau Garbage Collector with `filtergc` (or extended debug library),
-- we locate all instances of this configuration table and modify:
--   - drain = 0       (stamina never decreases while sprinting)
--   - stamina = 999999 (immense stamina reserve)
--   - regen = 999999   (instantaneous regeneration)
-- ==============================================================================

local function applyInfiniteStamina()
    -- Native Real / UNC GC filter matching tables with stamina config keys
    local configs = filtergc("table", {
        Keys = { "stamina", "drain", "regen", "multiplier" }
    })
    
    local count = 0
    for _, t in ipairs(configs) do
        if rawget(t, "drain") and rawget(t, "stamina") then
            t.drain = 0
            t.stamina = 999999
            t.regen = 999999
            count = count + 1
        end
    end
    return count
end

-- Immediate execution
local initialPatched = applyInfiniteStamina()
print(string.format("[Stamina] Unlimited stamina active! Patched %d configuration tables.", initialPatched))

-- Persist across player respawns
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

localPlayer.CharacterAdded:Connect(function()
    task.wait(1.5) -- Allow PlayerGui.sprint.LocalScript to reinitialize
    local rePatched = applyInfiniteStamina()
    print(string.format("[Stamina] Character respawned. Re-applied stamina patch (%d tables).", rePatched))
end)
