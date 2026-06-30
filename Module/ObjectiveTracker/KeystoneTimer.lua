-- ==============================
-- Inspired
-- ==============================
-- 블리자드 기본 M+ 타이머(ChallengeModeBlock) 리스킨

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local PLUS_TWO_RATIO = 0.8
local PLUS_THREE_RATIO = 0.6
local CHALLENGERS_PERIL_AFFIX_ID = 152

-- ==============================
-- 캐싱
-- ==============================
local C_ChallengeMode = C_ChallengeMode
local C_Scenario = C_Scenario
local C_ScenarioInfo = C_ScenarioInfo
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local select = select
local tonumber = tonumber

-- ==============================
-- 기능 1: 로컬 상태
-- ==============================
local tick2, tick3 = nil, nil
local hide_result  -- 기능 5에서 정의

-- ==============================
-- 기능 2: 적 병력 바 디자인 리스킨 (ObjectiveTrackerProgressBarTemplate 스타일)
-- ==============================
local DECOR_KEYS = { "BarFrame", "BarFrame2", "BarFrame3", "BarGlow", "Sheen", "Starburst" }

local function apply_bar_style(progressBar)
    local statusBar = progressBar.Bar
    if not statusBar then return end

    if not progressBar._dd_borderLeft then
        local borderLeft = statusBar:CreateTexture(nil, "ARTWORK")
        borderLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
        borderLeft:SetSize(15, 24)
        borderLeft:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
        borderLeft:SetPoint("LEFT", statusBar, "LEFT", -3, 0)

        local borderRight = statusBar:CreateTexture(nil, "ARTWORK")
        borderRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
        borderRight:SetSize(15, 24)
        borderRight:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
        borderRight:SetPoint("RIGHT", statusBar, "RIGHT", 3, 0)

        local borderMid = statusBar:CreateTexture(nil, "ARTWORK")
        borderMid:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
        borderMid:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
        borderMid:SetPoint("TOPLEFT", borderLeft, "TOPRIGHT", 0, 0)
        borderMid:SetPoint("BOTTOMRIGHT", borderRight, "BOTTOMLEFT", 0, 0)

        progressBar._dd_borderLeft = borderLeft
        progressBar._dd_borderRight = borderRight
        progressBar._dd_borderMid = borderMid
    end

    for _, key in ipairs(DECOR_KEYS) do
        local tex = statusBar[key]
        if tex then tex:Hide() end
    end

    progressBar._dd_borderLeft:Show()
    progressBar._dd_borderRight:Show()
    progressBar._dd_borderMid:Show()
end

local function remove_bar_style(progressBar)
    local statusBar = progressBar.Bar
    if not statusBar then return end

    for _, key in ipairs(DECOR_KEYS) do
        local tex = statusBar[key]
        if tex then tex:Show() end
    end

    if progressBar._dd_borderLeft then progressBar._dd_borderLeft:Hide() end
    if progressBar._dd_borderRight then progressBar._dd_borderRight:Hide() end
    if progressBar._dd_borderMid then progressBar._dd_borderMid:Hide() end
end

local function on_progress_bar_on_get(self, isNew, criteriaIndex)
    if dodoDB and dodoDB.enableKeystoneTimer ~= false and dodoDB.useKeystoneTimerBarStyle ~= false then
        apply_bar_style(self)
    else
        remove_bar_style(self)
    end
end

-- ==============================
-- 기능 3: 적 세력 퍼센트 소수점 2자리
-- ==============================
-- 블리자드 percentage 인자(quantity)는 정수로 반올림된 값 -> quantityString 원본 수치를
-- totalQuantity로 직접 나눠 재계산 (AngryKeystones 방식)
local function on_progress_bar_set_value(self)
    if not (dodoDB and dodoDB.enableKeystoneTimer ~= false and dodoDB.useKeystoneTimerPercent ~= false) then return end
    if not (C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()) then return end

    local numCriteria = select(3, C_Scenario.GetStepInfo())
    for criteriaIndex = 1, numCriteria do
        local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
        if criteriaInfo and criteriaInfo.isWeightedProgress then
            local currentQuantity = criteriaInfo.quantityString and tonumber(criteriaInfo.quantityString:match("%d+"))
            local totalQuantity = criteriaInfo.totalQuantity
            if currentQuantity and totalQuantity and totalQuantity > 0 then
                self.Bar.Label:SetFormattedText("%.2f%%", currentQuantity / totalQuantity * 100)
            end
            break
        end
    end
end

