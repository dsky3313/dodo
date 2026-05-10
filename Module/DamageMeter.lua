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
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local hooksecurefunc = hooksecurefunc
local issecretvalue = issecretvalue
local ipairs = ipairs
local _G = _G
local abs = math.abs

local DamageMeter = DamageMeter
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

-- 메인 창 크기 실시간 동기화
local function HookMainSize()
    if win1 or DamageMeterSessionWindow1 then
        win1 = win1 or DamageMeterSessionWindow1
        win1:HookScript("OnSizeChanged", function()
            SyncAllWindowSizes()
        end)
    end
end

-- ==============================
-- 초기화 버튼
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

    resetBtn:SetScript("OnMouseDown", function()
        resetBtn:GetNormalTexture():SetAlpha(0)
        resetBtn:GetHighlightTexture():SetAlpha(0)
    end)
    resetBtn:SetScript("OnMouseUp", function()
        resetBtn:GetNormalTexture():SetAlpha(1)
        resetBtn:GetHighlightTexture():SetAlpha(1)
    end)

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
    resetBtn:SetScript("OnClick", function()
        C_DamageMeter.ResetAllCombatSessions()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    -- 툴팁
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("피해량 초기화", 1, 1, 1)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
-- 이벤트
-- ==============================
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        frame:UnregisterEvent("ADDON_LOADED")

        if dodoDB.dmgMeterSyncSize == nil then
            dodoDB.dmgMeterSyncSize = true
        end
        if dodoDB.dmgMeterSnap == nil then
            dodoDB.dmgMeterSnap = true
        end
        if dodoDB.dmgMeterResetButton == nil then
            dodoDB.dmgMeterResetButton = true
        end

        hooksecurefunc(DamageMeter, "ShowNewSecondarySessionWindow", function()
            SyncAllWindowSizes()
            ApplyResetButtons()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        HookMainSize()
        SyncAllWindowSizes()
        ApplyResetButtons()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.SyncDamageMeterSize = SyncAllWindowSizes
