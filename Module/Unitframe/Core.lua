-- ==============================
-- Inspired
-- ==============================
-- oUF (https://www.curseforge.com/wow/addons/ouf)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local oUF = dodo.oUF or _G.oUF
dodo.UnitframeStyles = dodo.UnitframeStyles or {}

local config = {
	barTexture = [[Interface\Buttons\WHITE8X8]],
}

-- ==============================
-- 캐싱
-- ==============================
local AbbreviateNumbers = AbbreviateNumbers
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local RegisterUnitWatch = RegisterUnitWatch
local SecureUnitButton_OnLoad = SecureUnitButton_OnLoad
local string_format = string.format
local tostring = tostring
local UnregisterUnitWatch = UnregisterUnitWatch
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent
local UnitPowerType = UnitPowerType
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

	if issecretvalue(max) then
		if isMana then
			local pct = UnitPowerPercent(unit, nil, true, CurveConstants and CurveConstants.ScaleTo100)
			if not pct or issecretvalue(pct) then return '0' end
			return string_format('%.0f', pct)
		else
			local cur = UnitPower(unit)
			return issecretvalue(cur) and cur or tostring(cur)
		end
	end

	if max == 0 then return '' end

	local cur = UnitPower(unit)
	if isMana then
		if issecretvalue(cur) then
			local pct = UnitPowerPercent(unit, nil, true, CurveConstants and CurveConstants.ScaleTo100)
			if not pct or issecretvalue(pct) then return '0' end
			return string_format('%.0f', pct)
		end
		return string_format('%.0f', (cur / max) * 100)
	else
		if issecretvalue(cur) then return cur end
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

local function restore_unit_frame(frame, containerKey, contentKey)
	if not frame then return end
	frame:SetAlpha(1)
	if frame[containerKey] then frame[containerKey]:Show() end
	if frame[contentKey] then frame[contentKey]:Show() end
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
		if not dodo.IsBossHooked then
			dodo.IsBossHooked = true

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
-- oUF 스타일 정의
-- ==============================
local function create_style(self, unit)
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

	-- 체력 바 (self.Health)
	local health = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
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

	self.Health = health
	self.Health.colorClass = true
	self.Health.colorReaction = true
	self.Health.colorTapping = true
	self.Health.colorDisconnected = true
	self.Health.frequentUpdates = true

	self:Tag(self.nameText, '[name]')
	self:Tag(health.text, '[shortcurhp] | [perhp:decimal]')

	-- 유닛별 특화 컴포넌트 추가 호출
	local isBoss = unit and unit:match('^boss%d')
	local styleKey = isBoss and 'boss' or unit
	if dodo.UnitframeStyles and dodo.UnitframeStyles[styleKey] then
		dodo.UnitframeStyles[styleKey](self, unit)
	elseif dodo.UnitframeStyles and dodo.UnitframeStyles['etc'] then
		dodo.UnitframeStyles['etc'](self, unit)
	end

	-- 최종 프레임 크기 지정
	local uWidth = self.uWidth or 190
	local uHeight = self.uHeight or 30
	local showPower = self.showPower
	local pHeight = self.pHeight or 10

	health:SetSize(uWidth, uHeight)
	healthOverlay:SetAllPoints(health)
	health:SetPoint('CENTER', self, 'CENTER')

	if self.showHealthText == false then
		health.text:Hide()
	end

	self:SetSize(uWidth, uHeight + (showPower and pHeight or 0) + 10)
end

-- ==============================
-- 프레임 생성 및 상태 관리
-- ==============================
local playerFrame, targetFrame, targettargetFrame, focusFrame, petFrame
local customFrames = {}

local function create_ui()
	if playerFrame then return end

	oUF:RegisterStyle('dodo', create_style)
	oUF:SetActiveStyle('dodo')

	playerFrame = oUF:Spawn('player', 'dodoPlayerFrame')
	playerFrame:SetPoint('TOPRIGHT', PlayerFrame, 'TOPRIGHT', -20, -18)
	table.insert(customFrames, playerFrame)
	dodo.PlayerFrame = playerFrame

	targetFrame = oUF:Spawn('target', 'dodoTargetFrame')
	targetFrame:SetPoint('TOPLEFT', TargetFrame, 'TOPLEFT', 20, -18)
	table.insert(customFrames, targetFrame)
	dodo.TargetFrame = targetFrame

	targettargetFrame = oUF:Spawn('targettarget', 'dodoTargetTargetFrame')
	targettargetFrame:SetPoint('TOPLEFT', targetFrame, 'BOTTOMRIGHT', -100, -36)
	table.insert(customFrames, targettargetFrame)
	dodo.TargetTargetFrame = targettargetFrame

	focusFrame = oUF:Spawn('focus', 'dodoFocusFrame')
	focusFrame:SetPoint('TOPLEFT', FocusFrame, 'TOPLEFT', 20, -23)
	table.insert(customFrames, focusFrame)
	dodo.FocusFrame = focusFrame

	petFrame = oUF:Spawn('pet', 'dodoPetFrame')
	petFrame:SetPoint('TOPLEFT', playerFrame, 'BOTTOMLEFT', 0, -5)
	table.insert(customFrames, petFrame)
	dodo.PetFrame = petFrame

	for i = 1, 5 do
		local bossFrame = oUF:Spawn('boss' .. i, 'dodoBossFrame' .. i)
		bossFrame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -300, -278 - (i - 1) * 70)
		table.insert(customFrames, bossFrame)
	end
end

local function update_module_state()
	if not dodo or not dodo.DB then return end
	local isEnabled = (dodo.DB.enableUnitframeModule ~= false)

	for _, frame in ipairs(customFrames) do
		if frame then
			local isBoss = frame:GetName() and frame:GetName():match('^dodoBossFrame')
			if isEnabled then
				frame:SetAlpha(1)
				if not InCombatLockdown() then
					if isBoss and dodo.IsBossDebug then
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

local isInitialized = false
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		dodoDB = dodoDB or {}
		dodo.DB = dodo.DB or dodoDB
	elseif event == "PLAYER_LOGIN" then
		if isInitialized then return end
		isInitialized = true

		dodo.DB = dodo.DB or dodoDB or {}

		create_ui()
		update_module_state()

		if dodo.RegisterEditModeModuleSetting then
			dodo.RegisterEditModeModuleSetting("인터페이스", {
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
end)
