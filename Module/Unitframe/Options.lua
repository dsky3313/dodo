---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame   = CreateFrame
local math_floor    = math.floor
local NineSliceUtil = NineSliceUtil
local _G            = _G

-- ==============================
-- 설정 키 / 기본값
-- ==============================
local POWER_KEYS = {
	player = "unitframePowerPlayer",
	target = "unitframePowerTarget",
	focus  = "unitframePowerFocus",
	boss   = "unitframePowerBoss",
}
local POWER_DEFAULTS = { player = false, target = true, focus = false, boss = true }

local CASTBAR_KEYS = {
	player = "unitframeCastbarPlayer",
	target = "unitframeCastbarTarget",
	focus  = "unitframeCastbarFocus",
	boss   = "unitframeCastbarBoss",
}
local CASTBAR_DEFAULTS = { player = false, target = true, focus = false, boss = true }

local BUFFS_KEYS = {
	player = "unitframeBuffsPlayer",
	target = "unitframeBuffsTarget",
	focus  = "unitframeBuffsFocus",
	boss   = "unitframeBuffsBoss",
}
local BUFFS_DEFAULTS = { player = false, target = true, focus = false, boss = true }

local DEBUFFS_KEYS = {
	player = "unitframeDebuffsPlayer",
	target = "unitframeDebuffsTarget",
	focus  = "unitframeDebuffsFocus",
	boss   = "unitframeDebuffsBoss",
}
local DEBUFFS_DEFAULTS = { player = false, target = false, focus = false, boss = false }

local ABSORB_KEYS = {
	player = "unitframeAbsorbPlayer",
	target = "unitframeAbsorbTarget",
	focus  = "unitframeAbsorbFocus",
}
local ABSORB_DEFAULTS = { player = true, target = false, focus = false }

-- MultiDropDown은 nil을 true(체크)로 해석 — false 기본값 항목 초기화 필요
local FALSE_DEFAULTS = {
	unitframePowerPlayer   = false,
	unitframePowerFocus    = false,
	unitframeCastbarPlayer = false,
	unitframeCastbarFocus  = false,
	unitframeBuffsPlayer   = false,
	unitframeBuffsFocus    = false,
	unitframeAbsorbTarget  = false,
	unitframeAbsorbFocus   = false,
	-- 전투 표시 (player만 기본 true)
	unitframeCombatTarget  = false,
	unitframeCombatFocus   = false,
	unitframeCombatBoss    = false,
	-- 휴식 표시 (player만 기본 true)
	unitframeRestTarget    = false,
	unitframeRestFocus     = false,
	unitframeRestBoss      = false,
	-- 파티장 표시 (player·target 기본 true)
	unitframeLeaderFocus   = false,
	unitframeLeaderBoss    = false,
	-- 약화효과 (모두 기본 false)
	unitframeDebuffsPlayer = false,
	unitframeDebuffsTarget = false,
	unitframeDebuffsFocus  = false,
	unitframeDebuffsBoss   = false,
}

-- ==============================
-- 미리보기 Mixin
-- ==============================
local _preview_ref = nil
local PREVIEW_TABS   = { "player", "target", "focus", "boss" }
local PREVIEW_LABELS = { player = "플레이어", target = "대상", focus = "주시대상", boss = "우두머리" }

local UNIT_W       = { player = 190, target = 190, focus = 120, boss = 150 }
local UNIT_H       = { player = 30,  target = 30,  focus = 16,  boss = 30  }
local POWER_W      = { player = 120, target = 120, focus = 70,  boss = 120 }
local POWER_H_SIZE = 10
local CAST_H       = 16
local CAST_ICON    = 16
local BUFF_SIZE    = 18

local HEALTH_FILL_COLOR = { 0.25, 0.70, 0.25 }

local SIM_COMBAT_KEYS = { player = "unitframeCombatPlayer", target = "unitframeCombatTarget", focus = "unitframeCombatFocus", boss = "unitframeCombatBoss" }
local SIM_COMBAT_DEF  = { player = true,  target = false, focus = false, boss = false }
local SIM_REST_KEYS   = { player = "unitframeRestPlayer" }
local SIM_REST_DEF    = { player = true }
local SIM_LEADER_KEYS = { player = "unitframeLeaderPlayer", target = "unitframeLeaderTarget", focus = "unitframeLeaderFocus", boss = "unitframeLeaderBoss" }
local SIM_LEADER_DEF  = { player = true, target = true, focus = false, boss = false }

