--[[----------------------------------------------------------------------------

    ActionBarInterruptHighlight
    Copyright 2026 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local _, addon = ...

-- Note about warlocks: the interrupt pet abilities are the override spell
-- for Command Demon (119898): not the spell the pet casts, but the spell the
-- player casts to make the pet cast their spell.

local Interrupts = {
    [ 47528] = true,                -- Mind Freeze (Death Knight)
    [183752] = true,                -- Disrupt (Demon Hunter)
    [ 78675] = true,                -- Solar Beam (Druid)
    [106839] = true,                -- Skull Bash (Druid)
    [147362] = true,                -- Counter Shot (Hunter)
    [187707] = true,                -- Muzzle (Hunter)
    [  2139] = true,                -- Counterspell (Mage)
    [116705] = true,                -- Spear Hand Strike (Monk)
    [ 96231] = true,                -- Rebuke (Paladin)
    [ 15487] = true,                -- Silence (Priest)
    [  1766] = true,                -- Kick (Rogue)
    [ 57994] = true,                -- Wind Shear (Shaman)
    [119910] = true,                -- Spell Lock (Warlock Felhunter Pet)
    [132409] = true,                -- Spell Lock (Warlock Fel Ravager)
    [119914] = true,                -- Axe Toss (Warlock Felguard Pet)
    [  6552] = true,                -- Pummel (Warrior)
    [351338] = true,                -- Quell (Evoker)
}

local Events = {
    'ACTIONBAR_SLOT_CHANGED',
    'PLAYER_FOCUS_CHANGED',
    'PLAYER_TARGET_CHANGED',
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

local CooldownViewerNames = { "EssentialCooldownViewer", "UtilityCooldownViewer", }

--[[------------------------------------------------------------------------]]--

local function GetAllActionButtons()
    local buttons = {}

    -- Blizzard
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        local _, spellID = GetActionInfo(actionButton.action)
        buttons[actionButton] = spellID
    end

    -- CDM
    for _, viewerName in ipairs(CooldownViewerNames) do
        local viewer = _G[viewerName]
        for _, itemFrame in ipairs(viewer:GetItemFrames()) do
            if itemFrame.cooldownID then
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(itemFrame.cooldownID)
                if info then
                    buttons[itemFrame] = info.spellID
                end
            end
        end
    end

    -- Dominos
    if Dominos then
        for actionButton in pairs(Dominos.ActionButtons.buttons) do
            local _, spellID = GetActionInfo(actionButton.action)
            buttons[actionButton] = spellID
        end
    end

    -- LibActionButton variants
    -- The %- here is a literal "-"
    for name, lib in LibStub:IterateLibraries() do
        if name:match('^LibActionButton%-1.0') then
            for actionButton in pairs(lib:GetAllButtons()) do
                local actionType, _action = actionButton:GetAction()
                if actionType == "action" then
                    local _, spellID = GetActionInfo(actionButton.action)
                    buttons[actionButton] = spellID
                end
            end
        end
    end

    return buttons
end

--[[------------------------------------------------------------------------]]--

ABIHControllerMixin = {}

function ABIHControllerMixin:OnLoad()
    self:RegisterEvent('PLAYER_LOGIN')
end

function ABIHControllerMixin:Initialize()
    addon.InitializeOptions()
    addon.db.RegisterCallback(self, 'OnOptionsChanged', 'OnOptionsChanged')

    self.overlayPool = CreateFramePool('Frame', nil, "ABIHOverlayTemplate")

    self.state = {}

    FrameUtil.RegisterFrameForEvents(self, Events)

    -- This fires fairly often and causes a full rebuild of all the cooldown
    -- viewer itemFrames. Very inefficient compared to the actionbars.

    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged",
        function ()
            self:CreateOverlays()
            self:Update('target')
        end)
end

function ABIHControllerMixin:IsRelevantActionID(actionID)
    local _, spellID = GetActionInfo(actionID)
    if Interrupts[spellID] then
        return true
    end
    for overlay in self.overlayPool:EnumerateActive() do
        if overlay.spellID == spellID then
            return true
        end
    end
    return false
end

function ABIHControllerMixin:CreateOverlays()
    self.overlayPool:ReleaseAll()
    for actionButton, spellID in pairs(GetAllActionButtons()) do
        if Interrupts[spellID] then
            local overlay = self.overlayPool:Acquire()
            overlay.spellID = spellID
            overlay:Attach(actionButton)
        end
    end
end

function ABIHControllerMixin:RefreshOverlays()
    for overlay in self.overlayPool:EnumerateActive() do
        local unit = overlay:GetCurrentUnit()
        local state = self.state[unit]
        if state then
            overlay:Update(unpack(state))
        end
   end
end

function ABIHControllerMixin:UpdateUnitState(unit)
    if UnitCanAttack('player', unit) then
        local name, notInterruptible, _

        name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
        if name then
            local duration = UnitCastingDuration(unit)
            self.state[unit] = { true, notInterruptible, duration }
            return
        end

        name, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
        if name then
            local duration = UnitChannelDuration(unit)
            -- or UnitEmpoweredChannelDuration(unit)
            self.state[unit] = { true, notInterruptible, duration }
            return
        end
    end
    self.state[unit] = { false }
end

function ABIHControllerMixin:Update(...)
    for i = 1, select('#', ...) do
        local unit = select(i, ...)
        self:UpdateUnitState(unit)
    end
    self:RefreshOverlays()
end

function ABIHControllerMixin:OnOptionsChanged()
    self:CreateOverlays()
    self:Update('focus', 'target')
end

function ABIHControllerMixin:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
        self:CreateOverlays()
        self:Update('focus', 'target')
    elseif event == 'ACTIONBAR_SLOT_CHANGED' then
        -- This fires CONSTANTLY when assistedcombat is on a bar
        local actionID = ...
        if self:IsRelevantActionID(actionID) then
            self:CreateOverlays()
            self:Update('focus', 'target')
        end
    elseif event == 'PLAYER_TARGET_CHANGED' then
        self:Update('target')
    elseif event == 'PLAYER_FOCUS_CHANGED' then
        self:Update('focus')
    elseif event:sub(1, 14) == 'UNIT_SPELLCAST' then
        local unit = ...
        if unit == 'focus' or unit == 'target' then
            self:Update(unit)
        end
    end
end
