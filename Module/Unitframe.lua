-- ==============================
-- Inspired
-- ==============================
-- oUF (https://www.curseforge.com/wow/addons/ouf)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Unitframe", module)

local oUF = dodo.oUF or _G.oUF

local config = {
	width = 190,
	height = 30,
	powerWidth = 120,
	powerHeight = 10,
	barTexture = [[Interface\Buttons\WHITE8X8]],
	useHealPrediction = false, -- 예상 치유량 표시 여부 (기본값 off)
}

-- ==============================
-- 프레임 및 이벤트 핸들러 정의
-- ==============================
local is_boss_debug = false
local is_boss_hooked = false
local playerFrame
local targetFrame
local targettargetFrame
local focusFrame
local petFrame

-- ==============================
-- 캐싱
-- ==============================
-- abc 가나다 순으로 정렬
local AbbreviateNumbers = AbbreviateNumbers
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local EventRegistry = EventRegistry
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local pcall = pcall
local RegisterUnitWatch = RegisterUnitWatch
local SecureUnitButton_OnLoad = SecureUnitButton_OnLoad
local string_format = string.format
local table = table
local tostring = tostring
local UnregisterUnitWatch = UnregisterUnitWatch
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGetTotalHealAbsorbs = UnitGetTotalHealAbsorbs
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent
local UnitPowerType = UnitPowerType
local UnitReaction = UnitReaction
local UnitTokenFromGUID = UnitTokenFromGUID
local _G = _G

-- ==============================
-- 커스텀 oUF 태그
-- ==============================
oUF.Tags.Methods['shortcurhp'] = function(unit)
	return AbbreviateNumbers(UnitHealth(unit))
end
oUF.Tags.Events['shortcurhp'] = 'UNIT_HEALTH'

oUF.Tags.Methods['shortmaxhp'] = function(unit)
	return AbbreviateNumbers(UnitHealthMax(unit))
end
oUF.Tags.Events['shortmaxhp'] = 'UNIT_MAXHEALTH'

oUF.Tags.Methods['perhp:decimal'] = function(unit)
	local pct = UnitHealthPercent(unit, false, CurveConstants and CurveConstants.ScaleTo100)
	if not pct then return '0.0' end
	return string_format('%.1f', pct)
end
oUF.Tags.Events['perhp:decimal'] = 'UNIT_HEALTH UNIT_MAXHEALTH'

oUF.Tags.Methods['dodopower'] = function(unit)
	local max = UnitPowerMax(unit)
	if not max then return '' end

	local powerType, powerToken = UnitPowerType(unit)
	local isMana = (powerType == 0 or powerToken == "MANA")

	local maxSuccess, isMaxZero = pcall(function() return max == 0 end)
	if not maxSuccess then
		if isMana then
			local pct = UnitPowerPercent(unit, nil, true, CurveConstants and CurveConstants.ScaleTo100)
			if not pct then return '0' end
			local ok, formattedPct = pcall(function() return string_format('%.0f', pct) end)
			if ok then return formattedPct end
			return pct
		else
			local cur = UnitPower(unit)
			return cur
		end
	end

	if isMaxZero then return '' end

	local cur = UnitPower(unit)
	local curSuccess, isCurZero = pcall(function() return cur == 0 end)
	if not curSuccess then
		if isMana then
			local pct = UnitPowerPercent(unit, nil, true, CurveConstants and CurveConstants.ScaleTo100)
			if not pct then return '0' end
			local ok, formattedPct = pcall(function() return string_format('%.0f', pct) end)
			if ok then return formattedPct end
			return pct
		else
			return cur
		end
	end

	if isMana then
		return string_format('%.0f', (cur / max) * 100)
	else
		return tostring(cur)
	end
end
oUF.Tags.Events['dodopower'] = 'UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER'

-- ==============================
-- 블리자드 기본 프레임 비활성화
-- ==============================
local function disable_unit_frame(frame, containerKey, contentKey)
	if not frame then return end

	frame:SetAlpha(0)
	if frame[containerKey] then frame[containerKey]:Hide() end
	if frame[contentKey] then frame[contentKey]:Hide() end

	local health = frame.healthBar or frame.healthbar or frame.HealthBar
	if health then health:UnregisterAllEvents() end
	local power = frame.manabar or frame.ManaBar
	if power then power:UnregisterAllEvents() end
end

local original_disable_blizzard = oUF.DisableBlizzard
function oUF:DisableBlizzard(unit)
	if dodo and dodo.DB and dodo.DB.enableUnitframeModule == false then
		original_disable_blizzard(self, unit)
		return
	end
	if unit == 'player' then
		disable_unit_frame(PlayerFrame, 'PlayerFrameContainer', 'PlayerFrameContent')
	elseif unit == 'target' then
		disable_unit_frame(TargetFrame, 'TargetFrameContainer', 'TargetFrameContent')
	elseif unit == 'focus' then
		disable_unit_frame(FocusFrame, 'TargetFrameContainer', 'TargetFrameContent')
	elseif unit == 'targettarget' then
		disable_unit_frame(TargetFrameToT)
	elseif unit == 'focustarget' then
		disable_unit_frame(FocusFrameToT)
	elseif unit and unit:match('^boss%d?$') then
		if not is_boss_hooked then
			is_boss_hooked = true

			if BossTargetFrameContainer then
				BossTargetFrameContainer:SetAlpha(0)
			end

			for i = 1, 5 do
				local bossFrame = _G['Boss' .. i .. 'TargetFrame']
				if bossFrame then
					disable_unit_frame(bossFrame, 'TargetFrameContainer', 'TargetFrameContent')
				end
			end
		end
	else
		original_disable_blizzard(self, unit)
	end
end

-- ==============================
-- Aura 아이콘 스타일링
-- ==============================
local function post_create_button(element, button)
	button.Cooldown:SetReverse(true)
	button.Cooldown:SetHideCountdownNumbers(true)
	button.Cooldown.noCooldownCount = true

	button.Count:ClearAllPoints()
	button.Count:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 1, 0)
	button.Count:SetFontObject('SystemFont_Outline_Small')
	button.Count:SetTextColor(1, 1, 1)
