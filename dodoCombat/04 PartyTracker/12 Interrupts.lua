local _, ns = ...
local hooksecurefunc, C_Timer = ns.Probe('Interrupts', hooksecurefunc, C_Timer)
local _G = _G

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime
local C_Timer = C_Timer
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local C_ClassColor = C_ClassColor
local C_SpecializationInfo = C_SpecializationInfo
local UnitExists, UnitName, UnitGUID = UnitExists, UnitName, UnitGUID
local UnitClassBase = UnitClassBase
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local IsInGroup, IsInRaid = IsInGroup, IsInRaid
local GetRaidTargetIndex = GetRaidTargetIndex
local ipairs, pairs, pcall, type, tostring = ipairs, pairs, pcall, type, tostring
local mfloor, mabs = math.floor, math.abs
local sformat = string.format
local wipe = wipe
local secret = ns.IsSecret

ns.hasInterrupts = true

local DEFAULTS = {
	enable = false,
	lock = false,
	showSelf = true,
	groupOnly = true,
	dungeonOnly = false,
	hideInRaid = true,
	showReady = true,
	showIcon = true,
	iconSource = 'kick',
	showTimer = true,
	showMark = true,
	growth = 'DOWN',
	width = 180,
	height = 20,
	spacing = 2,
	iconGap = 2,
	textSize = 12,
	bgAlpha = 0.6,
	darkBars = false,
	darkAlpha = 1,
	x = -420,
	y = 0,
	px = 10, -- dodo: 파티 프레임 TOPRIGHT 기준 오프셋
	py = -16,
	tooltip = true, -- dodo: 행 툴팁
	observe = true,
	meterConfirm = true,
	partyCd = 15,
}

local function Migrate(cfg)
	cfg.growth = 'DOWN' -- dodo: 하단 성장 고정
	if cfg.iconSource ~= 'kick' and cfg.iconSource ~= 'kicked' then cfg.iconSource = 'kick' end
	cfg.kickCd, cfg.memberCd, cfg.kickOrder, cfg.texture = nil, nil, nil, nil
	if type(cfg.off) ~= 'table' then cfg.off = {} end -- dodo: 주문별 끄기 { [spellID] = true }
end

local function GetCfg() return ns.ModuleCfg('interrupts', DEFAULTS, Migrate) end
ns.IKGetCfg = GetCfg

local KICKS = {
	[47528]  = { cd = 15, class = 'DEATHKNIGHT', name = 'Mind Freeze', mods = { { 378848, landed = -3, likely = true } } },
	[183752] = { cd = 15, class = 'DEMONHUNTER', name = 'Disrupt' },
	[106839] = { cd = 15, class = 'DRUID',       name = 'Skull Bash' },
	[78675]  = { cd = 60, class = 'DRUID',       name = 'Solar Beam', mods = { { 202918, landed = -15, likely = true } } },
	[351338] = { cd = 20, class = 'EVOKER',      name = 'Quell', mods = { { 412713, pct = -10 } } },
	[147362] = { cd = 24, class = 'HUNTER',      name = 'Counter Shot' },
	[187707] = { cd = 15, class = 'HUNTER',      name = 'Muzzle' },
	[2139]   = { cd = 25, class = 'MAGE',        name = 'Counterspell', mods = { { 382297, add = -5, likely = true } } },
	[116705] = { cd = 15, class = 'MONK',        name = 'Spear Hand Strike' },
	[96231]  = { cd = 15, class = 'PALADIN',     name = 'Rebuke' },
	[15487]  = { cd = 30, class = 'PRIEST',      name = 'Silence' },
	[1766]   = { cd = 15, class = 'ROGUE',       name = 'Kick' },
	[57994]  = { cd = 12, healerCd = 30, class = 'SHAMAN', name = 'Wind Shear' },
	[6552]   = { cd = 15, class = 'WARRIOR',     name = 'Pummel', mods = { { 391271, pct = -10, likely = true } } },
	[386071] = { cd = 90, class = 'WARRIOR',     name = 'Disrupting Shout' },
	[19647]  = { cd = 24, class = 'WARLOCK',     name = 'Spell Lock' },
	[89766]  = { cd = 30, class = 'WARLOCK',     name = 'Axe Toss' },
	[119910] = { cd = 24, class = 'WARLOCK', icon = 19647 },
	[132409] = { cd = 24, class = 'WARLOCK', icon = 19647 },
	[1276467] = { cd = 24, class = 'WARLOCK', icon = 19647 },
	[119914] = { cd = 30, class = 'WARLOCK', icon = 89766 },
}

local CLASS_KICK = {
	DEATHKNIGHT = 47528, DEMONHUNTER = 183752, DRUID = 106839, EVOKER = 351338,
	HUNTER = 147362, MAGE = 2139, MONK = 116705, PALADIN = 96231, PRIEST = 15487,
	ROGUE = 1766, SHAMAN = 57994, WARRIOR = 6552, WARLOCK = 19647,
}

local SPEC_KICK = {
	[102] = 78675,
	[255] = 187707,
	[105] = false,
	[1468] = false,
	[65] = false,
	[256] = false,
	[257] = false,
	[270] = false,
}

local HEALER_NO_KICK = { DRUID = true, EVOKER = true, PALADIN = true, PRIEST = true, MONK = true }

local HEALER_SPEC = { [65] = true, [105] = true, [256] = true, [257] = true, [264] = true, [270] = true, [1468] = true }

local function Heals(spec, role)
	if spec then return HEALER_SPEC[spec] or false end
	return role == 'HEALER'
end

local tal = { ids = {}, all = {}, misses = {}, byGUID = {} }
for _, kick in pairs(KICKS) do
	for _, mod in ipairs(kick.mods or {}) do ns.TalentWant(tal, kick.class, mod[1]) end
end

function tal.Own()
	local class = UnitClassBase('player')
	if type(class) ~= 'string' or secret(class) then return nil end
	local config = ns.TalentConfig()
	return config and ns.TalentRanks(tal, class, config) or nil
end

local function KickCd(spell, heals, ranks, landed)
	local kick = spell and KICKS[spell]
	if not kick then return nil end
	if heals and kick.healerCd then return kick.healerCd end
	local cd, mul, cut = kick.cd, 1, 0
	for _, mod in ipairs(kick.mods or {}) do
		local rank = ranks and ranks[mod[1]]
		if type(rank) ~= 'number' or secret(rank) then rank = mod.likely and 1 or 0 end
		if rank > 0 then
			cd = cd + (mod.add or 0) * rank
			mul = mul * (1 + (mod.pct or 0) * rank / 100)
			cut = cut + (mod.landed or 0) * rank
		end
	end
	cd = cd * mul
	if landed then cd = cd + cut end
	return mfloor(cd * 100 + 0.5) / 100
end

local function SelfSpecId()
	local idx = ns.PlayerSpec()
	local get = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or _G.GetSpecializationInfo
	if not idx or not get then return nil end
	local ok, id = pcall(get, idx)
	if ok and not secret(id) and type(id) == 'number' and id > 0 then return id end
	return nil
end

local PLAYER_KICKS = {
	DEATHKNIGHT = { 47528 }, DEMONHUNTER = { 183752 }, DRUID = { 78675, 106839 },
	EVOKER = { 351338 }, HUNTER = { 187707, 147362 }, MAGE = { 2139 }, MONK = { 116705 },
	PALADIN = { 96231 }, PRIEST = { 15487 }, ROGUE = { 1766 }, SHAMAN = { 57994 },
	WARRIOR = { 6552 },
}
local WARLOCK_PET_KICKS = { { pet = 89766, poll = 119914 }, { pet = 19647, poll = 119910 } }

local function SpellKnown(id, bank)
	if not (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook) then
		return _G.IsSpellKnown and _G.IsSpellKnown(id) or false
	end
	local ok, known = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, id, bank)
	return ok and known and not secret(known) and true or false
end

local function PlayerKick()
	local class = UnitClassBase('player')
	if not class or secret(class) then return nil end
	if class == 'WARLOCK' then
		local petBank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Pet
		for _, k in ipairs(WARLOCK_PET_KICKS) do
			if petBank and SpellKnown(k.pet, petBank) then return k.pet, k.poll end
		end
		if SpellKnown(132409) then return 19647, 132409 end
		return nil
	end
	for _, id in ipairs(PLAYER_KICKS[class] or {}) do
		if SpellKnown(id) then return id, id end
	end
	return nil
end

local UNITS = { 'player', 'party1', 'party2', 'party3', 'party4' }
local CAST_OWNER = {
	player = 'player', pet = 'player',
	party1 = 'party1', partypet1 = 'party1',
	party2 = 'party2', partypet2 = 'party2',
	party3 = 'party3', partypet3 = 'party3',
	party4 = 'party4', partypet4 = 'party4',
}

local probe = {}
local function Probe(unit)
	local p = probe[unit]
	if not p then p = { plain = 0, secret = 0 } probe[unit] = p end
	return p
end
local obs = { total = 0, readable = 0, secret = 0, mine = 0, guessed = 0, unmatched = 0, meter = 0, confirmed = 0, named = 0, unconfirmed = 0,
	read = 0, sure = 0, moved = 0, area = 0, extra = 0, drawn = 0, layers = 0, nobody = 0, fell = 0, late = 0, dropped = 0 }

local SLOTS = 10
local stack = { REACH = 120, OUT = 3, HIGH = 24, ROOM = 4 }
local mtr = { by = {}, cur = {}, grown = {}, named = {}, plateSeen = {}, plateN = 0, PAIR = 0.25, OWN = 1, SLACK = 1.5 }

local PARTY_UNITS = { 'party1', 'party2', 'party3', 'party4' }

