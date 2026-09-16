-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local Enum = Enum
local issecretvalue = issecretvalue or function() return false end
local pairs = pairs
local string_format = string.format
local UnitClass = UnitClass
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local _G = _G

-- ==============================
-- 설정 테이블
-- ==============================
local POWER_UNITS = {
	player = true, target = true, focus = true, boss = true,
}

local POWER_DB_KEYS = {
	player = "unitframePowerPlayer",
	target = "unitframePowerTarget",
	focus  = "unitframePowerFocus",
	boss   = "unitframePowerBoss",
}

local POWER_DEFAULTS = {
	player = false, target = true, focus = false, boss = true,
}

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
	end

	self.Power.PostUpdate = function(element, u, cur, min, max)
		if not is_power_enabled(unit) then
			element:Hide()
			return
		end

		if unit == 'player' then
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
		else
			element:Show()
		end
	end

	self:Tag(power.text, '[dodopower]')

	if POWER_RESERVE_SPACE[unit] or is_power_enabled(unit) then
		self.showPower = true
	end
end

-- ==============================
-- 설정 등록
-- ==============================
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3

local POWER_SYSTEM_INDICES = {
	player = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Player) or 1,
	target = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Target) or 2,
	boss   = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Boss) or 5,
	focus  = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Focus) or 6,
}

if dodo.RegisterEditModeSystemSetting then
	for unit, sysIdx in pairs(POWER_SYSTEM_INDICES) do
		local sysID = string_format("%d_%d", Enum_EditModeSystem_UnitFrame, sysIdx)
		local dbKey = POWER_DB_KEYS[unit]
		local default = POWER_DEFAULTS[unit]
		dodo.RegisterEditModeSystemSetting(sysID, {
			{
				name = "자원 바",
				get = function()
					if not dodoDB or not dbKey then return default or false end
					local val = dodoDB[dbKey]
					return val == nil and (default or false) or val
				end,
				set = function(checked)
					if dodoDB and dbKey then dodoDB[dbKey] = checked end
					local frameMap = {
						player = dodo.PlayerFrame,
						target = dodo.TargetFrame,
						focus  = dodo.FocusFrame,
					}
					local frame = frameMap[unit]
					if frame and frame.Power then
						frame.Power:ForceUpdate()
					end
					if unit == "boss" then
						for i = 1, 5 do
							local bFrame = _G["dodoBossFrame" .. i]
							if bFrame and bFrame.Power then bFrame.Power:ForceUpdate() end
						end
					end
				end,
				disabled = function() return dodo.DB and dodo.DB.enableUnitframeModule == false end
			}
		})
	end
end
