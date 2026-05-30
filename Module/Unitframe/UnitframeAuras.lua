-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 아우라 공통 스타일
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
