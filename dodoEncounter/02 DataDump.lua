-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- 데이터수집 버튼 → dodoEncounterDumpDB 저장 + 리로드 (WTF\...\SavedVariables\dodoEncounter.lua 기록)
--   season : 모험 안내서 "현재 시즌" 탭 인스턴스 → 보스 → 능력(섹션 트리)
--   maps   : dodo.EncounterMapBosses 에 있는 mapID 인스턴스 (전 확장팩 탭 검색)
--   events : C_EncounterEvents 전체 eventID → spellID / 한글 스펠명
-- 타임라인 기록 (useEncounterRecord) → dodoEncounterDumpDB.records (풀마다 1개, 최근 RECORD_MAX개 유지)
--   added  : ENCOUNTER_TIMELINE_EVENT_ADDED 순서대로 { t=풀 후 경과초, id, dur=eventInfo.duration, spellID?, name? }
--   states : ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED { t, id, state } (0 진행 / 1 일시정지 / 2 완료 / 3 취소)
--   spellID/name 은 secret 이면 기록 안 함 (dur 는 NeverSecret)

---@class EncounterDumpAbility
---@field id number sectionID
---@field depth number
---@field title string
---@field spellID? number
---@field header number
---@field filtered? boolean

---@class EncounterDumpBoss
---@field name string
---@field journalEncounterID number
---@field encounterID number
---@field abilities EncounterDumpAbility[]

---@class EncounterRecordAdded
---@field t number
---@field id number
---@field dur number
---@field spellID? number
---@field name? string

---@class EncounterRecordPull
---@field encounterID number
---@field name string
---@field difficultyID number
---@field date string
---@field success? boolean
---@field added EncounterRecordAdded[]
---@field states table[]

---@class EncounterDumpInstance
---@field id number
---@field name string
---@field mapID number
---@field isRaid boolean
---@field tier string
---@field bosses EncounterDumpBoss[]

-- ==============================
-- 캐싱
-- ==============================
local C_EncounterEvents      = C_EncounterEvents
local C_EncounterJournal     = C_EncounterJournal
local C_EncounterTimeline    = C_EncounterTimeline
local C_Spell                = C_Spell
local C_UI                   = C_UI
local CreateFrame            = CreateFrame
local date                   = date
local EJ_GetCurrentTier      = EJ_GetCurrentTier
local EJ_GetEncounterInfoByIndex = EJ_GetEncounterInfoByIndex
local EJ_GetInstanceByIndex  = EJ_GetInstanceByIndex
local EJ_GetNumTiers         = EJ_GetNumTiers
local EJ_GetTierInfo         = EJ_GetTierInfo
local EJ_SelectInstance      = EJ_SelectInstance
local EJ_SelectTier          = EJ_SelectTier
local EJ_SetDifficulty       = EJ_SetDifficulty
local GetTime                = GetTime
local ipairs                 = ipairs
local issecretvalue          = issecretvalue
local math_floor             = math.floor
local pairs                  = pairs
local print                  = print
local select                 = select
local string_format          = string.format
local table_concat           = table.concat
local table_remove           = table.remove
local tostring               = tostring

local DIFFICULTY_DUNGEON = 23 -- 신화
local DIFFICULTY_RAID    = 16 -- 신화
local RECORD_MAX         = 200 -- 보관할 최근 풀 수 (전체 합산)

local _col = "|c" .. ((dodo.Colors and dodo.Colors.CharacterFrame and dodo.Colors.CharacterFrame.Enchant and dodo.Colors.CharacterFrame.Enchant.hex) or "ff00ff96")

-- ==============================
-- 기능: 모험 안내서 덤프
-- ==============================
local function walk_sections(section_id, depth, out)
    while section_id do
        local info = C_EncounterJournal.GetSectionInfo(section_id)
        if not info then return end
        out[#out + 1] = {
            id       = section_id,
            depth    = depth,
            title    = info.title,
            spellID  = (info.spellID and info.spellID ~= 0) and info.spellID or nil,
            header   = info.headerType,
            filtered = info.filteredByDifficulty or nil,
        }
        if info.firstChildSectionID then
            walk_sections(info.firstChildSectionID, depth + 1, out)
        end
        section_id = info.siblingSectionID
    end
end

