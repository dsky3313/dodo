-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local issecretvalue = issecretvalue or function() return false end
local type = type
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGetTotalHealAbsorbs = UnitGetTotalHealAbsorbs

local function on_absorb_changed(s, event, u)
	if u == s.unit then s.Health:ForceUpdate() end
end

-- ==============================
-- 보호막/치유흡수 오버레이 공통 빌더
-- ==============================
function dodo.UnitframeCreateAbsorb(self, unit)
	local uWidth = self.uWidth
	local health = self.Health

	-- 1. 보호막 (빈 체력 채움)
	local clipEmpty = health.clipEmpty
	if not clipEmpty then
		clipEmpty = CreateFrame('Frame', nil, health)
		clipEmpty:SetPoint('TOPLEFT', health:GetStatusBarTexture(), 'TOPRIGHT')
		clipEmpty:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT')
		clipEmpty:SetClipsChildren(true)
		health.clipEmpty = clipEmpty
	end

	local absorbBase = health.absorbBarBase
	if not absorbBase then
		absorbBase = CreateFrame('StatusBar', nil, clipEmpty)
		absorbBase:SetStatusBarTexture([[Interface\RaidFrame\Shield-Fill]])
		absorbBase:SetPoint('TOPLEFT', health:GetStatusBarTexture(), 'TOPRIGHT')
		absorbBase:SetPoint('BOTTOMLEFT', health:GetStatusBarTexture(), 'BOTTOMRIGHT')
		absorbBase:SetWidth(uWidth)
		absorbBase:SetStatusBarColor(1, 1, 1, 1)
		absorbBase:SetFrameLevel(health:GetFrameLevel() + 1)
		health.absorbBarBase = absorbBase
	end

	-- 2. 보호막 (체력 위 오버레이, 초과분 강조)
	local clipOverlap = health.clipOverlap
	if not clipOverlap then
		clipOverlap = CreateFrame('Frame', nil, health)
		clipOverlap:SetPoint('TOPLEFT', health, 'TOPLEFT')
		clipOverlap:SetPoint('BOTTOMRIGHT', health:GetStatusBarTexture(), 'BOTTOMRIGHT')
		clipOverlap:SetClipsChildren(true)
		health.clipOverlap = clipOverlap
	end

	local absorbOverlay = health.absorbBarOverlay
	if not absorbOverlay then
		absorbOverlay = CreateFrame('StatusBar', nil, clipOverlap)
		absorbOverlay:SetStatusBarTexture([[Interface\RaidFrame\Shield-Fill]])
		absorbOverlay:SetReverseFill(true)
		absorbOverlay:SetPoint('TOPRIGHT', health, 'TOPRIGHT')
		absorbOverlay:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT')
		absorbOverlay:SetWidth(uWidth)
		absorbOverlay:SetStatusBarColor(1, 1, 1, 0.6)
		absorbOverlay:SetFrameLevel(health:GetFrameLevel() + 2)
		health.absorbBarOverlay = absorbOverlay
	end

	-- 3. 치유 흡수 (Heal Absorb)
	local healAbsorb = health.healAbsorbBar
	if not healAbsorb then
		healAbsorb = CreateFrame('StatusBar', nil, clipOverlap)
		healAbsorb:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
		healAbsorb:SetReverseFill(true)
		healAbsorb:SetPoint('TOPRIGHT', health:GetStatusBarTexture(), 'TOPRIGHT')
		healAbsorb:SetPoint('BOTTOMRIGHT', health:GetStatusBarTexture(), 'BOTTOMRIGHT')
		healAbsorb:SetWidth(uWidth)
		healAbsorb:SetStatusBarColor(0.85, 0.1, 0.1, 0.55)
		healAbsorb:SetFrameLevel(health:GetFrameLevel() + 2)
		health.healAbsorbBar = healAbsorb
	end

	if not self.__unitframeAbsorbEventsRegistered then
		self:RegisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', on_absorb_changed)
		self:RegisterEvent('UNIT_HEAL_ABSORB_AMOUNT_CHANGED', on_absorb_changed)
		self.__unitframeAbsorbEventsRegistered = true
	end

	health.PostUpdate = function(element, u, cur, max)
		local totalAbsorb = UnitGetTotalAbsorbs(u) or 0
		local hasAbsorb = issecretvalue(totalAbsorb) or (type(totalAbsorb) == "number" and totalAbsorb > 0)

		if element.absorbBarBase then
			element.absorbBarBase:SetMinMaxValues(0, max)
			element.absorbBarBase:SetValue(totalAbsorb)
			if hasAbsorb then element.absorbBarBase:Show() else element.absorbBarBase:Hide() end
		end

		if element.absorbBarOverlay then
			element.absorbBarOverlay:SetMinMaxValues(0, max)
			element.absorbBarOverlay:SetValue(totalAbsorb)
			if hasAbsorb then element.absorbBarOverlay:Show() else element.absorbBarOverlay:Hide() end
		end

		local totalHealAbsorb = UnitGetTotalHealAbsorbs(u) or 0
		local hasHealAbsorb = issecretvalue(totalHealAbsorb) or (type(totalHealAbsorb) == "number" and totalHealAbsorb > 0)

		if element.healAbsorbBar then
			element.healAbsorbBar:SetMinMaxValues(0, max)
			element.healAbsorbBar:SetValue(totalHealAbsorb)
			if hasHealAbsorb then element.healAbsorbBar:Show() else element.healAbsorbBar:Hide() end
		end
	end
end
