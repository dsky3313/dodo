-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local issecretvalue = issecretvalue or function() return false end
local UnitClass = UnitClass
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

-- ==============================
-- 설정 테이블
-- ==============================
local POWER_UNITS = {
	player = true, target = true, focus = true, boss = true,
}

local MANA_SECONDARY_CLASSES = { PRIEST = true, SHAMAN = true, DRUID = true }

local POWER_DB_KEYS  = dodo.UF_DB_KEYS.power
local POWER_DEFAULTS = dodo.UF_DEFAULTS.power

-- player/target은 항상 프레임 공간 예약, focus/boss는 켜진 경우에만
local POWER_RESERVE_SPACE = {
	player = true, target = true, focus = false, boss = false,
}

local function is_power_enabled(unit)
	local dbKey = POWER_DB_KEYS[unit]
	if not dbKey then return false end
	if not dodoDB then return POWER_DEFAULTS[unit] or false end
	local val = dodoDB[dbKey]
	if val == nil then return POWER_DEFAULTS[unit] or false end
	return val
end

-- ==============================
-- 자원 바 공통 빌더
-- ==============================
function dodo.UnitframeCreatePower(self, unit)
	if not POWER_UNITS[unit] then return end
	if self.Power then return end

	local health = self.Health
	if not health then return end

	local power = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
	power:SetSize(120, 10)
	if unit == 'focus' then power:SetWidth(70) end
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

	-- 플레이어 전용: 마나 2차 자원 처리
	if unit == 'player' then
		local _, classFile = UnitClass('player')
		local is_mana_class = MANA_SECONDARY_CLASSES[classFile] or false

		self.Power.GetDisplayPower = function(element, u)
			if dodoDB and dodoDB.unitframePowerOnlyMana == false then return nil end
			if is_mana_class and UnitPowerType('player') ~= 0 then
				local maxMana = UnitPowerMax('player', 0)
				local isMaxManaSecret = issecretvalue and issecretvalue(maxMana)
				if maxMana and (isMaxManaSecret or maxMana > 0) then
					return 0, 0
				end
			end
		end

		self.Power.PostUpdate = function(element, u, cur, min, max)
			if not is_power_enabled(unit) then element:Hide() return end
			local powerType = UnitPowerType('player')
			local isManaSecondary = false
			if is_mana_class and powerType ~= 0 then
				local maxMana = UnitPowerMax('player', 0)
				isManaSecondary = maxMana and (issecretvalue(maxMana) or maxMana > 0)
			end
			local showBar = (dodoDB and dodoDB.unitframePowerOnlyMana == false)
				or (powerType == 0 or isManaSecondary)
			if showBar then element:Show() else element:Hide() end
		end
	else
		self.Power.PostUpdate = function(element, u, cur, min, max)
			if not is_power_enabled(unit) then element:Hide() return end
			element:Show()
		end
	end

	self:Tag(power.text, '[dodopower]')

	if POWER_RESERVE_SPACE[unit] or is_power_enabled(unit) then
		self.showPower = true
	end
end