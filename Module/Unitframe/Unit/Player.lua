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

	-- 전투 표시기
	local combatIndicator = self.CombatIndicator
	if not combatIndicator then
		combatIndicator = self:CreateTexture(nil, 'OVERLAY')
		combatIndicator:SetSize(22, 22)
		combatIndicator:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 4)
		self.CombatIndicator = combatIndicator
	end

	-- 휴식 표시기 (Zzz 플립북)
	local restIndicator = self.RestingIndicator
	if not restIndicator then
		restIndicator = CreateFrame('Frame', nil, self)
		restIndicator:SetSize(30, 30)
		restIndicator:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 8)

		local restTexture = restIndicator:CreateTexture(nil, 'ARTWORK')
		restTexture:SetAtlas('UI-HUD-UnitFrame-Player-Rest-Flipbook')
		restTexture:SetAllPoints()

		local restAnimGroup = restTexture:CreateAnimationGroup()
		restAnimGroup:SetLooping('REPEAT')
		local flipbook = restAnimGroup:CreateAnimation('FlipBook')
		flipbook:SetDuration(1.5)
		flipbook:SetFlipBookRows(7)
		flipbook:SetFlipBookColumns(6)
		flipbook:SetFlipBookFrames(42)
		flipbook:SetOrder(1)

		restIndicator.anim = restAnimGroup
		restIndicator.PostUpdate = function(element, isResting)
			if isResting then element.anim:Play() else element.anim:Stop() end
		end
		self.RestingIndicator = restIndicator
	end
end
