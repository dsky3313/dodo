local _, ns = ...
local hooksecurefunc, C_Timer = ns.Probe('PartyDefensives', hooksecurefunc, C_Timer)
local _G = _G

local CreateFrame = CreateFrame
local UIParent = UIParent
local IsInGroup, IsInRaid = IsInGroup, IsInRaid
local ipairs, type = ipairs, type
local tconcat = table.concat

local kit = ns.PTCKit

local function Unavailable()
	return not (kit and ns.PTCBar and not ns.PTCUnavailable)
end

ns.hasPartyDefensives = true
ns.PDFUnavailable = Unavailable()

ns.PDFWhy = function()
	if not (kit and ns.PTCBar) then return 'Party CDs is not loaded, and Party Defensives reads and draws its icons with it.' end
	return ns.PTCWhy and ns.PTCWhy() or ''
end

local DEFAULTS = {
	enable = false,
	lock = false,
	showSelf = true,
	groupOnly = true,
	dungeonOnly = false,
	showTimer = true,
	highlight = true,
	tooltip = false,
	grow = 'RIGHT',
	size = 36,
	spacing = 2,
	textSize = 16,
	names = true,
	namePos = 'IN',
	nameSize = 10,
	nameLen = 4,
	x = -160,
	y = -300,
	px = 10, -- dodo: 파티 프레임 TOPRIGHT 기준 오프셋 (차단기 시작점 y -100)
	py = -140,
	order = {},
	off = {},
	style = 'bar', -- dodo: 'icon' | 'bar' (바 형식 고정)
	barWidth = 180, -- dodo: bar 모드 전체 너비 (아이콘 포함)
}

local function Catalogue() return ns.PTCBarCatalogue and ns.PTCBarCatalogue('guard') or {} end

