-- ==============================
-- Inspired
-- ==============================
-- dodo

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local max_damage_windows = 3

-- ==============================
-- 캐싱
-- ==============================
local C_DamageMeter = C_DamageMeter
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local _G = _G

local win_cache = {}

local function get_session_window(i)
    if win_cache[i] then return win_cache[i] end
    local win = (i == 1 and DamageMeterSessionWindow1) or
                (i == 2 and DamageMeterSessionWindow2) or
                (i == 3 and DamageMeterSessionWindow3) or
                _G["DamageMeterSessionWindow"..i]
    if win then win_cache[i] = win end
    return win
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
    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
        C_DamageMeter.ResetAllCombatSessions()
    end
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
local function create_reset_button(win)
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

local function update_state()
    local is_enabled = dodoDB and dodoDB.enableDamageMeter ~= false and dodoDB.dmgMeterResetButton ~= false
    for i = 1, max_damage_windows do
        local win = get_session_window(i)
        if win then
            if is_enabled then
                create_reset_button(win)
                if win.dodoResetBtn then win.dodoResetBtn:Show() end
            else
                if win.dodoResetBtn then win.dodoResetBtn:Hide() end
            end
        end
    end
end

-- 외부 바인딩 노출
dodo.UpdateDamageMeterResetState = update_state