local function preview_get(db_keys, defaults, unit)
	local key = db_keys[unit]
	if not key then return false end
	if not dodoDB then return defaults[unit] or false end
	local v = dodoDB[key]
	return v == nil and (defaults[unit] or false) or v
end

local function make_nineslice(parent)
	local ns = CreateFrame('Frame', nil, parent, 'NineSliceCodeTemplate')
	ns:SetPoint('TOPLEFT',     parent, 'TOPLEFT',     -4,  3)
	ns:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT',  7, -6)
	ns:SetFrameLevel(parent:GetFrameLevel() + 3)
	ns:SetScale(0.6)
	NineSliceUtil.ApplyUniqueCornersLayout(ns, 'UI-HUD-ActionBar-Frame')
	return ns
end

dodoUnitframePreviewMixin = {}

dodoUnitframePreviewMixin.GetExtent = function()
	return 210
end

function dodoUnitframePreviewMixin:OnLoad()
	_preview_ref = self
	self._unit   = "player"

	local base = self:GetFrameLevel() + 1

	-- ── 체력 바 ───────────────────────────────────────────
	local hf = CreateFrame('Frame', nil, self)
	hf:SetFrameLevel(base)
	self.hf = hf

	local hBg = hf:CreateTexture(nil, 'BACKGROUND')
	hBg:SetAllPoints()
	hBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

	local hFill = hf:CreateTexture(nil, 'ARTWORK')
	hFill:SetTexture([[Interface\Buttons\WHITE8X8]])
	hFill:SetVertexColor(HEALTH_FILL_COLOR[1], HEALTH_FILL_COLOR[2], HEALTH_FILL_COLOR[3])
	self.hFill = hFill

	local absorbFill = hf:CreateTexture(nil, 'ARTWORK', nil, 1)
	absorbFill:SetTexture([[Interface\RaidFrame\Shield-Fill]])
	self.absorbFill = absorbFill

	make_nineslice(hf)

	local nText = hf:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	nText:SetPoint('BOTTOMLEFT', hf, 'TOPLEFT', 2, 3)
	self.nText = nText

	local hText = hf:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
	hText:SetPoint('RIGHT', hf, 'RIGHT', -5, 0)
	self.hText = hText

	-- ── 자원 바 ───────────────────────────────────────────
	local pf = CreateFrame('Frame', nil, self)
	pf:SetFrameLevel(base + 1)
	self.pf = pf

	local pBg = pf:CreateTexture(nil, 'BACKGROUND')
	pBg:SetPoint('TOPLEFT',     pf, 'TOPLEFT',     -2,  2)
	pBg:SetPoint('BOTTOMRIGHT', pf, 'BOTTOMRIGHT',  6, -7)
	pBg:SetAtlas('UI-HUD-CoolDownManager-Bar-BG')

	local pFill = pf:CreateTexture(nil, 'ARTWORK')
	pFill:SetAtlas('UI-HUD-CoolDownManager-Bar')
	self.pFill = pFill

	-- ── 캐스팅바 ──────────────────────────────────────────
	local cif = CreateFrame('Frame', nil, self)
	cif:SetFrameLevel(base)
	cif:SetSize(CAST_ICON, CAST_H)
	self.cif = cif

	local cIconBg = cif:CreateTexture(nil, 'BACKGROUND')
	cIconBg:SetAllPoints()
	cIconBg:SetColorTexture(0.12, 0.12, 0.12, 0.9)
	make_nineslice(cif)

	local cf = CreateFrame('Frame', nil, self)
	cf:SetFrameLevel(base)
	self.cf = cf

	local cBg = cf:CreateTexture(nil, 'BACKGROUND')
	cBg:SetAllPoints()
	cBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

	local cFill = cf:CreateTexture(nil, 'ARTWORK')
	cFill:SetTexture([[Interface\Buttons\WHITE8X8]])
	cFill:SetVertexColor(1, 0.7, 0)
	self.cFill = cFill
	make_nineslice(cf)

	-- ── 버프 슬롯 ─────────────────────────────────────────
	self.buffFrames = {}
	for i = 1, 5 do
		local bf = CreateFrame('Frame', nil, self)
		bf:SetSize(BUFF_SIZE, BUFF_SIZE)
		bf:SetFrameLevel(base)

		local bg = bf:CreateTexture(nil, 'BACKGROUND')
		bg:SetAllPoints()
		bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

		local bfill = bf:CreateTexture(nil, 'ARTWORK')
		bfill:SetAllPoints()
		bfill:SetAtlas('UI-HUD-ActionBar-IconFrame-Background', false)

		make_nineslice(bf)
		self.buffFrames[i] = bf
	end

	-- ── 소환수 시뮬레이션 (player 탭) ────────────────────────
	local petHf = CreateFrame('Frame', nil, self)
	petHf:SetFrameLevel(base)
	local petBg = petHf:CreateTexture(nil, 'BACKGROUND')
	petBg:SetAllPoints()
	petBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
	local petFill = petHf:CreateTexture(nil, 'ARTWORK')
	petFill:SetTexture([[Interface\Buttons\WHITE8X8]])
	petFill:SetVertexColor(HEALTH_FILL_COLOR[1], HEALTH_FILL_COLOR[2], HEALTH_FILL_COLOR[3])
	self.petFill = petFill
	make_nineslice(petHf)
	self.petHf = petHf

	-- ── 대상의 대상 시뮬레이션 (target 탭) ─────────────────
	local totHf = CreateFrame('Frame', nil, self)
	totHf:SetFrameLevel(base)
	local totBg = totHf:CreateTexture(nil, 'BACKGROUND')
	totBg:SetAllPoints()
	totBg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
	local totFill = totHf:CreateTexture(nil, 'ARTWORK')
	totFill:SetTexture([[Interface\Buttons\WHITE8X8]])
	totFill:SetVertexColor(HEALTH_FILL_COLOR[1], HEALTH_FILL_COLOR[2], HEALTH_FILL_COLOR[3])
	self.totFill = totFill
	make_nineslice(totHf)
	self.totHf = totHf

	-- ── 인디케이터 시뮬레이션 ─────────────────────────────
	-- 전투: oUF combatindicator.lua 기본 atlas 동일
	local combatSim = self.hf:CreateTexture(nil, 'OVERLAY', nil, 4)
	combatSim:SetSize(22, 22)
	combatSim:SetAtlas('UI-HUD-UnitFrame-Player-CombatIcon')
	self.combatSim = combatSim

	-- 휴식: Indicator.lua 동일 — 플립북 애니메이션
	local restSim = CreateFrame('Frame', nil, self)
	restSim:SetSize(30, 30)
	local restSimTex = restSim:CreateTexture(nil, 'ARTWORK')
	restSimTex:SetAtlas('UI-HUD-UnitFrame-Player-Rest-Flipbook')
	restSimTex:SetAllPoints()
	local restSimAnim = restSimTex:CreateAnimationGroup()
	restSimAnim:SetLooping('REPEAT')
	local restSimFB = restSimAnim:CreateAnimation('FlipBook')
	restSimFB:SetDuration(1.5)
	restSimFB:SetFlipBookRows(7)
	restSimFB:SetFlipBookColumns(6)
	restSimFB:SetFlipBookFrames(42)
	restSimFB:SetOrder(1)
	restSim.anim = restSimAnim
	self.restSim = restSim

	-- 파티장: oUF leaderindicator.lua 기본 atlas 동일, hf 위에 렌더링
	local leaderSim = self.hf:CreateTexture(nil, 'OVERLAY', nil, 4)
	leaderSim:SetSize(16, 16)
	leaderSim:SetAtlas('UI-HUD-UnitFrame-Player-Group-LeaderIcon')
	self.leaderSim = leaderSim

	self:Update()
