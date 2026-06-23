-- ==============================
-- Inspired
-- ==============================
-- EXBoss

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local INSTANCE_EVENTS = dodo.EncounterEvents

-- ==============================
-- 캐싱
-- ==============================
local C_EncounterEvents = C_EncounterEvents
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local IsInInstance = IsInInstance
local ipairs = ipairs

-- ==============================
-- 기능 1: 색상 적용/해제
-- ==============================
local current_events = nil -- 현재 적용된 이벤트 목록 (해제 시 사용)

local function clear_current()
    if not (C_EncounterEvents and C_EncounterEvents.SetEventColor) then return end
    if not current_events then return end
    -- SetEventColor가 ENCOUNTER_TIMELINE_STATE_UPDATED를 sync 발화 → tainted C_Timer chain 차단
    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, entry in ipairs(current_events) do
        C_EncounterEvents.SetEventColor(entry.eventID, 0, nil)
        C_EncounterEvents.SetEventColor(entry.eventID, 1, nil)
        C_EncounterEvents.SetEventColor(entry.eventID, 2, nil)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = nil
end

local function update_visual()
    clear_current()
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterTimelineColor ~= false) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID = select(8, GetInstanceInfo())
    local events = INSTANCE_EVENTS[mapID]
    if not events then return end

    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, entry in ipairs(events) do
        local role = dodo.Colors.EncounterColor and dodo.Colors.EncounterColor[entry.role]
        local color = role and CreateColor(role.r, role.g, role.b)
        C_EncounterEvents.SetEventColor(entry.eventID, 0, color)
        C_EncounterEvents.SetEventColor(entry.eventID, 1, color)
        local highlight_color = (dodoDB.useEncounterTimelineColorHighlight == false) and color or nil
        C_EncounterEvents.SetEventColor(entry.eventID, 2, highlight_color)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = events
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableEncounterTimelineColor == nil then dodoDB.enableEncounterTimelineColor = true end
        if dodoDB.useEncounterTimelineColorHighlight == nil then dodoDB.useEncounterTimelineColorHighlight = true end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_visual()
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.EncounterEvents, {
        {
            name = "막대 색상 변경",
            get = function() return dodoDB and dodoDB.enableEncounterTimelineColor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableEncounterTimelineColor = checked end
                update_visual()
                local panel = _G.dodoEditModeSystemPanel
                if panel and panel.UpdateDisabledStates then panel:UpdateDisabledStates() end
            end,
            disabled = function() return not dodo.Encounter.IsEnabled() end,
        },
        {
            name = "막대 색상 변경 (5초 전)",
            get = function() return dodoDB and dodoDB.useEncounterTimelineColorHighlight ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useEncounterTimelineColorHighlight = checked end
                update_visual()
            end,
            disabled = function() return not dodo.Encounter.IsEnabled() or dodoDB.enableEncounterTimelineColor == false end,
        },
    })
end