-- ==============================
-- 기능 4: +2 / +3 시간 틱마커
-- ==============================
local function calculate_bonus_timers(timeLimit, affixes)
    local plusTwoT = (timeLimit or 0) * PLUS_TWO_RATIO
    local plusThreeT = (timeLimit or 0) * PLUS_THREE_RATIO

    if not timeLimit or timeLimit <= 0 then
        return plusTwoT, plusThreeT
    end

    if affixes then
        for _, affixID in ipairs(affixes) do
            if affixID == CHALLENGERS_PERIL_AFFIX_ID then
                local oldTimer = timeLimit - 90
                if oldTimer > 0 then
                    plusTwoT = oldTimer * PLUS_TWO_RATIO + 90
                    plusThreeT = oldTimer * PLUS_THREE_RATIO + 90
                end
                break
            end
        end
    end

    return plusTwoT, plusThreeT
end

local function create_tick_marks(statusBar)
    if tick2 then return end

    tick2 = statusBar:CreateTexture(nil, "OVERLAY")
    tick2:SetAtlas("honorsystem-bar-frame-exhaustiontick", false)
    tick2:SetSize(14, 21)
    tick2:Hide()

    tick3 = statusBar:CreateTexture(nil, "OVERLAY")
    tick3:SetAtlas("honorsystem-bar-frame-exhaustiontick", false)
    tick3:SetSize(14, 21)
    tick3:Hide()
end

local function on_challenge_mode_activate(self, timerID, elapsedTime, timeLimit)
    hide_result()
    if not (dodoDB and dodoDB.enableKeystoneTimer ~= false and dodoDB.useKeystoneTimerTick ~= false) then
        if tick2 then tick2:Hide() end
        if tick3 then tick3:Hide() end
        return
    end

    local statusBar = self.StatusBar
    create_tick_marks(statusBar)

    local _, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    local plusTwoT, plusThreeT = calculate_bonus_timers(timeLimit, affixes)
    self._dd_plusTwoElapsed = plusTwoT
    self._dd_plusThreeElapsed = plusThreeT

    local barW = statusBar:GetWidth()
    local r2 = (timeLimit - plusTwoT) / timeLimit
    local r3 = (timeLimit - plusThreeT) / timeLimit

    tick2:SetVertexColor(0.4, 1, 0.4)
    tick2:ClearAllPoints()
    tick2:SetPoint("CENTER", statusBar, "LEFT", barW * r2, 2)
    tick2:Show()

    tick3:SetVertexColor(0.4, 1, 0.4)
    tick3:ClearAllPoints()
    tick3:SetPoint("CENTER", statusBar, "LEFT", barW * r3, 2)
    tick3:Show()
end

local function on_challenge_mode_update_time(self, elapsedTime)
    if not (dodoDB and dodoDB.enableKeystoneTimer ~= false and dodoDB.useKeystoneTimerTick ~= false) then return end
    if not self._dd_plusThreeElapsed then return end

    if tick3 and elapsedTime > self._dd_plusThreeElapsed then
        tick3:SetVertexColor(1, 1, 1)
    end
    if tick2 and elapsedTime > self._dd_plusTwoElapsed then
        tick2:SetVertexColor(1, 1, 1)
    end
end

-- ==============================
-- 기능 5: 완료 후 최종 시간 표시
-- ==============================
local result_frame = nil

hide_result = function()
    if result_frame then
        result_frame:Hide()
    end
end

local function get_or_create_result_frame()
    if result_frame then return result_frame end

    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(200, 28)
    f:SetFrameStrata("HIGH")

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0, 0, 0, 0.75)

    f.timeText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.timeText:SetPoint("LEFT", f, "LEFT", 10, 0)

    f.statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.statusText:SetPoint("RIGHT", f, "RIGHT", -10, 0)

    f:Hide()

    result_frame = f
    return f
end

local function show_completion_result(elapsedTime, timeLimit, affixes)
    if not (dodoDB and dodoDB.enableKeystoneTimer ~= false) then return end
    if not elapsedTime or not timeLimit or timeLimit <= 0 then return end

    local block = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock
    local f = get_or_create_result_frame()

    if block and block:IsShown() then
        local x, y = block:GetCenter()
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    else
        f:ClearAllPoints()
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -350)
    end

    local plusTwoT, plusThreeT = calculate_bonus_timers(timeLimit, affixes)

    local statusStr, r, g, b
    if elapsedTime <= plusThreeT then
        statusStr = "+3"
        r, g, b = 0.4, 1, 0.4
    elseif elapsedTime <= plusTwoT then
        statusStr = "+2"
        r, g, b = 0.4, 1, 0.4
    elseif elapsedTime <= timeLimit then
        statusStr = "+1"
        r, g, b = 1, 0.85, 0
    else
        statusStr = "시간 초과"
        r, g, b = 1, 0.3, 0.3
    end

    f.timeText:SetText(SecondsToClock(elapsedTime))
    f.timeText:SetTextColor(r, g, b)
    f.statusText:SetText(statusStr)
    f.statusText:SetTextColor(r, g, b)
    f:Show()
end

local function on_challenge_mode_completed()
    local block = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock
    if not block or not block.timerID then return end

    local _, elapsedTime = GetWorldElapsedTime(block.timerID)
    local timeLimit = block.timeLimit
    local _, affixes = C_ChallengeMode.GetActiveKeystoneInfo()

    show_completion_result(elapsedTime, timeLimit, affixes)
