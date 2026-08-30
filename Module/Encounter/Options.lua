---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.RegisterOption("우두머리 경보 (미완 ^^;)", function(category)
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableEncounter", "우두머리 경보 활성화",
        "우두머리 경보 타임라인 기능을 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableEncounter = val end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    T(dodo.UI:SettingsSectionHeader(category, "소리"))

    T(dodo.UI:SettingsCheckbox(category, "enableEncounterSound", "소리 알림",
        "우두머리 기술 타임라인 이벤트에 맞게 소리를 재생합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableEncounterSound = val end
            if dodo.EncounterApplySounds then dodo.EncounterApplySounds() end
        end))

    T(dodo.UI:SettingsSectionHeader(category, "텍스트 알림"))

    T(dodo.UI:SettingsCheckbox(category, "enableEncounterText", "텍스트 알림",
        "우두머리 기술이 시전될 때 화면에 텍스트 알림을 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableEncounterText = val end
        end))

    T(dodo.UI:SettingsSlider(category, "encounterTextIconSize", "아이콘 크기",
        "텍스트 알림의 아이콘 크기를 조정합니다.",
        16, 48, 1, 30, "Integer", function(val)
            if dodoDB then dodoDB.encounterTextIconSize = val end
            if dodo.EncounterRefreshText then dodo.EncounterRefreshText() end
        end))

    T(dodo.UI:SettingsSlider(category, "encounterTextFontSize", "텍스트 크기",
        "텍스트 알림의 글씨 크기를 조정합니다.",
        10, 24, 1, 15, "Integer", function(val)
            if dodoDB then dodoDB.encounterTextFontSize = val end
            if dodo.EncounterRefreshText then dodo.EncounterRefreshText() end
        end))

    local function _shown() return master_setting:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 3000)
