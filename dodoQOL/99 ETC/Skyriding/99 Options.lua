---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

dodo.SK_DEFAULTS = {
    enableSkyriding   = true,
    skyridingBarWidth  = 209,
    skyridingBarHeight = 11,
    skyridingFontSize  = 16,
}

dodo.RegisterOption("하늘타기", function(category)
    local D = dodo.SK_DEFAULTS

    local _, master = dodo.UI:SettingsCheckbox(category, "enableSkyriding", "하늘타기 속도 HUD",
        "하늘타기 중 속도 바와 정수 충전 현황을 표시합니다.",
        D.enableSkyriding, function(val)
            if dodoDB then dodoDB.enableSkyriding = val end
            if dodo.SkyridingUpdateVisual then dodo.SkyridingUpdateVisual() end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    T(dodo.UI:SettingsSectionHeader(category, "외형"))
    T(dodo.UI:SettingsSlider(category, "skyridingBarWidth", "바 너비",
        "속도 바의 너비를 설정합니다.",
        80, 400, 1, D.skyridingBarWidth, "Integer", function(val)
            if dodoDB then dodoDB.skyridingBarWidth = val end
            if dodo.SkyridingApplySize then dodo.SkyridingApplySize() end
        end))
    T(dodo.UI:SettingsSlider(category, "skyridingBarHeight", "바 높이",
        "속도 바의 높이를 설정합니다.",
        4, 30, 1, D.skyridingBarHeight, "Integer", function(val)
            if dodoDB then dodoDB.skyridingBarHeight = val end
            if dodo.SkyridingApplySize then dodo.SkyridingApplySize() end
        end))
    T(dodo.UI:SettingsSlider(category, "skyridingFontSize", "글꼴 크기",
        "속도 텍스트 글꼴 크기를 설정합니다.",
        8, 30, 1, D.skyridingFontSize, "Integer", function(val)
            if dodoDB then dodoDB.skyridingFontSize = val end
            if dodo.SkyridingApplyFont then dodo.SkyridingApplyFont() end
        end))

    local function _shown() return master:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 9500)
