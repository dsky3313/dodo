-- ==============================
-- Inspired
-- ==============================
-- ActionBarsEnhanced (https://www.curseforge.com/wow/addons/actionbarsenhanced)
-- ActionBar Interrupt Highlight (https://www.curseforge.com/wow/addons/actionbarinterrupthighlight)
-- CDMButtonAuras (https://www.curseforge.com/wow/addons/cdmbuttonauras)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local config = {
    colors = {
        range  = { r = 0.9, g = 0.1, b = 0.1 },
        mana   = { r = 0.1, g = 0.3, b = 1.0 },
        normal = { r = 1.0, g = 1.0, b = 1.0 }
    },
    replaceText = {
        { "SHIFT[%-%+]", "S" },
        { "CTRL[%-%+]", "C" },
        { "ALT[%-%+]", "A" },
        { "NUMPADMINUS", "N-" },
        { "NUMPADPLUS", "N+" },
        { "SPACE", "SP" },
        { "MOUSEWHEELUP", "MWU" },
        { "MOUSEWHEELDOWN", "MWD" },
        { "[%s%-]", "" }
    }
}

local Interrupts = {
    [47528]  = true, -- Mind Freeze          (죽기)
    [183752] = true, -- Disrupt              (악마사냥꾼)
    [78675]  = true, -- Solar Beam           (드루이드)
    [106839] = true, -- Skull Bash           (드루이드)
    [147362] = true, -- Counter Shot         (사냥꾼)
    [187707] = true, -- Muzzle               (사냥꾼)
    [2139]   = true, -- Counterspell         (마법사)
    [116705] = true, -- Spear Hand Strike    (수도사)
    [96231]  = true, -- Rebuke               (성기사)
    [15487]  = true, -- Silence              (사제)
    [1766]   = true, -- Kick                 (도적)
    [57994]  = true, -- Wind Shear           (주술사)
    [119910] = true, -- Spell Lock           (술사 지옥사냥개)
    [132409] = true, -- Spell Lock           (술사 지옥 약탈자)
    [89766]  = true, -- Axe Toss             (술사 지옥경비원)
    [6552]   = true, -- Pummel               (전사)
    [351338] = true, -- Quell                (기원사)
}

local IntEvents = {
    'ACTIONBAR_SLOT_CHANGED',
    'PLAYER_TARGET_CHANGED',
    'PLAYER_FOCUS_CHANGED',
}

local IntUnitEvents = {
    'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE',
    'UNIT_SPELLCAST_DELAYED',
    'UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_INTERRUPTIBLE',
    'UNIT_SPELLCAST_NOT_INTERRUPTIBLE',
    'UNIT_SPELLCAST_START',
    'UNIT_SPELLCAST_STOP',
}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local GetActionInfo = GetActionInfo
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local UnitCastingDuration = UnitCastingDuration
local UnitCastingInfo = UnitCastingInfo
local UnitChannelDuration = UnitChannelDuration
local UnitChannelInfo = UnitChannelInfo
local UnitExists = UnitExists

-- 변수
local ActionBarButtonEventsFrame = ActionBarButtonEventsFrame
local ActionBarButtonRangeCheckFrame = ActionBarButtonRangeCheckFrame
local AnchorUtil = AnchorUtil
local BuffBarCooldownViewer = BuffBarCooldownViewer
local BuffIconCooldownViewer = BuffIconCooldownViewer
local CreateFramePool = CreateFramePool
local FrameUtil = FrameUtil
local GridLayoutUtil = GridLayoutUtil
local MainActionBar = MainActionBar
local MultiBar5 = MultiBar5
local MultiBar6 = MultiBar6
local MultiBar7 = MultiBar7
local MultiBarBottomLeft = MultiBarBottomLeft
local MultiBarBottomRight = MultiBarBottomRight
local MultiBarLeft = MultiBarLeft
local MultiBarRight = MultiBarRight
local PixelUtil = PixelUtil
local PetActionBar = PetActionBar
local StanceBar = StanceBar

local activeOverlays = {}
local inCombat = false
local registeredButtons = {}
local watchedUnit = 'target'

local DesatCurve = C_CurveUtil.CreateCurve()
DesatCurve:SetType(Enum.LuaCurveType.Step)
DesatCurve:AddPoint(0, 0)
DesatCurve:AddPoint(0.001, 1)

local ReadyCurve = C_CurveUtil.CreateCurve()
ReadyCurve:SetType(Enum.LuaCurveType.Step)
ReadyCurve:AddPoint(0, 1)
ReadyCurve:AddPoint(0.001, 0)

local IntCooldownCurve = C_CurveUtil.CreateCurve()
IntCooldownCurve:SetType(Enum.LuaCurveType.Step)
IntCooldownCurve:AddPoint(0, 0)
IntCooldownCurve:AddPoint(0.001, 1)

local timerColorCurve = C_CurveUtil.CreateColorCurve()
timerColorCurve:SetType(Enum.LuaCurveType.Linear)
timerColorCurve:AddPoint(0.0,  CreateColor(1, 0.5, 0.5, 1))
timerColorCurve:AddPoint(3.0,  CreateColor(1, 1,   0.5, 1))
timerColorCurve:AddPoint(3.01, CreateColor(1, 1,   1,   1))
timerColorCurve:AddPoint(10.0, CreateColor(1, 1,   1,   1))

-- ==============================
-- 디스플레이
-- ==============================
-- CDM Overlay Mixin
dodo_Actionbar2OverlayMixin = {}

function dodo_Actionbar2OverlayMixin:OnLoad()
    local parent = self:GetParent()
    self:SetSize(parent:GetSize())
    self:SetFrameLevel(parent:GetFrameLevel() + 1)
    self.InnerGlow:SetVertexColor(0, 1, 0, 1)
    self.Timer:SetTextColor(0, 1, 0)
    self:Hide()
end

function dodo_Actionbar2OverlayMixin:StartTicker()
    if self._ticker then self._ticker:Cancel() end
    local interval = inCombat and 0.1 or 1.0
    self._ticker = C_Timer.NewTicker(interval, function()
        local item = self.viewerItem
        local auraInstanceID = item and rawget(item, "auraInstanceID")
        local auraDataUnit   = item and rawget(item, "auraDataUnit")
        if not auraInstanceID or not auraDataUnit then
            self:StopTicker()
            return
        end
        local durObj = C_UnitAuras.GetAuraDuration(auraDataUnit, auraInstanceID)
        if durObj then
            self.Timer:SetFormattedText("%d", durObj:GetRemainingDuration())
            self.Timer:Show()
        else
            self:StopTicker()
        end
    end)
    activeOverlays[self] = true
end

function dodo_Actionbar2OverlayMixin:StopTicker()
    if self._ticker then
        self._ticker:Cancel(); self._ticker = nil
    end
    activeOverlays[self] = nil
    self.Timer:Hide()
    self.InnerGlow:Hide()
    self:Hide()
end

function dodo_Actionbar2OverlayMixin:Update()
    local isEnabled = (dodoDB and dodoDB.useActionbarCDM ~= false)
    if not isEnabled then self:StopTicker(); return end

    local hasAura = self.viewerItem and rawget(self.viewerItem, "auraInstanceID") ~= nil
    if hasAura then
        self.InnerGlow:Show()
        self:Show()
        self:StartTicker()
    else
        self:StopTicker()
    end
end

-- Interrupt Overlay Mixin
dodoAB3OverlayMixin = {}

function dodoAB3OverlayMixin:OnHide()
    self:StopAnim()
    self:StopTimer()
end

function dodoAB3OverlayMixin:OnUpdate(elapsed)
    self.timerElapsed = (self.timerElapsed or 0) + elapsed
    if self.timerElapsed < 0.1 then return end
    self.timerElapsed = 0
    if self.duration then
        local timeText = string.format("%0.1f", self.duration:GetRemainingDuration())
        local color    = self.duration:EvaluateRemainingDuration(timerColorCurve)
        self.TimerReady:SetText(timeText)
        self.TimerReady:SetTextColor(color:GetRGB())
        self.TimerCooldown:SetText(timeText)
    else
        self:StopTimer()
    end
end

function dodoAB3OverlayMixin:StopAnim()
    if self.ProcLoop:IsPlaying() then self.ProcLoop:Stop() end
end

function dodoAB3OverlayMixin:StartTimer(duration)
    self.duration = duration
    self.timerElapsed = 0.1
    self.TimerReady:Show()
    self.TimerCooldown:Show()
    self:SetScript('OnUpdate', self.OnUpdate)
end

function dodoAB3OverlayMixin:StopTimer()
    self.duration = nil
    self.timerElapsed = 0
    self.TimerReady:Hide()
    self.TimerCooldown:Hide()
    self:SetScript('OnUpdate', nil)
end

function dodoAB3OverlayMixin:Update(active, notInterruptible, duration, readyVal, cooldownVal)
    local isEnabled = (dodoDB and dodoDB.useActionbarInterrupt ~= false)
    if not isEnabled then self:Hide(); return end

    if active then
        self:StartTimer(duration)
        self.ProcReady:SetAlpha(readyVal)
        self.TimerReady:SetAlpha(readyVal)
        self.ProcCooldown:SetAlpha(cooldownVal)
        self.TimerCooldown:SetAlpha(cooldownVal)
        if not self.ProcLoop:IsPlaying() then self.ProcLoop:Play() end
        self:SetAlphaFromBoolean(notInterruptible, 0, 1)
        self:Show()
    else
        self:Hide()
    end
end

function dodoAB3OverlayMixin:Attach(actionButton)
    self:SetParent(actionButton)
    self.button = actionButton
    self:ClearAllPoints()
    self:SetPoint('CENTER')
    local w, h = actionButton:GetSize()
    PixelUtil.SetSize(self, w, h)
    self.ProcReady:SetSize(w * 1.4, h * 1.4)
    self.ProcCooldown:SetSize(w * 1.4, h * 1.4)
    if actionButton.cooldown and not actionButton.__dodoAB3Hooked then
        actionButton.cooldown:HookScript("OnCooldownDone", function()
            dodoAB3ControllerMixin.controller:Update()
        end)
        actionButton.__dodoAB3Hooked = true
    end
end

-- Interrupt Controller Mixin
dodoAB3ControllerMixin = {}

function dodoAB3ControllerMixin:OnLoad()
    dodoAB3ControllerMixin.controller = self
    self:RegisterEvent('PLAYER_LOGIN')
end

function dodoAB3ControllerMixin:Initialize()
    self.overlayPool = CreateFramePool('Frame', nil, 'dodoAB3OverlayTemplate')
    FrameUtil.RegisterFrameForEvents(self, IntEvents)
    for _, event in ipairs(IntUnitEvents) do
        self:RegisterUnitEvent(event, 'focus', 'target')
    end
    watchedUnit = UnitExists('focus') and 'focus' or 'target'
end

function dodoAB3ControllerMixin:IsRelevantActionID(actionID)
    local _, spellID = GetActionInfo(actionID)
    if Interrupts[spellID] then return true end
    for overlay in self.overlayPool:EnumerateActive() do
        if overlay.spellID == spellID then return true end
    end
    return false
end

function dodoAB3ControllerMixin:CreateOverlays()
    self.overlayPool:ReleaseAll()
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        local _, spellID = GetActionInfo(actionButton.action)
        if Interrupts[spellID] then
            local overlay = self.overlayPool:Acquire()
            overlay.spellID = spellID
            overlay:Attach(actionButton)
        end
    end
end

function dodoAB3ControllerMixin:RefreshOverlays(isActive, notInterruptible, castDuration)
    for overlay in self.overlayPool:EnumerateActive() do
        local readyVal, cooldownVal = 1, 0
        if isActive and overlay.button and overlay.button.action then
            local cdDuration = C_ActionBar.GetActionCooldownDuration(overlay.button.action)
            local cdInfo     = C_ActionBar.GetActionCooldown(overlay.button.action)
            if cdDuration and cdInfo and not cdInfo.isOnGCD then
                readyVal    = cdDuration:EvaluateRemainingDuration(ReadyCurve)
                cooldownVal = cdDuration:EvaluateRemainingDuration(IntCooldownCurve)
            end
        end
        overlay:Update(isActive, notInterruptible, castDuration, readyVal, cooldownVal)
    end
end

function dodoAB3ControllerMixin:Update()
    local isEnabled = (dodoDB and dodoDB.useActionbarInterrupt ~= false)
    if not isEnabled then
        self:RefreshOverlays(false)
        return
    end

    local name, notInterruptible
    name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(watchedUnit)
    if name then
        self:RefreshOverlays(true, notInterruptible, UnitCastingDuration(watchedUnit))
        return
    end
    name, _, _, _, _, _, notInterruptible = UnitChannelInfo(watchedUnit)
    if name then
        self:RefreshOverlays(true, notInterruptible, UnitChannelDuration(watchedUnit))
        return
    end
    self:RefreshOverlays(false)
end

function dodoAB3ControllerMixin:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
        self:CreateOverlays()
        self:Update()
    elseif event == 'ACTIONBAR_SLOT_CHANGED' then
        local actionID = ...
        if self:IsRelevantActionID(actionID) then
            self:CreateOverlays()
            self:Update()
        end
    elseif event == 'PLAYER_TARGET_CHANGED' or event == 'PLAYER_FOCUS_CHANGED' then
        watchedUnit = UnitExists('focus') and 'focus' or 'target'
        self:Update()
    elseif event:sub(1, 14) == 'UNIT_SPELLCAST' then
        local unit = ...
        if unit == watchedUnit then self:Update() end
    end
end

-- ==============================
-- 동작
-- ==============================
local function GetShortenedKey(text)
    local RANGE_INDICATOR = "●"
    if not text or text == "" or text == RANGE_INDICATOR then return text end
    text = text:upper()
    for _, rule in ipairs(config.replaceText) do text = text:gsub(rule[1], rule[2]) end
    return text
end

local function UpdateButtonText(btn)
    if not btn.HotKey then return end
    local RANGE_INDICATOR = "●"
    local text = btn.HotKey:GetText()

    local hideHotkeys = (dodoDB and dodoDB.useActionbarHideHotkeys ~= false)
    local hideMacroNames = (dodoDB and dodoDB.useActionbarHideMacroNames == true)

    if hideHotkeys then
        btn.HotKey:SetAlpha(text == RANGE_INDICATOR and 1 or 0)
    else
        btn.HotKey:SetAlpha(1)
        local short = GetShortenedKey(text)
        if text ~= short then btn.HotKey:SetText(short) end
    end
    if btn.Name and not (btn:GetName() or ""):find("Pet") then
        btn.Name:SetAlpha(hideMacroNames and 0 or 1)
    end
end

local function UpdateIconColor(btn)
    if not btn.icon then return end

    local useColor = (dodoDB and dodoDB.useActionbarColor ~= false)
    if not useColor then
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturation(0)
        return
    end

    local r, g, b, desat = 1, 1, 1, 0
    if btn.__isOutOfRange then
        r, g, b, desat = config.colors.range.r, config.colors.range.g, config.colors.range.b, 1
    elseif btn.__isNotEnoughMana then
        r, g, b, desat = config.colors.mana.r, config.colors.mana.g, config.colors.mana.b, 1
    else
        r, g, b = config.colors.normal.r, config.colors.normal.g, config.colors.normal.b
        if btn.__isUsable == false then
            desat = 1
        elseif btn.__cdVal then
            desat = btn.__cdVal:EvaluateRemainingDuration(DesatCurve)
        else
            desat = 0
        end
    end
    btn.icon:SetVertexColor(r, g, b)
    btn.icon:SetDesaturation(desat)
end

local function UpdateState(btn)
    if not btn.action then return end
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(btn.action)
    local inRange = C_ActionBar.IsActionInRange(btn.action)
    btn.__isUsable = isUsable
    btn.__isNotEnoughMana = notEnoughMana
    btn.__isOutOfRange = (inRange == false)
    UpdateIconColor(btn)
    UpdateButtonText(btn)
end

local function UpdateCooldownState(btn)
    if not btn.action then return end
    local dur  = C_ActionBar.GetActionCooldownDuration(btn.action)
    local info = C_ActionBar.GetActionCooldown(btn.action)
    btn.__cdVal = (dur and info and not info.isOnGCD) and dur or nil
    UpdateIconColor(btn)
end

local function UpdatePadding(frame)
    if InCombatLockdown() or not frame or not frame.shownButtonContainers then return end

    local pad = (dodoDB and dodoDB.actionbarPadding) or 0
    local numRows = frame.numRows or 1
    local stride  = math.ceil(#frame.shownButtonContainers / numRows)
    local xMult   = frame.addButtonsToRight and 1 or -1
    local yMult   = frame.addButtonsToTop and 1 or -1
    local anchor  = frame.addButtonsToTop
        and (frame.addButtonsToRight and "BOTTOMLEFT" or "BOTTOMRIGHT")
        or  (frame.addButtonsToRight and "TOPLEFT"    or "TOPRIGHT")

    local layout = frame.isHorizontal
        and GridLayoutUtil.CreateStandardGridLayout(stride, pad, pad, xMult, yMult)
        or  GridLayoutUtil.CreateVerticalGridLayout(stride, pad, pad, xMult, yMult)
    GridLayoutUtil.ApplyGridLayout(frame.shownButtonContainers, AnchorUtil.CreateAnchor(anchor, frame, anchor), layout)
    if frame.Layout then frame:Layout() end
end

local function BuildButtonCache()
    dodo.buttonCache = {}
    local groups = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
        "StanceButton"
    }
    for _, group in ipairs(groups) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.action then
                local _, actionSpellID = GetActionInfo(btn.action)
                if actionSpellID then
                    local baseSpellID = C_Spell.GetBaseSpell(actionSpellID)
                    local spellName = C_Spell.GetSpellName(baseSpellID)
                    if spellName then
                        dodo.buttonCache[spellName] = dodo.buttonCache[spellName] or {}
                        table.insert(dodo.buttonCache[spellName], btn)
                    end
                end
            end
        end
    end
end

local function UpdateCDMFromItem(item)
    local isEnabled = (dodoDB and dodoDB.useActionbarCDM ~= false)
    if not isEnabled or not item or not item.cooldownID then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if not cdInfo or not cdInfo.spellID then return end
    local baseSpellID = C_Spell.GetBaseSpell(cdInfo.spellID)
    local spellName = C_Spell.GetSpellName(baseSpellID)
    local buttons = spellName and dodo.buttonCache and dodo.buttonCache[spellName]
    if buttons then
        for _, btn in ipairs(buttons) do
            if btn.cdmOverlay then
                local hasAuraData = rawget(item, "auraDataUnit") ~= nil and rawget(item, "auraInstanceID") ~= nil
                btn.cdmOverlay.viewerItem = hasAuraData and item or nil
                btn.cdmOverlay:Update()
            end
        end
    end
end

local function HookViewerItem(item)
    if not item.__AB2Hooked then
        hooksecurefunc(item, "RefreshData", function() UpdateCDMFromItem(item) end)
        item.__AB2Hooked = true
    end
    UpdateCDMFromItem(item)
end

local function BuildSpecialButtonCache()
    if InCombatLockdown() then return end
    local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
    for _, group in ipairs(cdmBars) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.action then
                if not btn.cdmOverlay then
                    btn.cdmOverlay = CreateFrame("Frame", nil, btn, "dodo_Actionbar2OverlayTemplate")
                end
                btn.cdmOverlay:ClearAllPoints()
                btn.cdmOverlay:SetAllPoints(btn)
            end
        end
    end
    BuildButtonCache()
end

-- ==============================
-- 이벤트
-- ==============================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
f:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")

f:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        local groups = {
            "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
            "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
            "StanceButton", "PetActionButton"
        }
        for _, group in ipairs(groups) do
            for i = 1, 12 do
                local btn = _G[group .. i]
                if btn then
                    registeredButtons[btn] = true
                    if btn.Update then hooksecurefunc(btn, "Update", UpdateState) end
                    if btn.UpdateUsable then hooksecurefunc(btn, "UpdateUsable", UpdateState) end
                    if (group == "StanceButton" or group == "PetActionButton") and btn.UpdateState then
                        hooksecurefunc(btn, "UpdateState", UpdateState)
                    end
                    if btn.cooldown then
                        btn.cooldown:HookScript("OnCooldownDone", function()
                            btn.__cdVal = nil
                            UpdateIconColor(btn)
                        end)
                    end
                    UpdateState(btn)
                    UpdateCooldownState(btn)
                end
            end
        end

        hooksecurefunc("ActionButton_ApplyCooldown", function(cd)
            local btn = cd:GetParent()
            if btn and registeredButtons[btn] then
                C_Timer.After(0, function()
                    if btn:IsVisible() then UpdateCooldownState(btn) end
                end)
            end
        end)

        local bars = {
            MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
            MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
            StanceBar, PetActionBar
        }
        for _, bar in ipairs(bars) do
            if bar then
                hooksecurefunc(bar, "UpdateGridLayout", UpdatePadding)
                UpdatePadding(bar)
            end
        end

        local cdmHook = function(_, item) HookViewerItem(item) end
        hooksecurefunc(BuffBarCooldownViewer, "OnAcquireItemFrame", cdmHook)
        hooksecurefunc(BuffIconCooldownViewer, "OnAcquireItemFrame", cdmHook)

        C_Timer.After(0.5, function()
            BuildSpecialButtonCache()
            for _, item in ipairs(BuffBarCooldownViewer:GetItemFrames()) do HookViewerItem(item) end
            for _, item in ipairs(BuffIconCooldownViewer:GetItemFrames()) do HookViewerItem(item) end
        end)

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        BuildSpecialButtonCache()

    elseif event == "ACTION_RANGE_CHECK_UPDATE" then
        local slot = ...
        local slotButtons = ActionBarButtonRangeCheckFrame.actions and ActionBarButtonRangeCheckFrame.actions[slot]
        if slotButtons then
            for _, btn in pairs(slotButtons) do
                if btn:IsVisible() then UpdateState(btn) end
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = (event == "PLAYER_REGEN_DISABLED")
        for overlay in pairs(activeOverlays) do overlay:StartTicker() end
        if not inCombat then BuildSpecialButtonCache() end
    end
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.ActionbarApplyColor = function()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then UpdateIconColor(btn) end
    end
end

dodo.ActionbarApplyText = function()
    for btn in pairs(registeredButtons) do
        if btn:IsVisible() then UpdateButtonText(btn) end
    end
end

dodo.ActionbarApplyPadding = function()
    local bars = {
        MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
        MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
        StanceBar, PetActionBar
    }
    for _, bar in ipairs(bars) do
        if bar then UpdatePadding(bar) end
    end
end

dodo.ActionbarApplyCDM = function()
    local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
    for _, group in ipairs(cdmBars) do
        for i = 1, 12 do
            local btn = _G[group .. i]
            if btn and btn.cdmOverlay then btn.cdmOverlay:Update() end
        end
    end
end

dodo.ActionbarApplyInterrupt = function()
    if dodoAB3ControllerMixin.controller then
        dodoAB3ControllerMixin.controller:Update()
    end
end