end

function dodoUnitframePreviewMixin:OnTabSelected(tabIndex)
	self._unit = PREVIEW_TABS[tabIndex] or "player"
end

function dodoUnitframePreviewMixin:Update()
	local unit = self._unit or "player"
	local W    = self:GetWidth()
	if not W or W <= 0 then return end

	local hW = UNIT_W[unit] or 190
	local hH = UNIT_H[unit] or 30
	local pW = POWER_W[unit] or 120

	local pEnabled = preview_get(POWER_KEYS,   POWER_DEFAULTS,   unit)
	local cEnabled = preview_get(CASTBAR_KEYS, CASTBAR_DEFAULTS, unit)
	local bEnabled = preview_get(BUFFS_KEYS,   BUFFS_DEFAULTS,   unit)
	local aEnabled = ABSORB_KEYS[unit] and preview_get(ABSORB_KEYS, ABSORB_DEFAULTS, unit) or false

	local cast_gap = 22
	local off_y    = 60
	local hx       = math_floor((W - hW) / 2)

	-- ── 체력 바 ───────────────────────────────────────────
	self.hf:ClearAllPoints()
	self.hf:SetPoint('TOPLEFT', self, 'TOPLEFT', hx, -(32 + off_y))
	self.hf:SetSize(hW, hH)
	self.hf:Show()

	self.hFill:ClearAllPoints()
	self.hFill:SetPoint('TOPLEFT',    self.hf, 'TOPLEFT',    0, 0)
	self.hFill:SetPoint('BOTTOMLEFT', self.hf, 'BOTTOMLEFT', 0, 0)
	self.hFill:SetWidth(math_floor(hW * 0.7))

	if aEnabled then
		self.absorbFill:ClearAllPoints()
		self.absorbFill:SetPoint('TOPLEFT',    self.hFill, 'TOPRIGHT',    0, 0)
		self.absorbFill:SetPoint('BOTTOMLEFT', self.hFill, 'BOTTOMRIGHT', 0, 0)
		self.absorbFill:SetWidth(math_floor(hW * 0.12))
		self.absorbFill:Show()
	else
		self.absorbFill:Hide()
	end

	self.nText:SetText(PREVIEW_LABELS[unit] or unit)
	if unit ~= "focus" then
		self.hText:SetText("70K | 70.0%")
		self.hText:Show()
	else
		self.hText:Hide()
	end

	-- ── 자원 바 ───────────────────────────────────────────
	if pEnabled then
		self.pf:ClearAllPoints()
		self.pf:SetPoint('TOPRIGHT', self.hf, 'BOTTOMRIGHT', -5, -2)
		self.pf:SetSize(pW, POWER_H_SIZE)
		self.pf:Show()

		self.pFill:ClearAllPoints()
		self.pFill:SetPoint('TOPLEFT',    self.pf, 'TOPLEFT',    0, 0)
		self.pFill:SetPoint('BOTTOMLEFT', self.pf, 'BOTTOMLEFT', 0, 0)
		self.pFill:SetWidth(math_floor(pW * 0.6))
	else
		self.pf:Hide()
	end

	-- ── 캐스팅바 ──────────────────────────────────────────
	if cEnabled then
		local cW = hW - CAST_ICON - 6
		self.cif:ClearAllPoints()
		self.cif:SetPoint('TOPLEFT', self.hf, 'BOTTOMLEFT', 0, -(cast_gap - CAST_H / 2))
		self.cif:Show()

		self.cf:ClearAllPoints()
		self.cf:SetPoint('TOPLEFT', self.cif, 'TOPRIGHT', 6, 0)
		self.cf:SetSize(cW, CAST_H)
		self.cf:Show()

		self.cFill:ClearAllPoints()
		self.cFill:SetPoint('TOPLEFT',    self.cf, 'TOPLEFT',    0, 0)
		self.cFill:SetPoint('BOTTOMLEFT', self.cf, 'BOTTOMLEFT', 0, 0)
		self.cFill:SetWidth(math_floor(cW * 0.5))
	else
		self.cif:Hide()
		self.cf:Hide()
	end

	-- ── 버프 ──────────────────────────────────────────────
	if bEnabled then
		for i = 1, 5 do
			self.buffFrames[i]:ClearAllPoints()
			self.buffFrames[i]:SetPoint('BOTTOMRIGHT', self.hf, 'TOPRIGHT', -(i - 1) * (BUFF_SIZE + 1), 4)
			self.buffFrames[i]:Show()
		end
	else
		for i = 1, 5 do self.buffFrames[i]:Hide() end
	end

	-- ── 소환수 (플레이어 탭만) ──────────────────────────────
	if unit == 'player' then
		self.petHf:ClearAllPoints()
		self.petHf:SetPoint('TOPLEFT', self.hf, 'BOTTOMLEFT', 0, -5)
		self.petHf:SetSize(100, 16)
		self.petHf:Show()
		self.petFill:ClearAllPoints()
		self.petFill:SetPoint('TOPLEFT',    self.petHf, 'TOPLEFT',    0, 0)
		self.petFill:SetPoint('BOTTOMLEFT', self.petHf, 'BOTTOMLEFT', 0, 0)
		self.petFill:SetWidth(math_floor(100 * 0.7))
	else
		self.petHf:Hide()
	end

	-- ── 대상의 대상 (대상 탭만) ─────────────────────────────
	if unit == 'target' then
		self.totHf:ClearAllPoints()
		self.totHf:SetPoint('TOPLEFT', self.hf, 'BOTTOMRIGHT', -100, -36)
		self.totHf:SetSize(100, 16)
		self.totHf:Show()
		self.totFill:ClearAllPoints()
		self.totFill:SetPoint('TOPLEFT',    self.totHf, 'TOPLEFT',    0, 0)
		self.totFill:SetPoint('BOTTOMLEFT', self.totHf, 'BOTTOMLEFT', 0, 0)
		self.totFill:SetWidth(math_floor(100 * 0.7))
	else
		self.totHf:Hide()
	end

	-- ── 인디케이터 (ETC/Indicator.lua reposition() 동일 로직) ───
	local sim_combat = preview_get(SIM_COMBAT_KEYS, SIM_COMBAT_DEF, unit)
	local sim_rest   = (unit == 'player') and preview_get(SIM_REST_KEYS, SIM_REST_DEF, unit) or false
	local sim_leader = preview_get(SIM_LEADER_KEYS, SIM_LEADER_DEF, unit)

	local ix = 2

	if sim_leader then
		self.leaderSim:ClearAllPoints()
		self.leaderSim:SetPoint('LEFT', self.nText, 'RIGHT', ix, 0)
		self.leaderSim:Show()
		ix = ix + 18  -- 16 + gap 2
	else
		self.leaderSim:Hide()
	end

	if sim_rest then
		self.restSim:ClearAllPoints()
		self.restSim:SetPoint('BOTTOMLEFT', self.nText, 'BOTTOMRIGHT', ix, 0)
		self.restSim:Show()
		self.restSim.anim:Play()
		ix = ix + 32  -- 30 + gap 2
	else
		self.restSim:Hide()
		self.restSim.anim:Stop()
	end

	if sim_combat then
		self.combatSim:ClearAllPoints()
		self.combatSim:SetPoint('BOTTOMLEFT', self.nText, 'BOTTOMRIGHT', ix, -2)
		self.combatSim:Show()
	else
		self.combatSim:Hide()
	end
