-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local _G          = _G

local COMBAT_KEYS    = { player = "unitframeCombatPlayer", target = "unitframeCombatTarget", focus = "unitframeCombatFocus",  boss = "unitframeCombatBoss"  }
local COMBAT_DEF     = { player = true,  target = false, focus = false, boss = false }

local REST_KEYS      = { player = "unitframeRestPlayer" }
local REST_DEF       = { player = true }

local LEADER_KEYS    = { player = "unitframeLeaderPlayer", target = "unitframeLeaderTarget", focus = "unitframeLeaderFocus",  boss = "unitframeLeaderBoss"  }
local LEADER_DEF     = { player = true,  target = true,  focus = false, boss = false }

-- ==============================
-- 동적 정렬: 파티장 → 휴식 → 전투 (좌→우)
-- ==============================
local function reposition(frame)
	local x  = 2
	local li = frame.LeaderIndicator
	local ri = frame.RestingIndicator
	local ci = frame.CombatIndicator

	if li and li:IsShown() then
		li:ClearAllPoints()
		li:SetPoint('LEFT', frame.nameText, 'RIGHT', x, 0)
		x = x + 18  -- 16 + gap 2
	end
	if ri and ri:IsShown() then
		ri:ClearAllPoints()
		ri:SetPoint('BOTTOMLEFT', frame.nameText, 'BOTTOMRIGHT', x, 0)
		x = x + 32  -- 30 + gap 2
	end
	if ci and ci:IsShown() then
		ci:ClearAllPoints()
		ci:SetPoint('BOTTOMLEFT', frame.nameText, 'BOTTOMRIGHT', x, -2)
	end
end

-- ==============================
-- 인디케이터 공통 빌더 (create_style에서 호출)
-- ==============================
function dodo.UnitframeCreateIndicators(self, unitKey)
	-- 전투 표시 (모든 유닛)
	if COMBAT_KEYS[unitKey] and not self.CombatIndicator then
		local ci = self:CreateTexture(nil, 'OVERLAY')
		ci:SetSize(22, 22)
		ci:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 0)
		ci.PostUpdate = function(element)
			reposition(element.__owner)
		end
		self.CombatIndicator = ci
	end

	-- 휴식 표시 (player only)
	if unitKey == 'player' and not self.RestingIndicator then
		local ri = CreateFrame('Frame', nil, self)
		ri:SetSize(30, 30)
		ri:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 0)

		local tex = ri:CreateTexture(nil, 'ARTWORK')
		tex:SetAtlas('UI-HUD-UnitFrame-Player-Rest-Flipbook')
		tex:SetAllPoints()

		local anim = tex:CreateAnimationGroup()
		anim:SetLooping('REPEAT')
		local fb = anim:CreateAnimation('FlipBook')
		fb:SetDuration(1.5)
		fb:SetFlipBookRows(7)
		fb:SetFlipBookColumns(6)
		fb:SetFlipBookFrames(42)
		fb:SetOrder(1)

		ri.anim = anim
		ri.PostUpdate = function(element, isResting)
			if isResting then element.anim:Play() else element.anim:Stop() end
			reposition(element.__owner)
		end
		self.RestingIndicator = ri
	end

	-- 파티장 표시 (모든 유닛)
	if LEADER_KEYS[unitKey] and not self.LeaderIndicator then
		local li = self:CreateTexture(nil, 'OVERLAY')
		li:SetSize(16, 16)
		li:SetPoint('LEFT', self.nameText, 'RIGHT', 2, 0)
		li:SetAtlas('UI-HUD-UnitFrame-Player-Group-LeaderIcon')
		li.PostUpdate = function(element)
			reposition(element.__owner)
		end
		self.LeaderIndicator = li
	end
end

-- ==============================
-- PLAYER_LOGIN: 초기 DB 상태 적용
-- ==============================
local function apply(frame, dbKey, elemName, default)
	if not frame then return end
	local val = dodoDB and dodoDB[dbKey]
	if val == nil then val = default end
	if val == false then frame:DisableElement(elemName) end
end

local initFrame = CreateFrame('Frame')
initFrame:RegisterEvent('PLAYER_LOGIN')
initFrame:SetScript('OnEvent', function(self, event)
	if event ~= 'PLAYER_LOGIN' then return end
	self:UnregisterEvent('PLAYER_LOGIN')

	-- 전투 표시
	apply(dodo.PlayerFrame, COMBAT_KEYS.player, 'CombatIndicator', COMBAT_DEF.player)
	apply(dodo.TargetFrame, COMBAT_KEYS.target, 'CombatIndicator', COMBAT_DEF.target)
	apply(dodo.FocusFrame,  COMBAT_KEYS.focus,  'CombatIndicator', COMBAT_DEF.focus)
	for i = 1, 5 do apply(_G['dodoBossFrame'..i], COMBAT_KEYS.boss, 'CombatIndicator', COMBAT_DEF.boss) end

	-- 휴식 표시 (player only)
	apply(dodo.PlayerFrame, REST_KEYS.player, 'RestingIndicator', REST_DEF.player)

	-- 파티장 표시
	apply(dodo.PlayerFrame, LEADER_KEYS.player, 'LeaderIndicator', LEADER_DEF.player)
	apply(dodo.TargetFrame, LEADER_KEYS.target, 'LeaderIndicator', LEADER_DEF.target)
	apply(dodo.FocusFrame,  LEADER_KEYS.focus,  'LeaderIndicator', LEADER_DEF.focus)
	for i = 1, 5 do apply(_G['dodoBossFrame'..i], LEADER_KEYS.boss, 'LeaderIndicator', LEADER_DEF.boss) end
end)
