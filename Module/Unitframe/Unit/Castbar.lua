-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local Enum = Enum
local ipairs = ipairs
local issecretvalue = issecretvalue or function() return false end
local NineSliceUtil = NineSliceUtil
local pairs = pairs
local string_format = string.format
local _G = _G

-- ==============================
-- 설정 테이블
-- ==============================
local CASTBAR_UNITS = {
	player = true, target = true, focus = true, boss = true,
}

local CASTBAR_DB_KEYS = {
	player = "unitframeCastbarPlayer",
	target = "unitframeCastbarTarget",
	focus  = "unitframeCastbarFocus",
	boss   = "unitframeCastbarBoss",
}

local CASTBAR_DEFAULTS = {
	player = false, target = true, focus = false, boss = true,
}

local function is_castbar_enabled(unit)
	local dbKey = CASTBAR_DB_KEYS[unit]
	if not dbKey then return false end
	if not dodoDB then return CASTBAR_DEFAULTS[unit] or false end
	local val = dodoDB[dbKey]
	if val == nil then return CASTBAR_DEFAULTS[unit] or false end
	return val
end

-- ==============================
-- 캐스팅바 공통 빌더
-- ==============================
function dodo.UnitframeCreateCastbar(self, uWidth, unit)
	if not CASTBAR_UNITS[unit] then return end
	if self.Castbar then return end

	local castbar = CreateFrame('StatusBar', nil, self, 'BackdropTemplate')
	castbar:SetSize(uWidth - 22, 16)
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
	icon:SetPoint('LEFT', self.Health, 'BOTTOMLEFT', 0, -22)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	castbar.Icon = icon

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
	castbar.PostCastStart = function(element, u, spellID, notInterruptible)
		if element.Time then element.Time:Show() end
		local isNotInterruptible = notInterruptible
		if issecretvalue and issecretvalue(isNotInterruptible) then isNotInterruptible = true end
		element:SetStatusBarColor(isNotInterruptible and 0.6 or 1, isNotInterruptible and 0.6 or 0.7, isNotInterruptible and 0.6 or 0)
	end

	castbar.PostChannelStart = function(element, u, spellID, notInterruptible)
		if element.Time then element.Time:Show() end
		local isNotInterruptible = notInterruptible
		if issecretvalue and issecretvalue(isNotInterruptible) then isNotInterruptible = true end
		element:SetStatusBarColor(isNotInterruptible and 0.6 or 1, isNotInterruptible and 0.6 or 0.7, isNotInterruptible and 0.6 or 0)
	end

	castbar.PostCastNotInterruptible = function(element, u)
		element:SetStatusBarColor(0.6, 0.6, 0.6)
	end

	castbar.PostCastInterruptible = function(element, u)
		element:SetStatusBarColor(1, 0.7, 0)
	end

	castbar.PostCastFail = function(element, u)
		if element.Text then element.Text:SetText("실패") end
		if element.Time then element.Time:Hide() end
	end

	castbar.PostCastInterrupted = function(element, u)
		if element.Text then element.Text:SetText("차단됨") end
		if element.Time then element.Time:Hide() end
	end

	self.Castbar = castbar
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

-- ==============================
-- 설정 등록
-- ==============================
local Enum_EditModeSystem_UnitFrame = (Enum and Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame) or 3

local CASTBAR_SYSTEM_INDICES = {
	player = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Player) or 1,
	target = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Target) or 2,
	boss   = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Boss) or 5,
	focus  = (Enum and Enum.EditModeUnitFrameSystem and Enum.EditModeUnitFrameSystem.Focus) or 6,
}

if dodo.RegisterEditModeSystemSetting then
	for unit, sysIdx in pairs(CASTBAR_SYSTEM_INDICES) do
		local sysID = string_format("%d_%d", Enum_EditModeSystem_UnitFrame, sysIdx)
		local dbKey = CASTBAR_DB_KEYS[unit]
		local default = CASTBAR_DEFAULTS[unit]
		dodo.RegisterEditModeSystemSetting(sysID, {
			{
				name = "캐스팅바",
				get = function()
					if not dodoDB or not dbKey then return default or false end
					local val = dodoDB[dbKey]
					return val == nil and (default or false) or val
				end,
				set = function(checked)
					if dodoDB and dbKey then dodoDB[dbKey] = checked end
					apply_castbar_state(unit)
				end,
				disabled = function() return dodoDB and dodoDB.enableUnitframeModule == false end
			}
		})
	end
end