local function Migrate(cfg)
	if type(cfg.off) ~= 'table' then cfg.off = {} end
	local left, order = {}, {}
	for _, e in ipairs(Catalogue()) do left[e.id] = true end
	if type(cfg.order) == 'table' then
		for _, id in ipairs(cfg.order) do
			if left[id] then
				order[#order + 1] = id
				left[id] = nil
			end
		end
	end
	for _, e in ipairs(Catalogue()) do
		if left[e.id] then order[#order + 1] = e.id end
	end
	cfg.order = order
end

local function GetCfg() return ns.ModuleCfg('partyDefensives', DEFAULTS, Migrate) end
ns.PDFGetCfg = GetCfg

local frame
local preview = false
local look = {}
local drawn = 0

local function ApplyPosition()
	if not frame then return end
	local cfg = GetCfg()
	frame:ClearAllPoints()
	-- dodo: 바 그룹 좌측상단 → 파티 프레임 우측상단
	local party = ns.PartyAnchor()
	if party then
		frame:SetPoint('TOPLEFT', party, 'TOPRIGHT', cfg.px or 10, cfg.py or -140)
		return
	end
	frame:SetPoint('CENTER', UIParent, 'CENTER', cfg.x or 0, cfg.y or 0)
end

local function Tag(c)
	local tag = c.guardTag
	if tag then return tag end
	tag = CreateFrame('Frame', nil, c)
	tag:SetAllPoints(c)
	tag.who = tag:CreateFontString(nil, 'OVERLAY')
	tag.who:SetJustifyH('CENTER')
	tag.who:SetWordWrap(false)
	c.guardTag = tag
	return tag
end

local lay = {}

-- ==============================
-- dodo: bar 모드 (12 Interrupts 차단기 바와 같은 디자인)
-- ==============================
-- 준비: 직업색 바 꽉 참 / 쿨 중: 어두운 바 위로 직업색이 왼쪽부터 차오름.
-- 엔진 타이머 슬롯(secret 가능)을 Sweep 과 같은 식으로 StatusBar 에 그림:
-- MinMax(m, m + cd/span), Value = slot.c → 채움 = 경과/cd. 쿨 중 여부는 slot.v 알파로만 표현 (연산 없음).
local BAR_TEX = 'Interface\\Buttons\\WHITE8X8'
local BAR_TICK = 0.1
local BAR_GAP = -1 -- 바 사이 간격 (차단기 기본값과 동일)
local placed = {}
local barAcc = 0
local listBorder
local barDiag = { ticks = 0, fills = 0, fails = 0, skip = 0 } -- /ptdef 진단용
local BAR_TEXT = 12 -- 이름/타이머 글자 크기 (12 Interrupts textSize 기본값과 동일)
local moved = {} -- 타이머를 바 오른쪽으로 옮긴 셀 (해제 시 원위치)

-- 쿨 숫자: 아이콘 중앙 → 바 오른쪽 (차단바 row.timer 'RIGHT', -4 와 같은 자리)
-- 슬롯 경로: 엔진 c.win 중심 가로 오프셋(c.winX, 10 PartyCDs) / 본인 주문: 09 ExactCooldowns ex.text
local function MoveTimer(c, b, size, barW)
	c.winX = barW - 7 -- 아이콘 중심 → 바 오른쪽 끝 - 여백 4 - 창 절반 (size + 6) / 2 + size / 2
	c.win:SetPoint('CENTER', c, 'CENTER', c.winX, c.seat or 0)
	local ex = c.ex
	if ex then
		ex.text:ClearAllPoints()
		ex.text:SetPoint('RIGHT', b, 'RIGHT', -4, 0)
		ex.text:SetJustifyH('RIGHT')
	end
	c.noShade = true -- 09 ExactCooldowns: 본인 주문 아이콘 흑백 처리 안 함
	if ex then ex.rc:SetAlpha(0) end -- 본인 주문 원형 스와이프 숨김
	moved[c] = true
end

local function ResetTimer(c)
	c.winX = nil
	c.win:SetPoint('CENTER', c, 'CENTER', 0, c.seat or 0)
	local ex = c.ex
	if ex then
		ex.text:ClearAllPoints()
		ex.text:SetPoint('CENTER', c, 'CENTER', 0, 0)
		ex.text:SetJustifyH('CENTER')
		ex.rc:SetAlpha(1)
	end
	c.noShade = nil
	moved[c] = nil
end

local function Bar(c)
	local b = c.guardBar
	if b then return b end
	b = CreateFrame('Frame', nil, c)
	-- 배경: 12 Interrupts row.bg 와 동일 (직업색 * 0.15, 알파 0.6, 항상 표시)
	b.bg = b:CreateTexture(nil, 'BACKGROUND')
	b.bg:SetAllPoints(b)
	-- 준비 판정용 숨김 바 (역방향 채움, 값 = slot.v, 채움 텍스처는 투명)
	-- slot.v = 1(쿨 중)이면 채움이 바 전체 → 아래 b.ready 폭 0 / 둘 다 0 이면 b.ready 꽉 참
	-- secret 값 비교 없이 앵커만으로 "쿨 중 아님" 을 그림
	b.gate = {}
	local prev
	for k = 1, 2 do
		local g = CreateFrame('StatusBar', nil, b)
		g:SetStatusBarTexture(BAR_TEX)
		g:SetStatusBarColor(0, 0, 0, 0)
		g:SetReverseFill(true)
		g:SetMinMaxValues(0, 1)
		g:SetValue(0)
		g:SetPoint('TOPLEFT', b, 'TOPLEFT', 0, 0)
		if prev then
			g:SetPoint('BOTTOMRIGHT', prev:GetStatusBarTexture(), 'BOTTOMLEFT', 0, 0)
		else
			g:SetPoint('BOTTOMRIGHT', b, 'BOTTOMRIGHT', 0, 0)
		end
		b.gate[k] = g
		prev = g
	end
	-- 준비 상태: 12 Interrupts row.ready 와 동일 (직업색 꽉 참)
	b.ready = b:CreateTexture(nil, 'BORDER')
	b.ready:SetTexture(BAR_TEX)
	b.ready:SetPoint('TOPLEFT', b, 'TOPLEFT', 0, 0)
	b.ready:SetPoint('BOTTOMRIGHT', prev:GetStatusBarTexture(), 'BOTTOMLEFT', 0, 0)
	-- 쿨 중: 경과만큼 왼쪽부터 차오르는 직업색 바 (12 Interrupts row.bar 와 동일)
	b.fill = {}
	for k = 1, 2 do
		local s = CreateFrame('StatusBar', nil, b)
		s:SetAllPoints(b)
		s:SetStatusBarTexture(BAR_TEX)
		s:SetMinMaxValues(0, 1)
		s:SetValue(0)
		s:SetAlpha(0)
		b.fill[k] = s
	end
	b.over = CreateFrame('Frame', nil, b)
	b.over:SetAllPoints(b)
	b.over:SetFrameLevel(b:GetFrameLevel() + 3)
	b.name = b.over:CreateFontString(nil, 'OVERLAY')
	b.name:SetPoint('LEFT', b, 'LEFT', 4, 0)
	b.name:SetPoint('RIGHT', b, 'RIGHT', -4, 0)
	b.name:SetJustifyH('LEFT')
	b.name:SetWordWrap(false)
	-- 행 하단 금속 테두리 (12 Interrupts 와 동일, 아이콘 ~ 바 전체)
	b.edgeBottom = b.over:CreateTexture(nil, 'BORDER')
	b.edgeBottom:SetAtlas('_UI-Frame-Metal-EdgeBottom', true)
	b.edgeBottom:SetHeight(16)
	b.edgeBottom:SetPoint('BOTTOMLEFT', c, 'BOTTOMLEFT', 0, -2)
	b.edgeBottom:SetPoint('BOTTOMRIGHT', b, 'BOTTOMRIGHT', 0, -2)
	c.guardBar = b
	return b
end

-- 본인 주문(t.exact)은 엔진이 슬롯 대신 게임 쿨다운(09 ExactCooldowns)으로 그림 → 바도 DurationObject 로 그림.
-- 켜짐 전환 시 + 1초마다만 DurationObject 갱신 (매 틱 생성 방지)
local EXACT_REFRESH = 10 -- BAR_TICK 단위
local function ExactFill(b, id)
	local S = _G.C_Spell
	local info = S.GetSpellCooldown(id)
	local on = type(info) == 'table' and info.isActive == true and info.isOnGCD ~= true
	if on then
		b.exactAge = (b.exactAge or 0) + 1
		if not b.exactOn or b.exactAge >= EXACT_REFRESH then
			b.exactAge = 0
			local d = S.GetSpellCooldownDuration(id, true)
			if d then b.fill[1]:SetTimerDuration(d) end
		end
	end
	b.exactOn = on
	b.fill[1]:SetAlpha(on and 1 or 0)
	b.fill[2]:SetAlpha(0)
	b.gate[1]:SetValue(on and 1 or 0)
	b.gate[2]:SetValue(0)
end

local function BarFill(b, t, now)
	if t.exact then return ExactFill(b, t.exact) end
	b.exactOn = nil
	local span = 255 * t.u
	for k = 1, 2 do
		local sl, s = t.slot[k], b.fill[k]
		local m = 1 - (now - sl.epoch) / span
		s:SetMinMaxValues(m, m + t.cd / span)
		s:SetValue(sl.c)
		s:SetAlpha(sl.v)
		b.gate[k]:SetValue(sl.v)
	end
end

local function BarTick(self, elapsed)
	barAcc = barAcc + elapsed
	if barAcc < BAR_TICK then return end
	barAcc = 0
	barDiag.ticks = barDiag.ticks + 1
	local now = kit.Clock()
	for i = 1, #placed do
		local e = placed[i]
		local b = e.c.guardBar
		if e.t and b and b:IsShown() then
			local ok, err = pcall(BarFill, b, e.t, now)
			if ok then
				barDiag.fills = barDiag.fills + 1
			else
				barDiag.fails, barDiag.err = barDiag.fails + 1, tostring(err)
				b.fill[1]:SetAlpha(0) b.fill[2]:SetAlpha(0)
				b.gate[1]:SetValue(0) b.gate[2]:SetValue(0)
			end
		else
			barDiag.skip = barDiag.skip + 1
		end
	end
end

-- 목록 전체 테두리 (12 Interrupts PlaceListBorder 와 동일)
local function PlaceListBorder(first, last, up)
	if not listBorder then
		listBorder = CreateFrame('Frame', nil, frame)
		listBorder.NineSlice = CreateFrame('Frame', nil, listBorder, 'NineSliceCodeTemplate')
		listBorder.NineSlice:SetPoint('TOPLEFT', listBorder, 'TOPLEFT', -4, 3)
		listBorder.NineSlice:SetPoint('BOTTOMRIGHT', listBorder, 'BOTTOMRIGHT', 7, -6)
		listBorder.NineSlice:SetScale(0.6)
		_G.NineSliceUtil.ApplyUniqueCornersLayout(listBorder.NineSlice, 'UI-HUD-ActionBar-Frame')
	end
	if not first then
		listBorder:Hide()
		return
	end
	local top, bottom = first, last
	if up then top, bottom = last, first end
	listBorder:SetFrameStrata(top.c:GetFrameStrata())
	listBorder:SetFrameLevel(top.c:GetFrameLevel() + 20)
	listBorder:ClearAllPoints()
	listBorder:SetPoint('TOPLEFT', top.c, 'TOPLEFT', 0, 0)
	listBorder:SetPoint('BOTTOMRIGHT', bottom.c.guardBar, 'BOTTOMRIGHT', 0, 0)
	listBorder:Show()
end

local function Place(list)
	local cfg = GetCfg()
	local size = cfg.size or 36
	-- local barMode = cfg.style == 'bar'
	local barMode = true -- dodo: 바 형식 고정
	local grow = cfg.grow == 'UP' and 'UP' or 'DOWN'
	kit.LayOpts(lay, size, BAR_GAP, grow, false, cfg.namePos, cfg.nameSize or 10, cfg.nameLen)
	-- dodo: 아이콘 모드 (주석처리)
	-- if barMode then
	-- 	local grow = cfg.grow == 'UP' and 'UP' or 'DOWN'
	-- 	kit.LayOpts(lay, size, cfg.spacing or 2, grow, false, cfg.namePos, cfg.nameSize or 10, cfg.nameLen)
	-- else
	-- 	kit.LayOpts(lay, size, cfg.spacing or 2, cfg.grow, cfg.names ~= false, cfg.namePos, cfg.nameSize or 10, cfg.nameLen)
	-- end
	local timers = cfg.showTimer ~= false
	local n = #list
	frame:SetSize(size, size)
	wipe(placed)
	for i, e in ipairs(list) do
		local c = e.c
		c:Show()
		-- c.clip:Show()
		c.clip:Hide() -- dodo: 쿨 중 아이콘 어둡게 하는 레이어 숨김 (차단바 아이콘처럼)
		c.win:SetShown(timers)
		local tag = Tag(c)
		tag:SetFrameLevel(c:GetFrameLevel() + 7)
		kit.Lay(c, tag.who, e.m, frame, i, n, lay)
		if barMode then
			local b = Bar(c)
			local r, g, bl = ns.ClassRGB(e.m and e.m.class, 1)
			b:ClearAllPoints()
			b:SetPoint('TOPLEFT', c, 'TOPRIGHT', 0, 0)
			b:SetPoint('BOTTOMLEFT', c, 'BOTTOMRIGHT', 0, 0)
			local barW = math.max(10, (cfg.barWidth or 180) - size)
			b:SetWidth(barW)
			MoveTimer(c, b, size, barW)
			b.bg:SetColorTexture(r * 0.15, g * 0.15, bl * 0.15, 0.6)
			b.ready:SetVertexColor(r, g, bl, 1)
			for k = 1, 2 do
				b.fill[k]:SetStatusBarColor(r, g, bl, 1)
			end
			b.name:SetFont(ns.GetFont(), BAR_TEXT, 'OUTLINE')
			b.name:SetPoint('RIGHT', b, 'RIGHT', -(BAR_TEXT * 2 + 8), 0) -- 타이머 자리 비움
			if not (e.m and pcall(b.name.SetText, b.name, e.m.name)) then b.name:SetText('') end
			b.edgeBottom:Show()
			b:Show()
			placed[#placed + 1] = e
		-- dodo: 아이콘 모드 (주석처리)
		-- elseif c.guardBar then
		-- 	c.guardBar:Hide()
		end
	end
	-- 이번 목록에서 빠진 셀은 타이머 원위치 (공생기 끔 → 파티원 줄로 돌아가는 경우)
	for c in pairs(moved) do
		local keep = false
		for i = 1, #placed do
			if placed[i].c == c then keep = true end
		end
		if not keep then ResetTimer(c) end
	end
	-- dodo: 화면상 맨 아래 줄은 하단 금속 테두리 생략
	local bottom = grow == 'UP' and placed[1] or placed[#placed]
	if bottom then bottom.c.guardBar.edgeBottom:Hide() end
	PlaceListBorder(placed[1], placed[#placed], grow == 'UP')
	drawn = n
	frame:SetShown(n > 0)
	frame:EnableMouse(ns.CanGrab(cfg, preview))
	if barMode and n > 0 then
		barAcc = BAR_TICK
		frame:SetScript('OnUpdate', BarTick)
	else
		frame:SetScript('OnUpdate', nil)
	end
end

local function EnsureFrame()
	if frame then return end
	frame = CreateFrame('Frame', 'dodoPartyDefensives', UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:SetSize(36, 36)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(false)
	frame:RegisterForDrag('RightButton')
	frame:Hide()
	ns.MakeDraggable(frame, GetCfg, 'x', 'y', ApplyPosition)
	ns.OnGrabChange(function() frame:EnableMouse(ns.CanGrab(GetCfg(), preview)) end)
end

local function Apply()
	local cfg = GetCfg()
	ns.PDFUnavailable = Unavailable()
	local want = (cfg.enable or preview) and not ns.PDFUnavailable
	if not (want or frame) then return end
	EnsureFrame()
	ApplyPosition()
	if not want then
		frame:Hide()
		drawn = 0
		for c in pairs(moved) do ResetTimer(c) end -- dodo: 타이머 원위치
		if ns.PTCBar then ns.PTCBar('guard', nil) end
		return
	end
	look.enable, look.preview = cfg.enable and true or false, preview
	look.showSelf, look.groupOnly, look.dungeonOnly = cfg.showSelf, cfg.groupOnly, cfg.dungeonOnly
	-- look.highlight, look.size, look.textSize = cfg.highlight, cfg.size, cfg.textSize
	look.highlight, look.size, look.textSize = cfg.highlight, cfg.size, BAR_TEXT -- dodo: 차단바와 같은 글자 크기
	look.tooltip = cfg.tooltip == true
	look.order, look.off, look.Place = cfg.order, cfg.off, Place
	ns.PTCBar('guard', frame, look)
end

ns.PDFApply = ns.Coalesce(Apply)

ns.PDFIsPreview = function() return preview end
ns.PDFSetPreview = function(state)
	preview = state and true or false
	Apply()
end

ns.PDFSpells = function()
	local cfg, out, byID = GetCfg(), {}, {}
	for _, e in ipairs(Catalogue()) do byID[e.id] = e end
	for _, id in ipairs(cfg.order) do
		local e = byID[id]
		if e then out[#out + 1] = { id = id, class = e.class, spec = e.spec, off = cfg.off[id] and true or false } end
	end
	return out
end

ns.PDFSetShown = function(id, on)
	GetCfg().off[id] = (not on) and true or nil
	ns.PDFApply()
end

ns.PDFMove = function(id, dir)
	if not kit.Swap(GetCfg().order, id, dir) then return false end
	ns.PDFApply()
	return true
end

_G.SLASH_DODOPTDEF1 = '/ptdef'
_G.SlashCmdList.DODOPTDEF = function()
	local function p(...) print('[dodo] 공생기', ...) end
	local cfg = GetCfg()
	if Unavailable() then
		p('|cffff5555not available:|r', ns.PDFWhy())
		return
	end
	p('enable =', cfg.enable and 'on' or 'off', '| preview =', preview and 'ON' or 'off', '| icons drawn =', drawn,
		'| in group =', IsInGroup() and 'yes' or 'no', '| in raid =', IsInRaid() and 'yes' or 'no',
		'| only while in a party =', cfg.groupOnly ~= false and 'on' or 'off', '| only in dungeons =', cfg.dungeonOnly and 'on' or 'off',
		'| include yourself =', cfg.showSelf ~= false and 'on' or 'off')
	local names = {}
	for _, e in ipairs(ns.PDFSpells()) do names[#names + 1] = ns.CdSpellName(e.id) .. (e.off and ' (off)' or '') end
	p('spells =', tconcat(names, ', '))
	p('each member\'s timer is listed by /ptcd, under that member')
	-- dodo: 바 진단
	local withT = 0
	for _, e in ipairs(placed) do if e.t then withT = withT + 1 end end
	p('bars placed =', #placed, '| with timer =', withT, '| ticks =', barDiag.ticks, '| fills =', barDiag.fills,
		'| skipped =', barDiag.skip, '| fails =', barDiag.fails, barDiag.err and ('| last error = ' .. barDiag.err) or '')
end