end

-- ==============================
-- oUF 스타일 정의
-- ==============================
local function create_style(self, unit)
	local isBoss = unit and unit:match('^boss%d')
	local uWidth = config.width
	local uHeight = config.height
	local pWidth = config.powerWidth
	local pHeight = config.powerHeight
	local showPower = true
	local showHealthText = true

	if unit == 'targettarget' or unit == 'pet' then
		uWidth = 100
		uHeight = 16
		showPower = false
		showHealthText = false
	elseif unit == 'focus' then
		uWidth = 120
		uHeight = 16
		showPower = false
		showHealthText = false
	elseif isBoss then
		uWidth = 150
		uHeight = 30
	end

	-- 클릭 및 메뉴 설정
	self:RegisterForClicks('AnyUp')
	self:SetAttribute('type1', 'target')
	self:SetAttribute('type2', 'togglemenu')
	self.menu = function(_, menuUnit)
		local u = self.unit or unit
		local popup = (u == 'player') and 'SELF' or (u == 'target') and 'TARGET' or 'FOCUS'
		UnitPopup_OpenMenu(popup, {
			fromPlayerFrame = (u == 'player'),
			unit = u,
		})
	end
	SecureUnitButton_OnLoad(self, unit, self.menu)

	-- ==============================
	-- 체력 바 (self.Health)
	-- ==============================
	local health = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
	health:SetSize(uWidth, uHeight)
	health:SetPoint('CENTER', self, 'CENTER')
	health:SetStatusBarTexture(config.barTexture)

	-- 배경
	health.bg = health:CreateTexture(nil, 'BACKGROUND')
	health.bg:SetAllPoints()
	health.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

	-- 테두리 (NineSlice)
	health.NineSlice = CreateFrame('Frame', nil, health, 'NineSliceCodeTemplate')
	health.NineSlice:SetPoint('TOPLEFT',     health, 'TOPLEFT',     -4,  3)
	health.NineSlice:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT',  7, -6)
	health.NineSlice:SetFrameLevel(health:GetFrameLevel() + 3)
	health.NineSlice:SetScale(0.6)
	NineSliceUtil.ApplyUniqueCornersLayout(health.NineSlice, 'UI-HUD-ActionBar-Frame')

	-- 텍스트용 레이어
	local healthOverlay = CreateFrame('Frame', nil, health)
	healthOverlay:SetAllPoints(health)
	healthOverlay:SetFrameLevel(health:GetFrameLevel() + 10)

	health.text = healthOverlay:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
	health.text:SetPoint('RIGHT', healthOverlay, 'RIGHT', -5, 0)

	self.nameText = healthOverlay:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	self.nameText:SetPoint('BOTTOMLEFT', health, 'TOPLEFT', 2, 3)

	if not showHealthText then
		health.text:Hide()
	end

	-- ==============================
	-- 예상 치유 및 보호막 (Health Prediction & Absorb)
	-- ==============================
	self.Health = health

	if unit == 'player' then
		-- 1. 예상 치유 (HealingAll)
		local healingAll = CreateFrame('StatusBar', nil, health)
		healingAll:SetPoint('TOP')
		healingAll:SetPoint('BOTTOM')
		healingAll:SetPoint('LEFT', health:GetStatusBarTexture(), 'RIGHT')
		healingAll:SetWidth(uWidth)
		healingAll:SetStatusBarTexture(config.barTexture)
		healingAll:SetStatusBarColor(0, 0.8, 0.4, 0.45)
		healingAll:SetFrameLevel(health:GetFrameLevel() + 1)

		-- 2. 보호막 (일반 - 체력바 끝에서부터 채움)
		local clipEmpty = CreateFrame('Frame', nil, health)
		clipEmpty:SetPoint('TOPLEFT', health:GetStatusBarTexture(), 'TOPRIGHT')
		clipEmpty:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT')
		clipEmpty:SetClipsChildren(true)

		local absorbBase = CreateFrame('StatusBar', nil, clipEmpty)
		absorbBase:SetStatusBarTexture([[Interface\RaidFrame\Shield-Fill]])
		absorbBase:SetPoint('TOPLEFT', health:GetStatusBarTexture(), 'TOPRIGHT')
		absorbBase:SetPoint('BOTTOMLEFT', health:GetStatusBarTexture(), 'BOTTOMRIGHT')
		absorbBase:SetWidth(uWidth)
		absorbBase:SetStatusBarColor(1, 1, 1, 1)
		absorbBase:SetFrameLevel(health:GetFrameLevel() + 1)

		-- 3. 보호막 (초과 - 체력바 꽉 찼거나 채워진 체력 위로 덮어쓰기)
		local clipOverlap = CreateFrame('Frame', nil, health)
		clipOverlap:SetPoint('TOPLEFT', health, 'TOPLEFT')
		clipOverlap:SetPoint('BOTTOMRIGHT', health:GetStatusBarTexture(), 'BOTTOMRIGHT')
		clipOverlap:SetClipsChildren(true)

		local absorbOverlay = CreateFrame('StatusBar', nil, clipOverlap)
		absorbOverlay:SetStatusBarTexture([[Interface\RaidFrame\Shield-Fill]])
		absorbOverlay:SetReverseFill(true)
		absorbOverlay:SetPoint('TOPRIGHT', health, 'TOPRIGHT')
		absorbOverlay:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT')
		absorbOverlay:SetWidth(uWidth)
		absorbOverlay:SetStatusBarColor(1, 1, 1, 0.6)
		absorbOverlay:SetFrameLevel(health:GetFrameLevel() + 2)

		-- 4. 치유 흡수 (Heal Absorb)
		local healAbsorb = CreateFrame('StatusBar', nil, clipOverlap)
		healAbsorb:SetStatusBarTexture(config.barTexture)
		healAbsorb:SetReverseFill(true)
		healAbsorb:SetPoint('TOPRIGHT', health:GetStatusBarTexture(), 'TOPRIGHT')
		healAbsorb:SetPoint('BOTTOMRIGHT', health:GetStatusBarTexture(), 'BOTTOMRIGHT')
		healAbsorb:SetWidth(uWidth)
		healAbsorb:SetStatusBarColor(0.85, 0.1, 0.1, 0.55)
		healAbsorb:SetFrameLevel(health:GetFrameLevel() + 2)

		if config.useHealPrediction then
			self.Health.HealingAll = healingAll
		else
			healingAll:Hide()
		end
		self.Health.absorbBarBase = absorbBase
		self.Health.absorbBarOverlay = absorbOverlay
		self.Health.healAbsorbBar = healAbsorb

		self:RegisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', function(self, event, u)
			if u == 'player' then
				self.Health:ForceUpdate()
			end
		end)
		self:RegisterEvent('UNIT_HEAL_ABSORB_AMOUNT_CHANGED', function(self, event, u)
			if u == 'player' then
				self.Health:ForceUpdate()
			end
		end)
	end

	self.Health.colorClass = true
	self.Health.colorReaction = true
	self.Health.colorTapping = true
	self.Health.colorDisconnected = true
	self.Health.frequentUpdates = true

	self.Health.PostUpdate = function(element, unit, cur, max, lossPerc)
		if unit == 'player' then
			local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
			local hasAbsorb = (issecretvalue and issecretvalue(totalAbsorb)) or (type(totalAbsorb) == "number" and totalAbsorb > 0)

			if element.absorbBarBase then
				element.absorbBarBase:SetMinMaxValues(0, max)
				element.absorbBarBase:SetValue(totalAbsorb)
				if hasAbsorb then
					element.absorbBarBase:Show()
				else
					element.absorbBarBase:Hide()
				end
			end

			if element.absorbBarOverlay then
				element.absorbBarOverlay:SetMinMaxValues(0, max)
				element.absorbBarOverlay:SetValue(totalAbsorb)
				if hasAbsorb then
					element.absorbBarOverlay:Show()
				else
					element.absorbBarOverlay:Hide()
				end
			end

			local totalHealAbsorb = UnitGetTotalHealAbsorbs(unit) or 0
			local hasHealAbsorb = (issecretvalue and issecretvalue(totalHealAbsorb)) or (type(totalHealAbsorb) == "number" and totalHealAbsorb > 0)

			if element.healAbsorbBar then
				element.healAbsorbBar:SetMinMaxValues(0, max)
				element.healAbsorbBar:SetValue(totalHealAbsorb)
				if hasHealAbsorb then
					element.healAbsorbBar:Show()
				else
					element.healAbsorbBar:Hide()
				end
			end
		end
	end

	self:Tag(self.nameText, '[name]')
	self:Tag(health.text, '[shortcurhp] | [perhp:decimal]')

	if unit == 'player' then
		-- ==============================
		-- 전투 상태 표시기 (self.CombatIndicator)
		-- ==============================
		local combatIndicator = self:CreateTexture(nil, 'OVERLAY')
		combatIndicator:SetSize(22, 22)
		combatIndicator:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 4)
		self.CombatIndicator = combatIndicator

		-- ==============================
		-- 휴식 상태 표시기 (self.RestingIndicator)
		-- ==============================
		local restIndicator = CreateFrame('Frame', nil, self)
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
			if isResting then
				element.anim:Play()
			else
				element.anim:Stop()
			end
		end

		self.RestingIndicator = restIndicator
	end

	-- ==============================
	-- 자원 바 (self.Power)
	-- ==============================
	if showPower then
		local power = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
		power:SetSize(pWidth, pHeight)
		power:SetPoint('RIGHT', health, 'BOTTOMRIGHT', -5, -2)
		power:SetFrameLevel(health:GetFrameLevel() + 5)
		power:SetStatusBarTexture('UI-HUD-CoolDownManager-Bar')

		-- 배경
		power.bg = power:CreateTexture(nil, 'BACKGROUND')
		power.bg:SetPoint('TOPLEFT',     power, 'TOPLEFT',     -2,  2)
		power.bg:SetPoint('BOTTOMRIGHT', power, 'BOTTOMRIGHT',  6, -7)
		power.bg:SetAtlas('UI-HUD-CoolDownManager-Bar-BG')

		-- 텍스트
		local powerOverlay = CreateFrame('Frame', nil, power)
		powerOverlay:SetAllPoints(power)
		powerOverlay:SetFrameLevel(power:GetFrameLevel() + 10)

		power.text = powerOverlay:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
		power.text:SetPoint('RIGHT', powerOverlay, 'RIGHT', -5, 0)
		power.text:SetTextColor(1, 1, 1)

		self.Power = power
		self.Power.colorPower = true

		if unit == 'player' then
			self.Power.displayAltPower = true
			self.Power.GetDisplayPower = function(element, u)
				if dodo and dodo.DB and dodo.DB.unitframePowerOnlyMana == false then
					return nil
				end

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
					if powerType == 0 or isManaSecondary then
						showBar = true
					end
				end

				if showBar then
					element:Show()
				else
					element:Hide()
				end
			end
		elseif unit == 'target' then
			self.Power.PostUpdate = function(element, u, cur, min, max)
				if dodo and dodo.DB and dodo.DB.unitframeTargetPower == false then
					element:Hide()
				else
					element:Show()
				end
			end
		end

		self:Tag(power.text, '[dodopower]')
	end

	-- ==============================
	-- 아우라 (버프 - 타겟 전용)
	-- ==============================
	if unit == 'target' then
		local buffs = CreateFrame('Frame', nil, self)
		buffs:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, -4)
		buffs:SetSize(uWidth, 20)
		buffs.num = 5
		buffs.spacing = 1
		buffs.size = 20
		buffs.initialAnchor = 'BOTTOMRIGHT'
		buffs.growthY = 'UP'
		buffs.growthX = 'LEFT'
		buffs.PostCreateButton = post_create_button
		buffs.PostUpdate = function(element)
			if dodo and dodo.DB and dodo.DB.unitframeTargetBuffs == false then
				element:Hide()
			end
		end

		self.Buffs = buffs
	end

	self:SetSize(uWidth, uHeight + (showPower and pHeight or 0) + 10)
