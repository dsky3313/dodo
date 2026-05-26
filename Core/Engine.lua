-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
_G[addonName] = dodo

dodo.Core = dodo.Core or {}
dodo.Config = dodo.Config or {}
dodo.Modules = dodo.Modules or {}
dodo.ModuleRegistry = dodo.ModuleRegistry or {}
dodo.UI = dodo.UI or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local engine = CreateFrame("Frame")

local function on_event(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodoDB
        if dodo.OnInitialize then dodo:OnInitialize() end
    elseif event == "PLAYER_LOGIN" then
        if dodo.OnEnable then dodo:OnEnable() end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

engine:SetScript("OnEvent", on_event)
engine:RegisterEvent("ADDON_LOADED")
engine:RegisterEvent("PLAYER_LOGIN")