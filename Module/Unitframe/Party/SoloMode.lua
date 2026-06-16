-- ==============================
-- Inspired
-- ==============================
-- KallyeSoloRaidFrames (https://www.curseforge.com/wow/addons/kallye-solo-raid-frames)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- WoW 에디트모드 유닛프레임 특수 고유 ID 빌드 (안전 가드 적용)
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3
local Enum_EditModeUnitFrameSystem_Party = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Party) or 3
local party_system_id = string.format("%d_%d", Enum_EditModeSystem_UnitFrame, Enum_EditModeUnitFrameSystem_Party)

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CompactPartyFrame = CompactPartyFrame
local hooksecurefunc = hooksecurefunc
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid

-- ==============================
-- 솔로일 때 파티프레임 강제 표시
-- ==============================
local function is_enabled()
	if dodo and dodo.DB and dodo.DB.enableUnitframeModule == false then return false end
	return dodoDB and dodoDB.enablePartyframeSoloMode ~= false
end

local force_show_party_frame

force_show_party_frame = function()
	if not is_enabled() then return end
	if IsInGroup() or IsInRaid() then return end

	if InCombatLockdown() then
		C_Timer.After(1, force_show_party_frame)
		return
	end

	if not CompactPartyFrame:IsShown() then
		CompactPartyFrame:SetShown(true)
	end
end

if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
	hooksecurefunc(CompactPartyFrame, "UpdateVisibility", force_show_party_frame)
end

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
	dodo.RegisterEditModeSystemSetting(party_system_id, {
		{
			name = "솔로일 때 파티프레임 표시",
			get = function() return dodoDB and dodoDB.enablePartyframeSoloMode ~= false end,
			set = function(checked)
				if dodoDB then dodoDB.enablePartyframeSoloMode = checked end
				if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
					CompactPartyFrame:UpdateVisibility()
				end
			end
		}
	})
end
