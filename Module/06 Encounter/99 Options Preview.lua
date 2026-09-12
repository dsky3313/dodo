---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local C_Timer      = C_Timer
local CreateFrame  = CreateFrame
local GetTime      = GetTime
local math_floor   = math.floor
local math_max     = math.max
local math_min     = math.min
local table_sort   = table.sort

local _preview_ref   = nil
local _tab_change_fn = nil
local PREVIEW_TABS   = { "text", "timeline" }

-- 텍스트 탭 쿨다운 루프 & 색상 사이클
local PREVIEW_CD         = 5   -- 쿨다운 시뮬 시간 (초)
local _text_cycle_timer  = nil
local _cycle_running     = false
local _color_idx         = 0
local _cycle_count       = 2   -- 텍스트 "(N)" 카운터
local _color_keys        = nil  -- lazy 초기화

local function get_color_keys()
    if _color_keys then return _color_keys end
    local ec = dodo.Colors and dodo.Colors.EncounterColor
    if not ec then return nil end
    _color_keys = {}
    for k in pairs(ec) do
        if not k:match("^ETC") then _color_keys[#_color_keys + 1] = k end
    end
    table_sort(_color_keys)
    return _color_keys
end

local function stop_text_cycle()
    _cycle_running = false
    if _text_cycle_timer then _text_cycle_timer:Cancel(); _text_cycle_timer = nil end
end

local function start_text_cycle(mixin)
    if _cycle_running then return end
    _cycle_running = true
    _color_idx     = 0
    _cycle_count   = 2

    local function apply()
        if not _cycle_running then return end
        _text_cycle_timer = nil

        local keys = get_color_keys()
        local ec   = dodo.Colors and dodo.Colors.EncounterColor

        _color_idx = _color_idx + 1
        if not keys or _color_idx > #keys then
            -- 한 바퀴 완료 → 리셋
            _color_idx   = 1
            _cycle_count = 2
        end

        if keys and ec and mixin.texNameFS then
            local c = ec[keys[_color_idx]]
            if c then mixin.texNameFS:SetTextColor(c.r, c.g, c.b, 1) end
            mixin.texNameFS:SetText("보스 능력명 (" .. _cycle_count .. ")")
        end
        _cycle_count = _cycle_count + 1

        if mixin.texIconCd then mixin.texIconCd:SetCooldown(GetTime(), PREVIEW_CD) end
        _text_cycle_timer = C_Timer.After(PREVIEW_CD + 1, apply)
    end

    apply()
end

-- 텍스트 탭: 04 Text.lua DEFAULT_ICON_SIZE / DEFAULT_FONT_SIZE 동일
local TEXT_ICON          = 132355
local TEXT_ICON_SIZE_DEF = 30
local TEXT_FONT_SIZE_DEF = 15

-- 타임라인 탭: 편집모드 설정값 반영
-- 아이콘 크기 90% / 여백 0 / 막대 가로 길이 82% (기준폭 300×0.82=246)
local TROW_H           = 34
local TROW_GAP         = 0     -- 편집모드 여백 = 0
local TROW_BAR_H       = 26
local TROW_ICON        = 34
local TROW_ICON_SCALE  = 0.9   -- 편집모드 아이콘 크기 = 90%
local TROW_WIDTH_SCALE = 0.82  -- 편집모드 막대 가로 길이 = 82%

local TIMELINE_ROWS = {
	{ role = "Tank",     label = "보스 능력명 (1)", timer = "45", fill = 0.80 },
	{ role = "Heal",     label = "보스 능력명 (2)", timer = "28", fill = 0.50 },
	{ role = "Mechanic", label = "보스 능력명 (3)", timer = "12", fill = 0.25 },
	{ role = "Adds",     label = "보스 능력명 (4)", timer = "4",  fill = 0.10 },
}

dodoEncounterPreviewMixin = {}

dodoEncounterPreviewMixin.GetExtent = function()
	return 210
end

function dodoEncounterPreviewMixin:OnLoad()
	_preview_ref = self
	self._tab    = "text"

	local base = self:GetFrameLevel() + 1

	-- ── 텍스트 알림 미리보기 ──────────────────────────────
	-- 04 Text.lua create_row() 구조:
	--   icon_frame LEFT(+5,0) / name_fs LEFT(icon.RIGHT,+8) / RIGHT(-5)
	--   Cooldown으로 남은시간 표시 (SetCooldown → 숫자 카운트다운)
	local tf = CreateFrame("Frame", nil, self)
	tf:SetFrameLevel(base)
	self.textFrame = tf

	-- 아이콘 (LibIcon:Create — 04 Text.lua create_row() 동일 패턴)
	local icon_lf = dodo.LibIcon:Create("dodoEncounterTextPreviewIcon", tf, {
		iconsize = { TEXT_ICON_SIZE_DEF, TEXT_ICON_SIZE_DEF },
	})
	icon_lf:SetPoint("LEFT", tf, "LEFT", 5, 0)
	icon_lf:EnableMouse(false)
	icon_lf.icon:SetTexture(TEXT_ICON)
	icon_lf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	self.texIconFrame = icon_lf
	self.texIconCd    = icon_lf.cooldown

	-- 스펠명 (STANDARD_TEXT_FONT OUTLINE, LEFT, MIDDLE)
	local texNameFS = tf:CreateFontString(nil, "OVERLAY")
	texNameFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", TEXT_FONT_SIZE_DEF, "OUTLINE")
	texNameFS:SetPoint("LEFT",  icon_lf,      "RIGHT",  8, 0)
	texNameFS:SetPoint("RIGHT", tf,           "RIGHT", -5, 0)
	texNameFS:SetJustifyH("LEFT")
	texNameFS:SetJustifyV("MIDDLE")
	texNameFS:SetText("보스 능력명")
	self.texNameFS = texNameFS

	tf:Hide()

	-- ── 타임라인 막대 미리보기 ────────────────────────────────
	-- EncounterTimelineTimerEventTemplate 구조:
	--   [Icon(34×34 + rounded mask + overlay)] [StatusBar(h=26) + BG + Spark + Name + Duration]
	local tlf = CreateFrame("Frame", nil, self)
	tlf:SetFrameLevel(base)
	self.timelineFrame = tlf

	self.timelineBars = {}
	for i, row in ipairs(TIMELINE_ROWS) do
		local rowFrame = CreateFrame("Frame", nil, tlf)
		rowFrame:SetHeight(TROW_H)
		rowFrame:SetPoint("TOPLEFT", tlf, "TOPLEFT", 0, -(i - 1) * (TROW_H + TROW_GAP))

		-- 아이콘 컨테이너 Frame (Blizzard: EncounterTimelineEventIconTemplate은 Frame임)
		-- MaskTexture + masked Texture는 반드시 동일 Frame의 자식이어야 작동
		local iconFrame = CreateFrame("Frame", nil, rowFrame)
		iconFrame:SetSize(TROW_ICON, TROW_ICON)
		iconFrame:SetScale(TROW_ICON_SCALE)
		iconFrame:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

		-- 아이콘 텍스처 (XML: SetAllPoints(0,0), EncounterTimelineTextureTemplate 동일)
		local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
		iconTex:SetTexture(TEXT_ICON)
		iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		iconTex:SetAllPoints()
		iconTex:SetSnapToPixelGrid(false)
		iconTex:SetTexelSnappingBias(0.0)

		-- 라운드 마스크 (XML: MaskTexture TOPLEFT(0,-1)/BOTTOMRIGHT(0,0) — iconFrame 기준)
		local iconMask = iconFrame:CreateMaskTexture(nil, "ARTWORK")
		iconMask:SetAtlas("UI-HUD-CoolDownManager-Mask")
		iconMask:SetPoint("TOPLEFT",     iconFrame, "TOPLEFT",     0, -1)
		iconMask:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 0,  0)
		iconMask:SetSnapToPixelGrid(false)
		iconMask:SetTexelSnappingBias(0.0)
		iconTex:AddMaskTexture(iconMask)

		-- 오버레이 (XML: NormalOverlay TOPLEFT(-7,6)/BOTTOMRIGHT(7,-7))
		local iconOvl = iconFrame:CreateTexture(nil, "OVERLAY")
		iconOvl:SetAtlas("UI-HUD-CoolDownManager-IconOverlay", false)
		iconOvl:SetPoint("TOPLEFT",     iconFrame, "TOPLEFT",      -7,  6)
		iconOvl:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT",   7, -7)

		-- StatusBar (UpdateTimerBarLayout: LEFT=Icon.RIGHT+4, RIGHT=frame.RIGHT-4)
		local sb = CreateFrame("StatusBar", nil, rowFrame)
		sb:SetPoint("LEFT",  iconFrame, "RIGHT", 4, 0)
		sb:SetPoint("RIGHT", rowFrame,  "RIGHT", -4, 0)
		sb:SetHeight(TROW_BAR_H)
		-- 원본 XML: <BarTexture atlas="UI-HUD-CoolDownManager-Bar" setAllPoints="true"/>
		-- WHITE8X8 먼저 세팅 후 atlas 교체 — combat preview 동일 패턴
		sb:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
		sb:GetStatusBarTexture():SetAtlas("UI-HUD-CoolDownManager-Bar")
		sb:SetMinMaxValues(0, 1000)
		sb:SetValue(math_floor(row.fill * 1000))

		-- Bar 배경 (XML: LEFT(-2,-2) / RIGHT(6,-2) / Size y=36)
		local barBg = sb:CreateTexture(nil, "BACKGROUND")
		barBg:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
		barBg:SetPoint("LEFT",  sb, "LEFT",  -2, -2)
		barBg:SetPoint("RIGHT", sb, "RIGHT",  6, -2)
		barBg:SetHeight(36)

		-- Spark (UpdateTimerSparkLayout: CENTER=fill.RIGHT)
		local spark = sb:CreateTexture(nil, "OVERLAY", nil, 1)
		spark:SetAtlas("UI-HUD-CoolDownManager-Bar-Pip", true)
		spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "RIGHT", 0, 0)

		-- Duration text (RIGHT of bar -5)
		local durFS = sb:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		durFS:SetPoint("RIGHT", sb, "RIGHT", -5, 0)
		durFS:SetJustifyH("LEFT")
		durFS:SetJustifyV("MIDDLE")
		durFS:SetText(row.timer)

		-- Name text (LEFT=bar+5 to Duration-5, TOP-BOTTOM span bar)
		local nameFS = sb:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		nameFS:SetPoint("LEFT",   sb,    "LEFT",   5, 0)
		nameFS:SetPoint("RIGHT",  durFS, "LEFT",  -5, 0)
		nameFS:SetPoint("TOP",    sb,    "TOP",    0, 0)
		nameFS:SetPoint("BOTTOM", sb,    "BOTTOM", 0, 0)
		nameFS:SetJustifyH("LEFT")
		nameFS:SetJustifyV("MIDDLE")
		nameFS:SetText(row.label)

		self.timelineBars[i] = {
			rowFrame = rowFrame,
			sb       = sb,
			role     = row.role,
			timer    = row.timer,
		}
	end
	tlf:Hide()
