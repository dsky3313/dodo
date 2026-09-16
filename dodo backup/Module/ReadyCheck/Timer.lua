-- ==============================
-- Inspired
-- ==============================
-- ReadyCheckTimer

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetTime = GetTime
local ReadyCheckFrame = ReadyCheckFrame
local UIParent = UIParent

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local main_frame = nil
local is_active = false
local expiration_time = 0
local hide_timer_handle = nil

local initFrame = CreateFrame("Frame")

-- ==============================
-- 기능 2: 상태 업데이트
-- ==============================
local function stop_timer()
    is_active = false
    if main_frame then
        main_frame:Hide()
        if main_frame.updater then
            main_frame.updater:Stop()
        end
    end
    if hide_timer_handle then
        hide_timer_handle:Cancel()
        hide_timer_handle = nil
    end
end

local function on_loop()
    if not is_active then return end
    local remaining = expiration_time - GetTime()
    if remaining <= 0 then
        stop_timer()
        return
    end
    main_frame:SetValue(remaining)
    if main_frame.text then
        main_frame.text:SetFormattedText("%d", math.ceil(remaining))
    end
end

local function update_visual()
    local isEnabled = (dodoDB and dodoDB.enableReadyCheckTimer ~= false)
    if isEnabled then
        if initFrame then
            initFrame:RegisterEvent("READY_CHECK")
            initFrame:RegisterEvent("READY_CHECK_FINISHED")
        end
    else
        if initFrame then
            initFrame:UnregisterEvent("READY_CHECK")
            initFrame:UnregisterEvent("READY_CHECK_FINISHED")
        end
        stop_timer()
    end
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function create_ui()
    if main_frame then return end

    main_frame = CreateFrame("StatusBar", "dodo_ReadyCheckTimerFrame", UIParent)
    main_frame:SetHeight(10)
    main_frame:ClearAllPoints()
    main_frame:SetPoint("BOTTOMLEFT", ReadyCheckFrame, "TOPLEFT", 0, -3)
    main_frame:SetPoint("BOTTOMRIGHT", ReadyCheckFrame, "TOPRIGHT", 0, -3)

    main_frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    main_frame:SetStatusBarColor(0.26, 0.42, 1, 1)
    main_frame:SetMinMaxValues(0, 1)
    main_frame:SetValue(0)

    -- 배경 (어두운 남색, ObjectiveTracker 동일)
    local bg = main_frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.07, 0.18, 1)

    -- 왼쪽 캡
    local borderLeft = main_frame:CreateTexture(nil, "ARTWORK")
    borderLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    borderLeft:SetSize(9, 14)
    borderLeft:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
    borderLeft:SetPoint("LEFT", main_frame, "LEFT", -3, 0)

    -- 오른쪽 캡 (TexCoord 좌우 반전)
    local borderRight = main_frame:CreateTexture(nil, "ARTWORK")
    borderRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    borderRight:SetSize(9, 14)
    borderRight:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
    borderRight:SetPoint("RIGHT", main_frame, "RIGHT", 3, 0)

    -- 중간 스트레치 (BorderLeft.TOPRIGHT ~ BorderRight.BOTTOMLEFT)
    local borderMid = main_frame:CreateTexture(nil, "ARTWORK")
    borderMid:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    borderMid:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
    borderMid:SetPoint("TOPLEFT", borderLeft, "TOPRIGHT", 0, 0)
    borderMid:SetPoint("BOTTOMRIGHT", borderRight, "BOTTOMLEFT", 0, 0)

    local text = main_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", 0, 3)
    text:SetText("")
    main_frame.text = text

    local updater = main_frame:CreateAnimationGroup()
    updater:SetLooping("REPEAT")
    local anim = updater:CreateAnimation()
    anim:SetDuration(0.04)
    updater:SetScript("OnLoop", on_loop)
    main_frame.updater = updater

    main_frame:Hide()
end

local function initialize()
    if dodoDB and dodoDB.enableReadyCheckTimer == nil then dodoDB.enableReadyCheckTimer = true end
    create_ui()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function hide_timer_delayed()
    stop_timer()
end

local function on_event(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        initialize()
        update_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "READY_CHECK" then
        if hide_timer_handle then
            hide_timer_handle:Cancel()
            hide_timer_handle = nil
        end

        local duration = arg2 or 35
        expiration_time = GetTime() + duration
        is_active = true

        if main_frame then
            main_frame:SetMinMaxValues(0, duration)
            main_frame:SetValue(duration)
            if main_frame.text then
                main_frame.text:SetFormattedText("%d", math.ceil(duration))
            end
            main_frame.updater:Play()
            main_frame:Show()
        end
    elseif event == "READY_CHECK_FINISHED" then
        if hide_timer_handle then
            hide_timer_handle:Cancel()
        end
        hide_timer_handle = C_Timer.NewTimer(2, hide_timer_delayed)
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
            name = "전투준비 타이머 활성화",
            get = function() return dodoDB and dodoDB.enableReadyCheckTimer ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableReadyCheckTimer = checked end
                update_visual()
            end
        }
    })
end