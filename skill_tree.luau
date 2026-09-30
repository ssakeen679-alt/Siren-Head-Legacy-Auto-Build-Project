local t = {
    root = {
        slot = 4,
        title = "UNLOCK POTENTIAL",
        description = "Open this monster's tree. Nothing below can be bought without it."
    },
    root_price = 100,
    health_from = 10,
    health_to = 29,
    damage_from = 30,
    damage_to = 49,
    ability_price = 1000
}
t.branch_totals = {
    defence = {
        { stat = "health", label = "Health", title = "MARROW", total = 0.5 },
        { stat = "stamina", label = "Stamina", title = "ENDURANCE", total = 1 }
    },
    offence = {
        { stat = "damage", label = "Damage", title = "FEROCITY", total = 0.5 },
        { stat = "sprint", label = "Sprint Speed", title = "SWIFTNESS", total = 0.5 }
    }
}
t.stat_ramp_from = 1
t.stat_ramp_to = 5
t.stat_price_from = 25
t.stat_price_to = 250
t.spur_pips = 3
t.node_step = 11
t.abilities = {
    ["Long Horse"] = {
        {
            slot = 1,
            arm = "offence",
            title = "DASH",
            description = "Charge forward. Anything you run through takes 200 base damage. 8 second cooldown."
        },
        {
            slot = 2,
            arm = "defence",
            title = "HEALING SCREAM",
            description = "Restore health to everyone within 100 studs. 15 second cooldown."
        },
        {
            slot = 3,
            arm = "offence",
            title = "DREAM",
            description = "Drag everyone within 100 studs into the dream with you. 90 second cooldown."
        }
    },
    ["Cartoon Cat"] = {
        {
            slot = 1,
            arm = "offence",
            title = "POUNCE",
            description = "Leap into the air and pounce onto a target to deal 50 base damage. 5 second cooldown."
        },
        {
            slot = 2,
            arm = "defence",
            title = "SCREAM",
            description = "Every survivor within 100 studs is shaken off their feet, and you regenerate 15% of your health. 25 second cooldown."
        },
        {
            slot = 3,
            arm = "offence",
            title = "STRETCH",
            description = "Stretch your arm in order to catch a survivor and then reel them back to you."
        }
    },
    ["Siren Head"] = {
        {
            slot = 1,
            arm = "offence",
            title = "THROW BOULDER",
            description = "Throw a boulder that deals 70 damage. 6 second cooldown."
        },
        {
            slot = 3,
            arm = "defence",
            title = "SIREN SCREAM",
            description = "Heal yourself for 2% max health a second for 15 seconds. 40 second cooldown."
        }
    },
    ["Mega Horn"] = {
        {
            slot = 1,
            arm = "defence",
            title = "ROAR",
            description = "15 damage and a slow drag inward for everyone within 40 studs. 14 second cooldown."
        },
        {
            slot = 3,
            arm = "offence",
            title = "SONIC WAVE",
            description = "A wave that keeps hitting for 8 damage a tick as it passes through. 8 second cooldown."
        }
    }
}

local _ = function(arg1, arg2) --[[ wobble ]] -- line: 95
    local v1 = math.sin(arg1 * 12.9898) * 43758.5453

    return (v1 - math.floor(v1) - 0.5) * 2 * arg2
end

function t.is_stat(arg3) -- line: 102
    -- upvalues:
    --  [1] t (copy)

    return arg3 >= t.health_from and arg3 <= t.health_to or arg3 >= t.damage_from and arg3 <= t.damage_to
end

function t.stat_progress(arg4) -- line: 110
    -- upvalues:
    --  [1] t (copy)

    local v3 = arg4 >= t.damage_from and true
    local v4 = v3 and t.damage_from or t.health_from
    local v5 = v3 and t.damage_to or t.health_to

    return (arg4 - v4) / math.max(v5 - v4, 1)
end

function t.arm_of(arg5) -- line: 119
    -- upvalues:
    --  [1] t (copy)

    if arg5 >= t.damage_from then
        return "offence"
    end

    return "defence"
end

local _ = function(arg6) --[[ ramp_at ]] -- line: 124
    -- upvalues:
    --  [1] t (copy)

    return t.stat_ramp_from + (t.stat_ramp_to - t.stat_ramp_from) * arg6
end

