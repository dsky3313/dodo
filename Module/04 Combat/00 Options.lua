-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 설정 기본값
-- ==============================
dodo.COMBAT_DEFAULTS = {
    enableCombat            = true,

    -- ResourceBar
    enableResourceBarModule = true,
    useResourceBar1         = true,
    useResourceBar2         = true,
    useResourceBarSmooth    = true,
    resourceBarWidth        = 272,
    resourceBarHeight       = 10,
    resourceBarFontSize     = 12,

    -- Debuff
    useDebuff               = true,
    debuffSize              = 56,
    debuffMax               = 6,
    debuffX                 = 350,
    debuffY                 = 0,

    -- BloodBrez
    useBloodBrez            = true,
    blbrIconSize            = 46,
    blbrIconPadding         = 2,

    -- Stance
    enableStance            = true,
    stanceIconSize          = 80,
}

-- ==============================
-- /dd 전투 설정 등록
-- ==============================
dodo.RegisterOption("전투", function(category)
    -- 마스터 토글
    local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableCombat", "전투 모듈 활성화",
        "전투 관련 모듈을 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableCombat = val end
        end)

    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end

    local layout = SettingsPanel:GetLayout(category)
    if layout and CreateSettingsButtonInitializer then
        local btn = CreateSettingsButtonInitializer("", "편집 모드 열기", function()
            SettingsPanel:Close(true)
            ShowUIPanel(EditModeManagerFrame)
        end, "편집 모드에서 전투 모듈의 위치와 크기를 조정할 수 있습니다.", false)
        layout:AddInitializer(btn)
        T(btn)
    end

    T(dodo.UI:SettingsCheckbox(category, "enableResourceBarModule", "자원바",
        "직업자원 막대와 보조자원 막대를 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableResourceBarModule = val end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useDebuff", "디버프 아이콘",
        "플레이어의 디버프를 아이콘으로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useDebuff = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "useBloodBrez", "블러드 & 전투부활",
        "블러드 디버프와 전투부활 현황을 추적합니다.",
        true, function(val)
            if dodoDB then dodoDB.useBloodBrez = val end
            if dodo.BloodBrez then dodo.BloodBrez() end
        end))

    T(dodo.UI:SettingsCheckbox(category, "enableStance", "태세 아이콘 ",
        "전사의 현재 태세를 아이콘으로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableStance = val end
            if dodo.StanceApply then dodo.StanceApply(val) end
        end))

    local function _shown() return master_setting:GetValue() end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 4000)

