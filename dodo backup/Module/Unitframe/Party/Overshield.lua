-- ==============================
-- Inspired
-- ==============================
-- MiniOvershields (https://www.curseforge.com/wow/addons/miniovershields)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- WoW 에디트모드 유닛프레임 특수 고유 ID 빌드 (안전 가드 적용)
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
local Enum_EditModeUnitFrameSystem_Raid = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Raid) or 4
local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3

local raid_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Raid)
local party_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax

-- ==============================
-- 파티/레이드 보호막 오버레이
-- ==============================
local function is_overshield_unit(unit)
	if unit == "player" then return true end
	if unit:match("^party%d+$") then return true end
	if unit:match("^raid%d+$") then return true end
	return false
end

local function update_overshield(frame)
	if not frame or frame:IsForbidden() then return end

	local healthBar = frame.healthBar
	local unit = frame.unit
	if not healthBar or not unit then return end

	local bar = healthBar.dodoOvershield

	if dodoDB.enablePartyframeOvershield == false or not is_overshield_unit(unit) then
		if bar then bar:Hide() end
		return
	end

	-- 블리자드 기본 표시는 부족 체력만큼만 채워줌 — overAbsorbGlow가 보일 때(흡수량 > 부족 체력)만 초과분 표시
	local glow = frame.overAbsorbGlow
	if not glow or not glow:IsVisible() then
		if bar then bar:Hide() end
		return
	end

	if not bar then
		bar = CreateFrame('StatusBar', nil, healthBar)
		bar:SetAllPoints(healthBar)
		bar:SetReverseFill(true)
		bar:SetStatusBarTexture([[Interface\RaidFrame\Shield-Fill]])
		bar:SetStatusBarColor(1, 1, 1, 0.6)
		bar:SetFrameLevel(healthBar:GetFrameLevel() + 1)
		healthBar.dodoOvershield = bar
	end

	local maxHealth = UnitHealthMax(unit) or 0
	local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0

	bar:SetMinMaxValues(0, maxHealth)
	bar:SetValue(totalAbsorb)
	bar:Show()
end

hooksecurefunc("CompactUnitFrame_UpdateAll", update_overshield)
hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", update_overshield)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
	dodo.RegisterEditModeSystemSetting(raid_system_id, {
		{
			name = "파티/레이드 보호막 표시",
			get = function() return dodoDB and dodoDB.enablePartyframeOvershield ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enablePartyframeOvershield = checked end
			end
		}
	})

	dodo.RegisterEditModeSystemSetting(party_system_id, {
		{
			name = "파티/레이드 보호막 표시",
			get = function() return dodoDB and dodoDB.enablePartyframeOvershield ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enablePartyframeOvershield = checked end
			end
		}
	})
end
