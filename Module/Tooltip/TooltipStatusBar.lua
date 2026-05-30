-- ==============================
-- Inspired
-- ==============================
-- Enhance QoL (https://www.curseforge.com/wow/addons/eqol)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local GameTooltipStatusBar = GameTooltipStatusBar
local hooksecurefunc = hooksecurefunc
local UnitExists = UnitExists

-- ==============================
-- 로컬 상태 및 업데이트
-- ==============================
local function update_statusbar()
    local is_enabled = (dodoDB.enableTooltip ~= false and dodoDB.useTooltipHealthHide ~= false)
    if is_enabled then
        GameTooltipStatusBar:Hide()
    else
        if not GameTooltipStatusBar:IsShown() and UnitExists("mouseover") then
            GameTooltipStatusBar:Show()
        end
    end
end

dodo.UpdateTooltipStatusBar = update_statusbar

local function on_tooltip_statusbar_show(self) 
    if dodoDB.enableTooltip ~= false and dodoDB.useTooltipHealthHide ~= false then 
        self:Hide() 
    end 
end

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.useTooltipHealthHide == nil then dodoDB.useTooltipHealthHide = true end
    update_statusbar()
    hooksecurefunc(GameTooltipStatusBar, "Show", on_tooltip_statusbar_show)
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting("Tooltip", {
        {
            name = "체력바 숨기기",
            get = function() return dodoDB and dodoDB.useTooltipHealthHide ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useTooltipHealthHide = checked end
                update_statusbar()
            end,
            disabled = function() return dodoDB and dodoDB.enableTooltip == false end,
        }
    })
end