end

local function refresh_preview()
	if _preview_ref and _preview_ref.Update then
		_preview_ref:Update()
	end
end

-- ==============================
-- 유닛별 업데이트 함수
-- ==============================
local function apply_power(unit)
	if unit == "boss" then
		for i = 1, 5 do
			local f = _G["dodoBossFrame" .. i]
			if f and f.Power then f.Power:ForceUpdate() end
		end
	else
		local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
		local f = map[unit]
		if f and f.Power then f.Power:ForceUpdate() end
	end
end

local function apply_castbar(unit, enabled)
	if unit == "boss" then
		for i = 1, 5 do
			local f = _G["dodoBossFrame" .. i]
			if f and f.Castbar then
				if enabled then f:EnableElement("Castbar") else f:DisableElement("Castbar") end
			end
		end
	else
		local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
		local f = map[unit]
		if f and f.Castbar then
			if enabled then f:EnableElement("Castbar") else f:DisableElement("Castbar") end
		end
	end
end

local function apply_buffs(unit, enabled)
	if unit == "boss" then
		for i = 1, 5 do
			local f = _G["dodoBossFrame" .. i]
			if f and f.Buffs then
				if enabled then f.Buffs:Show() else f.Buffs:Hide() end
			end
		end
	else
		local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
		local f = map[unit]
		if f and f.Buffs then
			if enabled then f.Buffs:Show() else f.Buffs:Hide() end
		end
	end
