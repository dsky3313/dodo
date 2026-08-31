---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- /dd 전투 설정 등록
-- ==============================
dodo.RegisterOption("전투", function(category)
    local layout = SettingsPanel:GetLayout(category)
    if layout and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer("", "편집 모드 열기", function()
            SettingsPanel:Close(true)
            ShowUIPanel(EditModeManagerFrame)
        end, "편집 모드에서 dodo 모듈의 위치와 크기를 조정할 수 있습니다.", false))
    end

    dodo.UI:SettingsCheckbox(category, "enableResourceBarModule", "자원바 모듈 활성화",
        "직업자원 막대와 보조자원 막대를 활성화합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableResourceBarModule = val end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end)

    dodo.UI:SettingsCheckbox(category, "useDebuff", "디버프 아이콘 모듈 활성화",
        "플레이어에게 걸린 디버프를 아이콘으로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.useDebuff = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
        end)

    dodo.UI:SettingsCheckbox(category, "useBloodBrez", "블러드 & 전투부활 모듈 활성화",
        "영웅심 디버프와 전투부활 충전량을 추적합니다.",
        true, function(val)
            if dodoDB then dodoDB.useBloodBrez = val end
            if dodo.BloodBrez then dodo.BloodBrez() end
        end)

    dodo.UI:SettingsCheckbox(category, "enableStance", "태세 아이콘 모듈 활성화",
        "전사의 현재 태세를 아이콘으로 표시합니다.",
        true, function(val)
            if dodoDB then dodoDB.enableStance = val end
            if dodo.StanceApply then dodo.StanceApply(val) end
        end)
end, 4000)

-- ==============================
-- EditMode 시스템 설정 등록
-- ==============================
dodo.ResourceBarEditModeSettings = {
    {
        name = "직업자원 막대",
        get  = function() return dodoDB and dodoDB.useResourceBar1 ~= false end,
        set  = function(checked)
            if dodoDB then dodoDB.useResourceBar1 = checked end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end,
    },
    {
        name = "보조자원 막대",
        get  = function() return dodoDB and dodoDB.useResourceBar2 ~= false end,
        set  = function(checked)
            if dodoDB then dodoDB.useResourceBar2 = checked end
            if dodo.UpdateResourceBarVisibility then dodo.UpdateResourceBarVisibility() end
        end,
    },
    {
        name = "부드러운 증감",
        get  = function() return dodoDB and dodoDB.useResourceBarSmooth ~= false end,
        set  = function(checked)
            if dodoDB then dodoDB.useResourceBarSmooth = checked end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateSmooth then dodo.ResourceBar.UpdateSmooth() end
        end,
    },
    {
        name   = "바 가로 크기",
        type   = "slider",
        minVal = 200,
        maxVal = 300,
        step   = 2,
        get    = function() return dodoDB and dodoDB.resourceBarWidth or 272 end,
        set    = function(val)
            if dodoDB then dodoDB.resourceBarWidth = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
        end,
    },
    {
        name   = "바 세로 크기",
        type   = "slider",
        minVal = 6,
        maxVal = 20,
        step   = 1,
        get    = function() return dodoDB and dodoDB.resourceBarHeight or 10 end,
        set    = function(val)
            if dodoDB then dodoDB.resourceBarHeight = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
        end,
    },
    {
        name   = "수치 글자 크기",
        type   = "slider",
        minVal = 8,
        maxVal = 18,
        step   = 1,
        get    = function() return dodoDB and dodoDB.resourceBarFontSize or 12 end,
        set    = function(val)
            if dodoDB then dodoDB.resourceBarFontSize = val end
            if dodo.ResourceBar and dodo.ResourceBar.UpdateOption then dodo.ResourceBar.UpdateOption() end
        end,
    },
}

dodo.DebuffEditModeSettings = {
    {
        name     = "아이콘 크기",
        type     = "slider",
        get      = function() return dodoDB and dodoDB.debuffSize or 56 end,
        set      = function(val)
            if dodoDB then dodoDB.debuffSize = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
        end,
        minVal   = 30,
        maxVal   = 80,
        step     = 2,
        disabled = function() return dodoDB and dodoDB.useDebuff == false end,
    },
    {
        name     = "최대 표시 개수",
        type     = "slider",
        get      = function() return dodoDB and dodoDB.debuffMax or 6 end,
        set      = function(val)
            if dodoDB then dodoDB.debuffMax = val end
            if dodo.DebuffApply then dodo.DebuffApply() end
        end,
        minVal   = 1,
        maxVal   = 6,
        step     = 1,
        disabled = function() return dodoDB and dodoDB.useDebuff == false end,
    },
}

dodo.BloodBrezEditModeSettings = {
    {
        name   = "아이콘 크기",
        type   = "slider",
        get    = function() return dodoDB and dodoDB.blbrIconSize    or 46 end,
        set    = function(val)
            if dodoDB then dodoDB.blbrIconSize = val end
            if dodo.BloodBrezApplySize then dodo.BloodBrezApplySize() end
        end,
        minVal = 30,
        maxVal = 60,
        step   = 2,
        disabled = function() return dodoDB and dodoDB.useBloodBrez == false end,
    },
    {
        name   = "아이콘 간격",
        type   = "slider",
        get    = function() return dodoDB and dodoDB.blbrIconPadding or 2 end,
        set    = function(val)
            if dodoDB then dodoDB.blbrIconPadding = val end
            if dodo.BloodBrezApplySize then dodo.BloodBrezApplySize() end
        end,
        minVal = 0,
        maxVal = 10,
        step   = 1,
        disabled = function() return dodoDB and dodoDB.useBloodBrez == false end,
    },
}

dodo.StanceEditModeSettings = {
    {
        name   = "아이콘 크기",
        type   = "slider",
        get    = function() return dodoDB and dodoDB.stanceIconSize or 80 end,
        set    = function(val)
            if dodoDB then dodoDB.stanceIconSize = val end
            if dodo.StanceApplyIconSize then dodo.StanceApplyIconSize(val) end
        end,
        minVal = 40,
        maxVal = 100,
        step   = 2,
    },
}

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("ResourceBar", dodo.ResourceBarEditModeSettings)
    dodo.RegisterEditModeSystemSetting("Debuff",      dodo.DebuffEditModeSettings)
    dodo.RegisterEditModeSystemSetting("BloodBrez",   dodo.BloodBrezEditModeSettings)
    dodo.RegisterEditModeSystemSetting("Stance",      dodo.StanceEditModeSettings)
end
