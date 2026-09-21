-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local C_ClassColor    = C_ClassColor
local C_CurveUtil     = C_CurveUtil
local CreateFrame     = CreateFrame
local Enum            = Enum
local ipairs          = ipairs
local C_Spell         = C_Spell
local C_Timer         = C_Timer
local GetTime         = GetTime
local IsSpellKnown    = IsSpellKnown
local issecretvalue   = issecretvalue or function() return false end
local math_max        = math.max
local math_min        = math.min
local NineSliceUtil   = NineSliceUtil
local pairs           = pairs
local select          = select
local UnitCastingDuration  = UnitCastingDuration
local UnitCastingInfo      = UnitCastingInfo
local UnitChannelDuration  = UnitChannelDuration
local UnitChannelInfo      = UnitChannelInfo
local UnitClass            = UnitClass
local UnitShouldDisplaySpellTargetName = UnitShouldDisplaySpellTargetName
local UnitSpellTargetClass = UnitSpellTargetClass
local UnitSpellTargetName  = UnitSpellTargetName
local _G = _G

-- ==============================
-- 설정 테이블
-- ==============================
local CASTBAR_UNITS = {
	player = true, target = true, focus = true, boss = true,
}

local CASTBAR_DB_KEYS  = dodo.UF_DB_KEYS.castbar
local CASTBAR_DEFAULTS = dodo.UF_DEFAULTS.castbar

local function is_castbar_enabled(unit)
	local dbKey = CASTBAR_DB_KEYS[unit]
	if not dbKey then return false end
	if not dodoDB then return CASTBAR_DEFAULTS[unit] or false end
	local val = dodoDB[dbKey]
	if val == nil then return CASTBAR_DEFAULTS[unit] or false end
	return val
end

-- ==============================
-- 차단 스킬
-- ==============================
local KICK_SPELLS = {
	WARRIOR     = { 6552 },           -- Pummel
	PALADIN     = { 96231 },          -- Rebuke
	HUNTER      = { 147362, 187707 }, -- Counter Shot, Muzzle
	ROGUE       = { 1766 },           -- Kick
	DEATHKNIGHT = { 47528 },          -- Mind Freeze
	SHAMAN      = { 57994 },          -- Wind Shear
	MAGE        = { 2139 },           -- Counterspell
	WARLOCK     = { 19647 },          -- Spell Lock
	MONK        = { 116705 },         -- Spear Hand Strike
	DRUID       = { 106839 },         -- Skull Bash
	DEMONHUNTER = { 183752 },         -- Disrupt
	EVOKER      = { 351338 },         -- Quell
}
local kick_spell_id = nil

local function get_kick_spell()
	if kick_spell_id then return kick_spell_id end
	local cls = select(2, UnitClass("player"))
	local list = KICK_SPELLS[cls]
	if not list then return nil end
	for _, id in ipairs(list) do
		if not IsSpellKnown or IsSpellKnown(id) then
			kick_spell_id = id; return id
		end
	end
	return nil
end

local spellWatcher = CreateFrame("Frame")
spellWatcher:RegisterEvent("SPELLS_CHANGED")
spellWatcher:SetScript("OnEvent", function() kick_spell_id = nil end)

