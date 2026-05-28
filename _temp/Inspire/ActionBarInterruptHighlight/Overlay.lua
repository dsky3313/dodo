--[[----------------------------------------------------------------------------

    ActionBarInterruptHighlight
    Copyright 2026 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local timerColorCurve = C_CurveUtil.CreateColorCurve()
timerColorCurve:SetType(Enum.LuaCurveType.Linear)
timerColorCurve:AddPoint(0.0, CreateColor(1, 0.5, 0.5, 1))
timerColorCurve:AddPoint(3.0, CreateColor(1, 1, 0.5, 1))
timerColorCurve:AddPoint(3.01, CreateColor(1, 1, 1, 1))
timerColorCurve:AddPoint(10.0, CreateColor(1, 1, 1, 1))

--[[------------------------------------------------------------------------]]--

-- This is wrong for any kind of complex macro that contains multiple commands
-- that execute, or one command that executes and has no conditions but then
-- subsequent commands with conditions that don't. But it should be good enough
-- for basic macros that do CC and interrupts, and a full macro parser would be
-- complex. And not significantly better since you can't tell what spell is
-- going to end the macro from the client.

-- I tried caching the gmatch split but it wasn't any faster.

local CAST_COMMANDS = {
    [SLASH_CAST1]   = true,
    [SLASH_CAST2]   = true,
    [SLASH_CAST3]   = true,
    [SLASH_CAST4]   = true,
    [SLASH_USE1]    = true,
    [SLASH_USE2]    = true,
}

local function GetMacroUnit(macroIdentifier)
    local macroBody = GetMacroBody(macroIdentifier)
    if macroBody == nil then return end

    for cmd, conditionsAndArgs in macroBody:gmatch("(/%w+)%s+([^\n]+)") do
        if CAST_COMMANDS[cmd] then
            local result, unit = SecureCmdOptionParse(conditionsAndArgs)
            if result then
                return unit
            end
        end
    end
end


--[[------------------------------------------------------------------------]]--

ABIHOverlayMixin = {}

function ABIHOverlayMixin:OnHide()
    self:StopAnim()
    self:StopTimer()
end

function ABIHOverlayMixin:OnUpdate()
    if self.duration then
        local color = self.duration:EvaluateRemainingDuration(timerColorCurve)
        self.Timer:SetFormattedText("%0.1f", self.duration:GetRemainingDuration())
        self.Timer:SetTextColor(color:GetRGB())
    else
        self:StopTimer()
    end
end

function ABIHOverlayMixin:StopAnim()
    if self.ProcLoop:IsPlaying() then
        self.ProcLoop:Stop()
    end
end

function ABIHOverlayMixin:StartAnim()
    self.ProcLoop:Play()
end

function ABIHOverlayMixin:StartTimer(duration)
    self.duration = duration
    self.Timer:Show()
    self:SetScript('OnUpdate', self.OnUpdate)
end

function ABIHOverlayMixin:StopTimer()
    self.duration = nil
    self.Timer:Hide()
    self:SetScript('OnUpdate', nil)
end

-- In an ideal world GetActionInfo would return the unit as well. Or there
-- would be a GetActionUnit function. This is a hack to try to figure it
-- out in a limited fashion.

function ABIHOverlayMixin:GetCurrentUnit()
    local parent = self:GetParent()

    if parent.action then
        if GetActionInfo(parent.action) == 'macro' then
            local macroName = GetActionText(parent.action)
            local unit = GetMacroUnit(macroName)
            if unit then
                return unit
            end
        end

        if C_ActionBar.IsHarmfulAction(parent.action, true) then
            -- "Focus Cast Key" from "Combat" settings.
            if IsModifiedClick('FOCUSCAST') then
                return 'focus'
            end
        end
    end

    return 'target'
end

-- Because notInterruptible is a secret, we can no longer show/hide
-- as a result of it, best we can do is SetAlphaFromBoolean. So
-- the animation and timer are always "playing" if there's a spell
-- cast going on, and we only make them visible with alpha if the
-- cast is interruptible.

function ABIHOverlayMixin:Update(active, notInterruptible, duration)
    if active then
        self:StartAnim()
        self:StartTimer(duration)
        self:SetAlphaFromBoolean(notInterruptible, 0, 1)
        self:Show()
    else
        self:Hide()
    end
end

function ABIHOverlayMixin:Attach(actionButton)
    self:SetParent(actionButton)
    self:ClearAllPoints()
    self:SetPoint('CENTER')
    local w, h = actionButton:GetSize()
    PixelUtil.SetSize(self, w, h)
    self.ProcLoopFlipbook:SetSize(w * 1.4, h * 1.4)
end

function ABIHOverlayMixin:AlreadyOverlayed()
    local parent = self:GetParent()
    local _, spellID = GetActionInfo(parent.action)
    return spellID and C_SpellActivationOverlay.IsSpellOverlayed(spellID)
end
