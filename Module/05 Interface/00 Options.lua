-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 설정 기본값
-- ==============================
dodo.INTERFACE_DEFAULTS = {
    enableInterface         = true,

    -- 피해량 전투기
    enableDamageMeterAlways = true,
    dmgMeterSyncSize        = true,
    dmgMeterSnap            = true,
    dmgMeterResetButton     = true,

    -- 대화창
    useFontOutline          = true,
    useFontShadow           = false,
    useFontSize             = true,
    fontSize                = 13,
    useGuildButton          = true,
    useLinkURLs             = true,

    -- 미니맵
    useFPSFrame             = true,
    useIconAddons           = true,
    useCoord                = true,
    useMinimapSquare        = true,
    useResetMinimapZoom     = true,

    -- 툴팁
    useTooltipHealthHide    = true,
    useTooltipColor         = true,
    useTooltipID            = true,
    useTooltipIcon          = true,
    useTooltipMount         = true,
}

-- ==============================
-- 인터페이스 (마스터 토글)
-- ==============================
dodo.RegisterOption("인터페이스", function(category)
    local D = dodo.INTERFACE_DEFAULTS
    dodo.UI:SettingsCheckbox(category, "enableInterface", "인터페이스 모듈 활성화",
        "인터페이스와 관련된 추가적인 기능을 활성화합니다.",
        D.enableInterface, function(val)
            if dodoDB then dodoDB.enableInterface = val end
        end)
end, 4900)

-- ==============================
-- 인터페이스.피해량 전투기
-- ==============================
dodo.RegisterOption("인터페이스.피해량 전투기", function(category)
    local D = dodo.INTERFACE_DEFAULTS
    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end
    T(dodo.UI:SettingsCheckbox(category, "enableDamageMeterAlways", "항상 활성화",      "전투 외에도 피해량 전투기를 항상 표시합니다.",                       D.enableDamageMeterAlways, nil))
    T(dodo.UI:SettingsCheckbox(category, "dmgMeterSyncSize",        "창 크기 동기화",   "피해량 전투기 창 크기를 dodo와 동기화합니다.",                       D.dmgMeterSyncSize,        dodo.UpdateDamageMeterSyncState))
    T(dodo.UI:SettingsCheckbox(category, "dmgMeterSnap",            "창 붙이기",        "피해량 전투기 창을 화면 가장자리에 자동으로 붙입니다.",               D.dmgMeterSnap,            dodo.UpdateDamageMeterSyncState))
    T(dodo.UI:SettingsCheckbox(category, "dmgMeterResetButton",     "초기화 버튼 생성", "피해량 전투기에 전투 데이터 초기화 버튼을 추가합니다.",               D.dmgMeterResetButton,     dodo.UpdateDamageMeterResetState))
    local function _shown()
        local s = Settings.GetSetting("dodo_enableInterface")
        return s == nil or s:GetValue()
    end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 5000)

-- ==============================
-- 인터페이스.대화창
-- ==============================
dodo.RegisterOption("인터페이스.대화창", function(category)
    local D = dodo.INTERFACE_DEFAULTS
    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end
    T(dodo.UI:SettingsCheckbox(category, "useFontOutline",   "글씨 외곽선 적용", "대화창 글씨에 외곽선을 적용합니다.",                        D.useFontOutline,  dodo.UpdateChatFontState))
    T(dodo.UI:SettingsCheckbox(category, "useFontShadow",    "글씨 그림자 적용", "대화창 글씨에 그림자 효과를 적용합니다.",                    D.useFontShadow,   dodo.UpdateChatFontState))
    local _cb, _sl, _init = dodo.UI:SettingsCheckboxSlider(category, "useFontSize", "fontSize", "글씨 크기 변경", "대화창 글씨 크기를 조정합니다.", 10, 20, 1, D.useFontSize, D.fontSize, "Integer", dodo.UpdateChatFontState)
    T(_init)
    T(dodo.UI:SettingsCheckbox(category, "useGuildButton",   "길드원 버튼 표시", "대화창에 길드원 이름 버튼을 표시합니다.",                    D.useGuildButton,  dodo.UpdateChatGuildButtonState))
    T(dodo.UI:SettingsCheckbox(category, "useLinkURLs",      "URL 링크화",       "대화창에 입력된 URL을 클릭 가능한 링크로 변환합니다.",        D.useLinkURLs,     dodo.UpdateChatURLState))
    local function _shown()
        local s = Settings.GetSetting("dodo_enableInterface")
        return s == nil or s:GetValue()
    end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 5100)