end

-- ==============================
-- 우두머리창 미리보기
-- ==============================
local function toggle_boss_debug(forceState)
	if dodo and dodo.DB and dodo.DB.enableUnitframeModule == false then return end

	if forceState ~= nil then
		is_boss_debug = forceState
	else
		is_boss_debug = not is_boss_debug
	end

	for i = 1, 5 do
		local bossFrame = _G['dodoBossFrame' .. i]
		if bossFrame then
			if is_boss_debug then
				UnregisterUnitWatch(bossFrame)
				bossFrame.unit = 'player'
				bossFrame:SetAlpha(1)
				bossFrame:Show()
				bossFrame:UpdateAllElements('UNIT_PORTRAIT_UPDATE')
				if bossFrame.nameText then
					bossFrame.nameText:SetText("우두머리 " .. i)
				end
			else
				bossFrame.unit = 'boss' .. i
				if not InCombatLockdown() then
					RegisterUnitWatch(bossFrame)
				end
			end
		end
	end
end

-- ==============================
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
	if not dodo or not dodo.DB then return end
	local isEnabled = (dodo.DB.enableUnitframeModule ~= false)

	local customFrames = {
		dodoPlayerFrame, dodoTargetFrame, dodoTargetTargetFrame,
		dodoFocusFrame, dodoPetFrame
	}
	for i = 1, 5 do
		table.insert(customFrames, _G['dodoBossFrame' .. i])
	end

	for _, frame in ipairs(customFrames) do
		if frame then
			local isBoss = frame:GetName() and frame:GetName():match('^dodoBossFrame')
			if isEnabled then
				frame:SetAlpha(1)
				if not InCombatLockdown() then
					if isBoss and is_boss_debug then
						UnregisterUnitWatch(frame)
						frame.unit = 'player'
						frame:Show()
						frame:UpdateAllElements('UNIT_PORTRAIT_UPDATE')
						if frame.nameText then
							local index = frame:GetName():match('^dodoBossFrame(%d+)')
							frame.nameText:SetText("우두머리 " .. (index or ""))
						end
					else
						RegisterUnitWatch(frame)
					end
				end
			else
				frame:SetAlpha(0)
				if not InCombatLockdown() then
					UnregisterUnitWatch(frame)
					frame:Hide()
				end
			end
		end
	end

	if isEnabled then
		disable_unit_frame(PlayerFrame, 'PlayerFrameContainer', 'PlayerFrameContent')
		disable_unit_frame(TargetFrame, 'TargetFrameContainer', 'TargetFrameContent')
		disable_unit_frame(FocusFrame, 'TargetFrameContainer', 'TargetFrameContent')
		disable_unit_frame(TargetFrameToT)
		disable_unit_frame(FocusFrameToT)
		if BossTargetFrameContainer then
			BossTargetFrameContainer:SetAlpha(0)
		end
		for i = 1, 5 do
			local bossFrame = _G['Boss' .. i .. 'TargetFrame']
			if bossFrame then
				disable_unit_frame(bossFrame, 'TargetFrameContainer', 'TargetFrameContent')
			end
		end
	else
		local function restore_unit_frame(frame, containerKey, contentKey)
			if not frame then return end
			frame:SetAlpha(1)
			if frame[containerKey] then frame[containerKey]:Show() end
			if frame[contentKey] then frame[contentKey]:Show() end
		end
		restore_unit_frame(PlayerFrame, 'PlayerFrameContainer', 'PlayerFrameContent')
		restore_unit_frame(TargetFrame, 'TargetFrameContainer', 'TargetFrameContent')
		restore_unit_frame(FocusFrame, 'TargetFrameContainer', 'TargetFrameContent')
		if TargetFrameToT then TargetFrameToT:SetAlpha(1) end
		if FocusFrameToT then FocusFrameToT:SetAlpha(1) end
		if BossTargetFrameContainer then
			BossTargetFrameContainer:SetAlpha(1)
		end
		for i = 1, 5 do
			local bossFrame = _G['Boss' .. i .. 'TargetFrame']
			if bossFrame then
				restore_unit_frame(bossFrame, 'TargetFrameContainer', 'TargetFrameContent')
			end
		end
	end
