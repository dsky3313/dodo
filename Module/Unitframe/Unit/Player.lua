-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 플레이어 스타일 주입
-- ==============================
dodo.UnitframeStyles['player'] = function(self, unit)
	self.uWidth = 190
	self.uHeight = 30

	local health = self.Health

	-- 예상 치유 (HealingAll)
	local healingAll = health.healingAll
	if not healingAll then
		healingAll = CreateFrame('StatusBar', nil, health)
		healingAll:SetPoint('TOP')
		healingAll:SetPoint('BOTTOM')
		healingAll:SetPoint('LEFT', health:GetStatusBarTexture(), 'RIGHT')
		healingAll:SetWidth(self.uWidth)
		healingAll:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
		healingAll:SetStatusBarColor(0, 0.8, 0.4, 0.45)
		healingAll:SetFrameLevel(health:GetFrameLevel() + 1)
		healingAll:Hide()
		health.healingAll = healingAll
	end

end