local function MemberCd(row)
	local spell = row.spell
	if spell and KICKS[spell] then return row.cd or KICKS[spell].cd end
	return GetCfg().partyCd or 15
end

local frame
local rows = {}
local pool = {}
local shown = {}
local previewActive = false
local specByGUID = {}
local members = {}

local BUNDLED_BAR = 'Interface\\Buttons\\WHITE8X8' -- dodo: 바 텍스처
local barTexPath
local barTexMiss, barTexWatched = false, false

local function BarTex()
	local chosen = ns.BarTexture(BUNDLED_BAR)
	if chosen ~= BUNDLED_BAR then return chosen end
	if barTexPath then return barTexPath end
	if barTexMiss then return BUNDLED_BAR end
	local lib = ns.LSM and ns.LSM()
	local hash = lib and lib.HashTable and lib:HashTable('statusbar')
	if hash then
		for name, path in pairs(hash) do
			local plain = tostring(name):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):lower()
			if plain == 'kiraui - main' and type(path) == 'string' and path ~= '' then
				barTexPath = path
				return path
			end
		end
	end
	if lib and not barTexWatched and type(lib.RegisterCallback) == 'function' then
		barTexWatched = pcall(lib.RegisterCallback, 'dodoPartyInterruptsBarTex', 'LibSharedMedia_Registered', function(_, mediatype)
			if mediatype == 'statusbar' then barTexMiss = false end
		end) and true or false
	end
	if barTexWatched then barTexMiss = true end
	return BUNDLED_BAR
end

local function ClassRGB(class)
	local c = class and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
	if not c and class and _G.RAID_CLASS_COLORS then c = _G.RAID_CLASS_COLORS[class] end
	if c then return c.r or 0.7, c.g or 0.7, c.b or 0.7 end
	return 0.7, 0.7, 0.7
end

local function ApplyPosition()
	if not frame then return end
	local cfg = GetCfg()
	frame:ClearAllPoints()
	-- dodo: 바 그룹 좌측상단 → 파티 프레임 우측상단
	local party = ns.PartyAnchor()
	if party then
		frame:SetPoint('TOPLEFT', party, 'TOPRIGHT', cfg.px or 10, cfg.py or -16)
		return
	end
	frame:SetPoint('CENTER', UIParent, 'CENTER', cfg.x or 0, cfg.y or 0)
end

local function EnsureFrame()
	if frame then return end
	frame = CreateFrame('Frame', 'dodoPartyInterrupts', UIParent)
	frame:SetFrameStrata('MEDIUM')
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(false)
	frame:RegisterForDrag('RightButton')
	ns.MakeDraggable(frame, GetCfg, 'x', 'y', function() ApplyPosition() end)
	ns.OnGrabChange(function() frame:EnableMouse(ns.CanGrab(GetCfg(), previewActive)) end)
	frame:Hide()
end

-- dodo: 행 툴팁 (전투 중 끔)
local function RowEnter(self)
	local tip = _G.GameTooltip
	if not tip or InCombatLockdown() or type(self.spell) ~= 'number' then return end
	tip:SetOwner(self, 'ANCHOR_RIGHT')
	tip:SetSpellByID(self.spell)
	tip:Show()
end

local function RowLeave(self)
	local tip = _G.GameTooltip
	if tip and tip:IsOwned(self) then tip:Hide() end
end

local function NewRow()
	local row = CreateFrame('Frame', nil, frame)
	row:SetScript('OnEnter', RowEnter)
	row:SetScript('OnLeave', RowLeave)
	row:SetMouseClickEnabled(false)
	row.bg = row:CreateTexture(nil, 'BACKGROUND')
	row.span = CreateFrame('Frame', nil, row)
	row.rg = {}
	local clip = row
	for s = 1, SLOTS do
		clip = CreateFrame('Frame', nil, clip)
		clip:SetClipsChildren(true)
		clip:SetAllPoints(row.span)
		row.rg[s] = clip
	end
	row.base = CreateFrame('Frame', nil, clip)
	row.base:SetAllPoints(row)
	row.icon = row.base:CreateTexture(nil, 'ARTWORK')
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.mark = row.base:CreateTexture(nil, 'ARTWORK')
	row.mark:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcons')
	row.mark:Hide()
	row.ready = row.base:CreateTexture(nil, 'ARTWORK')
	row.bar = CreateFrame('StatusBar', nil, row.base)
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(1)
	row.over = CreateFrame('Frame', nil, row.base)
	row.over:SetAllPoints(row)
	row.over:SetFrameLevel(row.bar:GetFrameLevel() + 1)
	row.timer = row.over:CreateFontString(nil, 'OVERLAY')
	row.text = CreateFrame('Frame', nil, row)
	row.text:SetAllPoints()
	row.text:SetFrameLevel(row:GetFrameLevel() + 3 * SLOTS + 8)
	-- dodo: 행 하단 금속 테두리 (ResourceBar1Template 과 동일)
	row.edgeBottom = row.text:CreateTexture(nil, 'BORDER')
	row.edgeBottom:SetAtlas('_UI-Frame-Metal-EdgeBottom', true)
	row.edgeBottom:SetHeight(16)
	row.edgeBottom:SetPoint('BOTTOMLEFT', row, 'BOTTOMLEFT', 0, -2)
	row.edgeBottom:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', 0, -2)
	row.name = row.text:CreateFontString(nil, 'OVERLAY')
	row.name:SetWordWrap(false)
	return row
end

local function AcquireRow()
	local row = table.remove(pool)
	if not row then row = NewRow() end
	row.cdStart, row.cdDur, row.previewRestart = nil, nil, nil
	row.kickedTex, row.markIdx, row.previewKicked = nil, nil, nil
	return row
end

local function ReleaseRow(row)
	stack.Clear(row)
	row:Hide()
	row.cdStart, row.cdDur, row.previewRestart, row.guid, row.sureAt = nil, nil, nil, nil, nil
	row.kickedTex, row.markIdx, row.previewKicked = nil, nil, nil
	row.hasMark = nil
	row.mark:Hide()
	pool[#pool + 1] = row
end

local KICK_ICON = 'Interface\\Icons\\Ability_Kick'

local function PaintIcon(row, cfg)
	if cfg.iconSource == 'kicked' and type(row.kickedTex) ~= 'nil'
		and pcall(row.icon.SetTexture, row.icon, row.kickedTex) then
		return
	end
	local tex = row.spell and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(row.spell)
	row.icon:SetTexture(tex or KICK_ICON)
end

local function StyleRow(row, cfg)
	local h, w = cfg.height or 20, cfg.width or 180
	row:SetSize(w, h)
	local r, g, b = ClassRGB(row.class)
	local dark = cfg.darkBars and true or false
	local tex = BarTex()
	if dark then
		row.bg:SetTexture(tex)
		row.bg:SetVertexColor(0.31, 0.31, 0.31, cfg.bgAlpha or 0.6)
	else
		row.bg:SetColorTexture(r * 0.15, g * 0.15, b * 0.15, cfg.bgAlpha or 0.6)
		row.bg:SetVertexColor(1, 1, 1, 1)
	end
	row.span:ClearAllPoints()
	row.span:SetPoint('TOPLEFT', row, 'TOPLEFT', -(h + 3 + stack.ROOM), stack.HIGH / 2)
	row.span:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT', stack.OUT, -stack.HIGH / 2)
	row.mark:ClearAllPoints()
	row.mark:SetPoint('RIGHT', row, 'LEFT', -3, 0)
	row.mark:SetSize(h, h)
	row.mark:SetShown((cfg.showMark and row.hasMark) and true or false)
	local left = 0
	row.icon:ClearAllPoints()
	row.icon:SetPoint('LEFT')
	row.icon:SetSize(h, h)
	row.icon:SetShown(cfg.showIcon and true or false)
	local gap = cfg.iconGap or 2
	if cfg.showIcon then left = h + gap end
	row.bg:ClearAllPoints()
	row.bg:SetPoint('TOPLEFT', row, 'TOPLEFT', left, 0)
	row.bg:SetPoint('BOTTOMRIGHT', row, 'BOTTOMRIGHT')
	row.bar:ClearAllPoints()
	row.bar:SetPoint('TOPLEFT', left, 0)
	row.bar:SetPoint('BOTTOMRIGHT')
	local fr, fg, fb, fa = r, g, b, 1
	if dark then fr, fg, fb, fa = 0, 0, 0, cfg.darkAlpha or 1 end
	row.fr, row.fg, row.fb, row.fa, row.tex = fr, fg, fb, fa, tex
	row.bar:SetStatusBarTexture(tex)
	row.bar:SetStatusBarColor(fr, fg, fb, fa)
	row.ready:ClearAllPoints()
	row.ready:SetPoint('TOPLEFT', row.bar)
	row.ready:SetPoint('BOTTOMRIGHT', row.bar)
	row.ready:SetTexture(tex)
	row.ready:SetVertexColor(fr, fg, fb, fa)
	local font, size = ns.GetFont(), cfg.textSize or 12
	row.timer:SetFont(font, size, 'OUTLINE')
	row.timer:ClearAllPoints()
	row.timer:SetPoint('RIGHT', row.bar, 'RIGHT', -4, 0)
	row.timer:SetJustifyH('RIGHT')
	row.timer:SetShown(cfg.showTimer and true or false)
	row.name:SetFont(font, size, 'OUTLINE')
	row.name:ClearAllPoints()
	row.name:SetPoint('LEFT', row.bar, 'LEFT', 4, 0)
	row.name:SetPoint('RIGHT', row.timer, 'LEFT', -4, 0)
	row.name:SetJustifyH('LEFT')
	if dark then row.name:SetTextColor(r, g, b) else row.name:SetTextColor(1, 1, 1) end
	row.name:SetText(row.label or '')
	PaintIcon(row, cfg)
	if row.lay then
		for s = 1, SLOTS do
			if row.lay[s] then stack.Style(row, row.lay[s], cfg) end
		end
	end
end

-- dodo: 차단바 목록 전체를 감싸는 테두리 (dodoUnitframe Castbar 와 동일한 NineSlice)
local listBorder

local function PlaceListBorder(first, last, up)
	if not listBorder then
		listBorder = CreateFrame('Frame', nil, frame)
		listBorder:SetFrameLevel(frame:GetFrameLevel() + 3 * SLOTS + 20)
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
	listBorder:ClearAllPoints()
	listBorder:SetPoint('TOPLEFT', top, 'TOPLEFT', 0, 0)
	listBorder:SetPoint('BOTTOMRIGHT', bottom, 'BOTTOMRIGHT', 0, 0)
	listBorder:Show()
end

local function Layout(list)
	if not frame then return end
	local cfg = GetCfg()
	local h, w, gap = cfg.height or 20, cfg.width or 180, cfg.spacing or 2
	frame:SetSize(w, h)
	local prev
	for _, row in ipairs(list) do
		row:ClearAllPoints()
		if not prev then
			row:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
		elseif cfg.growth == 'UP' then
			row:SetPoint('BOTTOMLEFT', prev, 'TOPLEFT', 0, gap)
		else
			row:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -gap)
		end
		row.edgeBottom:Show()
		row:SetMouseMotionEnabled(cfg.tooltip == true)
		prev = row
	end
	-- dodo: 화면상 맨 아래 줄은 하단 금속 테두리 생략
	local bottom = cfg.growth == 'UP' and list[1] or prev
	if bottom then bottom.edgeBottom:Hide() end
	PlaceListBorder(list[1], prev, cfg.growth == 'UP')