-- ==============================
-- 캐스팅바 공통 빌더
-- ==============================
function dodo.UnitframeCreateCastbar(self, uWidth, unit)
	if not CASTBAR_UNITS[unit] then return end
	if self.Castbar then return end

	local castbar = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
	castbar:SetSize(uWidth - 22, 16)
	castbar._kick_bar_w = uWidth - 22
	castbar:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	castbar:SetStatusBarColor(1, 0.7, 0)

	castbar.timeToHold = 0.5
	castbar.hideTradeSkills = true
	castbar.smoothing = Enum.StatusBarInterpolation.ExponentialEaseOut

	-- 배경
	castbar.bg = castbar:CreateTexture(nil, 'BACKGROUND')
	castbar.bg:SetAllPoints()
	castbar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

	-- 테두리 (NineSlice)
	castbar.NineSlice = CreateFrame('Frame', nil, castbar, 'NineSliceCodeTemplate')
	castbar.NineSlice:SetPoint('TOPLEFT',     castbar, 'TOPLEFT',     -4,  3)
	castbar.NineSlice:SetPoint('BOTTOMRIGHT', castbar, 'BOTTOMRIGHT',  7, -6)
	castbar.NineSlice:SetFrameLevel(castbar:GetFrameLevel() + 3)
	castbar.NineSlice:SetScale(0.6)
	NineSliceUtil.ApplyUniqueCornersLayout(castbar.NineSlice, 'UI-HUD-ActionBar-Frame')

	-- 아이콘
	local icon = castbar:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(16, 16)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	castbar.Icon = icon

	local health_ref = self.Health
	local function reanchor_icon()
		local iy = (unit == 'player' and UnitExists('pet')) and -52 or -22
		icon:ClearAllPoints()
		icon:SetPoint('LEFT', health_ref, 'BOTTOMLEFT', 0, iy)
	end
	reanchor_icon()

	if unit == 'player' then
		local petWatcher = CreateFrame('Frame')
		petWatcher:RegisterEvent('UNIT_PET')
		petWatcher:SetScript('OnEvent', function(_, _, unitToken)
			if unitToken == 'player' then reanchor_icon() end
		end)
	end

	-- 아이콘 테두리
	local iconFrame = CreateFrame('Frame', nil, castbar)
	iconFrame:SetAllPoints(icon)
	iconFrame.NineSlice = CreateFrame('Frame', nil, iconFrame, 'NineSliceCodeTemplate')
	iconFrame.NineSlice:SetPoint('TOPLEFT',     iconFrame, 'TOPLEFT',     -4,  3)
	iconFrame.NineSlice:SetPoint('BOTTOMRIGHT', iconFrame, 'BOTTOMRIGHT',  7, -6)
	iconFrame.NineSlice:SetFrameLevel(iconFrame:GetFrameLevel() + 3)
	iconFrame.NineSlice:SetScale(0.6)
	NineSliceUtil.ApplyUniqueCornersLayout(iconFrame.NineSlice, 'UI-HUD-ActionBar-Frame')

	-- 스킬 이름 텍스트
	local text = castbar:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline_Small')
	text:SetPoint('LEFT', castbar, 'LEFT', 5, 0)
	text:SetPoint('RIGHT', castbar, 'RIGHT', -40, 0)
	text:SetJustifyH('LEFT')
	local fontPath, _, fontFlags = text:GetFont()
	text:SetFont(fontPath, 9, fontFlags)
	castbar.Text = text

	-- 캐스팅 시간 텍스트
	local time = castbar:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
	time:SetPoint('RIGHT', castbar, 'RIGHT', -5, 0)
	time:SetJustifyH('RIGHT')
	castbar.Time = time

	castbar:SetPoint('LEFT', icon, 'RIGHT', 6, 0)

	-- 차단 눈금 클립 (unit frame 자식 → StatusBar fill clip 영향 없음)
	local kick_clip = CreateFrame("Frame", nil, self)
	kick_clip:SetAllPoints(castbar)
	kick_clip:SetClipsChildren(true)
	castbar.kick_clip = kick_clip

	local kick_positioner = CreateFrame("StatusBar", nil, kick_clip)
	kick_positioner:SetAllPoints(kick_clip)
	kick_positioner:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	kick_positioner:GetStatusBarTexture():SetAlpha(0)
	kick_positioner:SetMinMaxValues(0, 1)
	kick_positioner:SetValue(0)
	kick_positioner:Hide()
	castbar.kick_positioner = kick_positioner

	local kick_marker = CreateFrame("StatusBar", nil, kick_clip)
	kick_marker:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
	kick_marker:GetStatusBarTexture():SetAlpha(0)
	kick_marker:SetPoint("TOP",    kick_clip, "TOP")
	kick_marker:SetPoint("BOTTOM", kick_clip, "BOTTOM")
	kick_marker:SetPoint("LEFT",   kick_positioner:GetStatusBarTexture(), "RIGHT")
	kick_marker:SetMinMaxValues(0, 1)
	kick_marker:SetValue(0)
	kick_marker:Hide()
	castbar.kick_marker = kick_marker

	local kick_tick = kick_clip:CreateTexture(nil, "OVERLAY", nil, 7)
	kick_tick:SetColorTexture(1, 1, 1, 1)
	kick_tick:SetWidth(2)
	kick_tick:SetPoint("TOP",    kick_clip,                         "TOP")
	kick_tick:SetPoint("BOTTOM", kick_clip,                         "BOTTOM")
	kick_tick:SetPoint("LEFT",   kick_marker:GetStatusBarTexture(), "RIGHT")
	kick_tick:Hide()
	castbar.kick_tick = kick_tick

	-- 주문대상 (바 우측 외부)
	local target_text = castbar:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
	target_text:SetPoint('LEFT', castbar, 'RIGHT', 6, 0)
	target_text:SetJustifyH('LEFT')
	target_text:Hide()
	castbar.target_text = target_text

	-- 차단 눈금 업데이트 (OnUpdate에서 호출)
	local function update_kick_tick(element)
		local kt = element.kick_tick
		if not kt then return end
		local u = element._active_unit
		local function _hide()
			kt:Hide()
			if element.kick_positioner then element.kick_positioner:Hide() end
			if element.kick_marker     then element.kick_marker:Hide() end
		end
		if not u or element._not_interruptible then _hide(); return end

		local kick_id = get_kick_spell()
		if not kick_id then _hide(); return end

		local ct = element._cast_type or "cast"
		local castDur = (ct == "channel" or ct == "empower")
			and UnitChannelDuration(u) or UnitCastingDuration(u)
		if not castDur then _hide(); return end

		local kickDur = C_Spell.GetSpellCooldownDuration(kick_id)
		if not kickDur then _hide(); return end

		local total   = castDur:GetTotalDuration()
		local elapsed = castDur:GetElapsedDuration()

		if issecretvalue(elapsed) or issecretvalue(total) or total <= 0 then
			_hide(); return
		end

		local barW = element._kick_bar_w
		if not barW then _hide(); return end

		-- kickRem은 secret → SetValue로 위젯에 직접 전달
		element.kick_positioner:SetMinMaxValues(0, total)
		element.kick_positioner:SetValue(elapsed)
		element.kick_marker:SetMinMaxValues(0, total)
		element.kick_marker:SetWidth(barW)
		element.kick_marker:SetValue(kickDur:GetRemainingDuration())

		element.kick_positioner:Show()
		element.kick_marker:Show()
		kt:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(kickDur:IsZero(), 0.4, 1.0))
		kt:Show()
	end

	-- oUF UpdatePips 안전한 오버라이드 (비밀값 및 nil stages 에러 우회)
	castbar.Pips = castbar.Pips or {}
	castbar.UpdatePips = function(element, stages)
		if not stages then return end

		local isHoriz = element:GetOrientation() == 'HORIZONTAL'
		local elementSize = isHoriz and element:GetWidth() or element:GetHeight()

		if issecretvalue and issecretvalue(elementSize) then
			elementSize = isHoriz and (uWidth - 22) or 16
		end

		local lastOffset = 0
		for stage, stageSection in ipairs(stages) do
			local offset = lastOffset + (elementSize * stageSection)
			lastOffset = offset

			local pip = element.Pips[stage]
			if not pip then
				pip = CreateFrame('Frame', nil, element, 'CastingBarFrameStagePipTemplate')
				element.Pips[stage] = pip
			end

			pip:ClearAllPoints()
			pip:Show()

			if isHoriz then
				if pip.RotateTextures then pip:RotateTextures(0) end
				if element:GetReverseFill() then
					pip:SetPoint('TOP', element, 'TOPRIGHT', -offset, 0)
					pip:SetPoint('BOTTOM', element, 'BOTTOMRIGHT', -offset, 0)
				else
					pip:SetPoint('TOP', element, 'TOPLEFT', offset, 0)
					pip:SetPoint('BOTTOM', element, 'BOTTOMLEFT', offset, 0)
				end
			else
				if pip.RotateTextures then pip:RotateTextures(1.5708) end
				if element:GetReverseFill() then
					pip:SetPoint('LEFT', element, 'TOPLEFT', 0, -offset)
					pip:SetPoint('RIGHT', element, 'TOPRIGHT', 0, -offset)
				else
					pip:SetPoint('LEFT', element, 'BOTTOMLEFT', 0, offset)
					pip:SetPoint('RIGHT', element, 'BOTTOMRIGHT', 0, offset)
				end
			end
		end
	end

	-- 비활성화된 유닛에서 캐스팅바가 표시되지 않도록 ShouldShow 오버라이드
	castbar.__unitKey = unit
	castbar.ShouldShow = function(element, u)
		if not is_castbar_enabled(element.__unitKey) then return false end
		return element.__owner.__unit == u
	end

	-- 차단 속성 훅
	local cast_ok = true  -- FAILED/INTERRUPTED 시 false → PostCastStop 스킵

	local function cast_apply_color(element, spellID, notInterruptible, cast_type)
		local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
		if notInterruptible then
			local c = CC and CC.uninterruptible or { r = 0.71, g = 0.71, b = 0.71 }
			element:SetStatusBarColor(c.r, c.g, c.b)
		else
			local isImp = false
			if C_Spell and C_Spell.IsSpellImportant and spellID then
				local ok, v = pcall(C_Spell.IsSpellImportant, spellID)
				if ok and v then isImp = true end
			end
			local c
			if isImp then
				c = (CC and CC.importantColor) or { r = 1.00, g = 0.20, b = 0.78 }
			elseif cast_type == "channel" then
				c = (CC and CC.channelColor) or { r = 0.39, g = 1.00, b = 0.39 }
			else
				c = (CC and CC.castColor) or { r = 1.00, g = 1.00, b = 0.00 }
			end
			element:SetStatusBarColor(c.r, c.g, c.b)
		end
	end

	castbar.PostCastStart = function(element, u, spellID, notInterruptible)
		cast_ok = true
		element._holdUntil = nil
		element._active_unit = u
		if element.Time then element.Time:Show() end
		local ni = notInterruptible
		if issecretvalue and issecretvalue(ni) then ni = true end
		element._not_interruptible = ni
		local cast_type = "cast"
		local cn = UnitCastingInfo(u)
		if type(cn) == "nil" then
			local _, _, _, _, _, _, _, _, isEmpowered = UnitChannelInfo(u)
			cast_type = isEmpowered and "empower" or "channel"
		end
		element._cast_type = cast_type
		cast_apply_color(element, spellID, ni, cast_type)

		-- 주문대상
		if element.target_text then
			if UnitShouldDisplaySpellTargetName and UnitShouldDisplaySpellTargetName(u) then
				local tClass = UnitSpellTargetClass and UnitSpellTargetClass(u)
				if tClass and not issecretvalue(tClass) then
					local cc = C_ClassColor and C_ClassColor.GetClassColor(tClass)
					if cc then element.target_text:SetTextColor(cc.r, cc.g, cc.b)
					else element.target_text:SetTextColor(1, 1, 1) end
				else
					element.target_text:SetTextColor(1, 1, 1)
				end
				element.target_text:SetText(UnitSpellTargetName and UnitSpellTargetName(u) or "")
				element.target_text:Show()
			else
				element.target_text:SetText("")
				element.target_text:Hide()
			end
		end
	end

	castbar.PostCastStop = function(element, u, spellID)
		if not cast_ok then cast_ok = true; return end
		local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
		local c = CC and CC.successColor or { r = 0.39, g = 1.00, b = 0.39 }
		element:SetStatusBarColor(c.r, c.g, c.b)
		element._holdUntil = GetTime() + 0.5
		element._active_unit = nil
		if element.kick_tick   then element.kick_tick:Hide() end
		if element.target_text then element.target_text:Hide() end
	end

	castbar.PostCastInterruptible = function(element, u, spellID, notInterruptible)
		local ni = notInterruptible
		if issecretvalue and issecretvalue(ni) then ni = true end
		element._not_interruptible = ni
		local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
		if ni then
			local c = CC and CC.uninterruptible or { r = 0.45, g = 0.45, b = 0.45 }
			element:SetStatusBarColor(c.r, c.g, c.b)
		else
			local c = CC and CC.interruptReady or { r = 0.92, g = 0.35, b = 0.20 }
			element:SetStatusBarColor(c.r, c.g, c.b)
		end
	end

	castbar.PostCastFail = function(element, u)
		cast_ok = false
		element._holdUntil = nil
		element._active_unit = nil
		if element.Text then element.Text:SetText("실패") end
		if element.Time then element.Time:Hide() end
		if element.kick_tick   then element.kick_tick:Hide() end
		if element.target_text then element.target_text:Hide() end
		local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
		local c = CC and CC.interruptedColor or { r = 1.00, g = 0.20, b = 0.20 }
		element:SetStatusBarColor(c.r, c.g, c.b)
	end

	castbar.PostCastInterrupted = function(element, u, spellID, interruptedBy)
		cast_ok = false
		element._holdUntil = nil
		element._active_unit = nil
		if element.Text then element.Text:SetText("차단됨") end
		if element.Time then element.Time:Hide() end
		if element.kick_tick   then element.kick_tick:Hide() end
		if element.target_text then element.target_text:Hide() end
		local CC = dodo.ColorsUnitframe and dodo.ColorsUnitframe.Castbar
		local c = CC and CC.interruptedColor or { r = 1.00, g = 0.20, b = 0.20 }
		element:SetStatusBarColor(c.r, c.g, c.b)
	end

	self.Castbar = castbar

	-- oUF가 OnUpdate를 등록한 뒤 래핑: _holdUntil 동안 Hide 차단 + 차단 눈금 업데이트
	C_Timer.After(0, function()
		local saved = castbar:GetScript('OnUpdate')
		if not saved then return end
		castbar:SetScript('OnUpdate', function(self, elapsed)
			if self._holdUntil then
				if GetTime() < self._holdUntil then
					self:Show()
					return
				end
				self._holdUntil = nil
			end
			saved(self, elapsed)
			if self._active_unit then
				update_kick_tick(self)
			end
		end)
	end)
