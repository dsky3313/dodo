-- ==============================
-- Inspired
-- ==============================
-- RefineUI (Quests)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Quests", module)

-- ==============================
-- 캐싱 및 상수
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local ObjectiveTrackerFrame = ObjectiveTrackerFrame

-- ==============================
-- 기능 1: 퀘스트 자동 수락 및 완료
-- ==============================
local function auto_accept_quest()
    if not dodo.DB or not dodo.DB.useQuestAutoAccept then return end
    if QuestFrame:IsShown() and QuestFrameAcceptButton:IsVisible() then
        QuestFrameAcceptButton:Click()
    end
end

local function auto_complete_quest()
    if not dodo.DB or not dodo.DB.useQuestAutoComplete then return end
    if QuestFrame:IsShown() and QuestFrameCompleteButton:IsVisible() then
        QuestFrameCompleteButton:Click()
    elseif QuestFrameRewardPanel:IsShown() then
        QuestFrameCompleteQuestButton:Click()
    end
end

-- ==============================
-- 기능 2: 목표 추적기 자동 접기
-- ==============================
local function update_tracker_collapse(event)
    if not dodo.DB or not dodo.DB.useQuestAutoCollapse then return end
    if not ObjectiveTrackerFrame then return end

    local mode = dodo.DB.questAutoCollapseMode or "COMBAT"
    local inInstance = IsInInstance()
    local inCombat = InCombatLockdown()

    if event == "PLAYER_REGEN_DISABLED" then inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then inCombat = false end

    local shouldCollapse = false
    if mode == "COMBAT" then
        shouldCollapse = inCombat
    elseif mode == "INSTANCE" then
        shouldCollapse = inInstance
    elseif mode == "ALWAYS" then
        shouldCollapse = true
    end

    -- 인투컴뱃 중에는 SetCollapsed를 호출할 수 없으므로(보통 보안 상의 이유) 안전하게 처리
    C_Timer.After(0.1, function()
        if InCombatLockdown() and not shouldCollapse then return end -- 전투 중인데 펼치기는 위험할 수 있음
        if ObjectiveTrackerFrame.SetCollapsed then
            ObjectiveTrackerFrame:SetCollapsed(shouldCollapse)
        end
    end)
end

-- ==============================
-- 모듈 On/Off 제어
-- ==============================
local function update_module_state()
    local enabled = (dodo.DB and dodo.DB.enableQuestsModule ~= false)
    
    if not enabled then
        module.eventFrame:UnregisterAllEvents()
    else
        module.eventFrame:RegisterEvent("QUEST_DETAIL")
        module.eventFrame:RegisterEvent("QUEST_COMPLETE")
        module.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        module.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        module.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        module.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end
end

dodo.UpdateQuestsModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB.useQuestAutoAccept == nil then dodo.DB.useQuestAutoAccept = true end
    if dodo.DB.useQuestAutoComplete == nil then dodo.DB.useQuestAutoComplete = true end
    if dodo.DB.useQuestAutoCollapse == nil then dodo.DB.useQuestAutoCollapse = false end
    if dodo.DB.questAutoCollapseMode == nil then dodo.DB.questAutoCollapseMode = "COMBAT" end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    if not module.eventFrame then
        module.eventFrame = CreateFrame("Frame")
        module.eventFrame:SetScript("OnEvent", function(self, event)
            if event == "QUEST_DETAIL" then
                auto_accept_quest()
            elseif event == "QUEST_COMPLETE" then
                auto_complete_quest()
            else
                update_tracker_collapse(event)
            end
        end)
    end

    initialize()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    -- dodoEditModePanel 내부에 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("인터페이스", {
            {
                name = "퀘스트 자동 수락",
                get = function() return dodo.DB and dodo.DB.useQuestAutoAccept end,
                set = function(checked) dodo.DB.useQuestAutoAccept = checked end
            },
            {
                name = "퀘스트 자동 완료",
                get = function() return dodo.DB and dodo.DB.useQuestAutoComplete end,
                set = function(checked) dodo.DB.useQuestAutoComplete = checked end
            },
            {
                name = "추적기 자동 접기",
                get = function() return dodo.DB and dodo.DB.useQuestAutoCollapse end,
                set = function(checked) 
                    dodo.DB.useQuestAutoCollapse = checked 
                    update_tracker_collapse()
                end
            },
            {
                type = "dropdown",
                get = function() return dodo.DB and dodo.DB.questAutoCollapseMode or "COMBAT" end,
                set = function(val) 
                    dodo.DB.questAutoCollapseMode = val 
                    update_tracker_collapse()
                end,
                values = {
                    { text = "전투 중", value = "COMBAT" },
                    { text = "인던 내", value = "INSTANCE" },
                    { text = "항상", value = "ALWAYS" },
                }
            },
        })
    end
end
