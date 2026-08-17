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
	buffs:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, -4)
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
-- 설정 등록
-- ==============================
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3

local BUFFS_SYSTEM_INDICES = {
	player = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Player) or 1,
	target = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Target) or 2,
	boss   = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Boss) or 5,
	focus  = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Focus) or 6,
}

if dodo.RegisterEditModeSystemSetting then
	for unit, sysIdx in pairs(BUFFS_SYSTEM_INDICES) do
		local sysID = string_format("%d_%d", Enum_EditModeSystem_UnitFrame, sysIdx)
		local dbKey = BUFFS_DB_KEYS[unit]
		local default = BUFFS_DEFAULTS[unit]
		dodo.RegisterEditModeSystemSetting(sysID, {
			{
				name = "버프 표시",
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
					if frame and frame.Buffs then
						if checked then frame.Buffs:Show() else frame.Buffs:Hide() end
					end
					if unit == "boss" then
						for i = 1, 5 do
							local bFrame = _G["dodoBossFrame" .. i]
							if bFrame and bFrame.Buffs then
								if checked then bFrame.Buffs:Show() else bFrame.Buffs:Hide() end
							end
						end
					end
				end,
				disabled = function() return dodo.DB and dodo.DB.enableUnitframeModule == false end
			}
		})
	end
end
