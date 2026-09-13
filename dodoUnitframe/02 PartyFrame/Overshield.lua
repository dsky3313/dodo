-- ==============================
-- Inspired
-- ==============================
-- MiniOvershields (https://www.curseforge.com/wow/addons/miniovershields)

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
local hooksecurefunc = hooksecurefunc
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax

-- ==============================
-- 파티/레이드 보호막 오버레이
-- ==============================
local OVERSHIELD_UNIT_TYPE = { player = "party" }
for i = 1, 4  do OVERSHIELD_UNIT_TYPE["party"..i] = "party" end
for i = 1, 40 do OVERSHIELD_UNIT_TYPE["raid"..i]  = "raid"  end

local function update_overshield(frame)
	if not frame or frame:IsForbidden() then return end

	local healthBar = frame.healthBar
	local unit = frame.unit
	if not healthBar or not unit then return end

	local bar = healthBar.dodoOvershield
	local unit_type = OVERSHIELD_UNIT_TYPE[unit]

	local show = unit_type
		and dodoDB.enablePartyframeOvershield ~= false
		and (unit_type ~= "party" or dodoDB.enablePartyframeOvershieldParty ~= false)
		and (unit_type ~= "raid"  or dodoDB.enablePartyframeOvershieldRaid  == true)

	if not show then
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