end

dodo.UpdateUnitframeModuleState = update_module_state

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
	if playerFrame then return end

	oUF:RegisterStyle('dodo', create_style)
	oUF:SetActiveStyle('dodo')

	playerFrame = oUF:Spawn('player', 'dodoPlayerFrame')
	playerFrame:SetPoint('TOPRIGHT', PlayerFrame, 'TOPRIGHT', -20, -18)

	targetFrame = oUF:Spawn('target', 'dodoTargetFrame')
	targetFrame:SetPoint('TOPLEFT', TargetFrame, 'TOPLEFT', 20, -18)

	targettargetFrame = oUF:Spawn('targettarget', 'dodoTargetTargetFrame')
	targettargetFrame:SetPoint('TOPLEFT', targetFrame, 'BOTTOMRIGHT', -100, -15)

	focusFrame = oUF:Spawn('focus', 'dodoFocusFrame')
	focusFrame:SetPoint('TOPLEFT', FocusFrame, 'TOPLEFT', 20, -23)

	petFrame = oUF:Spawn('pet', 'dodoPetFrame')
	petFrame:SetPoint('TOPLEFT', playerFrame, 'BOTTOMLEFT', 0, -5)

	for i = 1, 5 do
		local bossFrame = oUF:Spawn('boss' .. i, 'dodoBossFrame' .. i)
		bossFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -300, -278 - (i - 1) * 70)
	end
