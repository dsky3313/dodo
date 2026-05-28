local _, addon = ...

CDMButtonAurasOverlayMixin = {}

-- local timerColorCurve = C_CurveUtil.CreateColorCurve()
-- timerColorCurve:SetType(Enum.LuaCurveType.Linear)
-- timerColorCurve:AddPoint(0.0, CreateColor(1, 0, 0, 1))
-- timerColorCurve:AddPoint(3.0, CreateColor(1, 1, 0, 1))
-- timerColorCurve:AddPoint(10.0, CreateColor(1, 1, 1, 1))

function CDMButtonAurasOverlayMixin:OnLoad()
    local parent = self:GetParent()
    PixelUtil.SetSize(self, parent:GetSize())

    if parent.cooldown then
        self:SetFrameLevel(parent.cooldown:GetFrameLevel() + 1)
    end

    -- Using Cooldown frame here only for the Abbrev capability. Once
    -- Blizzard provides the promised secret-safe SecondsFormatter then
    -- it can be changed to a FontString.
    self.Cooldown:SetPoint("TOPLEFT", parent.icon, "LEFT", 5, 0)
    self.Cooldown:SetPoint("BOTTOMRIGHT", parent.icon, "BOTTOM", 0, 3)
    self.Cooldown:SetDrawSwipe(false)
    self.Cooldown:SetCountdownFont("NumberFontNormal")
    self.Cooldown:SetCountdownAbbrevThreshold(60)
    self.Cooldown:SetScript('OnCooldownDone', function () self:Update() end)
end

function CDMButtonAurasOverlayMixin:SetViewerItem(viewerItem)
    self.viewerItem = viewerItem
end

function CDMButtonAurasOverlayMixin:Update()
    if self.viewerItem == nil then
        self:Hide()
        return
    end

    local unit = self.viewerItem.auraDataUnit
    local auraInstanceID = self.viewerItem.auraInstanceID

    if unit and auraInstanceID then
        local duration = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
        if duration then
            self.Cooldown:SetCooldownFromDurationObject(duration, true)
            self.Cooldown:Show()
        else
            self.Cooldown:Hide()
        end

        local count = C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraInstanceID)
        self.Stacks:SetText(count)

        if unit == 'player' then
            self.Glow:SetVertexColor(0, 0.7, 0, 0.5)
        else
            self.Glow:SetVertexColor(1, 0, 0, 0.5)
        end
        self.Glow:Show()

        self:Show()
    else
        self:Hide()
    end
end
