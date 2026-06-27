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
local applied_eids   = {} -- 실제 적용한 encounterEventID 목록 (해제용)

local function clear_current()
    if not (C_EncounterEvents and C_EncounterEvents.SetEventColor) then return end
    if not current_events then return end
    -- SetEventColor가 ENCOUNTER_TIMELINE_STATE_UPDATED를 sync 발화 → tainted C_Timer chain 차단
    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, eid in ipairs(applied_eids) do
        C_EncounterEvents.SetEventColor(eid, 0, nil)
        C_EncounterEvents.SetEventColor(eid, 1, nil)
        C_EncounterEvents.SetEventColor(eid, 2, nil)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    applied_eids   = {}
    current_events = nil
end

local function update_visual()
    clear_current()
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterTimelineColor ~= false) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID   = select(8, GetInstanceInfo())
    local boss_ids = dodo.EncounterMapBosses and dodo.EncounterMapBosses[mapID]
    if not boss_ids then return end

    -- spellID → encounterEventID 맵 (신규 형식 지원)
    local spell_map = {}
    if C_EncounterEvents.GetEventList and C_EncounterEvents.GetEventInfo then
        for _, id in ipairs(C_EncounterEvents.GetEventList()) do
            local info = C_EncounterEvents.GetEventInfo(id)
            if info and info.spellID and info.spellID ~= 0 then
                spell_map[info.spellID] = id
            end
        end
    end

    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    local all_events = {}
    for _, eid in ipairs(boss_ids) do
        local boss_data = dodo.EncounterData and dodo.EncounterData[eid]
        if boss_data and boss_data.events then
            for _, ev in ipairs(boss_data.events) do
                all_events[#all_events + 1] = ev
            end
        end
    end
    applied_eids = {}
    for _, entry in ipairs(all_events) do
        local encounter_eid = entry.eventID or (entry.spellID and spell_map[entry.spellID])
        if encounter_eid then
            local role = dodo.Colors.EncounterColor and dodo.Colors.EncounterColor[entry.role]
            local color = role and CreateColor(role.r, role.g, role.b)
            C_EncounterEvents.SetEventColor(encounter_eid, 0, color)
            C_EncounterEvents.SetEventColor(encounter_eid, 1, color)
            local highlight_color = (dodoDB.useEncounterTimelineColorHighlight == false) and color or nil
            C_EncounterEvents.SetEventColor(encounter_eid, 2, highlight_color)
            applied_eids[#applied_eids + 1] = encounter_eid
        end
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = all_events
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
