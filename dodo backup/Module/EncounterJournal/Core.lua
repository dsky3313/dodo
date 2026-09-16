-- ==============================
-- Inspired
-- ==============================
-- RefineUI (Modules/EncounterAchievements/UI.lua)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.EJAchievements = dodo.EJAchievements or {}
local M = dodo.EJAchievements

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodoDB.enableEJAchievements == nil then dodoDB.enableEJAchievements = true end
    if M.SetEnabled then M.SetEnabled(dodoDB.enableEJAchievements) end
end

local init_frame = CreateFrame("Frame")

local function on_event(self)
    initialize()
    self:UnregisterEvent("PLAYER_LOGIN")
end

init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

