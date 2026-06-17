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

-- ==============================
-- 설정 등록
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox

local function update_state()
    if M.SetEnabled then M.SetEnabled(dodoDB and dodoDB.enableEJAchievements ~= false) end
end

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["편의기능"] = dodo.OptionRegistrations["편의기능"] or {}
table.insert(dodo.OptionRegistrations["편의기능"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("편의기능"))
    Checkbox(category, "enableEJAchievements", "모험안내서 업적탭", "모험안내서에서 던전과 관련된 업적을 확인할 수 있습니다.", true, update_state)
end)