end

-- ==============================
-- oUF 캐스팅바 요소 활성/비활성 동기화
-- ==============================
-- oUF는 self.Castbar가 있으면 무조건 PlayerCastingBarFrame을 죽임 (castbar.lua Enable) —
-- 토글 off 시 DisableElement로 oUF Disable을 태워 블리자드 기본 캐스팅바를 복원시킴
local function get_unit_frames(unit)
	if unit == "boss" then
		local frames = {}
		for i = 1, 5 do frames[i] = _G["dodoBossFrame" .. i] end
		return frames
	end
	local map = { player = dodo.PlayerFrame, target = dodo.TargetFrame, focus = dodo.FocusFrame }
	return { map[unit] }
end

local function apply_castbar_state(unit)
	local enabled = is_castbar_enabled(unit)
	for _, frame in ipairs(get_unit_frames(unit)) do
		if frame and frame.Castbar then
			if enabled then
				frame:EnableElement('Castbar')
			else
				frame:DisableElement('Castbar')
			end
		end
	end

	-- 편집모드 중 토글 off 시 블리자드 캐스팅바 미리보기 즉시 표시 —
	-- RefreshCastBar/UpdateShownState는 내부(StopFinishAnims)에서 보호 테이블을 순회해
	-- 애드온 실행 흐름에선 taint 에러 발생. isInEditMode는 편집모드 진입 시 블리자드가
	-- 이미 세팅해놨으므로(계정설정 "시전 바" 체크 시) Show()만 호출해 표시 상태만 맞춤
	if unit == "player" and not enabled
		and EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()
		and PlayerCastingBarFrame and PlayerCastingBarFrame.isInEditMode then
		PlayerCastingBarFrame:Show()
	end
end

function dodo.UnitframeApplyCastbarStates()
	for unit in pairs(CASTBAR_UNITS) do
		apply_castbar_state(unit)
	end
end

-- 로그인 시 초기 상태 적용
-- Core.lua가 toc에서 먼저 로드되므로 같은 PLAYER_LOGIN 안에서 Core의 스폰(oUF Enable) 이후 실행됨.
-- PLAYER_ENTERING_WORLD 이전에 복원해야 블리자드 캐스팅바가 PEW 초기화를 정상 수신해
-- 편집모드 미리보기가 캐스팅 없이도 바로 표시됨
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	for unit in pairs(CASTBAR_UNITS) do
		if not is_castbar_enabled(unit) then
			apply_castbar_state(unit)
		end
	end
end)