---@return EncounterDumpInstance
local function dump_instance(inst_id, inst_name, map_id, is_raid, tier_name)
    EJ_SelectInstance(inst_id)
    EJ_SetDifficulty(is_raid and DIFFICULTY_RAID or DIFFICULTY_DUNGEON)
    local inst = { id = inst_id, name = inst_name, mapID = map_id, isRaid = is_raid, tier = tier_name, bosses = {} }

    local j = 1
    local b_name, _, je_id, root_id, _, _, enc_id = EJ_GetEncounterInfoByIndex(j, inst_id)
    while b_name do
        local boss = { name = b_name, journalEncounterID = je_id, encounterID = enc_id, abilities = {} }
        walk_sections(root_id, 0, boss.abilities)
        inst.bosses[#inst.bosses + 1] = boss
        j = j + 1
        b_name, _, je_id, root_id, _, _, enc_id = EJ_GetEncounterInfoByIndex(j, inst_id)
    end
    return inst
end

-- 한 탭의 던전/레이드 순회. filter(map_id) 가 false면 건너뜀
local function each_tier_instance(tier, filter, out_fn)
    EJ_SelectTier(tier)
    local tier_name = EJ_GetTierInfo(tier)
    for _, is_raid in ipairs({ false, true }) do
        local i = 1
        local inst_id, inst_name, _, _, _, _, _, _, _, _, map_id = EJ_GetInstanceByIndex(i, is_raid)
        while inst_id do
            if not filter or filter(map_id) then
                out_fn(dump_instance(inst_id, inst_name, map_id, is_raid, tier_name))
            end
            i = i + 1
            inst_id, inst_name, _, _, _, _, _, _, _, _, map_id = EJ_GetInstanceByIndex(i, is_raid)
        end
    end
end

local function dump_events()
    local out = {}
    if not (C_EncounterEvents and C_EncounterEvents.GetEventList) then return out, 0 end
    local n = 0
    for _, id in ipairs(C_EncounterEvents.GetEventList()) do
        local info = C_EncounterEvents.GetEventInfo(id)
        if info then
            local sid = info.spellID
            out[id] = { spellID = sid, name = sid and C_Spell.GetSpellName(sid) or nil }
            n = n + 1
        end
    end
    return out, n
end

local function run_dump()
    local prev_tier = EJ_GetCurrentTier()
    local num_tiers = EJ_GetNumTiers()

    -- 현재 시즌 = 마지막 탭
    local season = {}
    each_tier_instance(num_tiers, nil, function(inst) season[#season + 1] = inst end)

    -- dodo 데이터 mapID 인스턴스 (전 탭)
    local want = dodo.EncounterMapBosses or {}
    local maps, n_maps = {}, 0
    for tier = 1, num_tiers do
        each_tier_instance(tier, function(map_id) return want[map_id] and not maps[map_id] end, function(inst)
            maps[inst.mapID] = inst
            n_maps = n_maps + 1
        end)
    end
    local miss = {}
    for map_id in pairs(want) do
        if not maps[map_id] then miss[#miss + 1] = map_id end
    end

    local events, n_events = dump_events()

    if prev_tier then EJ_SelectTier(prev_tier) end

    dodoEncounterDumpDB = dodoEncounterDumpDB or {} -- records(타임라인 기록) 보존
    dodoEncounterDumpDB.season = season
    dodoEncounterDumpDB.maps   = maps
    dodoEncounterDumpDB.events = events
    print(string_format("[%sdodo|r] 데이터수집 완료: 현재 시즌 %d, dodo 인스턴스 %d (못 찾음: %s), 이벤트 %d",
        _col, #season, n_maps, #miss > 0 and table_concat(miss, ",") or "없음", n_events))
end

-- 99 Options.lua "데이터수집" 버튼 → 수집 후 리로드 (리로드 시 SavedVariables 기록)
function dodo.EncounterCollectData()
    run_dump()
    C_UI.Reload()
end

-- ==============================
-- 기능: 타임라인 기록 (eventInfo.duration)
-- ==============================
local record_frame = CreateFrame("Frame")
local current_pull = nil ---@type EncounterRecordPull|nil
local pull_start   = 0

local function round1(v) return math_floor(v * 10 + 0.5) / 10 end

-- secret 이면 nil (기록 불가)
local function plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

local function on_added(info)
    if not current_pull or not info then return end
    if info.source ~= dodo.Encounter.ENCOUNTER_SOURCE then return end -- source: NeverSecret
    local added = current_pull.added
    added[#added + 1] = {
        t       = round1(GetTime() - pull_start),
        id      = info.id,
        dur     = info.duration, -- NeverSecret
        spellID = plain(info.spellID),
        name    = plain(info.spellName),
    }
end

local function on_state(event_id)
    if not current_pull then return end
    local states = current_pull.states
    states[#states + 1] = {
        t     = round1(GetTime() - pull_start),
        id    = event_id,
        state = C_EncounterTimeline.GetEventState(event_id), -- NeverSecret
    }
end

local function on_start(encounter_id, encounter_name, difficulty_id)
    current_pull = {
        encounterID  = encounter_id,
        name         = encounter_name,
        difficultyID = difficulty_id,
        date         = date("%Y-%m-%d %H:%M"),
        added        = {},
        states       = {},
    }
    pull_start = GetTime()
    record_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    record_frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
end

local function on_end(success)
    record_frame:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    record_frame:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
    if not current_pull then return end
    current_pull.success = (success == 1)

    dodoEncounterDumpDB = dodoEncounterDumpDB or {}
    local records = dodoEncounterDumpDB.records or {}
    dodoEncounterDumpDB.records = records
    records[#records + 1] = current_pull
    while #records > RECORD_MAX do table_remove(records, 1) end

    print(string_format("[%sdodo|r] 타임라인 기록: %s (난이도 %s) %s, 이벤트 %d개 → /reload 시 저장",
        _col, tostring(current_pull.name), tostring(current_pull.difficultyID),
        current_pull.success and "처치" or "전멸", #current_pull.added))
    current_pull = nil
end

local function on_record_event(self, event, ...)
    if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        on_added(...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        on_state(...)
    elseif event == "ENCOUNTER_START" then
        local encounter_id, encounter_name, difficulty_id = ...
        on_start(encounter_id, encounter_name, difficulty_id)
    elseif event == "ENCOUNTER_END" then
        local success = select(5, ...)
        on_end(success)
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        dodo.EncounterUpdateRecorder()
    end
end

-- 토글 OFF → 모든 이벤트 해제 (백그라운드 소모 0)
function dodo.EncounterUpdateRecorder()
    if dodoDB.useEncounterRecord then
        record_frame:RegisterEvent("ENCOUNTER_START")
        record_frame:RegisterEvent("ENCOUNTER_END")
    else
        record_frame:UnregisterAllEvents()
        current_pull = nil
    end
end

record_frame:RegisterEvent("PLAYER_LOGIN")
record_frame:SetScript("OnEvent", on_record_event)
