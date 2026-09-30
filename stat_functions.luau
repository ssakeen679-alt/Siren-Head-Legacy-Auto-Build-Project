return {
    owns_upgrade = function(arg1, arg2, arg3) --[[ owns_upgrade ]] -- line: 5
        for _, val in next, string.split(arg1.Value, "|") do
            if val == arg2 .. ":" .. arg3 then
                return true
            end
        end

        return false
    end,
    count_upgrades = function(arg4, arg5, arg6, arg7) --[[ count_upgrades ]] -- line: 19
        local v3 = 0

        for _, val_1 in next, string.split(arg4.Value, "|") do
            local v6 = string.split(val_1, ":")
            local num = tonumber(v6[2])

            if v6[1] == arg5 then
                v3 = if not num then v3 else if not (arg6 <= num) then v3 else if not (arg7 >= num) then v3 else v3 + 1
            end
        end

        return v3
    end,
    get_gun_upgrade = function(arg8, arg9) --[[ get_gun_upgrade ]] -- line: 36
        for _, val_2 in next, string.split(arg8.Value, "|") do
            if val_2 ~= "" and val_2 ~= " " then
                local v9 = string.split(val_2, "=")
                local v10 = v9[1]
                local num_1 = tonumber(v9[2])

                if v10 == arg9 and num_1 then
                    return num_1
                end
            end
        end

        return 0
    end,
    change_gun_upgrade = function(arg10, arg11, arg12) --[[ change_gun_upgrade ]] -- line: 57
        local v11 = ""

        for _, val_3 in next, string.split(arg10.Value, "|") do
            if val_3 ~= "" and val_3 ~= " " then
                local v14 = string.split(val_3, "=")
                local v15 = v14[1]
                local num_2 = tonumber(v14[2])

                if v15 == arg11 then
                    v11 ..= v15 .. "=" .. num_2 + arg12 .. "|"
                else
                    v11 ..= v15 .. "=" .. num_2 .. "|"
                end
            end
        end

        return 0
    end,
    get_survivor_upgrades = function(arg13) --[[ get_survivor_upgrades ]] -- line: 83
        local t_1 = {}

        for _, val_4 in next, string.split(arg13.Value, "|") do
            local v18 = string.split(val_4, "=")
            t_1[v18[1]] = tonumber(v18[2])
        end

        return t_1
    end,
    get_setting = function(arg14, arg15) --[[ get_setting ]] -- line: 100
        for _, val_5 in next, string.split(arg14.Value, "|") do
            if val_5 ~= "" and val_5 ~= " " then
                local v22 = string.split(val_5, "=")

                if v22[1] == arg15 then
                    return v22[2]
                end
            end
        end
    end,
    set_setting = function(arg16, arg17, arg18) --[[ set_setting ]] -- line: 116
        local v23 = arg17 .. "=" .. tostring(arg18) .. "|"

        for _, val_6 in next, string.split(arg16.Value, "|") do
            if val_6 ~= "" and val_6 ~= " " and string.split(val_6, "=")[1] ~= arg17 then
                v23 ..= val_6 .. "|"
            end
        end

        return v23
    end
}

