-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 상태 업데이트 라우터
-- ==============================
function dodo.UpdateTooltipAll()
    if dodo.UpdateTooltipStatusBar then dodo.UpdateTooltipStatusBar() end
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.enableTooltip == nil then dodoDB.enableTooltip = true end
    if dodoDB.useTooltipHealthHide == nil then dodoDB.useTooltipHealthHide = true end
    if dodoDB.useTooltipID == nil then dodoDB.useTooltipID = true end
    if dodoDB.useTooltipColor == nil then dodoDB.useTooltipColor = true end
    if dodoDB.useTooltipMount == nil then dodoDB.useTooltipMount = true end
    if dodoDB.useTooltipIcon == nil then dodoDB.useTooltipIcon = true end

    dodo.UpdateTooltipAll()
end

local function on_event(self)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.RegisterOption("인터페이스.툴팁", function(category)
    dodo.UI:SettingsCheckbox(category, "useTooltipHealthHide", "체력바 숨기기",  "", true, dodo.UpdateTooltipStatusBar)
    dodo.UI:SettingsCheckbox(category, "useTooltipColor",      "색상 변경",      "", true, nil)
    dodo.UI:SettingsCheckbox(category, "useTooltipID",         "ID 표시",        "", true, nil)
    dodo.UI:SettingsCheckbox(category, "useTooltipIcon",       "아이콘 표시",    "", true, nil)
    dodo.UI:SettingsCheckbox(category, "useTooltipMount",      "탈것 정보 표시", "", true, nil)
end, 3900)