end

local function ShouldShow()
	if previewActive then return true end
	local cfg = GetCfg()
	if not cfg.enable then return false end
	if #shown == 0 then return false end
	if cfg.groupOnly and not IsInGroup() then return false end
	if cfg.hideInRaid and IsInRaid() then return false end
	if cfg.dungeonOnly and not ns.InDungeon() then return false end
	return true
end

local Tick

local function StartTicker()
	if frame and not frame:GetScript('OnUpdate') then
		frame.__acc = 0
		frame:SetScript('OnUpdate', Tick)
	end
end

-- dodo: 정수 표시 (올림)
local function FormatRem(rem)
	return sformat('%d', math.ceil(rem))
end

local function PaintTime(fs, rem, last)
	local k = math.ceil(rem)
	if k ~= last then fs:SetText(FormatRem(rem)) end
	return k
end

local function StackBefore(a, b)
	local ra, rb = a.cdStart ~= nil, b.cdStart ~= nil
	if ra ~= rb then return rb end
	if ra then
		local la, lb = a.cdStart + a.cdDur, b.cdStart + b.cdDur
		if la ~= lb then return la < lb end
	else
		local ca = KICKS[a.spell] and (a.cd or KICKS[a.spell].cd) or 99
		local cb = KICKS[b.spell] and (b.cd or KICKS[b.spell].cd) or 99
		if ca ~= cb then return ca < cb end
	end
	return (a.order or 0) < (b.order or 0)
end

