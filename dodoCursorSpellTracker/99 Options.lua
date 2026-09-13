---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

dodo.RegisterOption("커서 스펠트래커", function(category)
    dodo.UI:SettingsCheckbox(category, "enableCursorSpellTracker", "커서 스펠 트래커",
        "현재 직업/특성의 주요 스킬을 커서 근처에 표시합니다.",
        true, function(val)
            dodoDB.enableCursorSpellTracker = val
            if dodo.CursorSpellTrackerSetEnabled then dodo.CursorSpellTrackerSetEnabled(val) end
        end)
end, 7000)
