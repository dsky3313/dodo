-- ==============================
-- Inspired
-- ==============================
-- ActionBar Interrupt Highlight (https://www.curseforge.com/wow/addons/actionbarinterrupthighlight)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local FeatureInterruptBars = {
    ["MainActionBar"]       = true,
}

local Interrupts = {
    [47528]  = true, -- Mind Freeze
    [183752] = true, -- Disrupt
    [78675]  = true, -- Solar Beam
    [106839] = true, -- Skull Bash
    [147362] = true, -- Counter Shot
    [187707] = true, -- Muzzle
    [2139]   = true, -- Counterspell
    [116705] = true, -- Spear Hand Strike
    [96231]  = true, -- Rebuke
    [15487]  = true, -- Silence
    [1766]   = true, -- Kick
    [57994]  = true, -- Wind Shear
    [119910] = true, -- Spell Lock (술사 지옥사냥개)
    [132409] = true, -- Spell Lock (술사 지옥 약탈자)
    [89766]  = true, -- Axe Toss (술사 지옥경비원)
    [6552]   = true, -- Pummel
    [351338] = true, -- Quell
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
local ActionBarButtonEventsFrame = ActionBarButtonEventsFrame
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local CreateFramePool = CreateFramePool
local Enum = Enum
local FrameUtil = FrameUtil
local GetActionInfo = GetActionInfo
local issecretvalue = issecretvalue
local PixelUtil = PixelUtil
local UnitCastingDuration = UnitCastingDuration
local UnitCastingInfo = UnitCastingInfo
local UnitChannelDuration = UnitChannelDuration
local UnitChannelInfo = UnitChannelInfo
local UnitExists = UnitExists
local UnitGUID = UnitGUID

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

local watched_unit = 'target'

-- ==============================
-- 기능 구현
-- ==============================
InterruptOverlayMixin = {}

function InterruptOverlayMixin:OnHide()
    self:StopAnim()
    self:StopTimer()
end

function InterruptOverlayMixin:OnUpdate(elapsed)
    self.timerElapsed = (self.timerElapsed or 0) + elapsed
    if self.timerElapsed < 0.1 then return end
    self.timerElapsed = 0
    if self.duration then
        local remaining = self.duration:GetRemainingDuration()
        local isSecret = issecretvalue(remaining)
        if isSecret or (remaining ~= self._lastRemaining) then
            local color = self.duration:EvaluateRemainingDuration(timerColorCurve)
            self.TimerReady:SetFormattedText("%.1f", remaining)
            self.TimerCooldown:SetFormattedText("%.1f", remaining)
            self.TimerReady:SetTextColor(color:GetRGB())
            if not isSecret then
                self._lastRemaining = remaining
            end
        end
    else
        self:StopTimer()
    end
end

function InterruptOverlayMixin:StopAnim()
    if self.ProcLoop:IsPlaying() then self.ProcLoop:Stop() end
end

function InterruptOverlayMixin:StartTimer(duration)
    self.duration = duration
    self.timerElapsed = 0.1
    self.TimerReady:Show()
    self.TimerCooldown:Show()
    self:SetScript('OnUpdate', self.OnUpdate)
end

function InterruptOverlayMixin:StopTimer()
    self.duration = nil
    self.timerElapsed = 0
    self.TimerReady:Hide()
    self.TimerCooldown:Hide()
    self:SetScript('OnUpdate', nil)
end

function InterruptOverlayMixin:Update(active, notInterruptible, duration, readyVal, cooldownVal)
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

function InterruptOverlayMixin:Attach(actionButton)
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
            dodoAB3ControllerMixin.controller:update()
        end)
        actionButton.__dodoAB3Hooked = true
    end
end

-- Controller
dodoAB3ControllerMixin = {}

function dodoAB3ControllerMixin:OnLoad()
    dodoAB3ControllerMixin.controller = self
    self:RegisterEvent('PLAYER_LOGIN')
