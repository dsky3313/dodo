-- ==============================
-- Inspired
-- ==============================
-- DamageMeterTools 暴雪傷害統計增強 (https://www.curseforge.com/wow/addons/damagemetertools)
-- Default DamageMeter Tweaks (https://www.curseforge.com/wow/addons/default-damagemeter-tweaks)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 스냅 설정 (수정 가능)
local snapConfig = {
    point = "BOTTOM",       -- 2번 창의 기준점
    relativePoint = "TOP",  -- 1번 창의 기준점
    xOffset = 0,            -- 좌우 간격
    yOffset = 2             -- 상하 간격
}

local MAX_DAMAGE_WINDOWS = 3 -- 블리자드 지원 최대 개수

-- ==============================
-- 캐싱 (가나다 순 정렬)
-- ==============================
local CreateFrame = CreateFrame
local DamageMeter = DamageMeter
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local ResetAllCombatSessions = C_DamageMeter.ResetAllCombatSessions
local SOUNDKIT = SOUNDKIT
local UIParent = UIParent
local _G = _G
local abs = math.abs
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local issecretvalue = issecretvalue
local type = type

local win1, win2, win3 -- 윈도우 캐싱용 변수
local winCache = {}    -- 모든 세션 윈도우 캐싱

local function GetSessionWindow(i)
    if winCache[i] then return winCache[i] end
    local win = (i == 1 and DamageMeterSessionWindow1) or
                (i == 2 and DamageMeterSessionWindow2) or
                (i == 3 and DamageMeterSessionWindow3) or
                _G["DamageMeterSessionWindow"..i]
    if win then winCache[i] = win end
    return win
end

-- ==============================
-- 동작
-- ==============================
local function ApplyWindowSettings(i, win1, isSyncEnabled, isSnapEnabled)
    if InCombatLockdown() then return end
    local win = GetSessionWindow(i)
    if not win then return end

    -- 1. 크기 조절 및 버튼 잠금
    win:SetResizable(not isSyncEnabled)
    local container = win.MinimizeContainer
    local btn = container and container.ResizeButton
    if btn then
        if isSyncEnabled and btn:IsShown() then
            btn:Hide()
        elseif not isSyncEnabled and not btn:IsShown() then
            btn:Show()
            if container and not container:IsShown() then container:Show() end
        end
    end

    -- 2. 스냅 및 크기 동기화
    if isSnapEnabled and win:IsShown() then
        local prevWin = GetSessionWindow(i-1)
        if prevWin then
            -- 위치 고정
            local point, relativeTo = win:GetPoint()
            if relativeTo ~= prevWin then
                win:ClearAllPoints()
                win:SetPoint("BOTTOMLEFT", prevWin, "TOPLEFT", snapConfig.xOffset, snapConfig.yOffset)
            end

            -- 크기 동기화
            if isSyncEnabled then
                local w1, h1 = win1:GetSize()
                local w, h = win:GetSize()
                if abs(w - w1) > 0.1 or abs(h - h1) > 0.1 then
                    win:SetSize(w1, h1)
                end
            end

            -- 이동 기능 차단
            if not win.dodoOriginalStartMoving then
                win.dodoOriginalStartMoving = win.StartMoving
            end
            win.StartMoving = function() end
            win:SetMovable(true)
            if win.SetUserPlaced then win:SetUserPlaced(false) end
        end
    else
        -- 이동 기능 복구
        if win.dodoOriginalStartMoving then
            win.StartMoving = win.dodoOriginalStartMoving
            win.dodoOriginalStartMoving = nil
        end

        local point, relativeTo = win:GetPoint()
        if relativeTo and relativeTo == GetSessionWindow(i-1) then
            local left, bottom = win:GetLeft(), win:GetBottom()
            win:ClearAllPoints()
            if left and bottom then
                win:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            else
                win:SetPoint("CENTER", UIParent, "CENTER", 0, (i-1)*50)
            end
            if win.SetUserPlaced then win:SetUserPlaced(true) end
        end
        win:SetMovable(true)
    end
end

-- 크기 동기화
local function SyncAllWindowSizes()
    local win1 = GetSessionWindow(1)
    if not win1 then return end

    local isSyncEnabled = dodoDB and dodoDB.dmgMeterSyncSize ~= false
    local isSnapEnabled = dodoDB and dodoDB.dmgMeterSnap ~= false

    -- 2~3번 창까지 공통 로직 적용
    for i = 2, MAX_DAMAGE_WINDOWS do
        ApplyWindowSettings(i, win1, isSyncEnabled, isSnapEnabled)
    end
end

-- 메인 창 크기 실시간 동기화 정적 핸들러
local function on_main_size_changed()
    SyncAllWindowSizes()
end

local function HookMainSize()
    if win1 or DamageMeterSessionWindow1 then
        win1 = win1 or DamageMeterSessionWindow1
        win1:HookScript("OnSizeChanged", on_main_size_changed)
    end
end

-- ==============================
-- 초기화 버튼 정적 핸들러 (가비지 프리)
-- ==============================
local function on_reset_down(self)
    self:GetNormalTexture():SetAlpha(0)
    self:GetHighlightTexture():SetAlpha(0)
end

local function on_reset_up(self)
    self:GetNormalTexture():SetAlpha(1)
    self:GetHighlightTexture():SetAlpha(1)
end

local function on_reset_click()
    ResetAllCombatSessions()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

local function on_reset_enter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("피해량 초기화", 1, 1, 1)
    GameTooltip:Show()
end

local function on_reset_leave()
    GameTooltip:Hide()
end

-- ==============================
-- 초기화 버튼 생성
-- ==============================
local function CreateResetButton(win)
    if not win or win.dodoResetBtn then return end

    local resetBtn = CreateFrame("Button", nil, win)
    resetBtn:SetSize(30, 30)
    resetBtn:SetFrameLevel(win:GetFrameLevel() + 20)

    -- atlas
    resetBtn:SetNormalAtlas("common-dropdown-c-button")
    resetBtn:SetPushedAtlas("common-dropdown-c-button-pressed-1")
    resetBtn:SetHighlightAtlas("common-dropdown-c-button-hover-1")

    -- atlas Pushed
    resetBtn:GetNormalTexture():SetDrawLayer("BACKGROUND", 0)
    resetBtn:GetPushedTexture():SetDrawLayer("BACKGROUND", 1)

    resetBtn:SetScript("OnMouseDown", on_reset_down)
    resetBtn:SetScript("OnMouseUp", on_reset_up)

    -- atlas hover
    local highlight = resetBtn:GetHighlightTexture()
    if highlight then
        highlight:SetBlendMode("BLEND")
    end

    -- icon
    resetBtn.IconFrame = CreateFrame("Frame", nil, resetBtn)
    resetBtn.IconFrame:SetAllPoints()

    -- icon
    resetBtn.Icon = resetBtn.IconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    resetBtn.Icon:SetPoint("CENTER", 0, 0)
    resetBtn.Icon:SetSize(14, 14)
    resetBtn.Icon:SetAtlas("UI-RefreshButton")

    if win.SessionDropdown and win.SessionDropdown:IsShown() then
        resetBtn:SetPoint("RIGHT", win.SessionDropdown, "LEFT", -4, 0)
    else
        resetBtn:SetPoint("RIGHT", win.SettingsDropdown, "LEFT", -4, 0)
    end

    -- 클릭 이벤트
    resetBtn:SetScript("OnClick", on_reset_click)

    -- 툴팁
    resetBtn:SetScript("OnEnter", on_reset_enter)
    resetBtn:SetScript("OnLeave", on_reset_leave)

    win.dodoResetBtn = resetBtn
end

local function ApplyResetButtons()
    local isEnabled = dodoDB and dodoDB.dmgMeterResetButton ~= false
    for i = 1, MAX_DAMAGE_WINDOWS do
        local win = GetSessionWindow(i)
        if win then
            if isEnabled then
                CreateResetButton(win)
                if win.dodoResetBtn then win.dodoResetBtn:Show() end
            else
                if win.dodoResetBtn then win.dodoResetBtn:Hide() end
            end
        end
    end
end

dodo.UpdateDamageMeterResetButtons = ApplyResetButtons

-- ==============================
-- 이벤트 핸들러 (가비지 프리 정적 참조)
-- ==============================
local function on_secondary_session_shown()
    SyncAllWindowSizes()
    ApplyResetButtons()
end

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        self:UnregisterEvent("ADDON_LOADED")

        if dodoDB.dmgMeterSyncSize == nil then
            dodoDB.dmgMeterSyncSize = true
        end
        if dodoDB.dmgMeterSnap == nil then
            dodoDB.dmgMeterSnap = true
        end
        if dodoDB.dmgMeterResetButton == nil then
            dodoDB.dmgMeterResetButton = true
        end

        hooksecurefunc(DamageMeter, "ShowNewSecondarySessionWindow", on_secondary_session_shown)

    elseif event == "PLAYER_ENTERING_WORLD" then
        HookMainSize()
        SyncAllWindowSizes()
        ApplyResetButtons()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

-- ==============================
-- 이벤트 등록
-- ==============================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", on_event)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.SyncDamageMeterSize = SyncAllWindowSizes

-- ==============================
-- 설정 동적 등록 (Option.lua 연동)
-- ==============================
local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["combat"] = dodo.OptionRegistrations["combat"] or {}
table.insert(dodo.OptionRegistrations["combat"], function(category)
    local layoutCombat = SettingsPanel:GetLayout(category)
    if not layoutCombat then return end

    layoutCombat:AddInitializer(CreateSettingsListSectionHeaderInitializer("피해량 측정기 (미터기)"))
    Checkbox(category, "dmgMeterSyncSize", "창 크기 동기화", "보조 창들의 크기를 메인 창과 동일하게 맞춥니다.", true, dodo.SyncDamageMeterSize)
    Checkbox(category, "dmgMeterSnap", "창 붙이기", "보조 창을 메인 창 상단에 붙입니다.", true, dodo.SyncDamageMeterSize)
    Checkbox(category, "dmgMeterResetButton", "초기화 버튼 생성", "미터기 상단에 데이터 초기화(Reset) 버튼을 생성합니다.", true, dodo.UpdateDamageMeterResetButtons)
end)
