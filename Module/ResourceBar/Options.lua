---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local RB = dodo.ResourceBar

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("자원 막대 (미완 ^^;)", function(category)
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableResourceBarModule", "자원 막대 모듈 활성화",
        "직업자원 막대와 보조자원 막대를 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableResourceBarModule = val end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    T(dodo.UI:SettingsSectionHeader(category, "구성"))

    T(dodo.UI:SettingsCheckbox(category, "useResourceBar1", "직업자원 막대",
        "1번 막대 — 현재 직업/전문화의 주 자원(마나·분노·기력 등)을 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useResourceBar1 = val end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useResourceBar2", "보조자원 막대",
        "2번 막대 — 특성에 따라 룬·콤보 점수·지속시간·중첩 등을 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useResourceBar2 = val end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useResourceBarSmooth", "부드러운 증감",
        "자원 수치 변화 시 막대가 부드럽게 이동합니다.",
        true, function(val)
            if dodoDB then dodoDB.useResourceBarSmooth = val end
            if RB and RB.UpdateSmooth then RB.UpdateSmooth() end
        end))

    T(dodo.UI:SettingsSectionHeader(category, "크기"))

    T(dodo.UI:SettingsSlider(category, "resourceBarWidth", "가로 크기",
        "막대의 가로 길이(픽셀)를 조정합니다.",
        200, 300, 2, 272, nil, function(val)
            if dodoDB then dodoDB.resourceBarWidth = val end
            if RB and RB.UpdateOption then RB.UpdateOption() end
        end))

    T(dodo.UI:SettingsSlider(category, "resourceBarHeight", "세로 크기",
        "1번 막대의 세로 두께(픽셀)를 조정합니다.",
        6, 20, 1, 10, nil, function(val)
            if dodoDB then dodoDB.resourceBarHeight = val end
            if RB and RB.UpdateOption then RB.UpdateOption() end
        end))

    T(dodo.UI:SettingsSlider(category, "resourceBarFontSize", "수치 글자 크기",
        "막대에 표시되는 수치의 글자 크기를 조정합니다.",
        8, 18, 1, 12, nil, function(val)
            if dodoDB then dodoDB.resourceBarFontSize = val end
            if RB and RB.UpdateOption then RB.UpdateOption() end
        end))

    local function _shown() return master_setting:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 2000)