end

local function initialize()
	create_ui()
end

local function update_feature()
	-- 자원바 강제 업데이트
	if playerFrame and playerFrame.Power then
		playerFrame.Power:ForceUpdate()
	end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
	initialize()
	update_feature()
	update_module_state()

	-- LibEditMode 등록
	if LibEditMode then
		local systemID = Enum.EditModeSystem.UnitFrame or 1
		local playerSubSystemID = Enum.EditModeUnitFrameSystemIndices.Player or 1
		local targetSubSystemID = Enum.EditModeUnitFrameSystemIndices.Target or 2

		LibEditMode:AddSystemSettings(systemID, {
			{
				kind = LibEditMode.SettingType.Checkbox,
				name = "자원바",
				desc = "플레이어 프레임의 자원바(마나/기력 등)를 표시합니다.",
				default = true,
				get = function()
					return (dodo and dodo.DB and dodo.DB.unitframePower ~= false)
				end,
				set = function(_, newValue)
					if dodo and dodo.DB then
						dodo.DB.unitframePower = newValue
					end
					if playerFrame and playerFrame.Power then
						playerFrame.Power:ForceUpdate()
					end
				end,
			},
			{
				kind = LibEditMode.SettingType.Checkbox,
				name = "보조자원이 마나일때만 활성화",
				desc = "자원바가 마나(또는 보조 마나)일 때만 표시되도록 제한합니다.",
				default = true,
				get = function()
					return (dodo and dodo.DB and dodo.DB.unitframePowerOnlyMana ~= false)
				end,
				set = function(_, newValue)
					if dodo and dodo.DB then
						dodo.DB.unitframePowerOnlyMana = newValue
					end
					if playerFrame and playerFrame.Power then
						playerFrame.Power:ForceUpdate()
					end
				end,
				disabled = function()
					return (dodo and dodo.DB and dodo.DB.unitframePower == false)
				end,
			}
		}, playerSubSystemID)
	end

	if dodo.RegisterEditModeSetting then
		dodo.RegisterEditModeSetting("전투", {
			{
				name = "유닛프레임",
				get = function() return dodo.DB and dodo.DB.enableUnitframeModule ~= false end,
				set = function(checked)
					if dodo.DB then dodo.DB.enableUnitframeModule = checked end
					update_module_state()
				end
			}
		})
	end
end

-- ==============================
-- 이벤트 및 미리보기 연동
-- ==============================
if EventRegistry then
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		C_Timer.After(0.2, function()
			toggle_boss_debug(true)
		end)
	end)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		toggle_boss_debug(false)
	end)
end