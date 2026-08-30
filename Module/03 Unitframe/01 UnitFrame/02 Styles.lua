---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame        = CreateFrame
local EventRegistry      = EventRegistry
local InCombatLockdown   = InCombatLockdown
local RegisterUnitWatch  = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch

-- ==============================
-- 플레이어
-- ==============================
dodo.UnitframeStyles['player'] = function(self, unit)
	self.uWidth  = 190
	self.uHeight = 30

	local health = self.Health
	if not health.healingAll then
		local healingAll = CreateFrame('StatusBar', nil, health)
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

-- ==============================
-- 타겟
-- ==============================
dodo.UnitframeStyles['target'] = function(self, unit)
	self.uWidth  = 190
	self.uHeight = 30
end

-- ==============================
-- 주시대상
-- ==============================
dodo.UnitframeStyles['focus'] = function(self, unit)
	self.uWidth       = 120
	self.uHeight      = 16
	self.showHealthText = false
end

-- ==============================
-- 보스
-- ==============================
dodo.UnitframeStyles['boss'] = function(self, unit)
	self.uWidth  = 150
	self.uHeight = 30
end

function dodo.ToggleBossDebug(forceState)
	if dodoDB.enableUnitframeModule == false then return end
	if forceState ~= nil then
		dodo.IsBossDebug = forceState
	else
		dodo.IsBossDebug = not dodo.IsBossDebug
	end
	for i = 1, 5 do
		local bossFrame = _G['dodoBossFrame' .. i]
		if bossFrame then
			if dodo.IsBossDebug then
				UnregisterUnitWatch(bossFrame)
				bossFrame.__unit = 'player'
				bossFrame:SetAlpha(1)
				bossFrame:Show()
				bossFrame:UpdateAllElements('UNIT_PORTRAIT_UPDATE')
				if bossFrame.nameText then
					bossFrame.nameText:SetText("우두머리 " .. i)
				end
			else
				bossFrame.__unit = 'boss' .. i
				if not InCombatLockdown() then
					RegisterUnitWatch(bossFrame)
				end
			end
		end
	end
end

local function on_edit_mode_enter() dodo.ToggleBossDebug(true)  end
local function on_edit_mode_exit()  dodo.ToggleBossDebug(false) end
if EventRegistry then
	EventRegistry:RegisterCallback("EditMode.Enter", on_edit_mode_enter)
	EventRegistry:RegisterCallback("EditMode.Exit",  on_edit_mode_exit)
end

-- ==============================
-- 기타 (대상의 대상 / 소환수 / etc)
-- ==============================
dodo.UnitframeStyles['targettarget'] = function(self, unit)
	self.uWidth       = 100
	self.uHeight      = 16
	self.showHealthText = false
end

dodo.UnitframeStyles['pet'] = function(self, unit)
	self.uWidth       = 100
	self.uHeight      = 16
	self.showHealthText = false
end

dodo.UnitframeStyles['etc'] = function(self, unit)
	self.uWidth       = 120
	self.uHeight      = 16
	self.showHealthText = false
end
