-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local Enum = Enum
local pairs = pairs
local string_format = string.format
local _G = _G

-- ==============================
-- 아우라 버튼 공통 스타일
-- ==============================
function dodo.UnitframePostCreateButton(element, button)
	button.Cooldown:SetReverse(true)
	button.Cooldown:SetHideCountdownNumbers(true)
	button.Cooldown.noCooldownCount = true

	button.Count:ClearAllPoints()
	button.Count:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 1, 0)
	button.Count:SetFontObject('SystemFont_Outline_Small')
	button.Count:SetTextColor(1, 1, 1)
end

-- ==============================
-- 버프 공통 빌더
-- ==============================
local BUFFS_UNITS = {
	player = true, target = true, focus = true, boss = true,
}

local BUFFS_DB_KEYS = {
	player = "unitframeBuffsPlayer",
	target = "unitframeBuffsTarget",
	focus  = "unitframeBuffsFocus",
	boss   = "unitframeBuffsBoss",
}

local BUFFS_DEFAULTS = {
	player = false, target = true, focus = false, boss = true,
}

local function is_buffs_enabled(unit)
	local dbKey = BUFFS_DB_KEYS[unit]
	if not dbKey then return false end
	if not dodoDB then return BUFFS_DEFAULTS[unit] or false end
	local val = dodoDB[dbKey]
	if val == nil then return BUFFS_DEFAULTS[unit] or false end
	return val
end

function dodo.UnitframeCreateBuffs(self, uWidth, unit)
	if not BUFFS_UNITS[unit] then return end
	if self.Buffs then return end

	local buffs = self:CreateAuras({
		initialAnchor = 'BOTTOMRIGHT',
		growthX       = 'LEFT',
		growthY       = 'UP',
		layoutLimit   = uWidth,
	})
	buffs:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, -6)
	buffs:SetSize(uWidth, 20)
	buffs.size           = 20
	buffs.showCount      = true
	buffs.elementSpacing = 1
	buffs.PostCreateButton = dodo.UnitframePostCreateButton
	buffs.__unitKey = unit

	buffs:AddGroup('HELPFUL', { maxFrameCount = 5 })

	if not is_buffs_enabled(unit) then
		buffs:Hide()
	end

	self.Buffs = buffs
end

-- ==============================
-- 약화효과 빌더
-- ==============================
local DEBUFFS_DB_KEYS = {
	player = "unitframeDebuffsPlayer",
	target = "unitframeDebuffsTarget",
	focus  = "unitframeDebuffsFocus",
	boss   = "unitframeDebuffsBoss",
}

local DEBUFFS_DEFAULTS = {
	player = false, target = false, focus = false, boss = false,
}

local function is_debuffs_enabled(unit)
	local dbKey = DEBUFFS_DB_KEYS[unit]
	if not dbKey then return false end
	if not dodoDB then return DEBUFFS_DEFAULTS[unit] or false end
	local val = dodoDB[dbKey]
	if val == nil then return DEBUFFS_DEFAULTS[unit] or false end
	return val
end

function dodo.UnitframeCreateDebuffs(self, uWidth, unit)
	if not BUFFS_UNITS[unit] then return end
	if self.Debuffs then return end

	local debuffs = self:CreateAuras({
		initialAnchor = 'BOTTOMRIGHT',
		growthX       = 'LEFT',
		growthY       = 'UP',
		layoutLimit   = uWidth,
	})
	debuffs:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, 16)
	debuffs:SetSize(uWidth, 20)
	debuffs.size           = 20
	debuffs.showCount      = true
	debuffs.elementSpacing = 1
	debuffs.PostCreateButton = dodo.UnitframePostCreateButton
	debuffs.__unitKey = unit

	debuffs:AddGroup('HARMFUL', { maxFrameCount = 5 })

	if not is_debuffs_enabled(unit) then
		debuffs:Hide()
	end

	self.Debuffs = debuffs
end