function t.stat_of(arg7) -- line: 131
    -- upvalues:
    --  [1] t (copy)

    local v7 = t.branch_totals[t.arm_of(arg7)]

    return v7[(arg7 - (arg7 >= t.damage_from and t.damage_from or t.health_from)) % #v7 + 1]
end

local function ramp_sum(arg8, arg9) -- line: 141
    -- upvalues:
    --  [1] t (copy)

    local v9 = t.health_to - t.health_from + 1
    local v10 = 0

    for index = 0, v9 - 1 do
        if index % arg8 == arg9 then
            v10 += t.stat_ramp_from + (t.stat_ramp_to - t.stat_ramp_from) * (index / math.max(
                v9 - 1,
                1
            ))
        end
    end

    return v10
end

function t.share_of(arg10, arg11) -- line: 158
    -- upvalues:
    --  [1] t (copy)
    --  [2] ramp_sum (copy)

    if t.is_stat(arg10) then
        if t.stat_of(arg10).stat ~= arg11 then
            return 0
        end

        local v11 = t.branch_totals[t.arm_of(arg10)]
        local v12 = arg10 >= t.damage_from and t.damage_from or t.health_from

        return t.stat_of(arg10).total * (t.stat_ramp_from + (t.stat_ramp_to - t.stat_ramp_from) * t.stat_progress(
            arg10
        )) / ramp_sum(#v11, (arg10 - v12) % #v11)
    else
        return 0
    end
end

function t.describe(arg12) -- line: 173
    -- upvalues:
    --  [1] t (copy)

    local v15 = t.stat_of(arg12)

    return string.format("+%.1f%% %s.", t.share_of(arg12, v15.stat) * 100, v15.label)
end

function t.prerequisites(arg13) -- line: 182
    -- upvalues:
    --  [1] t (copy)

    local v16 = t.layout(arg13)

    if not v16 then
        return nil
    end

    local t_3 = {}

    for _, val in ipairs(v16) do
        if val.parent > 0 then
            t_3[val.slot] = v16[val.parent].slot
        end
    end

    return t_3
end

function t.price_of(arg14, arg15) -- line: 202
    -- upvalues:
    --  [1] t (copy)

    local v17 = t.abilities[arg14]

    if not v17 then
        return nil
    end

    if arg15 == t.root.slot then
        return t.root_price
    end

    for _, val_1 in next, v17 do
        if val_1.slot == arg15 then
            return t.ability_price
        end
    end

    if t.is_stat(arg15) then
        return math.floor(
            (t.stat_price_from + (t.stat_price_to - t.stat_price_from) * t.stat_progress(arg15)) / 5 + 0.5
        ) * 5
    end

    return nil
end

function t.layout(arg16) -- line: 239
    -- upvalues:
    --  [1] t (copy)

    local v19 = t.abilities[arg16]

    if not v19 then
        return nil
    end

    local t_4 = {
        {
            kind = "root",
            slot = t.root.slot,
            title = t.root.title,
            description = t.root.description,
            offset = Vector2.new(0, 0),
            parent = 0
        }
    }
    local t_6 = {}
    local t_7 = {}

    for key_2, val_2 in ipairs(v19) do
        local v22 = (val_2.arm == "defence" or not val_2.arm and key_2 % 2 == 1) and t_6 or t_7
        table.insert(v22, val_2)
    end

    local v23 = t.health_to - t.health_from + 1

    local function branch(
        arg17,
        arg18,
        _,
        arg20,
        arg21
    ) -- line: 280
        -- upvalues:
        --  [1] v23 (copy)
        --  [2] t (ref)
        --  [3] t_4 (copy)

        local v24 = v23 - #arg21 * t.spur_pips
        local v25 = math.floor(v24 / (#arg21 + 1))
        local v26 = arg17 - 1
        local v27 = 1
        local v28 = 0
        local v29 = Vector2.new(0, 0)

        local _ = function() --[[ take ]] -- line: 289
            -- upvalues:
            --  [1] v26 (ref)

            v26 += 1

            return v26
        end

        local _ = function(arg22, arg23) --[[ walk ]] -- line: 295
            -- upvalues:
            --  [1] t (ref)

            return arg22 + Vector2.new(math.sin(arg23), (math.cos(arg23))) * t.node_step
        end

        for index_1 = 0, v24 - 1 do
            v26 += 1
            local v32 = v26
            local v33 = arg18 * 0.5

            if index_1 > 0 then
                local v34 = arg18 * (math.sin(index_1 * 0.7) * 0.4 + 0.5)
                local v35 = math.sin(v32 * 12.9898) * 43758.5453
                v33 = v34 + (v35 - math.floor(v35) - 0.5) * 2 * 0.2
            end

            v29 += Vector2.new(math.sin(v33), (math.cos(v33))) * t.node_step
            local v38 = t_4
            local t_8 = {
                kind = "stat",
                slot = v32,
                arm = arg20,
                title = t.stat_of(v32).title,
                description = t.describe(v32),
                offset = v29,
                parent = v27
            }
            table.insert(v38, t_8)
            v27 = #t_4
            local v41 = #arg21
            local _ = math.cos(v33)

            if v28 < v41 then
                local v43 = index_1 + 1
                local v44 = v43 % v25

                if v44 == 0 then
                    v28 += 1
                    v44 = v27
                    v43 = v29

                    for index_2 = 1, t.spur_pips + 1 do
                        local v45 = index_2 > t.spur_pips and arg21[v28] or nil
                        local v46 = v45.slot
                        local _ = t.spur_pips + 1

                        if not v45 or not v46 then
                            v26 += 1
                            v46 = v26
                        end

                        local v48 = arg18 * (1.5707963267948966 + math.sin(index_2 * 1.1) * 0.35)
                        local v49 = math.sin((v46 + 97) * 12.9898) * 43758.5453
                        local v50 = v48 + (v49 - math.floor(v49) - 0.5) * 2 * 0.18
                        v43 += Vector2.new(math.sin(v50), (math.cos(v50))) * t.node_step
                        local t_9 = {
                            kind = nil,
                            slot = nil,
                            arm = nil,
                            title = nil,
                            description = nil,
                            offset = nil,
                            parent = nil
                        }
                        local v53 = t_4
                        local _ = math.cos(v50)
                        local _ = v49 - math.floor(v49) - 0.5
                        local _ = v49 - math.floor(v49)
                        local _ = math.floor(v49)
                        t_9.kind = if v45 then "ability" else "stat"
                        t_9.slot = v46
                        t_9.arm = arg20
                        t_9.title = v45 and v45.title or t.stat_of(v46).title
                        t_9.description = v45 and v45.description or t.describe(v46)
                        t_9.offset = v43
                        t_9.parent = v44
                        table.insert(v53, t_9)
                        v44 = #t_4
                    end
                end
            end
        end
    end

    branch(
        t.health_from,
        -1,
        "MARROW",
        "defence",
        t_6
    )
    branch(
        t.damage_from,
        1,
        "FEROCITY",
        "offence",
        t_7
    )

    return t_4
end

return t