end

function dodoEncounterPreviewMixin:OnTabSelected(tabIndex)
	self._tab = PREVIEW_TABS[tabIndex] or "text"
	if _tab_change_fn then _tab_change_fn(self._tab) end
	self:Update()  -- Update가 탭에 따라 사이클 시작/종료 직접 관리
end

function dodoEncounterPreviewMixin:Update()
	local tab = self._tab or "text"
	local W   = self:GetWidth()
	if not W or W <= 0 then return end
	local H   = self:GetHeight()

	-- ── 텍스트 탭 ──────────────────────────────────────
	if tab == "text" then
		self.timelineFrame:Hide()

		-- DB값으로 아이콘 크기·폰트 크기 반영 (LEM 설정과 동기화)
		local icon_sz   = (dodoDB and dodoDB.encounterTextIconSize) or TEXT_ICON_SIZE_DEF
		local font_sz   = (dodoDB and dodoDB.encounterTextFontSize) or TEXT_FONT_SIZE_DEF
		local row_h     = math_max(icon_sz, font_sz + 8)
		-- ROW_W: 아이콘+텍스트 실제 폭으로 한정 (textFrame 과도한 좌편향 방지)
		local ROW_W = math_min(icon_sz + 13 + 140, math_floor(W * 0.9))

		self.textFrame:ClearAllPoints()
		self.textFrame:SetPoint("CENTER", self, "CENTER", 0, 0)
		self.textFrame:SetSize(ROW_W, row_h)

		self.texIconFrame:SetSize(icon_sz, icon_sz)
		self.texIconFrame:RescaleIcon()  -- LibIcon margin 갱신
		self.texNameFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", font_sz, "OUTLINE")

		-- 쿨다운 루프 + 색상 사이클 (이미 실행 중이면 무시)
		start_text_cycle(self)

		self.textFrame:Show()
		return
	end

	-- ── 타임라인 탭 ────────────────────────────────────
	stop_text_cycle()
	self.textFrame:Hide()

	local use_color      = not dodoDB or dodoDB.enableEncounterTimelineColor ~= false
	local highlight      = use_color and (not dodoDB or dodoDB.useEncounterTimelineColorHighlight ~= false)
	local DEFAULT_COLOR  = { r = 0.8, g = 0.1, b = 0.1 }  -- 색상 꺼짐 기본 / 5초 전 하이라이트

	local totalH = #TIMELINE_ROWS * TROW_H + (#TIMELINE_ROWS - 1) * TROW_GAP
	local TW     = math_min(math_floor(300 * TROW_WIDTH_SCALE), math_floor(W * 0.9))
	local ox     = math_floor((W - TW) / 2)

	self.timelineFrame:ClearAllPoints()
	self.timelineFrame:SetPoint("TOPLEFT", self, "TOPLEFT", ox, -54)
	self.timelineFrame:SetSize(TW, totalH)

	local ec = dodo.Colors and dodo.Colors.EncounterColor

	for i, entry in ipairs(self.timelineBars) do
		entry.rowFrame:SetWidth(TW)

		local timer_val = tonumber(entry.timer) or 99
		local is_urgent = highlight and timer_val <= 5
		local r, g, b
		if not use_color or is_urgent then
			r, g, b = DEFAULT_COLOR.r, DEFAULT_COLOR.g, DEFAULT_COLOR.b
		else
			local base_c = ec and ec[entry.role]
			if base_c then
				r, g, b = base_c.r or 0.5, base_c.g or 0.5, base_c.b or 0.5
			else
				r, g, b = DEFAULT_COLOR.r, DEFAULT_COLOR.g, DEFAULT_COLOR.b
			end
		end
		entry.sb:SetStatusBarColor(r, g, b)
	end

	self.timelineFrame:Show()
end

local function refresh_preview()
	if _preview_ref and _preview_ref.Update then
		_preview_ref:Update()
	end
end
dodo.EncounterRefreshPreview = refresh_preview

function dodo.EncounterSetTabChangeFn(fn)
	_tab_change_fn = fn
end

function dodo.EncounterGetPreviewTab()
	return (_preview_ref and _preview_ref._tab) or "text"
end
