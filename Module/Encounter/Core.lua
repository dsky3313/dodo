-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

dodo.Encounter = {}

-- NeverSecret → 비교 허용
dodo.Encounter.ENCOUNTER_SOURCE = (Enum and Enum.EncounterTimelineEventSource and Enum.EncounterTimelineEventSource.Encounter) or 0
dodo.Encounter.STATE_FINISHED   = (Enum and Enum.EncounterTimelineEventState  and Enum.EncounterTimelineEventState.Finished)   or 2
dodo.Encounter.STATE_CANCELED   = (Enum and Enum.EncounterTimelineEventState  and Enum.EncounterTimelineEventState.Canceled)   or 3

-- ==============================
-- 캐싱
-- ==============================
local C_CVar      = C_CVar
local CreateFrame = CreateFrame
local GetCVar     = GetCVar
local SetCVar     = SetCVar

-- ==============================
-- 기능: CVar 보장 & 활성화 확인
-- ==============================
local function ensure_encounter_warnings()
    local cvar = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("encounterWarningsEnabled")
                 or (GetCVar and GetCVar("encounterWarningsEnabled"))
    if cvar == "0" then
        if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar("encounterWarningsEnabled", "1")
        elseif SetCVar then SetCVar("encounterWarningsEnabled", "1") end
    end
end
dodo.Encounter.EnsureWarnings = ensure_encounter_warnings

function dodo.Encounter.IsEnabled()
    return dodoDB and dodoDB.enableEncounter ~= false
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.enableEncounter == nil then dodoDB.enableEncounter = true end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "우두머리 경보",
            get = function() return dodoDB and dodoDB.enableEncounter ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableEncounter = checked end
            end,
        },
    })
end