end

-- ==============================
-- 기능 6: 인스턴스 진입 시 트래커 자동 접기
-- ==============================
local AUTO_COLLAPSE_MODULES = {
    "ACHIEVEMENT_TRACKER_MODULE",
    "BONUS_OBJECTIVE_TRACKER_MODULE",
    "CAMPAIGN_QUEST_TRACKER_MODULE",
    "QUEST_TRACKER_MODULE",
    "WORLD_QUEST_TRACKER_MODULE",
}

local function set_module_collapsed(module, shouldCollapse)
    if not module or not module.Header or not module.Header.MinimizeButton then return end
    local isCollapsed = module:IsCollapsed() and true or false
    if shouldCollapse ~= isCollapsed then
        module.Header.MinimizeButton:Click()
    end
end

local function update_tracker_collapse()
    if not (dodoDB and dodoDB.enableKeystoneTimer ~= false and dodoDB.useKeystoneTimerAutoCollapse ~= false) then return end
    local inInstance = IsInInstance()
    for _, name in ipairs(AUTO_COLLAPSE_MODULES) do
        set_module_collapsed(_G[name], inInstance)
    end
end

-- ==============================
-- 상태 업데이트
-- ==============================
local function update_visual()
    local master = dodoDB and dodoDB.enableKeystoneTimer ~= false
    local barStyleOn = master and dodoDB.useKeystoneTimerBarStyle ~= false

    local usedBars = ScenarioObjectiveTracker and ScenarioObjectiveTracker.usedProgressBars
    if usedBars then
        for _, progressBar in pairs(usedBars) do
            if barStyleOn then
                apply_bar_style(progressBar)
            else
                remove_bar_style(progressBar)
            end
        end
    end

    if not (master and dodoDB.useKeystoneTimerTick ~= false) then
        if tick2 then tick2:Hide() end
        if tick3 then tick3:Hide() end
    end
end

local function initialize()
    if dodoDB.enableKeystoneTimer == nil then dodoDB.enableKeystoneTimer = true end
    if dodoDB.useKeystoneTimerBarStyle == nil then dodoDB.useKeystoneTimerBarStyle = true end
    if dodoDB.useKeystoneTimerPercent == nil then dodoDB.useKeystoneTimerPercent = true end
    if dodoDB.useKeystoneTimerTick == nil then dodoDB.useKeystoneTimerTick = true end
    if dodoDB.useKeystoneTimerAutoCollapse == nil then dodoDB.useKeystoneTimerAutoCollapse = true end
    local block = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock
    if block then
        hooksecurefunc(block, "Activate", on_challenge_mode_activate)
        hooksecurefunc(block, "UpdateTime", on_challenge_mode_update_time)
    end

    if ScenarioTrackerProgressBarMixin then
        hooksecurefunc(ScenarioTrackerProgressBarMixin, "OnGet", on_progress_bar_on_get)
        hooksecurefunc(ScenarioTrackerProgressBarMixin, "SetValue", on_progress_bar_set_value)
    end

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
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        self:RegisterEvent("CHALLENGE_MODE_RESET")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        on_challenge_mode_completed()
    elseif event == "CHALLENGE_MODE_RESET" then
        hide_result()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsInInstance() then
            hide_result()
        end
        update_tracker_collapse()
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
            name = "쐐기 타이머",
            get = function() return dodoDB and dodoDB.enableKeystoneTimer ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableKeystoneTimer = checked end
                update_visual()
            end
        },
    })
end

if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ObjectiveTracker, {
        {
            name = "디자인 변경",
            get = function() return dodoDB and dodoDB.useKeystoneTimerBarStyle ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useKeystoneTimerBarStyle = checked end
                update_visual()
            end,
            disabled = function() return dodoDB and dodoDB.enableKeystoneTimer == false end,
        },
        {
            name = "퍼센트 소수점",
            get = function() return dodoDB and dodoDB.useKeystoneTimerPercent ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useKeystoneTimerPercent = checked end
            end,
            disabled = function() return dodoDB and dodoDB.enableKeystoneTimer == false end,
        },
        {
            name = "+2 / +3 틱 표시",
            get = function() return dodoDB and dodoDB.useKeystoneTimerTick ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useKeystoneTimerTick = checked end
                update_visual()
            end,
            disabled = function() return dodoDB and dodoDB.enableKeystoneTimer == false end,
        },
        {
            name = "인스턴스 시 트래커 자동 접기",
            get = function() return dodoDB and dodoDB.useKeystoneTimerAutoCollapse ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useKeystoneTimerAutoCollapse = checked end
                update_tracker_collapse()
            end,
            disabled = function() return dodoDB and dodoDB.enableKeystoneTimer == false end,
        },
    })
end
