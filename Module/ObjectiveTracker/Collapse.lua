-- ==============================
-- Inspired
-- ==============================
-- QuestLogCollapse (https://www.curseforge.com/wow/addons/quest-log-collapse)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 접기 대상 트래커 (QLC 방식: 통짜 모듈이 아닌 개별 트래커 프레임에 SetCollapsed 호출)
local TRACKERS = {
    { globalName = "QuestObjectiveTracker",         name = "Quest" },
    { globalName = "CampaignQuestObjectiveTracker", name = "Campaign" },
    { globalName = "AchievementObjectiveTracker",   name = "Achievement" },
    { globalName = "BonusObjectiveTracker",         name = "Bonus" },
    { globalName = "WorldQuestObjectiveTracker",    name = "WorldQuest" },
}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local ipairs = ipairs
local pcall = pcall
local select = select
local type = type

-- ==============================
-- 기능 1: 로컬 상태
-- ==============================
local initFrame = CreateFrame("Frame")

-- QLC taint 블랙리스트: SetCollapsed 중 에러 감지된 트래커는 세션 동안 제외
-- (UIWidget 포함 트래커의 SetCollapsed는 위젯 풀 프레임을 taint시켜 /reload 전까지 지속됨)
local taint_blacklist = {}

-- QLC 전투 큐: 전투 중 트래커 조작 금지, PLAYER_REGEN_ENABLED에서 지연 실행
local pending_apply = false

-- 전투 중 토글 off 시 원복 대기 (전투 종료 후 apply_all(false) 실행)
local pending_restore = false

-- 존 이벤트 연달아 발화 시 타이머 중복 예약 방지
local timer_scheduled = false

-- ==============================
-- 기능 2: 인스턴스 판별 (QLC IsInDungeon)
-- ==============================
local function is_in_collapse_zone()
    local instanceType = select(2, IsInInstance())
    return instanceType == "party" or instanceType == "raid" or instanceType == "scenario"
        or instanceType == "pvp" or instanceType == "arena"
end

-- ==============================
-- 기능 3: 트래커 접기/펼치기 (QLC SafeCollapse/SafeExpand)
-- ==============================
local function set_tracker_collapsed(tracker, name, collapsed)
    if not tracker or taint_blacklist[name] then return end
    if type(tracker.SetCollapsed) ~= "function" then return end

    -- pcall로 taint 에러 격리, 실패 시 세션 블랙리스트 등재 (QLC 동적 블랙리스트)
    -- 폴백으로 tracker.collapsed 직접 쓰기 금지 — 블리자드 프레임 테이블 taint됨
    local ok = pcall(tracker.SetCollapsed, tracker, collapsed)
    if not ok then
        taint_blacklist[name] = true
    end
end

local function apply_all(collapsed)
    for _, def in ipairs(TRACKERS) do
        set_tracker_collapsed(_G[def.globalName], def.name, collapsed)
    end
end

local function apply_state()
    if not (dodoDB and dodoDB.enableCollapse ~= false) then return end

    -- QLC: 전투 중엔 절대 조작 안 함 — 전투 종료 시 재시도
    if InCombatLockdown() then
        pending_apply = true
        return
    end
    pending_apply = false
    apply_all(is_in_collapse_zone())
end

-- 존 변경 직후엔 트래커/퀘스트 시스템 초기화 중이라 지연 실행 (QLC 지연 전략 축소판)
local function on_apply_timer()
    timer_scheduled = false
    apply_state()
end

-- ==============================
-- 상태 업데이트
-- ==============================
local function update_visual()
    local isEnabled = (dodoDB and dodoDB.enableCollapse ~= false)
    if isEnabled then
        pending_restore = false
        initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        initFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        apply_state()
    else
        initFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        initFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        initFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        pending_apply = false
        -- 비활성화 시 접힌 상태 원복 (전투 중이면 종료 후 원복 — 접힌 채 방치 방지)
        if InCombatLockdown() then
            pending_restore = true
            initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            apply_all(false)
        end
    end
end

local function initialize()
    if dodoDB.enableCollapse == nil then
        -- KeystoneTimer 자동 접기에서 분리 — 기존 설정값 이관
        dodoDB.enableCollapse = dodoDB.useKeystoneTimerAutoCollapse ~= false
        dodoDB.useKeystoneTimerAutoCollapse = nil
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        initialize()
        update_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if not timer_scheduled then
            timer_scheduled = true
            C_Timer.After(1, on_apply_timer)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending_restore then
            -- 전투 중 토글 off 원복 처리
            pending_restore = false
            apply_all(false)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        elseif pending_apply then
            -- QLC 전투 큐 처리: 전투 중 미뤄둔 접기/펼치기 실행
            apply_state()
        end
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ObjectiveTracker, {
        {
            name = "퀘스트 목록 접기",
            get = function() return dodoDB and dodoDB.enableCollapse ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableCollapse = checked end
                update_visual()
            end
        },
    })
end
