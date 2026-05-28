local _, addon = ...

CDMButtonAurasControllerMixin = {}

-- This is a terrific waste and should be cached

local function FindActionButtonForSpellName(name)
    for _, actionBar in ipairs(ActionButtonUtil.ActionBarButtonNames) do
        for i = 1, NUM_ACTIONBAR_BUTTONS do
            local btn = _G[actionBar..i]
            local _, actionSpellID = GetActionInfo(btn.action)
            if actionSpellID then
                local baseSpellID = C_Spell.GetBaseSpell(actionSpellID)
                local actionSpellName = C_Spell.GetSpellName(baseSpellID)
                if name == actionSpellName then
                    return btn
                end
            end
        end
    end
    for i = 1, NUM_SPECIAL_BUTTONS do
        -- Stance Bar buttons
        local stanceBtn = StanceBar.actionButtons[i]
        local stanceSpellID = select(4, GetShapeshiftFormInfo(stanceBtn:GetID()))
        if stanceSpellID then
            local stanceSpellName = C_Spell.GetSpellName(stanceSpellID)
            if name == stanceSpellName then
                return stanceBtn
            end
        end
    end
end

function CDMButtonAurasControllerMixin:GetActionButtonList(spellID)
    local buttonList = {}

    local cdSpellName = C_Spell.GetSpellName(spellID)
    local spellNameList = { cdSpellName }
    tAppendAll(spellNameList, addon.AuraMapByName[cdSpellName] or {})
    for _, spellName in ipairs(spellNameList) do
        local button = FindActionButtonForSpellName(spellName)
        if button then
            table.insert(buttonList, button)
        end
    end
    return buttonList
end

function CDMButtonAurasControllerMixin:GetOverlay(actionButton)
    if not self.overlayFrames[actionButton] then
        local name = actionButton:GetName() .. "CDMButtonAurasOverlay"
        self.overlayFrames[actionButton] = CreateFrame('Frame', name, actionButton, "CDMButtonAurasOverlayTemplate")
    end
    return self.overlayFrames[actionButton]
end

function CDMButtonAurasControllerMixin:UpdateFromItem(item)
    if not item.cooldownID then return end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if cdInfo.spellID then
        local buttonList = self:GetActionButtonList(cdInfo.spellID)
        for _, button in ipairs(buttonList) do
            local overlay = self:GetOverlay(button)
            overlay:SetViewerItem(item)
            overlay:Update()
        end
    end
end

function CDMButtonAurasControllerMixin:UpdateFromViewer(viewer)
    for _, itemFrame in ipairs(viewer:GetItemFrames()) do
        if itemFrame.cooldownID then
            self:UpdateFromItem(itemFrame)
        end
    end
end

function CDMButtonAurasControllerMixin:HookViewerItem(item)
    if not item.__CDMBAHooked then
        local hook = function () self:UpdateFromItem(item) end
        hooksecurefunc(item, 'RefreshData', hook)
        item.__CDMBAHooked = true
    end
end

-- This is super awkward, and a side effect of the way everything is driven
-- from the viewerItem update hook, which doesn't know anything about
-- actionbuttons and doesn't handle them changing.
--
-- It might be better if the viewer item update hook manages a state table
-- and then the overlay Update() can look at it to decide if they even
-- still exist.
--
-- Also possibly overlayFrames should be a frame pool, we could release them
-- all and rescan.
--
-- On the other hand it's pretty efficient at the moment. Depends if it ends
-- up holding back other improvements.

function CDMButtonAurasControllerMixin:RefreshAllOverlays()
    for _, overlay in pairs(self.overlayFrames) do
        overlay:SetViewerItem(nil)
    end
    self:UpdateFromViewer(BuffBarCooldownViewer)
    self:UpdateFromViewer(BuffIconCooldownViewer)
    for _, overlay in pairs(self.overlayFrames) do
        overlay:Update()
    end
end

function CDMButtonAurasControllerMixin:Initialize()
    addon.InitializeOptions()
    --[==[@debug@
    addon.InitializeGUIOptions()
    --@end-debug@]==]
    local hook = function (_, item) self:HookViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, 'OnAcquireItemFrame', hook)
    hooksecurefunc(BuffIconCooldownViewer, 'OnAcquireItemFrame', hook)

    self:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
end

function CDMButtonAurasControllerMixin:OnLoad()
    self.overlayFrames = {}
    self:RegisterEvent('PLAYER_LOGIN')
end

function CDMButtonAurasControllerMixin:OnEvent(event)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
    elseif event == 'ACTIONBAR_SLOT_CHANGED' then
        self:RefreshAllOverlays()
    end
end

_G.CDMBA = addon