-- ==============================
-- 인터페이스.미니맵
-- ==============================
dodo.RegisterOption("인터페이스.미니맵", function(category)
    local D = dodo.INTERFACE_DEFAULTS
    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end
    T(dodo.UI:SettingsCheckbox(category, "useFPSFrame",         "FPS/MS 표시",        "미니맵에 현재 FPS와 네트워크 지연(MS)을 표시합니다.",        D.useFPSFrame,         dodo.UpdateMinimapFPSState))
    T(dodo.UI:SettingsCheckbox(category, "useIconAddons",       "애드온 아이콘 모음", "미니맵 주변 애드온 아이콘을 한 곳에 모아 정리합니다.",       D.useIconAddons,       dodo.UpdateMinimapIconAddonsState))
    T(dodo.UI:SettingsCheckbox(category, "useCoord",            "좌표 표시",          "미니맵 아래에 플레이어 현재 좌표를 표시합니다.",              D.useCoord,            dodo.UpdateMinimapCoordState))
    T(dodo.UI:SettingsCheckbox(category, "useMinimapSquare",    "사각형 미니맵",      "둥근 미니맵을 사각형으로 변경합니다.",                        D.useMinimapSquare,    dodo.UpdateMinimapSquareState))
    T(dodo.UI:SettingsCheckbox(category, "useResetMinimapZoom", "줌 초기화",          "지역 이동 시 미니맵 확대/축소를 기본값으로 초기화합니다.",    D.useResetMinimapZoom, dodo.UpdateMinimapZoomState))
    local function _shown()
        local s = Settings.GetSetting("dodo_enableInterface")
        return s == nil or s:GetValue()
    end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 5200)

-- ==============================
-- 인터페이스.툴팁
-- ==============================
dodo.RegisterOption("인터페이스.툴팁", function(category)
    local D = dodo.INTERFACE_DEFAULTS
    local _sub = {}
    local function T(v) if v then _sub[#_sub+1] = v end return v end
    T(dodo.UI:SettingsCheckbox(category, "useTooltipHealthHide", "체력바 숨기기",  "툴팁 하단의 체력 막대를 숨깁니다.",                          D.useTooltipHealthHide, dodo.UpdateTooltipStatusBar))
    T(dodo.UI:SettingsCheckbox(category, "useTooltipColor",      "색상 변경",      "툴팁 배경 색상을 대상 반응도에 따라 변경합니다.",             D.useTooltipColor,      nil))
    T(dodo.UI:SettingsCheckbox(category, "useTooltipID",         "ID 표시",        "툴팁에 아이템·NPC·주문 ID를 표시합니다.",                    D.useTooltipID,         nil))
    T(dodo.UI:SettingsCheckbox(category, "useTooltipIcon",       "아이콘 표시",    "툴팁에 아이템 아이콘을 표시합니다.",                          D.useTooltipIcon,       nil))
    T(dodo.UI:SettingsCheckbox(category, "useTooltipMount",      "탈것 정보 표시", "탈것 툴팁에 탑승 방법과 속도 정보를 표시합니다.",             D.useTooltipMount,      nil))
    local function _shown()
        local s = Settings.GetSetting("dodo_enableInterface")
        return s == nil or s:GetValue()
    end
    for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end
end, 5300)
