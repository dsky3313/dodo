-- ==============================
-- Inspired
-- ==============================
-- RefineUI (https://github.com/Enkiduke/RefineUI)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

-- ==============================
-- 캐싱
-- ==============================
local BAG_ITEM_QUALITY_COLORS = BAG_ITEM_QUALITY_COLORS
local BlizzardCreateColor = CreateColor
local C_CurveUtil = C_CurveUtil
local C_Item = C_Item
local Enum = Enum
local format = string.format
local pairs = pairs
local PowerBarColor = PowerBarColor
local select = select
local type = type
local UnitClass = UnitClass

-- ==============================
-- 기능 1: 색상 생성 헬퍼 (CreateColor)
-- ==============================
-- Creates a color table that can be indexed [1],[2],[3] or .r,.g,.b
local function CreateColor(r, g, b, a)
	local color = {}
	
	if r > 1 or g > 1 or b > 1 then
		r, g, b = r / 255, g / 255, b / 255 -- Handle 0-255 inputs
	end
	
	color.r, color.g, color.b = r, g, b
	color[1], color[2], color[3] = r, g, b
	
	if a then
		color.a = a
		color.colorStr = format("|c%02x%02x%02x%02x", a * 255, r * 255, g * 255, b * 255)
	else
		color.colorStr = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
	end
	
	return color
end

dodo.CreateColor = CreateColor

-- ==============================
-- 기능 2: 색상 팔레트 정의 (dodo.Colors)
-- ==============================
dodo.Colors = {
	-- Empowered Casts (Evoker)
	EmpowerStages = {
		CreateColor(96, 172, 85),
		CreateColor(176, 172, 57),
		CreateColor(200, 140, 56),
		CreateColor(202, 69, 57),
	},

	-- Unit Reaction
	Reaction = {
		[1] = CreateColor(222, 95, 95), -- Hated
		[2] = CreateColor(222, 95, 95), -- Hostile
		[3] = CreateColor(222, 145, 95), -- Unfriendly
		[4] = CreateColor(255, 221, 60), -- Neutral
		[5] = CreateColor(86, 174, 87), -- Friendly
		[6] = CreateColor(86, 174, 87), -- Honored
		[7] = CreateColor(86, 174, 87), -- Revered
		[8] = CreateColor(86, 174, 87), -- Exalted
	},

	-- Classes
	Class = {
		["DEATHKNIGHT"] = CreateColor(196, 30, 58),
		["DEMONHUNTER"] = CreateColor(163, 48, 201),
		["DRUID"]       = CreateColor(255, 124, 10),
		["EVOKER"]      = CreateColor(51, 147, 127),
		["HUNTER"]      = CreateColor(170, 211, 114),
		["MAGE"]        = CreateColor(63, 199, 235),
		["MONK"]        = CreateColor(0, 255, 150),
		["PALADIN"]     = CreateColor(244, 140, 186),
		["PRIEST"]      = CreateColor(255, 255, 255),
		["ROGUE"]       = CreateColor(255, 244, 104),
		["SHAMAN"]      = CreateColor(0, 112, 221),
		["WARLOCK"]     = CreateColor(135, 136, 238),
		["WARRIOR"]     = CreateColor(198, 155, 109),
	},
	
	-- Power Types (ResourceBar Bar1 전용 테마 색상)
	Power = {
		["ESSENCE"]        = CreateColor(0.16, 0.57, 0.49),
		["HOLY_POWER"]     = CreateColor(0.95, 0.9, 0.6),
		["SOUL_SHARDS"]    = CreateColor(0.58, 0.51, 0.79),
		["COMBO_POINTS"]   = CreateColor(1.0, 0.96, 0.41),
		["CHI"]            = CreateColor(0.0, 1.0, 0.59),
		["ARCANE_CHARGES"] = CreateColor(0.25, 0.78, 0.92),
	},

	-- Specializations (ResourceBar Bar2 전용 테마 색상)
	Spec = {
		["DEATHKNIGHT"] = { [1] = CreateColor(1, 0, 0), -- 
							[2] = CreateColor(0, 0.8, 1), -- 
							[3] = CreateColor(0.3, 0.9, 0.3) }, -- 
		["DEMONHUNTER"] = { [2] = CreateColor(0.86, 0.59, 0.98) }, -- 악탱
		["DRUID"]       = { [3] = CreateColor(0, 0.82, 1) }, -- 수드
		["MONK"]        = { [1] = CreateColor(0, 1, 0.59) }, -- 양조
		["SHAMAN"]      = { [3] = CreateColor(0, 0.82, 1) }, -- 복술
		["WARRIOR"]     = { [1] = CreateColor(1, 0.588, 0.196), -- 무전
							[2] = CreateColor(0, 0.82, 1), -- 분전
							[3] = CreateColor(1, 0.588, 0.196) }, -- 전탱
	},

	-- Debuffs (디버프 유형별 색상)
	Debuff = {
		[0] = DEBUFF_TYPE_NONE_COLOR or CreateColor(0.8, 0.8, 0.8),
		[1] = DEBUFF_TYPE_MAGIC_COLOR or CreateColor(0.2, 0.6, 1.0),
		[2] = DEBUFF_TYPE_CURSE_COLOR or CreateColor(0.6, 0.0, 1.0),
		[3] = DEBUFF_TYPE_DISEASE_COLOR or CreateColor(0.6, 0.4, 0.0),
		[4] = DEBUFF_TYPE_POISON_COLOR or CreateColor(0.0, 0.6, 0.0),
		[9] = DEBUFF_TYPE_BLEED_COLOR or CreateColor(1.0, 0.0, 0.0),
		[11] = DEBUFF_TYPE_BLEED_COLOR or CreateColor(1.0, 0.0, 0.0),
	},

	-- Action Bars (행동단축바 상태 색상)
	ActionColors = {
		range  = CreateColor(0.9, 0.1, 0.1),
		mana   = CreateColor(0.1, 0.3, 1.0),
		normal = CreateColor(1.0, 1.0, 1.0),
		cdmGlow  = CreateColor(0, 1, 0),
		cdmTimer = CreateColor(0, 1, 0),
		cdmCount = CreateColor(1, 1, 0)
	},
}

-- Blizzard 순정 PowerBarColor 동적 적용
for power, color in pairs(PowerBarColor) do
	if type(power) == 'string' and color.r then
		dodo.Colors.Power[power] = CreateColor(color.r, color.g, color.b)
	end
end

-- ==============================
-- 기능 3: 아이템 품질 등급 캐싱
-- ==============================
dodo.Colors.Quality = {}
for i = 0, 8 do
	local r, g, b
	if C_Item and C_Item.GetItemQualityColor then
		r, g, b = C_Item.GetItemQualityColor(i)
	else
		local qColor = BAG_ITEM_QUALITY_COLORS and BAG_ITEM_QUALITY_COLORS[i]
		if qColor then
			r, g, b = qColor.r, qColor.g, qColor.b
		else
			r, g, b = 1, 1, 1
		end
	end
	dodo.Colors.Quality[i] = CreateColor(r, g, b)
end

-- ==============================
-- 기능 4: 플레이어 직업 색상 캐싱
-- ==============================
local myClass = UnitClass and select(2, UnitClass("player"))
dodo.MyClassColor = myClass and dodo.Colors.Class[myClass] or CreateColor(1, 1, 1)

-- ==============================
-- 기능 5: Curves (WoW 12.0+)
-- ==============================
if C_CurveUtil then
	dodo.CurvePercent = CurveConstants and CurveConstants.ScaleTo100 or 1.0
	dodo.SmoothBars = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or nil

	-- Dispel / Debuff Types
	local DEBUFF_COLORS = dodo.Colors.Debuff

	dodo.DispelColorCurve = C_CurveUtil.CreateColorCurve()
	dodo.DispelColorCurve:SetType(Enum.LuaCurveType.Step)
	for typeID, colorInfo in pairs(DEBUFF_COLORS) do
		dodo.DispelColorCurve:AddPoint(typeID, colorInfo)
	end

	-- Cooldowns (Expired -> Seconds -> Minutes)
	dodo.CooldownColorCurve = C_CurveUtil.CreateColorCurve()
	dodo.CooldownColorCurve:SetType(Enum.LuaCurveType.Step)
	dodo.CooldownColorCurve:AddPoint(0,  BlizzardCreateColor(1, 0, 0))
	dodo.CooldownColorCurve:AddPoint(4,  BlizzardCreateColor(1, 0.8, 0))
	dodo.CooldownColorCurve:AddPoint(60, BlizzardCreateColor(1, 1, 1))

	-- Interrupt Timer (ActionBar.lua 차단 타이머 그라데이션)
	dodo.Colors.InterruptTimerColorCurve = C_CurveUtil.CreateColorCurve()
	dodo.Colors.InterruptTimerColorCurve:SetType(Enum.LuaCurveType.Linear)
	dodo.Colors.InterruptTimerColorCurve:AddPoint(0.0,  BlizzardCreateColor(1, 0.5, 0.5, 1))
	dodo.Colors.InterruptTimerColorCurve:AddPoint(3.0,  BlizzardCreateColor(1, 1,   0.5, 1))
	dodo.Colors.InterruptTimerColorCurve:AddPoint(3.01, BlizzardCreateColor(1, 1,   1,   1))
	dodo.Colors.InterruptTimerColorCurve:AddPoint(10.0, BlizzardCreateColor(1, 1,   1,   1))

	-- Cast Colors
	dodo.Colors.Cast = {
		Interruptible    = {1, 0.8, 0},
		NonInterruptible = {1, 0.2, 0.2},
	}
	dodo.Colors.CastBG = {
		Interruptible    = {0.3, 0.24, 0},
		NonInterruptible = {0.3, 0.06, 0.06},
	}
end