local function ShowRows()
	table.sort(shown, StackBefore)
	local visible = {}
	for _, row in ipairs(shown) do
		if row:IsShown() then visible[#visible + 1] = row end
	end
	Layout(visible)
	if frame then frame:SetShown(ShouldShow()) end
end

local function SetMark(row, idx)
	row.hasMark = false
	row.markIdx = idx
	if type(idx) ~= 'nil' and _G.SetRaidTargetIconTexture then
		row.hasMark = pcall(_G.SetRaidTargetIconTexture, row.mark, idx) and true or false
	end
	row.mark:SetShown((row.hasMark and GetCfg().showMark) and true or false)
end

local function SetKicked(row, tex)
	row.kickedTex = tex
	PaintIcon(row, GetCfg())
end

function stack.Busy(row)
	local lay = row.lay
	if not lay then return false end
	for s = 1, SLOTS do
		if lay[s] and lay[s].on then return true end
	end
	return false
end

function stack.Full(row, f)
	f:ClearAllPoints()
	f:SetAllPoints(row.span)
end

function stack.Not(f, L)
	f:ClearAllPoints()
	f:SetPoint('TOPLEFT', L.tally, 'TOPLEFT', 0, 0)
	f:SetPoint('BOTTOMRIGHT', L.tfill, 'BOTTOMRIGHT', 0, 0)
end

function stack.Off(row, s)
	local L = row.lay and row.lay[s]
	if not L or not L.on then return end
	L.on = false
	L.root:Hide()
	stack.Full(row, row.rg[s])
	for k = 1, SLOTS do
		local M = row.lay[k]
		if M and k ~= s then stack.Full(row, M.g[s]) end
	end
end

function stack.Clear(row)
	if not row.lay then return end
	for s = 1, SLOTS do stack.Off(row, s) end
end

function stack.Style(row, L, cfg)
	local h, w = cfg.height or 20, cfg.width or 180
	local gw = stack.REACH * (w + h + 3 + stack.ROOM + stack.OUT)
	if L.gw ~= gw then
		L.gw = gw
		pcall(L.tally.SetWidth, L.tally, gw)
	end
	L.bar:SetStatusBarTexture(row.tex or BarTex())
	L.bar:SetStatusBarColor(row.fr or 0.7, row.fg or 0.7, row.fb or 0.7, row.fa or 1)
	L.timer:SetFont(ns.GetFont(), cfg.textSize or 12, 'OUTLINE')
	L.timer:SetShown(cfg.showTimer and true or false)
	if not cfg.showIcon then L.icon:Hide() end
	if not cfg.showMark then L.mark:Hide() end
end

function stack.Layer(row, s)
	local lay = row.lay
	if not lay then lay = {} row.lay = lay end
	if lay[s] then return lay[s] end
	local L = { g = {}, row = row }
	L.root = CreateFrame('Frame', nil, row)
	L.root:SetAllPoints(row)
	L.root:SetFrameLevel(row:GetFrameLevel() + SLOTS + 4)
	L.tally = CreateFrame('StatusBar', nil, L.root)
	L.tally:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
	L.tally:SetStatusBarColor(0, 0, 0, 0)
	L.tally:SetAlpha(0)
	L.tally:SetMinMaxValues(0, 1)
	L.tally:SetValue(1)
	L.tally:SetPoint('TOPRIGHT', row.span, 'TOPRIGHT', 0, 0)
	L.tally:SetPoint('BOTTOMRIGHT', row.span, 'BOTTOMRIGHT', 0, 0)
	L.tfill = L.tally:GetStatusBarTexture()
	local f = L.root
	for t = 1, SLOTS do
		if t ~= s then
			f = CreateFrame('Frame', nil, f)
			f:SetClipsChildren(true)
			f:SetAllPoints(row.span)
			L.g[t] = f
		end
	end
	L.c = CreateFrame('Frame', nil, f)
	L.c:SetClipsChildren(true)
	L.c:SetPoint('TOPLEFT', L.tfill, 'TOPRIGHT', 0, 0)
	L.c:SetPoint('BOTTOMRIGHT', L.tally, 'BOTTOMRIGHT', 0, 0)
	L.bar = CreateFrame('StatusBar', nil, L.c)
	L.bar:SetPoint('TOPLEFT', row.bar, 'TOPLEFT', 0, 0)
	L.bar:SetPoint('BOTTOMRIGHT', row.bar, 'BOTTOMRIGHT', 0, 0)
	L.over = CreateFrame('Frame', nil, L.c)
	L.over:SetAllPoints(row)
	L.over:SetFrameLevel(L.bar:GetFrameLevel() + 1)
	L.timer = L.over:CreateFontString(nil, 'OVERLAY')
	L.timer:SetPoint('RIGHT', L.bar, 'RIGHT', -4, 0)
	L.timer:SetJustifyH('RIGHT')
	L.icon = L.c:CreateTexture(nil, 'ARTWORK')
	L.icon:SetAllPoints(row.icon)
	L.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	L.mark = L.c:CreateTexture(nil, 'ARTWORK')
	L.mark:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcons')
	L.mark:SetAllPoints(row.mark)
	L.mark:Hide()
	L.root:Hide()
	lay[s] = L
	stack.Style(row, L, GetCfg())
	return L
end

function stack.Look(L, row, mark, tex)
	local cfg = GetCfg()
	local own = cfg.iconSource == 'kicked' and type(tex) ~= 'nil' and pcall(L.icon.SetTexture, L.icon, tex)
	if not own then
		local spell = row.spell and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(row.spell)
		L.icon:SetTexture(spell or KICK_ICON)
	end
	L.icon:SetShown(cfg.showIcon and true or false)
	local marked = false
	if cfg.showMark and type(mark) ~= 'nil' and _G.SetRaidTargetIconTexture then
		marked = pcall(_G.SetRaidTargetIconTexture, L.mark, mark) and true or false
	end
	L.mark:SetShown(marked)
end

function stack.Put(row, before, after, at, dur, mark, tex)
	local lay = row.lay
	local s, old
	for k = 1, SLOTS do
		local M = lay and lay[k]
		if not (M and M.on) then s = k break end
		if not old or M.start < lay[old].start then old = k end
	end
	if not s then
		stack.Off(row, old)
		s = old
		obs.dropped = obs.dropped + 1
	end
	local L = stack.Layer(row, s)
	if not (pcall(L.tally.SetMinMaxValues, L.tally, 0, after) and pcall(L.tally.SetValue, L.tally, before)) then return false end
	for _, g in pairs(L.g) do stack.Full(row, g) end
	lay = row.lay
	for k = 1, SLOTS do
		local M = lay[k]
		if k ~= s and M and M.on then stack.Not(M.g[s], L) end
	end
	stack.Not(row.rg[s], L)
	L.on, L.start, L.dur, L.last = true, at, dur, nil
	L.bar:SetMinMaxValues(0, dur)
	L.bar:SetValue(GetTime() - at) -- dodo: 차오르는 바
	L.timer:SetText('')
	stack.Look(L, row, mark, tex)
	L.root:Show()
	if not row:IsShown() then
		row:Show()
		ShowRows()
	end
	StartTicker()
	return true, s, L
end

function stack.Step(row, now, showTimer)
	local lay = row.lay
	local busy, ended = false, false
	for s = 1, SLOTS do
		local L = lay[s]
		if L and L.on then
			local rem = L.start + L.dur - now
			if rem <= 0 then
				stack.Off(row, s)
				ended = true
			else
				L.bar:SetValue(L.dur - rem) -- dodo: 차오르는 바
				if showTimer then L.last = PaintTime(L.timer, rem, L.last) end
				busy = true
			end
		end
	end
	if ended and not busy and not row.cdStart and not previewActive and not GetCfg().showReady then
		row:Hide()
		ShowRows()
	end
	return busy
end

local function SetReady(row)
	row.cdStart, row.cdDur = nil, nil
	row.timer:SetText('')
	row.__lastText = nil
	row.bar:Hide()
	row.ready:Show()
	SetMark(row, nil)
	SetKicked(row, nil)
	if not GetCfg().showReady and not previewActive and not stack.Busy(row) then row:Hide() end
	ShowRows()
end

local function StartCooldown(row, start, dur)
	if not dur or dur <= 0 then return end
	row.cdStart, row.cdDur = start, dur
	row.bar:SetMinMaxValues(0, dur)
	row.bar:SetValue(GetTime() - start) -- dodo: 차오르는 바
	row.ready:Hide()
	row.bar:Show()
	row:Show()
	ShowRows()
	StartTicker()
end

local learnedSwept = false
local function LearnedStore()
	local db = _G.dodoDB and _G.dodoDB.partyTracker -- dodo: 저장소
	if type(db) ~= 'table' then return nil end
	if type(db.ikLearned) ~= 'table' then db.ikLearned = {} end
	local store = db.ikLearned
	if not learnedSwept then
		learnedSwept = true
		for spell, v in pairs(store) do
			local cap = KICKS[spell] and KICKS[spell].cd
			if type(v) == 'number' and cap and v > cap + 0.25 then store[spell] = nil end
		end
	end
	return store
end

local function OwnHealerCd(spell)
	local m = members.player
	return m and m.heals and KICKS[spell] and KICKS[spell].healerCd or nil
end

local function LearnLength(spell, secs)
	local store = LearnedStore()
	if not store or not spell or type(secs) ~= 'number' or secs < 3 then return end
	if OwnHealerCd(spell) then return end
	local cap = KICKS[spell] and KICKS[spell].cd
	if cap and secs > cap + 0.25 then return end
	local cur = store[spell]
	if type(cur) ~= 'number' or secs < cur then store[spell] = mfloor(secs * 2 + 0.5) / 2 end
end

local function OwnCd(spell)
	local healerCd = OwnHealerCd(spell)
	if healerCd then return healerCd, 'healer table' end
	local store = LearnedStore()
	local v = store and spell and store[spell]
	if type(v) == 'number' and v > 0 then return v, 'measured' end
	local cd = spell and KickCd(spell, false, tal.Own(), false)
	if cd then return cd, 'table' end
	return GetCfg().partyCd or 15, 'fallback'
end

local function RefreshSelf(castSpell)
	local row = rows.player
	if not row or previewActive then return end
	local poll = row.poll or row.spell
	local now = GetTime()
	local info = poll and C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(poll)
	if not info then
		if castSpell and KICKS[castSpell] and not row.cdStart then
			StartCooldown(row, now, OwnCd(castSpell))
		end
		return
	end
	local running = (info.isActive and not info.isOnGCD) and true or false
	if not running then
		if row.cdStart then SetReady(row) end
		return
	end
	local st, du = info.startTime, info.duration
	if not secret(st) and not secret(du) and type(st) == 'number' and type(du) == 'number' and du > 2 then
		LearnLength(poll, du)
		if not row.cdStart or row.cdDur ~= du or (row.cdStart - st) > 0.5 or (st - row.cdStart) > 0.5 then
			StartCooldown(row, st, du)
		end
		row.fromCast = nil
		return
	end
	if row.cdStart then return end
	StartCooldown(row, now, OwnCd(poll))
	row.fromCast = castSpell ~= nil
end

local function SelfStillDown(row, now)
	row.__pollAt = now
	local poll = row.poll or row.spell
	local info = poll and C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(poll)
	if not info then return true end
	return (info.isActive and not info.isOnGCD) and true or false
end

local function SelfEndedEarly(row, now)
	if SelfStillDown(row, now) then return false end
	local elapsed = now - row.cdStart
	if row.fromCast then LearnLength(row.poll or row.spell, elapsed) end
	row.fromCast = nil
	return true
end

local function SelfStretch(row)
	row.cdDur = row.cdDur + 0.5
	row.bar:SetMinMaxValues(0, row.cdDur)
end

Tick = function(self, elapsed)
	self.__acc = (self.__acc or 0) + elapsed
	if self.__acc < 0.05 then return end
	self.__acc = 0
	local now, busy = GetTime(), false
	local showTimer = GetCfg().showTimer
	for _, row in ipairs(shown) do
		if row.lay and stack.Step(row, now, showTimer) then busy = true end
		if row.cdStart then
			local rem = row.cdStart + row.cdDur - now
			if rem <= 0 and row.unit == 'player' and not previewActive and SelfStillDown(row, now) then
				SelfStretch(row)
				busy = true
			elseif rem <= 0 then
				if previewActive then row.previewRestart = now + 2 busy = true end
				SetReady(row)
			elseif row.unit == 'player' and not previewActive and now - (row.__pollAt or 0) >= 0.15 and SelfEndedEarly(row, now) then
				SetReady(row)
			else
				row.bar:SetValue(row.cdDur - rem) -- dodo: 차오르는 바
				if showTimer then row.__lastText = PaintTime(row.timer, rem, row.__lastText) end
				busy = true
			end
		elseif previewActive and row.previewRestart then
			if now >= row.previewRestart then
				row.previewRestart = nil
				StartCooldown(row, now, row.cd or 15)
				SetMark(row, 8)
				SetKicked(row, row.previewKicked)
			end
			busy = true
		end
	end
	if not busy then self:SetScript('OnUpdate', nil) end
end

local function Read(fn, unit)
	if not fn then return nil end
	local ok, v = pcall(fn, unit)
	if not ok or secret(v) then return nil end
	return v
end

local function MemberSpell(m)
	if m.spec and SPEC_KICK[m.spec] ~= nil then return SPEC_KICK[m.spec] or nil end
	if m.role == 'HEALER' and HEALER_NO_KICK[m.class] then return nil end
	return CLASS_KICK[m.class]
end

ns.IKKickLength = function(unit)
	if unit == 'player' then
		local spell = PlayerKick()
		return spell and KickCd(spell, Heals(SelfSpecId(), Read(UnitGroupRolesAssigned, unit)), tal.Own(), true), spell
	end
	local class = Read(UnitClassBase, unit)
	if not class then return nil end
	local guid = Read(UnitGUID, unit)
	local m = { class = class, role = Read(UnitGroupRolesAssigned, unit), spec = guid and specByGUID[guid] or nil }
	local spell = MemberSpell(m)
	return spell and KickCd(spell, Heals(m.spec, m.role), guid and tal.byGUID[guid], true), spell
end

local function WantsTalents(m)
	local kick = m.spell and KICKS[m.spell]
	return (m.guid and kick and kick.mods and not tal.byGUID[m.guid] and ns.InDungeon()) and true or false
end

local function WantsSpec(m)
	return not m.spec or WantsTalents(m)
end

local inspectQueue = {}
local inspectTicker
local QueueInspect

local function UnitForGUID(guid)
	for unit, m in pairs(members) do
		if m.guid == guid then return unit end
	end
end

local ScheduleRebuild

local function ReadSpec(unit)
	local get = C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization or _G.GetInspectSpecialization
	local spec = Read(get, unit)
	if type(spec) == 'number' and spec > 0 then return spec end
	return nil
end

local function StopInspects()
	wipe(inspectQueue)
	if inspectTicker then inspectTicker:Cancel() inspectTicker = nil end
	for _, m in pairs(members) do m.tries = nil end
end

local function InspectStep()
	if not GetCfg().enable then StopInspects() return end
	if #inspectQueue == 0 then
		if inspectTicker then inspectTicker:Cancel() inspectTicker = nil end
		return
	end
	local unit = inspectQueue[1]
	local m = members[unit]
	if not m or not WantsSpec(m) then
		table.remove(inspectQueue, 1)
		return
	end
	if m.guid and specByGUID[m.guid] and not m.spec then
		m.spec = specByGUID[m.guid]
		ScheduleRebuild()
		if not WantsTalents(m) then
			table.remove(inspectQueue, 1)
			return
		end
	end
	local tries = (m.tries or 0) + 1
	if tries > 12 then
		table.remove(inspectQueue, 1)
		C_Timer.After(30, function()
			local cur = members[unit]
			if cur and cur.guid == m.guid and WantsSpec(cur) then
				cur.tries = 0
				QueueInspect(unit)
			end
		end)
		return
	end
	local _, why = ns.SendInspect(unit)
	if why == 'wait' then return end
	table.remove(inspectQueue, 1)
	m.tries = tries
	inspectQueue[#inspectQueue + 1] = unit
end

QueueInspect = function(unit)
	for _, u in ipairs(inspectQueue) do if u == unit then return end end
	inspectQueue[#inspectQueue + 1] = unit
	if not inspectTicker and C_Timer and C_Timer.NewTicker then
		inspectTicker = C_Timer.NewTicker(1, InspectStep)
	end
end

local function OnInspectReady(guid)
	if secret(guid) then return end
	local unit = UnitForGUID(guid)
	if not unit then return end
	local m = members[unit]
	local spec = ReadSpec(unit)
	local changed = false
	if spec then
		specByGUID[guid] = spec
		if m.spec ~= spec then
			m.spec = spec
			changed = true
		end
	end
	local ranks = ns.TalentRanks(tal, m.class)
	if ranks then
		tal.byGUID[guid] = ranks
		changed = true
	end
	if changed then ScheduleRebuild() end
end

local function Rebuild()
	if previewActive or not frame then return end
	local cfg = GetCfg()
	local old = members
	members = {}
	wipe(shown)
	local keep = {}
	for idx, unit in ipairs(UNITS) do
		local isSelf = unit == 'player'
		if (not isSelf or cfg.showSelf) and UnitExists(unit) then
			local class = Read(UnitClassBase, unit)
			if class then
				local guid = Read(UnitGUID, unit)
				local m = {
					guid = guid,
					name = Read(UnitName, unit),
					class = class,
					role = Read(UnitGroupRolesAssigned, unit),
					spec = guid and specByGUID[guid] or nil,
					tries = old[unit] and old[unit].guid == guid and old[unit].tries or nil,
				}
				m.heals = Heals(isSelf and SelfSpecId() or m.spec, m.role)
				members[unit] = m
				local spell, poll
				if isSelf then
					spell, poll = PlayerKick()
				else
					spell = MemberSpell(m)
				end
				m.spell = spell
				if not isSelf and WantsSpec(m) then QueueInspect(unit) end
				-- if spell then
				if spell and not cfg.off[spell] then -- dodo: 꺼진 차단기는 행 안 만듦
					local row = rows[unit]
					if row and row.guid ~= guid then
						ReleaseRow(row)
						row = nil
					end
					if not row then
						row = AcquireRow()
						rows[unit] = row
					end
					keep[unit] = true
					row.unit, row.guid, row.class, row.order = unit, guid, class, idx
					row.label = m.name or unit
					row.spell, row.poll = spell, poll
					row.cd = KickCd(spell, m.heals, isSelf and tal.Own() or (guid and tal.byGUID[guid]), not isSelf) or 15
					StyleRow(row, cfg)
					local busy = row.cdStart ~= nil
					if busy then
						row.ready:Hide()
						row.bar:Show()
					else
						row.bar:Hide()
						row.ready:Show()
						row.timer:SetText('')
						row.__lastText = nil
					end
					row:SetShown((cfg.showReady or busy or stack.Busy(row)) and true or false)
					shown[#shown + 1] = row
				end
			end
		end
	end
	for unit, row in pairs(rows) do
		if not keep[unit] then
			ReleaseRow(row)
			rows[unit] = nil
		end
	end
	if mtr.on then mtr.Base(false) end
	ShowRows()
	RefreshSelf()
end

local rebuildPending = false
ScheduleRebuild = function()
	if rebuildPending then return end
	rebuildPending = true
	C_Timer.After(0.2, function()
		rebuildPending = false
		Rebuild()
	end)
end

local PREVIEW = {
	{ label = '플레이어', class = 'DEATHKNIGHT', spell = 47528,  kicked = 'Interface\\Icons\\Spell_Shadow_ShadowBolt' },
	{ label = '플레이어', class = 'MONK',        spell = 116705, kicked = 'Interface\\Icons\\Spell_Frost_FrostBolt02' },
	{ label = '플레이어', class = 'MAGE',        spell = 2139,   kicked = 'Interface\\Icons\\Spell_Holy_FlashHeal' },
	{ label = '플레이어', class = 'SHAMAN',      spell = 57994,  kicked = 'Interface\\Icons\\Spell_Fire_FlameBolt' },
	{ label = '플레이어', class = 'ROGUE',       spell = 1766,   kicked = 'Interface\\Icons\\Spell_Nature_Lightning' },
}

local function BuildPreview()
	local cfg = GetCfg()
	for unit, row in pairs(rows) do ReleaseRow(row) rows[unit] = nil end
	wipe(shown)
	local now = GetTime()
	for i, p in ipairs(PREVIEW) do
		local row = AcquireRow()
		rows['preview' .. i] = row
		row.unit, row.guid, row.class, row.order = nil, nil, p.class, i
		row.label, row.spell, row.poll = p.label, p.spell, nil
		row.cd = KickCd(p.spell, false, nil, true)
		row.previewKicked = p.kicked
		StyleRow(row, cfg)
		row:Show()
		shown[#shown + 1] = row
		if i == 1 then
			row.bar:Hide()
			row.ready:Show()
			row.previewRestart = now + 3
		else
			StartCooldown(row, now - (i - 1) * 2.5, row.cd)
			SetMark(row, 10 - i)
			SetKicked(row, p.kicked)
		end
	end
	ShowRows()
	StartTicker()
end

local function SetPreview(on)
	on = on and true or false
	if on == previewActive then return end
	previewActive = on
	EnsureFrame()
	if on then
		BuildPreview()
	else
		for unit, row in pairs(rows) do ReleaseRow(row) rows[unit] = nil end
		wipe(shown)
		Rebuild()
	end
	frame:EnableMouse(ns.CanGrab(GetCfg(), previewActive))
	frame:SetShown(ShouldShow())
end
ns.IKIsPreview = function() return previewActive end

-- dodo: 주문 목록 (/dd 전투 > 파티 주문 추적 > 주문 목록)
local KICK_IDS = {}
for id in pairs(KICKS) do KICK_IDS[#KICK_IDS + 1] = id end
table.sort(KICK_IDS, function(a, b)
	if KICKS[a].class ~= KICKS[b].class then return KICKS[a].class < KICKS[b].class end
	return a < b
end)

ns.IKSpells = function()
	local off, out = GetCfg().off, {}
	for _, id in ipairs(KICK_IDS) do
		out[#out + 1] = { id = id, class = KICKS[id].class, cd = KICKS[id].cd, off = off[id] and true or false }
	end
	return out
end

ns.IKSetShown = function(id, on)
	if not KICKS[id] then return end
	GetCfg().off[id] = (not on) and true or nil
	ScheduleRebuild()
end
ns.IKSetPreview = SetPreview

local function Apply()
	EnsureFrame()
	local cfg = GetCfg()
	ApplyPosition()
	frame:EnableMouse(ns.CanGrab(cfg, previewActive))
	if not cfg.enable then
		if previewActive then SetPreview(false) end
		for unit, row in pairs(rows) do ReleaseRow(row) rows[unit] = nil end
		wipe(shown)
		StopInspects()
		frame:Hide()
		return
	end
	stack.Check()
	if previewActive then
		for _, row in ipairs(shown) do StyleRow(row, cfg) end
		ShowRows()
	else
		Rebuild()
	end
end

local lastSelfKickAt = -10
local selfClaimKick = -20
local lastObservedAt = -10
local lastObservedUnit
local lastGuessRow, lastGuessAt = nil, -10

local function MarkSelf(mark, tex)
	local row = rows.player
	if row then
		C_Timer.After(0, function()
			if row.cdStart then
				SetMark(row, mark)
				SetKicked(row, tex)
			end
		end)
	end
end

local function OnCast(unit, spellID)
	local owner = CAST_OWNER[unit]
	if not owner then return end
	local p = Probe(unit)
	if secret(spellID) then
		p.secret = p.secret + 1
		p.lastAt = GetTime()
		return
	end
	p.plain = p.plain + 1
	p.last, p.lastAt = spellID, GetTime()
	local kick = KICKS[spellID]
	if not kick then return end
	local handed, handMark, handTex
	if owner == 'player' then
		lastSelfKickAt = GetTime()
		if lastGuessRow and GetTime() - lastGuessAt < 0.4 then
			handed, handMark, handTex = true, lastGuessRow.markIdx, lastGuessRow.kickedTex
			SetReady(lastGuessRow)
			obs.guessed = obs.guessed - 1
			obs.mine = obs.mine + 1
			lastGuessRow = nil
			selfClaimKick = lastSelfKickAt
		elseif mtr.last and not mtr.last.taken and GetTime() - mtr.last.at < 0.4 then
			local h = mtr.last
			h.taken = true
			handed, handMark, handTex = true, h.mark, h.tex
			obs.mine = obs.mine + 1
			selfClaimKick = lastSelfKickAt
		end
	end
	if not GetCfg().enable or previewActive then return end
	local row = rows[owner]
	if not row or row.class ~= kick.class then return end
	if owner == 'player' then
		C_Timer.After(0, function() RefreshSelf(spellID) end)
		if handed then MarkSelf(handMark, handTex) end
		return
	end
	local iconSpell = kick.icon or spellID
	if row.spell ~= iconSpell then
		row.spell = iconSpell
		row.cd = KickCd(spellID, members[owner] and members[owner].heals, row.guid and tal.byGUID[row.guid], true)
		if members[owner] then members[owner].spell = iconSpell end
		StyleRow(row, GetCfg())
	end
	lastObservedAt, lastObservedUnit = GetTime(), owner
	stack.Clear(row)
	row.sureAt = GetTime()
	StartCooldown(row, GetTime(), MemberCd(row))
end

local function OwnerOfGUID(guid)
	local owner = UnitForGUID(guid)
	if owner then return owner end
	for _, unit in ipairs(PARTY_UNITS) do
		if members[unit] and Read(UnitGUID, 'partypet' .. unit:sub(-1)) == guid then return unit end
	end
	if Read(UnitGUID, 'pet') == guid then return 'player' end
	return nil
end

local SESSIONS = { 'Current', 'Overall' }
local meterSnap = {}
local lastMeterLists = {}
local specIconCache = {}

local function SpecIcon(specID)
	if not specID then return nil end
	local cached = specIconCache[specID]
	if cached ~= nil then return cached or nil end
	local get = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID or _G.GetSpecializationInfoByID
	local ok, _, _, _, icon = pcall(get, specID)
	if not ok or secret(icon) or type(icon) ~= 'number' then icon = false end
	specIconCache[specID] = icon
	return icon or nil
end

local function ShortName(n)
	return (tostring(n):gsub('%-.*$', ''))
end

local function ReadMeterList(sessionType)
	local DM, E = _G.C_DamageMeter, _G.Enum
	if not (DM and DM.GetCombatSessionFromType and E and E.DamageMeterType and E.DamageMeterType.Interrupts) then return nil end
	local ok, session = pcall(DM.GetCombatSessionFromType, sessionType, E.DamageMeterType.Interrupts)
	if not ok or type(session) ~= 'table' or type(session.combatSources) ~= 'table' then return nil end
	local list, seen = {}, {}
	for _, src in ipairs(session.combatSources) do
		if type(src) == 'table' then
			local class = src.classFilename
			if secret(class) or type(class) ~= 'string' or class == '' then class = nil end
			if class then
				local me = src.isLocalPlayer
				if secret(me) then me = nil else me = me and true or false end
				local icon = src.specIconID
				if secret(icon) or type(icon) ~= 'number' then icon = nil end
				local name = src.name
				if secret(name) or type(name) ~= 'string' or name == '' then name = nil end
				local key = name and ShortName(name) or (class .. ':' .. tostring(icon) .. (me and ':me' or ''))
				seen[key] = (seen[key] or 0) + 1
				if seen[key] > 1 then key = key .. '#' .. seen[key] end
				list[#list + 1] = { key = key, class = class, icon = icon, me = me, name = name }
			end
		end
	end
	return list
end

local function MatchMember(e, out)
	local n = 0
	for _, unit in ipairs(UNITS) do
		local m = members[unit]
		local isMe = unit == 'player'
		local okUnit = e.me ~= nil and e.me and isMe
		if not okUnit and m and m.class == e.class then
			okUnit = e.me == nil or (e.me == isMe)
			if okUnit and e.name and m.name and ShortName(e.name) ~= ShortName(m.name) then okUnit = false end
			if okUnit and e.icon and m.spec then
				local icon = SpecIcon(m.spec)
				if icon and icon ~= e.icon then okUnit = false end
			end
		end
		if okUnit and not out[unit] then
			out[unit] = true
			n = n + 1
		end
	end
	return n
end

local function DiffMeter(sessionType)
	local list = ReadMeterList(sessionType)
	if not list then return nil end
	local old = meterSnap[sessionType]
	meterSnap[sessionType] = list
	if not old then return nil, list end
	local oldIdx = {}
	for i, e in ipairs(old) do oldIdx[e.key] = i end
	local newcomer, climber, nNew, nClimb = nil, nil, 0, 0
	for i, e in ipairs(list) do
		local o = oldIdx[e.key]
		if not o then
			newcomer, nNew = e, nNew + 1
		elseif i < o then
			climber, nClimb = e, nClimb + 1
		end
	end
	if nNew == 1 then return newcomer, list end
	if nNew == 0 and nClimb == 1 then return climber, list end
	return nil, list
end

local function MeterKicker()
	local E = _G.Enum
	local ST = E and E.DamageMeterSessionType
	if not ST then return nil, nil end
	local cands = {}
	local narrowed = false
	local owner, ownerSet, via
	for _, name in ipairs(SESSIONS) do
		local st = ST[name]
		if st then
			local e, list = DiffMeter(st)
			lastMeterLists[name] = list
			if owner then
				e = nil
			elseif e then
				local mine = {}
				if MatchMember(e, mine) == 1 then
					owner, ownerSet, via = next(mine), mine, name
				elseif next(mine) and not narrowed then
					cands, narrowed = mine, true
				end
			elseif list and not narrowed then
				for _, entry in ipairs(list) do MatchMember(entry, cands) end
			end
		end
	end
	if owner then return owner, ownerSet, via end
	if not next(cands) then cands = nil end
	return nil, cands, nil
end

local function GuessKicker(cands, allowBusy)
	local best
	for _, unit in ipairs(PARTY_UNITS) do
		local row = rows[unit]
		if row and (allowBusy or not row.cdStart) and (not cands or cands[unit]) and (not best or StackBefore(row, best)) then best = row end
	end
	return best
end

local pendings, meterHits = {}, {}

local function CloserToOwnKick(at)
	local d = mabs(at - lastSelfKickAt)
	for _, q in ipairs(pendings) do
		if mabs(q.at - lastSelfKickAt) < d then return true end
	end
	return false
end

local function ChargeRow(row, at, mark, tex)
	StartCooldown(row, at, MemberCd(row))
	SetMark(row, mark)
	SetKicked(row, tex)
end

local function Guess(at, mark, cands, tex)
	local row = GuessKicker(cands)
	if not row and cands then row = GuessKicker(cands, true) or GuessKicker(nil) end
	if not row then
		obs.unmatched = obs.unmatched + 1
		lastObservedUnit = nil
		return
	end
	obs.guessed = obs.guessed + 1
	lastObservedUnit = row.unit
	lastGuessRow, lastGuessAt = row, at
	ChargeRow(row, at, mark, tex)
end

local function Sure(row, at, mark, tex)
	stack.Clear(row)
	row.sureAt = at
	lastObservedAt, lastObservedUnit = at, row.unit
	ChargeRow(row, at, mark, tex)
end

local function Charge(at, owner, mark, cands, tex)
	if owner then
		if owner == 'player' then RefreshSelf() MarkSelf(mark, tex) return end
		local row = rows[owner]
		if row then Sure(row, at, mark, tex) else lastObservedAt, lastObservedUnit = at, owner end
		return
	end
	lastObservedAt = at
	if lastSelfKickAt ~= selfClaimKick and mabs(at - lastSelfKickAt) < 0.8 and not CloserToOwnKick(at) then
		selfClaimKick = lastSelfKickAt
		obs.mine = obs.mine + 1
		lastObservedUnit = 'player'
		MarkSelf(mark, tex)
		return
	end
	Guess(at, mark, cands, tex)
end

function stack.Check()
	if stack.ok ~= nil or stack.checking then return end
	local t = stack.test
	if not t then
		local host = CreateFrame('Frame', nil, UIParent)
		host:SetSize(1, 1)
		host:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', 0, 0)
		host:SetAlpha(0)
		local bar = CreateFrame('StatusBar', nil, host)
		bar:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
		bar:SetSize(1000, 1)
		bar:SetPoint('BOTTOMLEFT', host, 'BOTTOMLEFT', 0, 0)
		local c = CreateFrame('Frame', nil, host)
		c:SetPoint('TOPLEFT', bar:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		c:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT', 0, 0)
		t = { bar = bar, c = c }
		stack.test = t
	end
	local function Width()
		local l, r = t.c:GetLeft(), t.c:GetRight()
		if type(l) ~= 'number' or type(r) ~= 'number' or secret(l) or secret(r) then return nil end
		return r - l
	end
	if not (pcall(t.bar.SetMinMaxValues, t.bar, 0, 2) and pcall(t.bar.SetValue, t.bar, 1)) then
		stack.ok, stack.why = false, 'a bar refused the values'
		return
	end
	stack.checking = true
	C_Timer.After(0.1, function()
		local open = Width()
		pcall(t.bar.SetMinMaxValues, t.bar, 0, 3)
		pcall(t.bar.SetValue, t.bar, 3)
		C_Timer.After(0.1, function()
			stack.checking = false
			local shut = Width()
			if not open or not shut then
				stack.ok, stack.why = false, 'the clip edge could not be read'
			elseif mabs(open - 500) > 2 or mabs(shut) > 2 then
				stack.ok, stack.why = false, sformat('the clip measured %.1f and %.1f, wanted 500 and 0', open, shut)
			else
				stack.ok, stack.why = true, nil
			end
		end)
	end)
end

local lastEventAt = -10
local lastMeterOwner, lastMeterVia

mtr.TYPE = _G.Enum and _G.Enum.DamageMeterType and _G.Enum.DamageMeterType.Interrupts

function mtr.Usable()
	local DM, E = _G.C_DamageMeter, _G.Enum
	local ST = E and E.DamageMeterSessionType
	return (DM and DM.GetCombatSessionSourceFromType and ST and ST.Current and mtr.TYPE) and true or false
end

function mtr.Take(out, guid, unit)
	local ok, d = pcall(_G.C_DamageMeter.GetCombatSessionSourceFromType, _G.Enum.DamageMeterSessionType.Current, mtr.TYPE, guid)
	if not ok then
		mtr.why = 'the read was refused: ' .. tostring(d)
		return
	end
	local hiddenTable = _G.issecrettable
	if type(d) ~= 'table' or secret(d) or (hiddenTable and hiddenTable(d)) then
		mtr.why = 'the answer was hidden'
		return
	end
	local spells = d.combatSpells
	if type(spells) ~= 'table' or secret(spells) or (hiddenTable and hiddenTable(spells)) then
		mtr.why = 'the spell list was hidden'
		return
	end
	out[guid] = { n = #spells, a = d.totalAmount, unit = unit }
end

function mtr.Read()
	local cur = mtr.cur
	wipe(cur)
	if not mtr.Usable() then
		mtr.why = 'this client has no per-member meter read'
		return nil
	end
	local asked = false
	for i, unit in ipairs(PARTY_UNITS) do
		local m = members[unit]
		if m and m.guid then
			asked = true
			mtr.Take(cur, m.guid, unit)
			if m.class == 'WARLOCK' then
				local pet = Read(UnitGUID, 'partypet' .. i)
				if pet then mtr.Take(cur, pet, unit) end
			end
		end
	end
	if asked and next(cur) == nil then return nil end
	return cur
end

function mtr.Fell(cur, prev)
	for g, c in pairs(cur) do
		local p = prev[g]
		if p and c.n < p.n then return true end
	end
	return false
end

function mtr.Base(force)
	local cur = mtr.Read()
	if not cur then return end
	if not force then
		if not mtr.Fell(cur, mtr.by) then
			for g, c in pairs(cur) do
				if not mtr.by[g] then mtr.by[g] = c end
			end
			return
		end
	end
	mtr.by, mtr.cur = cur, mtr.by
end

function mtr.Down(row, now)
	return (row.sureAt and now - row.sureAt < MemberCd(row) - mtr.SLACK) and true or false
end

function mtr.Stops(now)
	local n, mark, tex, owners = 0, nil, nil, nil
	local i = 1
	while pendings[i] do
		local p = pendings[i]
		if mabs(p.at - now) <= mtr.PAIR then
			table.remove(pendings, i)
			n = n + 1
			if n == 1 then mark, tex = p.mark, p.icon end
			if p.owner then
				owners = owners or {}
				owners[#owners + 1] = p.owner
			end
		else
			i = i + 1
		end
	end
	return n, mark, tex, owners
end

function mtr.Update(now)
	local cur = mtr.Read()
	if not cur then return false end
	obs.read = obs.read + 1
	local prev = mtr.by
	local fell = mtr.Fell(cur, prev)
	local grown, named = mtr.grown, mtr.named
	wipe(grown)
	wipe(named)
	local nGrown = 0
	for g, c in pairs(cur) do
		local p = prev[g]
		local before = fell and 0 or (p and p.n)
		if before and c.n > before then
			if not grown[c.unit] then nGrown = nGrown + 1 end
			grown[c.unit] = (grown[c.unit] or 0) + c.n - before
		end
	end
	local stops, mark, tex, owners = mtr.Stops(now)
	local plates = (mtr.plateAt and now >= mtr.plateAt and now - mtr.plateAt <= mtr.PAIR) and mtr.plateN or 0
	local h = { at = now, mark = mark, tex = tex, marked = stops > 0, rows = {}, layers = {} }
	local mine = false
	if owners then
		for _, u in ipairs(owners) do
			if u == 'player' then mine = true
			elseif rows[u] then named[u] = 'sure' end
		end
	end
	for unit, d in pairs(grown) do
		local row = rows[unit]
		if row and not named[unit] then
			if d > 1 or (nGrown == 1 and plates > 1) then
				named[unit] = 'area'
				obs.area = obs.area + 1
			elseif mtr.Down(row, now) then
				named[unit] = 'extra'
				obs.extra = obs.extra + 1
			else
				named[unit] = 'sure'
			end
		end
	end
	local moved, cands, via = MeterKicker()
	lastMeterOwner, lastMeterVia = moved, via
	if nGrown == 0 and not owners and moved and moved ~= 'player' and rows[moved] and not mtr.Down(rows[moved], now) then
		named[moved] = 'sure'
		obs.moved = obs.moved + 1
	end
	local placed = false
	for unit, why in pairs(named) do
		if why == 'sure' then
			Sure(rows[unit], now, mark, tex)
			obs.sure = obs.sure + 1
			h.rows[#h.rows + 1] = rows[unit]
			placed = true
		end
	end
	local pending = lastSelfKickAt ~= selfClaimKick and now - lastSelfKickAt <= mtr.OWN and now >= lastSelfKickAt - 0.05
	if mine or (pending and not placed) then
		if pending then selfClaimKick = lastSelfKickAt end
		obs.mine = obs.mine + 1
		h.self, h.taken = true, true
		MarkSelf(mark, tex)
	end
	local drew = 0
	if stack.ok == true then
		for g, c in pairs(cur) do
			local unit = c.unit
			local row = rows[unit]
			local p = prev[g]
			if row and not named[unit] and not fell and p and p.n >= 1 and type(p.a) ~= 'nil' and type(c.a) ~= 'nil'
				and not mtr.Down(row, now) then
				local ok, _, L = stack.Put(row, p.a, c.a, now, MemberCd(row), mark, tex)
				if ok then
					drew = drew + 1
					h.layers[#h.layers + 1] = L
				else
					mtr.why = 'a timer bar refused the hidden counts'
				end
			end
		end
	end
	mtr.by, mtr.cur = cur, prev
	if drew > 0 then
		obs.drawn = obs.drawn + 1
		obs.layers = obs.layers + drew
	elseif not placed and not h.self then
		if stack.ok ~= true and not fell then
			obs.fell = obs.fell + 1
			Guess(now, mark, cands, tex)
		else
			obs.nobody = obs.nobody + 1
		end
	end
	mtr.last = h
	return true
end

function mtr.Attach(now, mark, tex)
	local h = mtr.last
	if not h or h.marked or now < h.at or now - h.at > mtr.PAIR then return false end
	h.marked, h.mark, h.tex = true, mark, tex
	obs.late = obs.late + 1
	if h.self then MarkSelf(mark, tex) end
	for _, row in ipairs(h.rows) do
		SetMark(row, mark)
		SetKicked(row, tex)
	end
	for _, L in ipairs(h.layers) do
		if L.on and L.start == h.at then stack.Look(L, L.row, mark, tex) end
	end
	return true
end

local function Expire(list, now, onDrop)
	while list[1] and now - list[1].at > 1.5 do
		local e = table.remove(list, 1)
		if onDrop then onDrop(e) end
	end
end

local function DropUnconfirmed()
	obs.unconfirmed = obs.unconfirmed + 1
end

local function Pair(now)
	Expire(pendings, now, DropUnconfirmed)
	Expire(meterHits, now)
	while pendings[1] and meterHits[1] do
		local p, h = pendings[1], meterHits[1]
		local gap = p.at - h.at
		if gap > 1 then
			table.remove(meterHits, 1)
		elseif gap < -1 then
			table.remove(pendings, 1)
			DropUnconfirmed()
		else
			table.remove(pendings, 1)
			table.remove(meterHits, 1)
			obs.confirmed = obs.confirmed + 1
			local owner = p.owner
			if not owner and h.owner then
				owner = h.owner
				obs.named = obs.named + 1
			end
			Charge(p.at, owner, p.mark, h.cands, p.icon)
		end
	end
end

local function OnEnemyInterrupted(unit, spellID, interruptedBy)
	if type(unit) ~= 'string' or secret(unit) then return end
	if CAST_OWNER[unit] then return end
	if ns.Ask(_G.UnitCanAttack, 'player', unit) == false then return end
	obs.total = obs.total + 1
	local cfg = GetCfg()
	if not cfg.enable or not cfg.observe or previewActive then return end
	local now = GetTime()
	if unit:find('^nameplate%d') then
		if mtr.plateAt ~= now then
			mtr.plateAt, mtr.plateN = now, 0
			wipe(mtr.plateSeen)
		end
		if not mtr.plateSeen[unit] then
			mtr.plateSeen[unit] = true
			mtr.plateN = mtr.plateN + 1
		end
	end
	local owner
	if not secret(interruptedBy) and interruptedBy ~= nil then
		obs.readable = obs.readable + 1
		owner = OwnerOfGUID(interruptedBy)
		if not owner then return end
	else
		obs.secret = obs.secret + 1
	end
	if now - lastEventAt < 0.02 then return end
	if owner and now - lastObservedAt < 0.5 and lastObservedUnit == owner then return end
	lastEventAt = now
	local mark
	if cfg.showMark and GetRaidTargetIndex then
		local ok, idx = pcall(GetRaidTargetIndex, unit)
		if ok then mark = idx end
	end
	local icon
	if cfg.showIcon and C_Spell and C_Spell.GetSpellTexture then
		local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
		if ok then icon = tex end
	end
	if cfg.meterConfirm then
		if mtr.Attach(now, mark, icon) then return end
		pendings[#pendings + 1] = { at = now, owner = owner, mark = mark, icon = icon }
		Pair(now)
	else
		Charge(now, owner, mark, nil, icon)
	end
end

local lastMeterAt = -10

local function OnMeterUpdate(dmType)
	if not mtr.TYPE or secret(dmType) or dmType ~= mtr.TYPE then return end
	local now = GetTime()
	if now == lastMeterAt then return end
	lastMeterAt = now
	obs.meter = obs.meter + 1
	local cfg = GetCfg()
	if not cfg.observe or previewActive then
		MeterKicker()
		mtr.Base(true)
		return
	end
	if mtr.Update(now) then return end
	obs.fell = obs.fell + 1
	local owner, cands, via = MeterKicker()
	lastMeterOwner, lastMeterVia = owner, via
	meterHits[#meterHits + 1] = { at = now, owner = owner, cands = cands }
	Pair(now)
end

local castFrames = {}
for unit in pairs(CAST_OWNER) do
	local f = CreateFrame('Frame')
	f.unit = unit
	f:SetScript('OnEvent', function(_, _, _, _, spellID) OnCast(unit, spellID) end)
	castFrames[#castFrames + 1] = f
end

local evt = CreateFrame('Frame')
evt:RegisterEvent('PLAYER_ENTERING_WORLD')
evt:RegisterEvent('GROUP_ROSTER_UPDATE')
evt:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
evt:RegisterEvent('INSPECT_READY')
evt:RegisterEvent('SPELLS_CHANGED')
evt:RegisterUnitEvent('UNIT_NAME_UPDATE', 'party1', 'party2', 'party3', 'party4')
evt:RegisterUnitEvent('UNIT_PET', 'player')
evt:RegisterEvent('DAMAGE_METER_RESET')

local LIVE_EVENTS = { 'SPELL_UPDATE_COOLDOWN', 'UNIT_SPELLCAST_INTERRUPTED',
	'UNIT_SPELLCAST_CHANNEL_STOP' }
local METER_EVENT = 'DAMAGE_METER_COMBAT_SESSION_UPDATED'
local listening, listeningMeter
local function SyncEvents()
	local cfg = GetCfg()
	local on = cfg.enable and true or false
	local meter = on and cfg.meterConfirm and true or false
	if meter ~= listeningMeter then
		listeningMeter = meter
		if meter then
			wipe(meterSnap)
			evt:RegisterEvent(METER_EVENT)
			evt:RegisterEvent('DAMAGE_METER_CURRENT_SESSION_UPDATED')
			evt:RegisterEvent('PLAYER_REGEN_DISABLED')
			mtr.on = true
			mtr.Base(true)
		else
			evt:UnregisterEvent(METER_EVENT)
			evt:UnregisterEvent('DAMAGE_METER_CURRENT_SESSION_UPDATED')
			evt:UnregisterEvent('PLAYER_REGEN_DISABLED')
			mtr.on = false
		end
	end
	if on == listening then return end
	listening = on
	for _, e in ipairs(LIVE_EVENTS) do
		if on then evt:RegisterEvent(e) else evt:UnregisterEvent(e) end
	end
	for _, f in ipairs(castFrames) do
		if on then f:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', f.unit)
		else f:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED') end
	end
end
ns.IKApply = function()
	Apply()
	SyncEvents()
end

local QueueSelf = ns.Coalesce(function() RefreshSelf() end)

evt:SetScript('OnEvent', function(_, event, arg1, arg2, arg3, arg4)
	if event == 'DAMAGE_METER_COMBAT_SESSION_UPDATED' then
		OnMeterUpdate(arg1)
	elseif event == 'DAMAGE_METER_CURRENT_SESSION_UPDATED' then
		mtr.Base(false)
	elseif event == 'PLAYER_REGEN_DISABLED' then
		mtr.Base(false)
		C_Timer.After(0.5, function() if mtr.on then mtr.Base(false) end end)
	elseif event == 'DAMAGE_METER_RESET' then
		wipe(meterSnap)
		if listeningMeter then mtr.Base(true) end
	elseif event == 'UNIT_SPELLCAST_INTERRUPTED' then
		OnEnemyInterrupted(arg1, arg3, arg4)
	elseif event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
		if secret(arg4) or arg4 ~= nil then OnEnemyInterrupted(arg1, arg3, arg4) end
	elseif event == 'PLAYER_ENTERING_WORLD' then
		if not stack.checking then stack.ok = nil end
		if ns.InDungeon() and not (ns.KeyActive and ns.KeyActive()) then wipe(tal.byGUID) end
		Apply()
		SyncEvents()
		if listeningMeter then mtr.Base(true) end
	elseif event == 'INSPECT_READY' then
		OnInspectReady(arg1)
	elseif event == 'SPELL_UPDATE_COOLDOWN' then
		if GetCfg().enable then QueueSelf() end
	elseif event == 'PLAYER_SPECIALIZATION_CHANGED' then
		if type(arg1) == 'string' and not secret(arg1) and arg1 ~= 'player' then
			local m = members[arg1]
			if m and m.guid then
				specByGUID[m.guid] = nil
				tal.byGUID[m.guid] = nil
			end
		end
		if GetCfg().enable then ScheduleRebuild() end
	else
		if GetCfg().enable then ScheduleRebuild() end
	end
end)

_G.SLASH_DODOPTKICK1 = '/ptkick'
_G.SlashCmdList.DODOPTKICK = function()
	local cfg = GetCfg()
	local restr = _G.C_Secrets and _G.C_Secrets.HasSecretRestrictions and _G.C_Secrets.HasSecretRestrictions()
	ns.Msg(sformat('Interrupts: %s, %s, preview %s, secret restrictions %s, only in dungeons %s (%s)',
		cfg.enable and 'enabled' or 'disabled',
		IsInGroup() and (IsInRaid() and 'in a raid' or 'in a party') or 'solo',
		previewActive and 'on' or 'off',
		tostring(restr),
		cfg.dungeonOnly and 'on' or 'off',
		ns.InDungeon() and 'in a dungeon' or 'not in a dungeon'))
	local now = GetTime()
	for _, unit in ipairs(UNITS) do
		local m = members[unit]
		if m then
			local row = rows[unit]
			local state = 'ready'
			if row and row.cdStart then state = sformat('%.1fs left', row.cdStart + row.cdDur - now) end
			local cdText
			if unit == 'player' then
				local poll = row and (row.poll or row.spell)
				local secs, from = OwnCd(poll)
				local info = poll and C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(poll)
				local live
				if not info then live = 'no cooldown info'
				elseif secret(info.startTime) or secret(info.duration) then live = 'numbers hidden now'
				else live = sformat('numbers readable now (duration %s)', tostring(info.duration)) end
				cdText = sformat('own: real read when allowed, else %gs (%s); %s', secs, from, live)
			elseif row then
				cdText = sformat('%gs (%s)', MemberCd(row), m.guid and tal.byGUID[m.guid] and 'from their talents' or 'common talents assumed')
			else cdText = '-' end
			local seen = unit ~= 'player' and m.guid and mtr.by[m.guid]
			ns.Msg(sformat('  %s: %s %s role=%s spec=%s kick=%s uses %s, %s%s%s%s',
				unit, tostring(m.name), tostring(m.class), tostring(m.role), tostring(m.spec),
				tostring(m.spell), cdText,
				m.spell and state or 'no interrupt',
				seen and sformat(' | meter: %d enemy spells kicked this fight', seen.n) or '',
				not m.spec and unit ~= 'player' and ' (spec pending)' or '',
				unit ~= 'player' and WantsTalents(m) and ' (talents pending)' or ''))
		end
	end
	ns.Msg(sformat('  casts ended early %d (%d named the kicker, %d secret, %d never confirmed), meter interrupts %d, confirmed %d: %d named by the meter, %d guessed, %d yours, %d unmatched%s',
		obs.total, obs.readable, obs.secret, obs.unconfirmed, obs.meter, obs.confirmed, obs.named, obs.guessed, obs.mine, obs.unmatched,
		cfg.meterConfirm and '' or ' (meter confirmation off)'))
	ns.Msg(sformat('  waiting: %d cast-ended events, %d meter hits', #pendings, #meterHits))
	ns.Msg(sformat('  kicker read from the meter count of each member: %s | timer layers: %s',
		mtr.Usable() and (mtr.on and 'listening' or 'off (meter confirmation off or disabled)') or 'not on this client',
		stack.ok == true and 'check passed' or stack.ok == false and ('check failed: ' .. tostring(stack.why)) or 'not checked yet'))
	ns.Msg(sformat('  meter updates read %d: named for sure %d (%d by the meter row moving), extra interrupts not counted %d, area interrupts not counted %d, drawn by the game %d (%d timers), nobody to draw %d, guessed %d, marks that came late %d, oldest timer dropped %d%s',
		obs.read, obs.sure, obs.moved, obs.extra, obs.area, obs.drawn, obs.layers, obs.nobody, obs.fell, obs.late, obs.dropped,
		mtr.why and (' | last problem: ' .. tostring(mtr.why)) or ''))
	do
		local store = LearnedStore()
		local poll = rows.player and (rows.player.poll or rows.player.spell)
		if store and poll then
			ns.Msg(sformat('  own kick %d: measured %s, table %s', poll, tostring(store[poll]), tostring(OwnHealerCd(poll) or KickCd(poll, false, tal.Own(), false))))
		end
	end
	ns.Msg(sformat('  last meter hit: %s', lastMeterOwner and sformat('%s via the %s list', lastMeterOwner, tostring(lastMeterVia)) or 'kicker not readable from the lists'))
	for _, name in ipairs(SESSIONS) do
		local list = lastMeterLists[name]
		if list then
			local parts = {}
			for i, e in ipairs(list) do
				local units = {}
				MatchMember(e, units)
				local names = {}
				for unit in pairs(units) do names[#names + 1] = unit end
				table.sort(names)
				parts[#parts + 1] = sformat('%d. %s%s -> %s', i, e.key, e.name and '' or ' (name hidden)', #names > 0 and table.concat(names, '/') or '?')
			end
			ns.Msg(sformat('  %s interrupt list: %s', name, #parts > 0 and table.concat(parts, '; ') or 'empty'))
		else
			ns.Msg(sformat('  %s interrupt list: not read yet', name))
		end
	end
	local any = false
	for unit, p in pairs(probe) do
		any = true
		ns.Msg(sformat('  casts from %s: %d readable, %d secret%s', unit, p.plain, p.secret,
			p.last and sformat(', last readable spell %d', p.last) or ''))
	end
	if not any then ns.Msg('  no cast events received yet') end
end