end

local function apply_debuffs(unit, enabled)
	if unit == "boss" then
		for i = 1, 5 do
			local f = _G["dodoBossFrame" .. i]
			if f and f.Debuffs then
				if enabled then f.Debuffs:Show() else f.Debuffs:Hide() end
			end
		end
	else
		local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
		local f = map[unit]
		if f and f.Debuffs then
			if enabled then f.Debuffs:Show() else f.Debuffs:Hide() end
		end
	end
end

local function apply_absorb(unit)
	local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
	local f = map[unit]
	if f and f.Health then f.Health:ForceUpdate() end
end

-- ==============================
-- /dd 설정 등록
-- ==============================
dodo.RegisterOption("유닛프레임 (미완 ^^;)", function(category)
	-- false가 기본인 항목 초기화 (nil → MultiDropDown이 체크로 오인 방지)
	if dodoDB then
		for key, val in pairs(FALSE_DEFAULTS) do
			if dodoDB[key] == nil then dodoDB[key] = val end
		end
	end

	-- 마스터 토글
	local _, master_setting = dodo.UI:SettingsCheckbox(category, "enableUnitframeModule", "유닛프레임 활성화",
		"oUF 커스텀 유닛프레임 모듈(플레이어·대상·주시대상·우두머리·펫) 전체를 활성화/비활성화합니다.",
		true, function(val)
			if dodoDB then dodoDB.enableUnitframeModule = val end
			if dodo.UpdateUnitframeModuleState then dodo.UpdateUnitframeModuleState() end
			refresh_preview()
		end)

	local _sub = {}
	local function T(v) if v then _sub[#_sub+1] = v end return v end

	-- 미리보기
	T(dodo.UI:SettingsTabbedPreview(category, { "플레이어", "대상", "주시대상", "우두머리" }, dodoUnitframePreviewMixin))

	-- 구성 요소 섹션
	T(dodo.UI:SettingsSectionHeader(category, "구성 요소"))

	-- 자원 바
	local power_init = T(dodo.UI:SettingsMultiDropDown(category, "자원 바", {
		{ text = "플레이어", key = POWER_KEYS.player },
		{ text = "대상",     key = POWER_KEYS.target },
		{ text = "주시대상", key = POWER_KEYS.focus },
		{ text = "우두머리", key = POWER_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(POWER_KEYS) do
			if k == key then apply_power(unit) end
		end
		refresh_preview()
	end))
	-- PanelInitializer는 GetSetting 없음 → SetParentInitializer 내부 크래시 방지
	if power_init then power_init.GetSetting = function() return nil end end

	local mana_init = dodo.UI:SettingsCheckbox(category, "unitframePowerOnlyMana", "2차자원이 마나일 경우에만 활성화",
		"2차자원이 마나일 때만 자원 바를 표시합니다.\n해당 클래스 : 드루이드, 주술사, 암흑사제",
		true, function(val)
			if dodoDB then dodoDB.unitframePowerOnlyMana = val end
			apply_power("player")
		end)
	if mana_init and power_init and mana_init.SetParentInitializer then
		mana_init:SetParentInitializer(power_init)
	end
	T(mana_init)

	-- 캐스팅바
	T(dodo.UI:SettingsMultiDropDown(category, "캐스팅바", {
		{ text = "플레이어", key = CASTBAR_KEYS.player },
		{ text = "대상",     key = CASTBAR_KEYS.target },
		{ text = "주시대상", key = CASTBAR_KEYS.focus },
		{ text = "우두머리", key = CASTBAR_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		local unit_map = {
			[CASTBAR_KEYS.player] = "player",
			[CASTBAR_KEYS.target] = "target",
			[CASTBAR_KEYS.focus]  = "focus",
			[CASTBAR_KEYS.boss]   = "boss",
		}
		local unit = unit_map[key]
		if unit then apply_castbar(unit, selected) end
		refresh_preview()
	end))

	-- 보호막
	T(dodo.UI:SettingsMultiDropDown(category, "보호막 표시", {
		{ text = "플레이어", key = ABSORB_KEYS.player },
		{ text = "대상",     key = ABSORB_KEYS.target },
		{ text = "주시대상", key = ABSORB_KEYS.focus },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(ABSORB_KEYS) do
			if k == key then apply_absorb(unit) end
		end
		refresh_preview()
	end))

	-- 강화 및 약화 효과 섹션
	T(dodo.UI:SettingsSectionHeader(category, "강화 및 약화 효과"))

	-- 강화효과
	T(dodo.UI:SettingsMultiDropDown(category, "강화효과", {
		{ text = "플레이어", key = BUFFS_KEYS.player },
		{ text = "대상",     key = BUFFS_KEYS.target },
		{ text = "주시대상", key = BUFFS_KEYS.focus },
		{ text = "우두머리", key = BUFFS_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(BUFFS_KEYS) do
			if k == key then apply_buffs(unit, selected) end
		end
		refresh_preview()
	end))

	-- 약화효과
	T(dodo.UI:SettingsMultiDropDown(category, "약화효과", {
		{ text = "플레이어", key = DEBUFFS_KEYS.player },
		{ text = "대상",     key = DEBUFFS_KEYS.target },
		{ text = "주시대상", key = DEBUFFS_KEYS.focus },
		{ text = "우두머리", key = DEBUFFS_KEYS.boss },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		for unit, k in pairs(DEBUFFS_KEYS) do
			if k == key then apply_debuffs(unit, selected) end
		end
	end))

	-- 추가기능 섹션
	T(dodo.UI:SettingsSectionHeader(category, "추가기능"))

	local function toggle(frame, elem, selected)
		if not frame then return end
		if selected then frame:EnableElement(elem) else frame:DisableElement(elem) end
	end

	-- 파티장 표시
	T(dodo.UI:SettingsMultiDropDown(category, "파티장 표시", {
		{ text = "플레이어", key = "unitframeLeaderPlayer" },
		{ text = "대상",     key = "unitframeLeaderTarget" },
		{ text = "주시대상", key = "unitframeLeaderFocus"  },
		{ text = "우두머리", key = "unitframeLeaderBoss"   },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		local map = { unitframeLeaderPlayer = dodo.PlayerFrame, unitframeLeaderTarget = dodo.TargetFrame, unitframeLeaderFocus = dodo.FocusFrame }
		if map[key] then
			toggle(map[key], 'LeaderIndicator', selected)
		elseif key == "unitframeLeaderBoss" then
			for i = 1, 5 do toggle(_G['dodoBossFrame'..i], 'LeaderIndicator', selected) end
		end
		refresh_preview()
	end))
	
	-- 휴식 표시
	T(dodo.UI:SettingsMultiDropDown(category, "휴식 표시", {
		{ text = "플레이어", key = "unitframeRestPlayer" },
		{ text = "대상",     key = "unitframeRestTarget" },
		{ text = "주시대상", key = "unitframeRestFocus"  },
		{ text = "우두머리", key = "unitframeRestBoss"   },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		if key == "unitframeRestPlayer" then toggle(dodo.PlayerFrame, 'RestingIndicator', selected) end
		refresh_preview()
	end))

	-- 전투 표시
	T(dodo.UI:SettingsMultiDropDown(category, "전투 표시", {
		{ text = "플레이어", key = "unitframeCombatPlayer" },
		{ text = "대상",     key = "unitframeCombatTarget" },
		{ text = "주시대상", key = "unitframeCombatFocus"  },
		{ text = "우두머리", key = "unitframeCombatBoss"   },
	}, function(key, selected)
		if dodoDB then dodoDB[key] = selected end
		local map = { unitframeCombatPlayer = dodo.PlayerFrame, unitframeCombatTarget = dodo.TargetFrame, unitframeCombatFocus = dodo.FocusFrame }
		if map[key] then
			toggle(map[key], 'CombatIndicator', selected)
		elseif key == "unitframeCombatBoss" then
			for i = 1, 5 do toggle(_G['dodoBossFrame'..i], 'CombatIndicator', selected) end
		end
		refresh_preview()
	end))

	local function _shown() return master_setting:GetValue() end
	for _, v in ipairs(_sub) do if v.AddShownPredicate then v:AddShownPredicate(_shown) end end

end, 2)
