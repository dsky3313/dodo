local T, C, L = unpack((select(2, ...)))

local UnitFrames = T["UnitFrames"]
local Widgets = UnitFrames.Widgets

local function addDefaultWidgets(self, unitFrame)
	self:add("Health", Widgets.HealthBar, { height = 19, font = C.Party.HealthFont, showValue = C.Party.ShowHealthText,
			valueAnchor = { "TOPRIGHT", -4, 6 }, tag = C.Party.HealthTag.Value, texture = C.Textures.UFPartyHealthTexture, })
	self:add("Power", Widgets.PowerBar, { height = 4, font = C.Party.HealthFont, showValue = C.Party.ShowManaText,
			texture = C.Textures.UFPartyPowerTexture, })
	self:add("Name", Widgets.Name, { font = C.Party.Font, anchor = { "TOPLEFT", 4, 7 }, })

	self:add("RaidTargetIndicator", Widgets.RaidTargetIndicator, { anchor = { "CENTER" }, })
	self:add("ReadyCheckIndicator", Widgets.ReadyCheckIndicator)
	self:add("ResurrectIndicator", Widgets.ResurrectIndicator)
	self:add("LeaderIndicator", Widgets.LeaderIndicator)
	self:add("Range", Widgets.RangeIndicator, { outsideAlpha = C.Party.RangeAlpha, })
	self:add("Highlight", Widgets.HighlightIndicator, { size = C.Party.HighlightSize, color = C.Party.HighlightColor, })

	if C.UnitFrames.HealComm then
		self:add("HealComm", Widgets.HealComm, { texture = C.Textures.UFPartyHealthTexture, })
	end

	if C.Party.Buffs then
		self:add("Buffs", Widgets.BuffsIndicator, { parent = unitFrame, height = 24, width = 190,
				anchor = { "TOPLEFT", "BOTTOMLEFT", 0, -6 }, buffSize = 24, buffNum = 7, })
	end

	if C.Party.Debuffs then
		self:add("Debuffs", Widgets.Debuffs, { parent = unitFrame, height = unitFrame:GetHeight(), width = 250,
				anchor = { "LEFT", "RIGHT", 6, 0 }, debuffSize = unitFrame:GetHeight(), debuffNum = 6, })
	end
end

-- Create new WidgetManager for Party and expose for external edits.
UnitFrames.PartyWidgets = UnitFrames.newWidgetManager("Party", addDefaultWidgets)

function UnitFrames:Party()
	self:RegisterForClicks("AnyUp")
	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)
	self:CreateShadow()
	self.Shadow:SetFrameLevel(2)

	self.Backdrop = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.Backdrop:SetAllPoints()
	self.Backdrop:SetFrameLevel(self:GetFrameLevel())
	self.Backdrop:SetBackdrop(UnitFrames.Backdrop)
	self.Backdrop:SetBackdropColor(0, 0, 0)

	-- not implemented anywhere?
	local MasterLooter = self:CreateTexture(nil, "OVERLAY")
	MasterLooter:SetSize(16, 16)
	MasterLooter:SetPoint("TOPRIGHT", self, "TOPLEFT", -4.5, -20)
	self.MasterLooterIndicator = MasterLooter

	UnitFrames.PartyWidgets:createWidgets(self)
end