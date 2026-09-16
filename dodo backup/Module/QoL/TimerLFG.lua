-- ==============================
-- Inspired
-- ==============================
-- LFGTimer (BigWigs LFGTimer 로직 이식)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local Checkbox = Checkbox
local CreateFrame = CreateFrame
local GetTime = GetTime
local LFGDungeonReadyPopup = LFGDungeonReadyPopup

-- ==============================
-- 기능 1: 로컬 상태 및 설정
-- ==============================
local LFG_DURATION = 40

local main_frame = nil
local is_active = false
local expiration_time = 0

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
    local isEnabled = (dodoDB and dodoDB.enableLFGTimer ~= false)
    if isEnabled then
        if initFrame then
            initFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
            initFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
            initFrame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
        end
    else
        if initFrame then
            initFrame:UnregisterEvent("LFG_PROPOSAL_SHOW")
            initFrame:UnregisterEvent("LFG_PROPOSAL_FAILED")
            initFrame:UnregisterEvent("LFG_PROPOSAL_SUCCEEDED")
        end
        stop_timer()
    end
end

-- ==============================
-- 기능 3: UI 생성
-- ==============================
local function create_ui()
    if main_frame then return end

    main_frame = CreateFrame("StatusBar", "dodo_LFGTimerFrame", LFGDungeonReadyPopup)
    main_frame:SetHeight(10)
    main_frame:ClearAllPoints()
    main_frame:SetPoint("TOPLEFT", LFGDungeonReadyPopup, "BOTTOMLEFT", 0, -3)
    main_frame:SetPoint("TOPRIGHT", LFGDungeonReadyPopup, "BOTTOMRIGHT", 0, -3)

    main_frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    main_frame:SetStatusBarColor(0.26, 0.42, 1, 1)
    main_frame:SetMinMaxValues(0, LFG_DURATION)
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
    if dodoDB and dodoDB.enableLFGTimer == nil then dodoDB.enableLFGTimer = true end
    create_ui()
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
    elseif event == "LFG_PROPOSAL_SHOW" then
        expiration_time = GetTime() + LFG_DURATION
        is_active = true

        if main_frame then
            main_frame:SetMinMaxValues(0, LFG_DURATION)
            main_frame:SetValue(LFG_DURATION)
            if main_frame.text then
                main_frame.text:SetFormattedText("%d", LFG_DURATION)
            end
            main_frame.updater:Play()
            main_frame:Show()
        end
    elseif event == "LFG_PROPOSAL_FAILED" or event == "LFG_PROPOSAL_SUCCEEDED" then
        stop_timer()
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "enableLFGTimer", "던전찾기 타이머", "던전찾기 수락 팝업에 남은 시간 타이머를 표시합니다.", true, function()
        update_visual()
    end)
end)
