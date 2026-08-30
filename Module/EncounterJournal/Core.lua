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
dodo.RegisterOption("편의기능.모험안내서", function(category)
    dodo.UI:SettingsCheckbox(category, "enableEJAchievements", "업적 탭 활성화", "모험 안내서에 업적 탭을 추가합니다.", true, function() end)
    dodo.UI:SettingsCheckbox(category, "enableEJID", "ID 표시", "모험 안내서에 우두머리와 능력의 ID를 표시합니다.", true, function() dodo.EJID.SetEnabled(dodoDB.enableEJID ~= false) end)
end, 7500)

