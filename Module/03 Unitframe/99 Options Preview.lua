---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame   = CreateFrame
local math_floor    = math.floor
local NineSliceUtil = NineSliceUtil
local _G            = _G

local _preview_ref   = nil
local _tab_change_fn = nil

local PREVIEW_TABS   = { "player", "target", "focus", "boss", "party" }
local PREVIEW_LABELS = { player = "플레이어", target = "대상", focus = "주시대상", boss = "우두머리 1" }

local UNIT_W       = { player = 190, target = 190, focus = 120, boss = 150 }
local UNIT_H       = { player = 30,  target = 30,  focus = 16,  boss = 30  }
local POWER_W      = { player = 120, target = 120, focus = 70,  boss = 120 }
local POWER_H_SIZE = 10
local CAST_H       = 16
local CAST_ICON    = 16
local BUFF_SIZE    = 20
local BUFF_ICONS   = { 132341, 132362, 132352, 132351, 613534 }
local DEBUFF_ICONS = { 237517, 136105, 132344, 132090, 237553 }

local HEALTH_FILL_COLOR = { 0.25, 0.70, 0.25 }

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
	return 250
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
	pf:SetFrameLevel(base + 5)
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

	local cIcon = cif:CreateTexture(nil, 'ARTWORK')
	cIcon:SetAllPoints()
	cIcon:SetTexture(132355)
	cIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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

	local cText = cf:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
	cText:SetPoint('LEFT', cf, 'LEFT', 5, 0)
	cText:SetPoint('RIGHT', cf, 'RIGHT', -40, 0)
	cText:SetJustifyH('LEFT')
	local fontPath, _, fontFlags = cText:GetFont()
	cText:SetFont(fontPath, 9, fontFlags)
	cText:SetText("필사의 일격")

	local cTime = cf:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
	cTime:SetPoint('RIGHT', cf, 'RIGHT', -5, 0)
	cTime:SetJustifyH('RIGHT')
	cTime:SetText("0.4")

	-- ── 버프 슬롯 ─────────────────────────────────────────
	self.buffFrames = {}
	for i = 1, 5 do
		local bf = CreateFrame('Frame', nil, self)
		bf:SetSize(BUFF_SIZE, BUFF_SIZE)
		bf:SetFrameLevel(base)

		local icon = bf:CreateTexture(nil, 'ARTWORK')
		icon:SetAllPoints()
		icon:SetTexture(BUFF_ICONS[i])

		self.buffFrames[i] = bf
	end

	-- ── 디버프 슬롯 ───────────────────────────────────────
	self.debuffFrames = {}
	for i = 1, 5 do
		local df = CreateFrame('Frame', nil, self)
		df:SetSize(BUFF_SIZE, BUFF_SIZE)
		df:SetFrameLevel(base)

		local icon = df:CreateTexture(nil, 'ARTWORK')
		icon:SetAllPoints()
		icon:SetTexture(DEBUFF_ICONS[i])

		self.debuffFrames[i] = df
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
	local petName = petHf:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	petName:SetPoint('BOTTOMLEFT', petHf, 'TOPLEFT', 2, 3)
	petName:SetText("소환수")
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
	local totName = totHf:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	totName:SetPoint('BOTTOMLEFT', totHf, 'TOPLEFT', 2, 3)
	totName:SetText("대상의 대상")
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

	-- ── 순정 파티프레임 비주얼 목업 ─────────────────────────
	-- CompactUnitFrameTemplate 직접 사용 불가 (taint) → 동일 atlas/texture 정적 목업
	local cmock = {}
	local cmf = CreateFrame("Frame", nil, self)
	cmf:SetFrameLevel(base)

	-- 배경: CompactUnitFrame.xml background atlas
	local cmBg = cmf:CreateTexture(nil, "BACKGROUND")
	cmBg:SetAtlas("raidframe-hp-bg-white", false)
	cmBg:SetHorizTile(true) cmBg:SetVertTile(true)
	cmBg:SetAllPoints()
	cmock.bg = cmBg

	-- 체력바 fill: RaidFrame-Hp-Fill atlas (Update에서 SetWidth 꽉 채움)
	local cmFill = cmf:CreateTexture(nil, "BORDER")
	cmFill:SetAtlas("RaidFrame-Hp-Fill", false)
	cmFill:SetHorizTile(true) cmFill:SetVertTile(true)
	cmFill:SetPoint("TOPLEFT",    cmf, "TOPLEFT",    1, -1)
	cmFill:SetPoint("BOTTOMLEFT", cmf, "BOTTOMLEFT", 1,  1)
	cmock.fill = cmFill

	-- 초과보호막: Overshield.lua 동일 — Interface\RaidFrame\Shield-Fill, 흰색 0.6α, 오른쪽 앵커
	local cmShield = cmf:CreateTexture(nil, "BORDER", nil, 1)
	cmShield:SetTexture([[Interface\RaidFrame\Shield-Fill]])
	cmShield:SetVertexColor(1, 1, 1, 0.6)
	cmShield:SetPoint("TOPRIGHT",    cmf, "TOPRIGHT",    -1, -1)
	cmShield:SetPoint("BOTTOMRIGHT", cmf, "BOTTOMRIGHT", -1,  1)
	cmock.shield = cmShield

	-- 역할 아이콘 (Update에서 GetMicroIconForRole로 atlas 설정 및 앵커 조정)
	local cmRole = cmf:CreateTexture(nil, "ARTWORK", nil, 1)
	cmRole:SetSize(14, 14)
	cmRole:Hide()
	cmock.roleIcon = cmRole

	-- 이름: GameFontHighlightSmall, LEFT 정렬 (Update에서 역할아이콘 오른쪽에 앵커됨)
	local cmName = cmf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	cmName:SetPoint("LEFT", cmf, "LEFT", 4, 0)
	cmName:SetJustifyH("LEFT")
	cmName:SetText("파티원")
	cmock.nameText = cmName

	-- 파티장 아이콘: Leader.lua Config 기준 TOPLEFT(3,8), 16x16
	local cmLeader = cmf:CreateTexture(nil, "OVERLAY", nil, 2)
	cmLeader:SetSize(16, 16)
	cmLeader:SetTexture([[Interface\GroupFrame\UI-Group-LeaderIcon]])
	cmLeader:SetPoint("TOPLEFT", cmf, "TOPLEFT", 3, 8)
	cmock.leaderIcon = cmLeader

	cmf:Hide()
	cmock.hf = cmf
	self.partyMock = cmock

	self:Update()
