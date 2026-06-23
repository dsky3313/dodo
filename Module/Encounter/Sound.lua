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
local SOUND_ROOT = "Interface\\AddOns\\" .. addonName .. "\\Media\\Sound\\"

-- EncounterEventSoundTrigger:
--   0 = OnTextWarningShown  (미사용)
--   1 = OnTimelineEventFinished  (시전 시) ← 소리
--   2 = OnTimelineEventHighlight (미사용)
--
-- entry.sound 키 목록 (Data.lua에서 사용):
--   "Tank" / "AOE" / "Phase" / "Frontal"
-- entry.sound 없으면 entry.role로 폴백 (Tank→Tank, Heal→AOE, Mechanic→Phase, Other→소리없음)
local SOUND_MAP = {
    Tank    = { file = SOUND_ROOT .. "Tank.ogg",    channel = "Master" },
    AOE     = { file = SOUND_ROOT .. "AOE.ogg",     channel = "Master" },
    Phase   = { file = SOUND_ROOT .. "Phase.ogg",   channel = "Master" },
    Frontal = { file = SOUND_ROOT .. "Frontal.ogg", channel = "Master" },
    
    -- role 폴백
    Heal     = { file = SOUND_ROOT .. "AOE.ogg",   channel = "Master" },
    Mechanic = { file = SOUND_ROOT .. "Phase.ogg", channel = "Master" },
}

local current_events = nil

-- ==============================
-- 기능: 소리 적용/해제
-- ==============================
local function clear_sounds()
    if not (C_EncounterEvents and C_EncounterEvents.SetEventSound) then return end
    if not current_events then return end
    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, entry in ipairs(current_events) do
        C_EncounterEvents.SetEventSound(entry.eventID, 0, nil)
        C_EncounterEvents.SetEventSound(entry.eventID, 1, nil)
        C_EncounterEvents.SetEventSound(entry.eventID, 2, nil)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = nil
end

local function apply_sounds()
    clear_sounds()
    if not dodo.Encounter.IsEnabled() then return end
    if not (dodoDB and dodoDB.enableEncounterSound ~= false) then return end
    if not (C_EncounterEvents and C_EncounterEvents.SetEventSound) then return end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then return end

    local mapID = select(8, GetInstanceInfo())
    local events = dodo.EncounterEvents and dodo.EncounterEvents[mapID]
    if not events then return end

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

    print(string.format("[dodo Sound] mapID=%s raw_role=%s spec_role=%s final_role=%s is_dps=%s",
        tostring(mapID), tostring(raw_role), tostring(spec_role), tostring(role), tostring(is_dps)))

    local et = EncounterTimeline
    if et then et:UnregisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    for _, entry in ipairs(events) do
        local sound1 = SOUND_MAP[entry.sound or entry.role]
        if is_dps and entry.role == "Tank" then sound1 = nil end
        print(string.format("[dodo Sound]   eventID=%s entryRole=%s sound=%s sound1=%s",
            tostring(entry.eventID), tostring(entry.role), tostring(entry.sound or "-"), tostring(sound1 and sound1.file or "nil")))
        C_EncounterEvents.SetEventSound(entry.eventID, 0, nil)
        C_EncounterEvents.SetEventSound(entry.eventID, 1, sound1)
        C_EncounterEvents.SetEventSound(entry.eventID, 2, nil)
    end
    if et then et:RegisterEvent("ENCOUNTER_TIMELINE_STATE_UPDATED") end
    current_events = events
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local sound_frame = CreateFrame("Frame")

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