end

function dodoAB3ControllerMixin:initialize()
    self.overlayPool = CreateFramePool('Frame', nil, 'InterruptOverlayTemplate')
    FrameUtil.RegisterFrameForEvents(self, IntEvents)
    for _, event in ipairs(IntUnitEvents) do
        self:RegisterUnitEvent(event, 'focus', 'target')
    end
    watched_unit = UnitExists('focus') and 'focus' or 'target'
end

function dodoAB3ControllerMixin:is_relevant_action_id(actionID)
    if not self.overlayPool then return false end
    local _, spellID = GetActionInfo(actionID)
    if Interrupts[spellID] then return true end
    for overlay in self.overlayPool:EnumerateActive() do
        if overlay.spellID == spellID then return true end
    end
    return false
end

function dodoAB3ControllerMixin:create_overlays()
    if not self.overlayPool then return end
    self.overlayPool:ReleaseAll()
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        local barName = dodo.get_bar_name_by_button(actionButton)
        if barName and FeatureInterruptBars[barName] then
            local _, spellID = GetActionInfo(actionButton.action)
            if Interrupts[spellID] then
                local overlay = self.overlayPool:Acquire()
                overlay.spellID = spellID
                overlay:Attach(actionButton)
            end
        end
    end
end

function dodoAB3ControllerMixin:refresh_overlays(isActive, notInterruptible, castDuration)
    if not self.overlayPool then return end
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

function dodoAB3ControllerMixin:update()
    local isEnabled = (dodoDB and dodoDB.useActionbarInterrupt ~= false)
    if not isEnabled then
        self:refresh_overlays(false)
        return
    end

    local name, notInterruptible
    name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(watched_unit)
    if name then
        self:refresh_overlays(true, notInterruptible, UnitCastingDuration(watched_unit))
        return
    end
    name, _, _, _, _, _, notInterruptible = UnitChannelInfo(watched_unit)
    if name then
        self:refresh_overlays(true, notInterruptible, UnitChannelDuration(watched_unit))
        return
    end
    self:refresh_overlays(false)
end

function dodoAB3ControllerMixin:on_event(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:initialize()
        self:create_overlays()
        self:update()
    elseif event == 'ACTIONBAR_SLOT_CHANGED' then
        local actionID = ...
        if self:is_relevant_action_id(actionID) then
            self:create_overlays()
            self:update()
        end
    elseif event == 'PLAYER_TARGET_CHANGED' or event == 'PLAYER_FOCUS_CHANGED' then
        watched_unit = UnitExists('focus') and 'focus' or 'target'
        self:update()
    elseif event:sub(1, 14) == 'UNIT_SPELLCAST' then
        local unit = ...
        if unit == watched_unit then self:update() end
    end
end
dodoAB3ControllerMixin.OnEvent = dodoAB3ControllerMixin.on_event

dodo.DisableInterruptController = function()
    if dodoAB3ControllerMixin.controller then
        dodoAB3ControllerMixin.controller:UnregisterAllEvents()
        dodoAB3ControllerMixin.controller:refresh_overlays(false)
    end
end

dodo.ActionbarApplyInterrupt = function()
    if dodoAB3ControllerMixin.controller then
        dodoAB3ControllerMixin.controller:update()
    end
end

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ActionBar, {
        {
            name = "오버레이: 차단",
            get = function() return dodoDB and dodoDB.useActionbarInterrupt ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useActionbarInterrupt = checked end
                dodo.ActionbarApplyInterrupt()
            end,
            disabled = function() return dodoDB and dodoDB.enableActionbar == false end
        }
    })
end

-- ==============================
-- 컨트롤러 동적 생성 및 실행
-- ==============================
local controller = CreateFrame("Frame")
for k, v in pairs(dodoAB3ControllerMixin) do
    controller[k] = v
end
controller:OnLoad()
controller:SetScript("OnEvent", controller.OnEvent)
