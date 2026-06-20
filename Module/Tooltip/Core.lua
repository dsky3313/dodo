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
-- 에딧모드 모듈 마스터 토글 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "툴팁",
            get = function() return dodoDB and dodoDB.enableTooltip ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableTooltip = checked end
                dodo.UpdateTooltipAll()
            end
        }
    })
end
