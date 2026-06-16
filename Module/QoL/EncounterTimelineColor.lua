-- ==============================
-- Inspired
-- ==============================
-- EXBoss - 블리자드 순정 인카운터 타임라인 바 색상 변경 기능 포팅

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

---@class EncounterTimelineColorEntry
---@field eventID number 블리자드 인카운터 타임라인 고정 이벤트 ID
---@field role string dodo.Colors.EncounterRole 키

-- eventID는 EXBossData/EncounterData.lua에서 추출한 블리자드 고정 ID (패치별로 변동 가능)
---@type EncounterTimelineColorEntry[]
local EVENT_COLOR_LIST = {
    -- 알게타르 대학 - 벡사무스
    { eventID = 274, role = "Other" },    -- 마력 구슬
    { eventID = 275, role = "Heal" },     -- 마나 폭탄
    { eventID = 276, role = "Tank" },     -- 마력 몰아내기
    { eventID = 277, role = "Mechanic" }, -- 마력 균열
}

-- ==============================
-- 캐싱
-- ==============================
local C_EncounterEvents = C_EncounterEvents
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local ipairs = ipairs

-- ==============================
-- 기능 1: 색상 적용/해제
-- ==============================
local function update_visual()
    if not (C_EncounterEvents and C_EncounterEvents.SetEventColor) then return end

    local enabled = dodoDB and dodoDB.enableEncounterTimelineColor ~= false
    for _, entry in ipairs(EVENT_COLOR_LIST) do
        if enabled then
            local role = dodo.Colors.EncounterRole and dodo.Colors.EncounterRole[entry.role]
            local color = role and CreateColor(role.r, role.g, role.b)
            C_EncounterEvents.SetEventColor(entry.eventID, color)
        else
            C_EncounterEvents.SetEventColor(entry.eventID, nil)
        end
    end
end

local function initialize()
    if dodoDB.enableEncounterTimelineColor == nil then dodoDB.enableEncounterTimelineColor = true end
    update_visual()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        initialize()
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
            name = "보스 타임라인 색상 변경",
            get = function() return dodoDB and dodoDB.enableEncounterTimelineColor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableEncounterTimelineColor = checked end
                update_visual()
            end
        }
    })
end
