-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 대상 스타일 주입
-- ==============================
dodo.UnitframeStyles['target'] = function(self, unit)
	self.uWidth = 190
	self.uHeight = 30
	self.pHeight = 10
	self.showPower = true

	local uWidth = self.uWidth
	local health = self.Health

	-- 자원 바 (self.Power)
	local power = self.Power
	if not power then
		power = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
		power:SetSize(120, 10)
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
		self.Power.PostUpdate = function(element, u, cur, min, max)
			if dodo and dodo.DB and dodo.DB.unitframeTargetPower == false then
				element:Hide()
			else
				element:Show()
			end
		end
		self:Tag(power.text, '[dodopower]')
	end

	-- 버프 표시 (Buffs)
	local buffs = self.Buffs
	if not buffs then
		buffs = CreateFrame('Frame', nil, self)
		buffs:SetPoint('BOTTOMRIGHT', self, 'TOPRIGHT', 0, -4)
		buffs:SetSize(uWidth, 20)
		buffs.num = 5
		buffs.spacing = 1
		buffs.size = 20
		buffs.initialAnchor = 'BOTTOMRIGHT'
		buffs.growthY = 'UP'
		buffs.growthX = 'LEFT'
		buffs.PostCreateButton = dodo.UnitframePostCreateButton
		buffs.PostUpdate = function(element)
			if dodo and dodo.DB and dodo.DB.unitframeTargetBuffs == false then
				element:Hide()
			end
		end
		self.Buffs = buffs
	end

	-- 캐스팅바 부착
	if dodo.UnitframeCreateCastbar then
		dodo.UnitframeCreateCastbar(self, uWidth)
	end
end
