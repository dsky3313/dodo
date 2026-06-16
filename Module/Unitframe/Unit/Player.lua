-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local issecretvalue = issecretvalue or function() return false end
local UnitClass = UnitClass
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

	-- 2~4. 보호막/치유흡수 오버레이 (공용 헬퍼)
	dodo.UnitframeCreateAbsorb(self, unit)

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
