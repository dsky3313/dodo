-- ==============================
-- Inspired
-- ==============================
-- EXBoss DenOfNalorakk/DungeonCommon.lua

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame     = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local GetTime         = GetTime
local IsInInstance    = IsInInstance
local math_ceil       = math.ceil
local UIParent        = UIParent

-- ==============================
-- 상수
-- ==============================
-- 날로라크의 소굴: GetInstanceInfo() 8번째 반환값 (안정적 맵 ID)
local INSTANCE_ID  = 2825
local BAR_DURATION = 50   -- 모진바람 주기 (초)

-- ==============================
-- 상태
-- ==============================
local main_frame      = nil
local is_active       = false
local expiration_time = 0
local boss_kill_count = 0
local in_encounter    = false
local current_inst_id = 0

local initFrame = CreateFrame("Frame")

-- ==============================
-- 타이머 제어
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
        main_frame.text:SetFormattedText("모진바람 %d", math_ceil(remaining))
    end
end

-- ==============================
-- 활성화 조건: 1번 보스 사망 후 2번 보스 전투 시작 전
-- ==============================
local function is_warning_window()
    local _, instance_type = IsInInstance()
    if instance_type ~= "party" then return false end
    if current_inst_id ~= INSTANCE_ID then return false end
    return boss_kill_count == 1 and not in_encounter
end

local function start_timer()
    if not is_warning_window() then
        stop_timer()
        return
    end
    expiration_time = GetTime() + BAR_DURATION
    is_active = true
    if main_frame then
        main_frame:SetMinMaxValues(0, BAR_DURATION)
        main_frame:SetValue(BAR_DURATION)
        if main_frame.text then
            main_frame.text:SetFormattedText("모진바람 %d", BAR_DURATION)
        end
        main_frame.updater:Play()
        main_frame:Show()
    end
end

-- ==============================
-- 이벤트 등록/해제
-- ==============================
local function update_visual()
    local isEnabled = (dodoDB and dodoDB.enableEJDungeonEvent ~= false)
    if isEnabled then
        initFrame:RegisterEvent("ENCOUNTER_WARNING")
        initFrame:RegisterEvent("BOSS_KILL")
        initFrame:RegisterEvent("ENCOUNTER_START")
        initFrame:RegisterEvent("ENCOUNTER_END")
        initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        initFrame:UnregisterEvent("ENCOUNTER_WARNING")
        initFrame:UnregisterEvent("BOSS_KILL")
        initFrame:UnregisterEvent("ENCOUNTER_START")
        initFrame:UnregisterEvent("ENCOUNTER_END")
        initFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        stop_timer()
    end
end

-- ==============================
-- UI 생성
-- ==============================
local function create_ui()
    if main_frame then return end

    main_frame = CreateFrame("StatusBar", "dodo_DungeonEventTimerFrame", UIParent)
    main_frame:SetSize(220, 16)
    main_frame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    main_frame:SetFrameStrata("HIGH")

    main_frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    main_frame:SetStatusBarColor(0.4, 0.7, 1, 1)
    main_frame:SetMinMaxValues(0, BAR_DURATION)
    main_frame:SetValue(0)

    local bg = main_frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.07, 0.18, 1)

    local borderLeft = main_frame:CreateTexture(nil, "ARTWORK")
    borderLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    borderLeft:SetSize(9, 14)
    borderLeft:SetTexCoord(0.007843, 0.043137, 0.193548, 0.774193)
    borderLeft:SetPoint("LEFT", main_frame, "LEFT", -3, 0)

    local borderRight = main_frame:CreateTexture(nil, "ARTWORK")
    borderRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    borderRight:SetSize(9, 14)
    borderRight:SetTexCoord(0.043137, 0.007843, 0.193548, 0.774193)
    borderRight:SetPoint("RIGHT", main_frame, "RIGHT", 3, 0)

    local borderMid = main_frame:CreateTexture(nil, "ARTWORK")
    borderMid:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder")
    borderMid:SetTexCoord(0.113726, 0.1490196, 0.193548, 0.774193)
    borderMid:SetPoint("TOPLEFT", borderLeft, "TOPRIGHT", 0, 0)
    borderMid:SetPoint("BOTTOMRIGHT", borderRight, "BOTTOMLEFT", 0, 0)

    local text = main_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER", 0, 0)
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
    if dodoDB and dodoDB.enableEJDungeonEvent == nil then dodoDB.enableEJDungeonEvent = true end
    create_ui()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "dodoQOL" then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        initialize()
        update_visual()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        local new_inst_id = tonumber(instanceID) or 0
        -- 인스턴스 변경 시에만 리셋 (같은 던전 내 시체 달려가기는 유지)
        if new_inst_id ~= current_inst_id then
            boss_kill_count = 0
            in_encounter    = false
            current_inst_id = new_inst_id
        end
        stop_timer()
    elseif event == "BOSS_KILL" then
        boss_kill_count = boss_kill_count + 1
        if boss_kill_count ~= 1 then stop_timer() end
    elseif event == "ENCOUNTER_START" then
        in_encounter = true
        stop_timer()
    elseif event == "ENCOUNTER_END" then
        in_encounter = false
    elseif event == "ENCOUNTER_WARNING" then
        -- ENCOUNTER_WARNING 파라미터 미필터: 창 조건이 맞을 때만 타이머 시작/리셋
        start_timer()
    end
end

initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", on_event)

-- ==============================
-- 공개 API
-- ==============================
dodo.EJDungeonEventUpdateVisual = update_visual