end

function dodoUnitframePreviewMixin:OnTabSelected(tabIndex)
	self._unit = PREVIEW_TABS[tabIndex] or "player"
	if _tab_change_fn then _tab_change_fn(self._unit) end
end

function dodoUnitframePreviewMixin:Update()
	local unit = self._unit or "player"
	local W    = self:GetWidth()
	if not W or W <= 0 then return end

	-- ── 파티 탭 ──────────────────────────────────────────
	if unit == "party" then
		self.hf:Hide() self.pf:Hide() self.cif:Hide() self.cf:Hide()
		self.petHf:Hide() self.totHf:Hide()
		self.combatSim:Hide() self.restSim:Hide() self.leaderSim:Hide()
		for i = 1, 5 do self.buffFrames[i]:Hide() self.debuffFrames[i]:Hide() end

		local mock = self.partyMock
		local BAR_W = 144
		local BAR_H = 54
		local ox    = math_floor((W - BAR_W) / 2)
		local oy    = -math_floor((self:GetHeight() - BAR_H) / 2)

		mock.hf:ClearAllPoints()
		mock.hf:SetPoint("TOPLEFT", self, "TOPLEFT", ox, oy)
		mock.hf:SetSize(BAR_W, BAR_H)

		-- bg 색상
		if COMPACT_UNIT_FRAME_FRIENDLY_HEALTH_COLOR_BG then
			local r, g, b = COMPACT_UNIT_FRAME_FRIENDLY_HEALTH_COLOR_BG:GetRGB()
			mock.bg:SetVertexColor(r, g, b)
		end

		-- 체력바 fill: 클래스 색상, 꽉 채움
		local _, classToken = UnitClass("player")
		local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
		if classColor then
			mock.fill:SetVertexColor(classColor.r, classColor.g, classColor.b)
		elseif COMPACT_UNIT_FRAME_FRIENDLY_HEALTH_COLOR then
			local r, g, b = COMPACT_UNIT_FRAME_FRIENDLY_HEALTH_COLOR:GetRGB()
			mock.fill:SetVertexColor(r, g, b)
		end
		mock.fill:SetWidth(BAR_W - 2)

		-- 초과보호막 오버레이: Overshield.lua 동일 — 오른쪽 15% 흰색
		local use_shield = not dodoDB or dodoDB.enablePartyframeOvershield ~= false
		if use_shield then
			mock.shield:SetWidth(math_floor(BAR_W * 0.15))
			mock.shield:Show()
		else
			mock.shield:Hide()
		end

		-- 역할 아이콘: 소스 기준 TOPLEFT(3,-2), 17×17
		-- 숨길 때 size(1,17) — Legacy 레이아웃에서 이름 앵커 기준점으로 사용됨
		local specIdx  = GetSpecialization and GetSpecialization() or nil
		local specRole = specIdx and GetSpecializationRole and GetSpecializationRole(specIdx) or "NONE"
		local roleAtlas = GetMicroIconForRole and GetMicroIconForRole(specRole)
		mock.roleIcon:ClearAllPoints()
		mock.roleIcon:SetPoint("TOPLEFT", mock.hf, "TOPLEFT", 3, -2)
		if roleAtlas and roleAtlas ~= "" then
			mock.roleIcon:SetAtlas(roleAtlas)
			mock.roleIcon:SetSize(17, 17)
			mock.roleIcon:Show()
		else
			mock.roleIcon:Hide()
			mock.roleIcon:SetSize(1, 17)
		end

		-- 이름: Legacy 레이아웃 기준
		-- TOPLEFT = roleIcon.TOPRIGHT(0,-1), TOPRIGHT = frame.TOPRIGHT(-3,-3)
		mock.nameText:ClearAllPoints()
		mock.nameText:SetPoint("TOPLEFT", mock.roleIcon, "TOPRIGHT", 0, -1)
		mock.nameText:SetPoint("TOPRIGHT", mock.hf, "TOPRIGHT", -3, -3)
		mock.nameText:SetJustifyH("LEFT")

		-- 파티장 아이콘
		local use_leader = not dodoDB or dodoDB.enablePartyframeLeader ~= false
		if use_leader then mock.leaderIcon:Show() else mock.leaderIcon:Hide() end

		mock.hf:Show()
		return
	end

	-- 파티 탭 아닐 때 숨기기
	self.partyMock.hf:Hide()

	local UF_DB = dodo.UF_DB_KEYS
	local UF_DF = dodo.UF_DEFAULTS
	if not UF_DB or not UF_DF then return end

	local hW = UNIT_W[unit] or 190
	local hH = UNIT_H[unit] or 30
	local pW = POWER_W[unit] or 120

	local pEnabled = preview_get(UF_DB.power,   UF_DF.power,   unit)
	local cEnabled = preview_get(UF_DB.castbar, UF_DF.castbar, unit)
	local bEnabled = preview_get(UF_DB.buffs,   UF_DF.buffs,   unit)
	local aEnabled = UF_DB.absorb[unit] and preview_get(UF_DB.absorb, UF_DF.absorb, unit) or false

	local cast_gap = 22
	local off_y    = 80
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
		self.pf:SetPoint('RIGHT', self.hf, 'BOTTOMRIGHT', -5, -2)
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
		local cif_y = -(cast_gap - CAST_H / 2)
		if unit == 'player' then cif_y = cif_y - 30 end
		self.cif:ClearAllPoints()
		self.cif:SetPoint('TOPLEFT', self.hf, 'BOTTOMLEFT', 0, cif_y)
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

	-- ── 디버프 ────────────────────────────────────────────
	local dEnabled = preview_get(UF_DB.debuffs, UF_DF.debuffs, unit)
	if dEnabled then
		for i = 1, 5 do
			self.debuffFrames[i]:ClearAllPoints()
			self.debuffFrames[i]:SetPoint('BOTTOMRIGHT', self.hf, 'TOPRIGHT', -(i - 1) * (BUFF_SIZE + 1), 26)
			self.debuffFrames[i]:Show()
		end
	else
		for i = 1, 5 do self.debuffFrames[i]:Hide() end
	end

	-- ── 소환수 (플레이어 탭만) ──────────────────────────────
	if unit == 'player' then
		self.petHf:ClearAllPoints()
		self.petHf:SetPoint('TOPLEFT', self.hf, 'BOTTOMLEFT', 0, -20)
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
		self.totHf:SetPoint('TOPLEFT', self.hf, 'BOTTOMRIGHT', -100, -50)
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
	local sim_combat = preview_get(UF_DB.combat, UF_DF.combat, unit)
	local sim_rest   = (unit == 'player') and preview_get(UF_DB.rest, UF_DF.rest, unit) or false
	local sim_leader = preview_get(UF_DB.leader, UF_DF.leader, unit)

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
dodo.UnitframeRefreshPreview = refresh_preview

function dodo.UnitframeSetTabChangeFn(fn)
	_tab_change_fn = fn
end

function dodo.UnitframeGetPreviewUnit()
	return (_preview_ref and _preview_ref._unit) or "player"
end
