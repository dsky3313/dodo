-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local issecretvalue = issecretvalue or function() return false end
local type = type
local UnitClass = UnitClass
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGetTotalHealAbsorbs = UnitGetTotalHealAbsorbs
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

-- ==============================
-- 플레이어 스타일 주입
-- ==============================
dodo.UnitframeStyles['player'] = function(self, unit)
	self.uWidth = 190
	self.uHeight = 30
	self.pHeight = 10
	self.showPower = true

	local uWidth = self.uWidth
	local health = self.Health

	-- 1. 예상 치유 (HealingAll)
	local healingAll = health.healingAll
	if not healingAll then
		healingAll = CreateFrame('StatusBar', nil, health)
		healingAll:SetPoint('TOP')
		healingAll:SetPoint('BOTTOM')
		healingAll:SetPoint('LEFT', health:GetStatusBarTexture(), 'RIGHT')
		healingAll:SetWidth(uWidth)
		healingAll:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
		healingAll:SetStatusBarColor(0, 0.8, 0.4, 0.45)
		healingAll:SetFrameLevel(health:GetFrameLevel() + 1)
		healingAll:Hide() -- 원본 config.useHealPrediction = false 에 따라 기본적으로 숨김
		health.healingAll = healingAll
	end

	-- 2. 보호막 (일반)
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

	-- 3. 보호막 (초과)
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

	-- 4. 치유 흡수 (Heal Absorb)
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

	if not self.__unitframeEventsRegistered then
		self:RegisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', function(s, event, u)
			if u == 'player' then s.Health:ForceUpdate() end
		end)
		self:RegisterEvent('UNIT_HEAL_ABSORB_AMOUNT_CHANGED', function(s, event, u)
			if u == 'player' then s.Health:ForceUpdate() end
		end)
		self.__unitframeEventsRegistered = true
	end

	health.PostUpdate = function(element, u, cur, max)
		local totalAbsorb = UnitGetTotalAbsorbs(u) or 0
		local hasAbsorb = (issecretvalue and issecretvalue(totalAbsorb)) or (type(totalAbsorb) == "number" and totalAbsorb > 0)

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
		local hasHealAbsorb = (issecretvalue and issecretvalue(totalHealAbsorb)) or (type(totalHealAbsorb) == "number" and totalHealAbsorb > 0)

		if element.healAbsorbBar then
			element.healAbsorbBar:SetMinMaxValues(0, max)
			element.healAbsorbBar:SetValue(totalHealAbsorb)
			if hasHealAbsorb then element.healAbsorbBar:Show() else element.healAbsorbBar:Hide() end
		end
	end

	-- 전투 표시기
	local combatIndicator = self.CombatIndicator
	if not combatIndicator then
		combatIndicator = self:CreateTexture(nil, 'OVERLAY')
		combatIndicator:SetSize(22, 22)
		combatIndicator:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 4)
		self.CombatIndicator = combatIndicator
	end

	-- 휴식 표시기 (Zzz 플립북)
	local restIndicator = self.RestingIndicator
	if not restIndicator then
		restIndicator = CreateFrame('Frame', nil, self)
		restIndicator:SetSize(30, 30)
		restIndicator:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 8)

		local restTexture = restIndicator:CreateTexture(nil, 'ARTWORK')
		restTexture:SetAtlas('UI-HUD-UnitFrame-Player-Rest-Flipbook')
		restTexture:SetAllPoints()

		local restAnimGroup = restTexture:CreateAnimationGroup()
		restAnimGroup:SetLooping('REPEAT')
		local flipbook = restAnimGroup:CreateAnimation('FlipBook')
		flipbook:SetDuration(1.5)
		flipbook:SetFlipBookRows(7)
		flipbook:SetFlipBookColumns(6)
		flipbook:SetFlipBookFrames(42)
		flipbook:SetOrder(1)

		restIndicator.anim = restAnimGroup
		restIndicator.PostUpdate = function(element, isResting)
			if isResting then element.anim:Play() else element.anim:Stop() end
		end
		self.RestingIndicator = restIndicator
	end

	-- 자원 바 (self.Power)
	local power = self.Power
	if not power then
		power = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
		power:SetSize(120, 10)
		power:SetPoint('RIGHT', health, 'BOTTOMRIGHT', -5, -2)
		power:SetFrameLevel(health:GetFrameLevel() + 5)
		power:SetStatusBarTexture('UI-HUD-CoolDownManager-Bar')

		power.bg = power:CreateTexture(nil, 'BACKGROUND')
		power.bg:SetPoint('TOPLEFT',     power, 'TOPLEFT',     -2,  2)
		power.bg:SetPoint('BOTTOMRIGHT', power, 'BOTTOMRIGHT',  6, -7)
		power.bg:SetAtlas('UI-HUD-CoolDownManager-Bar-BG')

		local powerOverlay = CreateFrame('Frame', nil, power)
		powerOverlay:SetAllPoints(power)
		powerOverlay:SetFrameLevel(power:GetFrameLevel() + 10)

		power.text = powerOverlay:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
		power.text:SetPoint('RIGHT', powerOverlay, 'RIGHT', -5, 0)
		power.text:SetTextColor(1, 1, 1)

		self.Power = power
		self.Power.colorPower = true
		self.Power.displayAltPower = true

		self.Power.GetDisplayPower = function(element, u)
			if dodo and dodo.DB and dodo.DB.unitframePowerOnlyMana == false then return nil end

			local powerType = UnitPowerType('player')
			local _, classFile = UnitClass('player')
			if (classFile == "PRIEST" or classFile == "SHAMAN" or classFile == "DRUID") then
				if powerType ~= 0 then
					local maxMana = UnitPowerMax('player', 0)
					local isMaxManaSecret = issecretvalue and issecretvalue(maxMana)
					if maxMana and (isMaxManaSecret or maxMana > 0) then
						return 0, 0
					end
				end
			end
		end

		self.Power.PostUpdate = function(element, u, cur, min, max)
			if dodo and dodo.DB and dodo.DB.unitframePower == false then
				element:Hide()
				return
			end

			local powerType = UnitPowerType('player')
			local _, classFile = UnitClass('player')
			local isManaSecondary = false
			if (classFile == "PRIEST" or classFile == "SHAMAN" or classFile == "DRUID") then
				if powerType ~= 0 then
					local maxMana = UnitPowerMax('player', 0)
					local isMaxManaSecret = issecretvalue and issecretvalue(maxMana)
					if maxMana and (isMaxManaSecret or maxMana > 0) then
						isManaSecondary = true
					end
				end
			end

			local showBar = false
			if dodo and dodo.DB and dodo.DB.unitframePowerOnlyMana == false then
				showBar = true
			else
				if powerType == 0 or isManaSecondary then showBar = true end
			end

			if showBar then element:Show() else element:Hide() end
		end

		self:Tag(power.text, '[dodopower]')
	end
end
