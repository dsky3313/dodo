-- ==============================
-- Inspired
-- ==============================
-- EXBoss (https://www.curseforge.com/wow/addons/exboss)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
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

local dodoColors = dodo.Colors

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
    if dodoDB.enableEncounterTimelineColor == false then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID   = select(8, GetInstanceInfo())
    local boss_ids = dodo.EncounterMapBosses and dodo.EncounterMapBosses[mapID]
    if not boss_ids then return end

    local spell_map = dodo.Encounter.GetSpellMap()

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
        local eids = entry.eventID and { entry.eventID }
            or (entry.spellID and spell_map[entry.spellID])
        if eids then
            local role = dodoColors.Encounter and dodoColors.Encounter[entry.role]
            local color = role and CreateColor(role.r, role.g, role.b)
            local highlight_color = (dodoDB.useEncounterTimelineColorHighlight == false) and color or nil
            for _, encounter_eid in ipairs(eids) do
                C_EncounterEvents.SetEventColor(encounter_eid, 0, color)
                C_EncounterEvents.SetEventColor(encounter_eid, 1, color)
                C_EncounterEvents.SetEventColor(encounter_eid, 2, highlight_color)
                applied_eids[#applied_eids + 1] = encounter_eid
            end
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
    if event == "PLAYER_LOGIN" then
        local D = dodo.EC_DEFAULTS
        if dodoDB.enableEncounterTimelineColor == nil then dodoDB.enableEncounterTimelineColor = D.enableEncounterTimelineColor end
        if dodoDB.useEncounterTimelineColorHighlight == nil then dodoDB.useEncounterTimelineColorHighlight = D.useEncounterTimelineColorHighlight end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_visual()
    end
end

initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", on_event)

dodo.EncounterUpdateTimelineVisual = update_visual

