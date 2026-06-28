---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_EncounterEvents      = C_EncounterEvents
local CreateFrame            = CreateFrame
local GetInstanceInfo        = GetInstanceInfo
local GetSpecialization      = GetSpecialization
local GetSpecializationInfo  = GetSpecializationInfo
local IsInInstance           = IsInInstance
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local ipairs                 = ipairs
local select                 = select

-- ==============================
-- 설정 및 테이블
-- ==============================
local SOUND_ROOT = "Interface\\AddOns\\" .. addonName .. "\\Media\\Sound\\Encounter\\"

---@class dodo.SoundData
---@field file    string 사운드 파일 경로
---@field channel string 재생 채널

---@alias dodo.SoundKey "Tank"|"AOE"|"Phase"|"Frontal"|"Mechanic"|"Dispel"

---@class dodo.EncounterEntry
---@field eventID integer
---@field role    "Tank"|"Heal"|"Mechanic"|"Other"
---@field sound   dodo.SoundKey|nil
---@field enable  boolean|nil

-- EncounterEventSoundTrigger:
--   0 = OnTextWarningShown  (미사용)
--   1 = OnTimelineEventFinished  (시전 시) ← 소리
--   2 = OnTimelineEventHighlight (미사용)
--
-- sound from ttsfree.com (SunHi 14%, 5%) > https://mp3cut.net/ko/change-volume volume 130%
---@type table<dodo.SoundKey, dodo.SoundData>
local SOUND_MAP = {
    Adds      = { file = SOUND_ROOT .. "Adds.mp3",      channel = "Master" },
    AOE       = { file = SOUND_ROOT .. "AOE.mp3",       channel = "Master" },
    Dispel    = { file = SOUND_ROOT .. "Dispel.mp3",    channel = "Master" },
    Frontal   = { file = SOUND_ROOT .. "Frontal.mp3",   channel = "Master" },
    Interrupt = { file = SOUND_ROOT .. "Interrupt.mp3", channel = "Master" },
    Phase     = { file = SOUND_ROOT .. "Phase.mp3",     channel = "Master" },
    Pool      = { file = SOUND_ROOT .. "Pool.mp3",      channel = "Master" },
    Soak      = { file = SOUND_ROOT .. "Soak.mp3",      channel = "Master" },
    Tank      = { file = SOUND_ROOT .. "Tank.mp3",      channel = "Master" },
}

---@type dodo.EncounterEntry[]|nil
local current_events = nil
local applied_eids   = {}   -- 실제 적용한 encounterEventID 목록 (해제용)

-- ==============================
-- 기능: 소리 적용/해제
-- ==============================
---@return nil
local function clear_sounds()
    if not (C_EncounterEvents and C_EncounterEvents.SetEventSound) then return end
    if not current_events then return end
    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, eid in ipairs(applied_eids) do
        C_EncounterEvents.SetEventSound(eid, 0, nil)
        C_EncounterEvents.SetEventSound(eid, 1, nil)
        C_EncounterEvents.SetEventSound(eid, 2, nil)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    applied_eids   = {}
    current_events = nil
end

---@return nil
local function apply_sounds()
    clear_sounds()
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterSound ~= false) then return end
    if not (C_EncounterEvents and C_EncounterEvents.SetEventSound) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID    = select(8, GetInstanceInfo())
    local boss_ids = dodo.EncounterMapBosses and dodo.EncounterMapBosses[mapID]
    if not boss_ids then return end

    dodo.Encounter.EnsureWarnings()

    local raw_role = UnitGroupRolesAssigned("player")
    local role = raw_role
    local spec_role = nil
    if role == "NONE" then
        local si = GetSpecialization()
        if si then _, _, _, _, spec_role = GetSpecializationInfo(si) end
        role = spec_role or role
    end
    local is_dps = (role == "DAMAGER")

    -- spellID → encounterEventID 리스트 맵 (같은 spellID 사이클별 다중 ID 대응)
    local spell_map = {}
    if C_EncounterEvents.GetEventList and C_EncounterEvents.GetEventInfo then
        for _, id in ipairs(C_EncounterEvents.GetEventList()) do
            local info = C_EncounterEvents.GetEventInfo(id)
            if info and info.spellID and info.spellID ~= 0 then
                local t = spell_map[info.spellID]
                if not t then t = {}; spell_map[info.spellID] = t end
                t[#t + 1] = id
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
        local eids = entry.eventID and { entry.eventID }
            or (entry.spellID and spell_map[entry.spellID])
        if eids then
            local sound1 = SOUND_MAP[entry.sound or entry.role]
            if is_dps and entry.role == "Tank" then sound1 = nil end
            for _, encounter_eid in ipairs(eids) do
                C_EncounterEvents.SetEventSound(encounter_eid, 0, nil)
                C_EncounterEvents.SetEventSound(encounter_eid, 1, sound1)
                C_EncounterEvents.SetEventSound(encounter_eid, 2, nil)
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
local sound_frame = CreateFrame("Frame")

---@param self Frame
---@param event string
---@param arg1  any
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableEncounterSound == nil then dodoDB.enableEncounterSound = true end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        apply_sounds()
    end
end

sound_frame:RegisterEvent("ADDON_LOADED")
sound_frame:RegisterEvent("PLAYER_LOGIN")
sound_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
sound_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.EncounterEvents, {
        {
            name = "소리 알림",
            get  = function() return dodoDB and dodoDB.enableEncounterSound ~= false end,
            set  = function(checked)
                if dodoDB then dodoDB.enableEncounterSound = checked end
                apply_sounds()
            end,
            disabled = function() return not dodo.Encounter.IsEnabled() end,
        },
    })
end
