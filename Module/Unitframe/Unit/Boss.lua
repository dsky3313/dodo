-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local EventRegistry = EventRegistry
local InCombatLockdown = InCombatLockdown
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch

-- ==============================
-- 보스 스타일 주입
-- ==============================
local function boss_style(self, unit)
	self.uWidth = 150
	self.uHeight = 30
end
dodo.UnitframeStyles['boss'] = boss_style

-- ==============================
-- 우두머리 미리보기 디버그 기능
-- ==============================
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

local function on_edit_mode_enter()
	dodo.ToggleBossDebug(true)
end

local function on_edit_mode_exit()
	dodo.ToggleBossDebug(false)
end

if EventRegistry then
	EventRegistry:RegisterCallback("EditMode.Enter", on_edit_mode_enter)
	EventRegistry:RegisterCallback("EditMode.Exit", on_edit_mode_exit)
end
