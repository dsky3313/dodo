local _, ns = ...
local hooksecurefunc, C_Timer = ns.Probe('PartyCC', hooksecurefunc, C_Timer)
local _G = _G

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime
local UnitExists = UnitExists
local UnitCanAttack, UnitCanAssist = UnitCanAttack, UnitCanAssist
local UnitIsDeadOrGhost, UnitAffectingCombat = UnitIsDeadOrGhost, UnitAffectingCombat
local IsInGroup, IsInRaid = IsInGroup, IsInRaid
local InCombatLockdown = InCombatLockdown
local ipairs, pairs, pcall, type, tostring, tonumber, next = ipairs, pairs, pcall, type, tostring, tonumber, next
local mmax, mmin, floor = math.max, math.min, math.floor
local tremove = table.remove
local format = string.format
local wipe = wipe

local secret = ns.IsSecret
local Ask = ns.Ask
local kit = ns.PTCKit

local HAS_WIDGETS = (ns.IS_121 and ns.HasTemplate('CustomAuraContainerTemplate')) and true or false

local function Unavailable()
	return not (kit and HAS_WIDGETS and not ns.PTCUnavailable)
end

ns.hasPartyCC = true
ns.CCUnavailable = Unavailable()

ns.CCWhy = function()
	if not kit then return 'Party CDs is not loaded, and Party CC draws its icons with it.' end
	if not HAS_WIDGETS then return 'The game\'s aura container widgets are not available on this client.' end
	return ns.PTCWhy and ns.PTCWhy() or ''
end

local TOKENS = { 'player', 'party1', 'party2', 'party3', 'party4' }
local GROUPS = 1 -- dodo: 군중제어 1/2 하나로 합침 (원본 2)
local MAX_PLATES = 40
local STRIDE = 16384
local READ_EVERY, TICK, LINGER, SETTLE = 0.2, 0.25, 1, 0.4
local NOT_MINE, ANYONE = 'HARMFUL|!PLAYER', 'HARMFUL'

local EMPTY = {}

local SPELLS = {
	[119381] = { class = 'MONK', cd = 60, debuff = { 119381 }, bar = 1, aoe = true, mods = { { 344359, add = -5 } } },
	[179057] = { class = 'DEMONHUNTER', cd = 45, debuff = { 179057 }, bar = 1, aoe = true, need = { 179057 } },
	[30283] = { class = 'WARLOCK', cd = 60, debuff = { 30283 }, bar = 1, aoe = true, need = { 30283 }, mods = { { 1270255, add = -15 } } },
	[192058] = { class = 'SHAMAN', cd = 60, debuff = { 118905 }, lag = 2, bar = 1, aoe = true, need = { 192058 },
		mods = { { 381867, add = -5 }, { 265046, add = -10 }, { 445027, add = -5 } } },
	[46968] = { class = 'WARRIOR', cd = 40, debuff = { 132168 }, bar = 1, aoe = true, need = { 46968 },
		mods = { { 275339, add = -15, likely = true }, { 440992, add = -5 } } },
	[109248] = { class = 'HUNTER', cd = 45, debuff = { 117405, 117526 }, bar = 1, aoe = true, need = { 109248 } },
	[853] = { class = 'PALADIN', cd = 45, debuff = { 853 }, bar = 1, mods = { { 234299, add = -15 } } },
	[19577] = { class = 'HUNTER', cd = 60, debuff = { 24394, 474421 }, cast = { 474421 }, bar = 1, need = { 19577, 474421 },
		mods = { { 459507, add = -20 } } },
	[207167] = { class = 'DEATHKNIGHT', cd = 60, debuff = { 207167 }, bar = 2, aoe = true, need = { 207167 } },
	[115750] = { class = 'PALADIN', cd = 90, debuff = { 105421 }, bar = 2, aoe = true, need = { 115750 }, mods = { { 469325, add = -15 } } },
	[8122] = { class = 'PRIEST', cd = 40, debuff = { 8122 }, bar = 2, aoe = true, need = { 8122 }, mods = { { 196704, add = -10 } } },
	[99] = { class = 'DRUID', cd = 30, debuff = { 99 }, bar = 2, aoe = true, need = { 99 } },
	[5246] = { class = 'WARRIOR', cd = 90, debuff = { 5246 }, bar = 2, aoe = true, need = { 5246 }, mods = { { 424742, add = -15 } } },
	[207684] = { class = 'DEMONHUNTER', cd = 120, debuff = { 207685 }, lag = 2, cast = { 389813 }, bar = 2, aoe = true, need = { 207684 },
		mods = { { 320418, add = -30 }, { 389718, pct = -15 } } },
	[202138] = { class = 'DEMONHUNTER', cd = 60, debuff = { 204843 }, lag = 2, cast = { 389807 }, spec = 581, role = 'TANK', bar = 2,
		aoe = true, need = { 202138 }, mods = { { 389718, pct = -15 } } },
	[108199] = { class = 'DEATHKNIGHT', cd = 90, debuff = { 374776 }, spec = 250, role = 'TANK', bar = 2, aoe = true, need = { 108199 } },
	[102793] = { class = 'DRUID', cd = 60, debuff = { 127797 }, bar = 2, aoe = true, need = { 102793 } },
	[132469] = { class = 'DRUID', cd = 30, debuff = { 61391 }, bar = 2, aoe = true, need = { 132469 }, mods = { { 400140, add = -5 } } },
	[2094] = { class = 'ROGUE', cd = 120, debuff = { 2094 }, hold = true, bar = 2, need = { 2094 },
		mods = { { 200733, pct = -50 }, { 256165, pct = -25 }, { 441415, pct = -10 } } },
}
local ORDER = {
	119381, 179057, 30283, 192058, 46968, 109248, 853, 19577,
	207167, 115750, 8122, 99, 5246, 207684, 202138, 108199, 102793, 132469, 2094,
}
local FIRST = { 119381, 179057, 30283, 192058, 46968, 109248, 207167, 115750, 8122, 99, 5246 }

local NAME = '플레이어'
local PREVIEW_AT = { 0.35, 1, 0.7 }
local EDIT_ICONS = 7

local DEFAULTS = {
	enable = false,
	lock = false,
	showSelf = true,
	groupOnly = true,
	dungeonOnly = false,
	talents = true,
	tooltip = false,
	maxUnits = 10,
	aoeUnits = 4,
	-- dodo: 하나로 합침 (기절기 → 그 외 순서 유지)
	spells1 = { 119381, 179057, 30283, 192058, 46968, 109248, 853, 19577,
		207167, 115750, 8122, 99, 5246, 207684, 202138, 108199, 102793, 132469, 2094 },
	-- spells1 ={ 119381, 179057, 30283, 192058, 46968, 109248, 853, 19577 },
	-- spells2 = { 207167, 115750, 8122, 99, 5246, 207684, 202138, 108199, 102793, 132469, 2094 },
	x1 = -160, y1 = -150,
	x2 = -160, y2 = -200,
	grow1 = 'RIGHT', grow2 = 'RIGHT',
	size1 = 36, size2 = 36,
	spacing1 = 2, spacing2 = 2,
	textSize1 = 16, textSize2 = 16,
	names1 = true, names2 = true,
	namePos1 = 'IN', namePos2 = 'IN',
	nameSize1 = 10, nameSize2 = 10,
	nameLen1 = 4, nameLen2 = 4,
}

local function Migrate(cfg)
	cfg.cds = nil
	for g = 1, GROUPS do
		if type(cfg['spells' .. g]) ~= 'table' then cfg['spells' .. g] = {} end
	end
	-- dodo: 예전 2번 묶음 저장값 → 1번 뒤에 합침
	if type(cfg.spells2) == 'table' then
		local list = cfg.spells1
		for _, id in ipairs(cfg.spells2) do list[#list + 1] = id end
		cfg.spells2 = nil
	end
	if type(cfg.seen) ~= 'table' then
		cfg.seen = {}
		for _, id in ipairs(FIRST) do cfg.seen[id] = true end
	end
	for _, id in ipairs(ORDER) do
		if not cfg.seen[id] then
			cfg.seen[id] = true
			local there = false
			for g = 1, GROUPS do
				for _, v in ipairs(cfg['spells' .. g]) do
					if v == id then there = true end
				end
			end
			if not there then
				local list = cfg.spells1 -- dodo: 하나로 합침 (원본 'spells' .. (SPELLS[id].bar or 1))
				list[#list + 1] = id
			end
		end
	end
end

local function GetCfg() return ns.ModuleCfg('partyCC', DEFAULTS, Migrate) end
ns.CCGetCfg = GetCfg

local function Sum(sp, known) return ns.TalentLength(sp.cd, sp.mods or EMPTY, known, nil, true) end

local function Cap(cfg) return mmax(1, mmin(MAX_PLATES, floor(tonumber(cfg.maxUnits) or 10))) end

local function Reach(aoe, cfg)
	local cap = Cap(cfg)
	if not aoe then return cap end
	return mmin(cap, mmax(1, floor(tonumber(cfg.aoeUnits) or 4)))
end

local bars, feeds, members = {}, {}, {}
local byCast = {}
local sensHost
local built, preview, listening = false, false, false
local filter, filterNote = NOT_MINE, nil
local ticker, lastN, drawnRadial
local waitBuild, gated = false, false
local stats ={ reads = 0, hidden = 0, errors = 0, own = 0, ownHidden = 0, scans = 0 }
local QueueRefresh, QueueScan

local function Fault(err)
	stats.errors = stats.errors + 1
	stats.lastErr = tostring(err)
end

local talents = { byGUID = {}, stale = {}, misses = {}, ids = {}, all = {}, reads = 0, asks = 0 }
do
	for _, id in ipairs(ORDER) do
		local sp = SPELLS[id]
		for _, need in ipairs(sp.need or EMPTY) do ns.TalentWant(talents, sp.class, need) end
		for _, mod in ipairs(sp.mods or EMPTY) do ns.TalentWant(talents, sp.class, mod[1]) end
	end

	local function Known(id)
		local SB = _G.C_SpellBook
		return Ask((SB and SB.IsSpellKnown) or _G.IsPlayerSpell, id)
	end

	talents.Own = function(class)
		local own = talents.own
		if not own then
			local config = ns.TalentConfig()
			local ok, read = false, nil
			if config then ok, read = pcall(ns.TalentRanks, talents, class, config) end
			own = (ok and read) or {}
			for _, id in ipairs(talents.ids[class] or EMPTY) do
				if own[id] == nil then
					local known = Known(id)
					if known ~= nil then own[id] = known and 1 or 0 end
				end
			end
			for id, sp in pairs(SPELLS) do
				if sp.class == class and sp.need then
					local base = Known(id)
					for _, alt in ipairs(sp.cast or EMPTY) do
						if Known(alt) == true then base = true end
					end
					if base == true then
						for _, need in ipairs(sp.need) do
							if (own[need] or 0) < 1 then own[need] = 1 end
						end
					end
				end
			end
			talents.own = own
		end
		return own
	end

	talents.Of = function(m, cfg)
		if m.fake or cfg.talents == false then return nil end
		if m.me then return talents.Own(m.class) end
		return m.guid and talents.byGUID[m.guid] or nil
	end

	talents.Wanted = function(m)
		if m.me or m.fake or not m.guid or not talents.ids[m.class or ''] or not ns.InDungeon() then return false end
		return talents.byGUID[m.guid] == nil or talents.stale[m.guid] == true
	end

	talents.Again = function()
		for guid in pairs(talents.byGUID) do talents.stale[guid] = true end
		for _, m in pairs(members) do m.asks = nil end
	end

	talents.Ready = function(guid)
		if secret(guid) or type(guid) ~= 'string' then return false end
		local m = members[guid]
		if not m or m.me or m.fake or not talents.ids[m.class or ''] then return false end
		local ok, got = pcall(ns.TalentRanks, talents, m.class)
		if not ok then
			Fault(got)
			got = nil
		end
		local old = talents.byGUID[guid]
		if not got then
			m.talentMiss = (m.talentMiss or 0) + 1
			if m.talentMiss < 3 then return false end
			got = old or {}
		end
		talents.reads = talents.reads + 1
		talents.byGUID[guid], talents.stale[guid], m.talentMiss = got, nil, nil
		for _, id in ipairs(talents.ids[m.class]) do
			if (old and old[id]) ~= got[id] then return true end
		end
		return false
	end

	local queue, asker = {}, nil

	local function Stop()
		wipe(queue)
		if asker then
			asker:Cancel()
			asker = nil
		end
	end

	local function Step()
		local cfg = GetCfg()
		if #queue == 0 or not cfg.enable or cfg.talents == false then
			Stop()
			return
		end
		local m = queue[1]
		if members[m.guid or ''] ~= m or not talents.Wanted(m) or (m.asks or 0) >= 6 then
			tremove(queue, 1)
			return
		end
		local sent, why = ns.SendInspect(m.unit, 2.5)
		if why == 'wait' then return end
		tremove(queue, 1)
		if sent then
			m.asks = (m.asks or 0) + 1
			talents.asks = talents.asks + 1
		end
		queue[#queue + 1] = m
	end

	talents.Queue = function(m)
		for _, q in ipairs(queue) do
			if q == m then return end
		end
		queue[#queue + 1] = m
		if not asker then asker = C_Timer.NewTicker(1, Step) end
	end

	talents.Stop = Stop
end


local function Tracker(m, id, cd, n)
	local t = m.tr[id]
	if not t then
		t = { slot = { {}, {} }, primed = false }
		m.tr[id] = t
	end
	if t.cd ~= cd then
		t.cd, t.u, t.loop = cd, kit.Unit(cd), nil
		t.P = kit.CODES * t.u
		t.def = { id = id, show = id, cd = cd }
		kit.Clear(t, n)
		t.primed, t.fresh = false, true
	end
	return t
end

local function Seed(t, at, n)
	local frac = PREVIEW_AT[(at - 1) % #PREVIEW_AT + 1]
	if frac >= 1 then return end
	local began = n - floor(t.cd * frac)
	kit.Clear(t, began - 1)
	kit.StartPlain(t, began)
	t.loop = true
end

local function NewCell(bar)
	local c = kit.NewCell(bar.frame)
	c.tag = CreateFrame('Frame', nil, c)
	c.tag:SetAllPoints(c)
	c.who = c.tag:CreateFontString(nil, 'OVERLAY')
	c.who:SetJustifyH('CENTER')
	c.who:SetWordWrap(false)
	c.who:Hide()
	return c
end

local function Loose(c)
	local old = c.t
	if old and old.cell == c then old.cell = nil end
	c.t, c.m = nil, nil
end

local function Bind(g, list, cfg, n)
	local bar = bars[g]
	local look = bar.look
	look.size, look.textSize = cfg['size' .. g] or 36, cfg['textSize' .. g] or 16
	look.tooltip = cfg.tooltip == true
	for i, e in ipairs(list) do
		local t = e.t
		local c = bar.cells[i]
		if not c or not pcall(kit.Dress, c, t.def, look) then
			if c then
				Loose(c)
				kit.Scrap(c)
			end
			c = NewCell(bar)
			bar.cells[i] = c
			kit.Dress(c, t.def, look)
		end
		if c.t ~= t then
			Loose(c)
			c.t = t
		end
		c.glow:SetAlpha(0)
		c.tag:SetFrameLevel(c:GetFrameLevel() + 7)
		t.cell, c.m = c, e.m
		kit.PushCell(t, c, n)
	end
	for i = #list + 1, #bar.cells do Loose(bar.cells[i]) end
	bar.n = #list
end

local lay = {}

-- dodo: 행 당 개수 초과 시 줄바꿈 (가로 성장 → 아래로 새 줄, 세로 성장 → 오른쪽으로 새 열)
local function Wrap(c, frame, i, n, per, o)
	local k = i - 1
	local line, pos = floor(k / per), k % per
	local x, y
	if o.grow == 'UP' or o.grow == 'DOWN' then
		x = line * o.step
		y = (o.grow == 'UP' and 1 or -1) * pos * o.tall
	else
		local count = mmin(per, n - line * per)
		y = -line * o.tall
		if o.grow == 'LEFT' then
			x = -pos * o.step
		elseif o.grow == 'CENTER' then
			x = (pos - (count - 1) / 2) * o.step
		else
			x = pos * o.step
		end
	end
	c:ClearAllPoints()
	ns.PixelPoint(c, 'CENTER', frame, 'CENTER', x, y)
	kit.Seat(c)
end

local function Layout(g, cfg)
	local bar = bars[g]
	local size = cfg['size' .. g] or 36
	kit.LayOpts(lay, size, cfg['spacing' .. g] or 2, cfg['grow' .. g], cfg['names' .. g] ~= false,
		cfg['namePos' .. g], cfg['nameSize' .. g] or 10, cfg['nameLen' .. g])
	local n = bar.n or 0
	bar.frame:SetSize(size, size)
	local per = mmax(1, floor(tonumber(cfg.perRow) or 99)) -- dodo: 행 당 개수
	for i, c in ipairs(bar.cells) do
		local on = i <= n
		if on then
			kit.Lay(c, c.who, c.m, bar.frame, i, n, lay)
			if n > per then Wrap(c, bar.frame, i, n, per, lay) end
		end
		c:SetShown(on)
		c.clip:SetShown(on)
		c.win:SetShown(on)
	end
	bar.frame:SetShown(n > 0)
	bar.frame:EnableMouse(ns.CanGrab(cfg, preview))
end

local function TickOne(t, c, n)
	if kit.Roll(t, n) then kit.PushCell(t, c, n) end
	local running = false
	for k = 1, 2 do
		local sl = t.slot[k]
		if secret(sl.v) or sl.v ~= 0 then
			if not secret(sl.v) and not secret(sl.c) and kit.Left(t, sl, n) <= -kit.LINGER then
				sl.v = 0
				if t.loop then kit.StartPlain(t, n) end
				kit.PushCell(t, c, n)
			else
				local ok, err = pcall(kit.Range, c, k, sl, t.u, n)
				if not ok then Fault(err) end
				running = true
			end
		end
	end
	if running then kit.Seat(c) end
end

local function Tick()
	local n = kit.Now()
	local radial = kit.Swipe()
	if radial ~= drawnRadial then
		drawnRadial = radial
		QueueRefresh()
	end
	local second = n ~= lastN
	lastN = n
	local any = false
	for g = 1, GROUPS do
		local bar = bars[g]
		for i = 1, bar.n or 0 do
			local c = bar.cells[i]
			local t = c and c.t
			if t then
				any = true
				if radial and c.arc[1] then
					local now = kit.Clock()
					for k = 1, 2 do
						local sl = t.slot[k]
						if secret(sl.v) or sl.v ~= 0 then kit.Arc(c, k, sl, t, now) end
					end
				end
				if second then TickOne(t, c, n) end
			end
		end
	end
	if not any and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function EnsureTicker()
	lastN = nil
	if not ticker then ticker = C_Timer.NewTicker(TICK, Tick) end
end

local PLATES, IS_PLATE = {}, {}
for i = 1, MAX_PLATES do
	PLATES[i] = 'nameplate' .. i
	IS_PLATE[PLATES[i]] = true
end

local unitOf, slotOf, alive, calm = {}, {}, {}, {}
local tracking, taken, rulesHold, lingerUntil, loose = false, 0, true, 0, false
local scanTicker

local function Verdict(unit, strict)
	if Ask(UnitExists, unit) ~= true then return 'no such unit' end
	if Ask(UnitCanAttack, 'player', unit) == false then return 'not attackable' end
	if Ask(UnitCanAssist, 'player', unit) ~= false then return 'friendly, or the client would not say' end
	if Ask(UnitIsDeadOrGhost, unit) == true then return 'dead' end
	if Ask(_G.UnitIsBossMob, unit) == true then return 'boss' end
	if strict and Ask(UnitAffectingCombat, unit) == false then return 'not in combat', true end
	return nil
end

local function FeedOf(id)
	local f = feeds[id]
	if f then return f end
	f = { include = {}, sensors = {}, n = 0, on = false, hold = SPELLS[id].hold, aoe = SPELLS[id].aoe, at = {}, by = {}, settle = 0 }
	for _, d in ipairs(SPELLS[id].debuff) do f.include[d] = true end
	f.head = CreateFrame('Frame', nil, sensHost)
	f.head:SetSize(1, 1)
	f.head:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -(MAX_PLATES + 12), 0)
	local ok, tail = pcall(CreateFrame, 'Frame', nil, sensHost, ns.TAIL_TEMPLATE)
	local okS, span = pcall(CreateFrame, 'Frame', nil, sensHost, ns.TAIL_TEMPLATE)
	if not (ok and tail and okS and span) then
		tail = (ok and tail) or CreateFrame('Frame', nil, sensHost)
		span = (okS and span) or CreateFrame('Frame', nil, sensHost)
		f.failed = 'no ' .. tostring(ns.TAIL_TEMPLATE)
	end
	tail:SetSize(1, 1)
	tail:SetPoint('TOPLEFT', f.head, 'TOPLEFT', 0, 0)
	span:SetPoint('TOPLEFT', f.head, 'TOPLEFT', 0, 0)
	span:SetPoint('BOTTOMRIGHT', tail, 'BOTTOMRIGHT', 0, 0)
	f.tail, f.span = tail, span
	feeds[id] = f
	return f
end

local function Reads(f, slot)
	return not f.aoe and (f.hold or not calm[slot])
end

local function Cover(f, reach)
	if not f.aoe then return end
	local at, by, list = f.at, f.by, f.sensors
	local want = f.on and mmin(#list, reach or Reach(true, GetCfg())) or 0
	for k = 1, #list do
		local unit = at[k]
		local slot = unit and slotOf[unit]
		if unit and (k > want or not slot or calm[slot]) then
			at[k], by[unit] = nil, nil
			pcall(list[k].SetEnabled, list[k], false)
		end
	end
	local k = 1
	for slot = 1, MAX_PLATES do
		local unit = unitOf[slot]
		if unit and not calm[slot] and not by[unit] then
			while k <= want and at[k] do k = k + 1 end
			if k > want then break end
			at[k], by[unit] = unit, k
			pcall(list[k].SetUnit, list[k], unit)
			pcall(list[k].SetEnabled, list[k], true)
		end
	end
end

local function NewSensor(f)
	local ok, s = pcall(CreateFrame, 'AuraContainer', nil, sensHost, 'CustomAuraContainerTemplate,' .. ns.TAIL_TEMPLATE)
	if not ok or not s then
		ok, s = pcall(CreateFrame, 'AuraContainer', nil, sensHost, 'CustomAuraContainerTemplate')
	end
	if not ok or not s then return nil, 'the client refused the AuraContainer frame', false end
	s:SetSize(1, 1)
	pcall(s.EnableMouse, s, false)
	local okG, err = ns.AddSensorGroup(s, 'stop', filter, f.include, STRIDE)
	if not okG then
		s:Hide()
		return nil, tostring(err), true
	end
	pcall(s.SetEnabled, s, false)
	return s
end

local function Grow(f)
	local s, why, refused = NewSensor(f)
	if not s and refused and filter == NOT_MINE then
		filter, filterNote = ANYONE, why
		s, why = NewSensor(f)
	end
	if not s then
		f.failed = why
		return false
	end
	local last = f.sensors[#f.sensors]
	local ok, err = pcall(function()
		if last then
			s:SetPoint('TOPLEFT', last, 'TOPRIGHT', 0, 0)
		else
			s:SetPoint('TOPLEFT', f.head, 'TOPLEFT', 0, 0)
		end
		f.tail:ClearAllPoints()
		f.tail:SetPoint('TOPLEFT', s, 'TOPRIGHT', 0, 0)
	end)
	if not ok then
		f.failed = tostring(err)
		s:Hide()
		return false
	end
	local slot = #f.sensors + 1
	f.sensors[slot] = s
	local unit = unitOf[slot]
	if f.aoe then
		Cover(f)
	elseif unit and f.on and Reads(f, slot) then
		pcall(s.SetUnit, s, unit)
		pcall(s.SetEnabled, s, true)
		f.settle = GetTime() + SETTLE
	end
	return true
end

local builder = CreateFrame('Frame')
builder:Hide()
builder:SetScript('OnUpdate', function(self)
	if InCombatLockdown() then
		waitBuild = true
		self:Hide()
		return
	end
	local cfg = GetCfg()
	for _, f in pairs(feeds) do
		if f.on and not f.failed and #f.sensors < Reach(f.aoe, cfg) then
			Grow(f)
			return
		end
	end
	self:Hide()
end)

local function TopUp()
	if InCombatLockdown() then
		waitBuild = true
		return
	end
	waitBuild = false
	builder:Show()
end

local driver = CreateFrame('Frame')
driver:Hide()

local function Wake()
	if not driver:IsShown() then driver:Show() end
end

local function Release(slot)
	local unit = unitOf[slot]
	if not unit then return end
	unitOf[slot], calm[slot] = nil, nil
	slotOf[unit] = nil
	taken = taken - 1
	lingerUntil = GetTime() + LINGER
	for _, f in pairs(feeds) do
		local s
		if f.aoe then
			local k = f.by[unit]
			if k then
				f.at[k], f.by[unit] = nil, nil
				s = f.sensors[k]
			end
		else
			s = f.sensors[slot]
		end
		if s then pcall(s.SetEnabled, s, false) end
	end
end

local function Take(slot, unit, still)
	unitOf[slot] = unit
	slotOf[unit] = slot
	calm[slot] = still or nil
	taken = taken + 1
	local settle = GetTime() + SETTLE
	for _, f in pairs(feeds) do
		local s = f.on and Reads(f, slot) and f.sensors[slot]
		if s then
			pcall(s.SetUnit, s, unit)
			pcall(s.SetEnabled, s, true)
			f.settle = settle
		end
	end
end

local function Calm(slot, still)
	if (calm[slot] or false) == still then return end
	calm[slot] = still or nil
	local unit = unitOf[slot]
	for _, f in pairs(feeds) do
		local s = f.on and not f.hold and not f.aoe and f.sensors[slot]
		if s then
			if not still then pcall(s.SetUnit, s, unit) end
			pcall(s.SetEnabled, s, not still)
		end
	end
end

local later = {}

local function Room(cap, evict)
	for slot = 1, cap do
		if not unitOf[slot] then return slot end
	end
	if not evict then return nil end
	for slot = 1, cap do
		if calm[slot] then
			Release(slot)
			return slot
		end
	end
	return nil
end

local function Rescan()
	if not tracking then return end
	stats.scans = stats.scans + 1
	local cap = Cap(GetCfg())
	local hold = true
	if InCombatLockdown() then
		hold = false
		for unit in pairs(alive) do
			if Verdict(unit, true) == nil then
				hold = true
				break
			end
		end
	end
	rulesHold = hold
	for slot = 1, MAX_PLATES do
		local unit = unitOf[slot]
		if unit then
			local why, still = true, false
			if slot <= cap then why, still = Verdict(unit, hold) end
			if why == nil then
				Calm(slot, false)
			elseif loose and still then
				Calm(slot, true)
			else
				Release(slot)
			end
		end
	end
	local n = 0
	for unit in pairs(alive) do
		if not slotOf[unit] then
			local why, still = Verdict(unit, hold)
			if why == nil then
				local slot = Room(cap, true)
				if not slot then break end
				Take(slot, unit, false)
			elseif still then
				n = n + 1
				later[n] = unit
			end
		end
	end
	if loose and taken < cap then
		for i = 1, n do
			local slot = Room(cap)
			if not slot then break end
			Take(slot, later[i], true)
		end
	end
	for i = n, 1, -1 do later[i] = nil end
	local reach = Reach(true, GetCfg())
	for _, f in pairs(feeds) do Cover(f, reach) end
	if taken > 0 then Wake() end
end

QueueScan = ns.Coalesce(Rescan)

local watch = CreateFrame('Frame')
watch:SetScript('OnEvent', function(_, event, unit)
	if type(unit) ~= 'string' or secret(unit) or not IS_PLATE[unit] then return end
	if event == 'NAME_PLATE_UNIT_REMOVED' then
		alive[unit] = nil
		local slot = slotOf[unit]
		if slot then
			Release(slot)
			Wake()
		end
	elseif event == 'NAME_PLATE_UNIT_ADDED' then
		alive[unit] = true
	end
	QueueScan()
end)

local function StartTracking()
	if tracking then return end
	tracking = true
	wipe(alive)
	for _, unit in ipairs(PLATES) do
		if Ask(UnitExists, unit) == true then alive[unit] = true end
	end
	watch:RegisterEvent('NAME_PLATE_UNIT_ADDED')
	watch:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
	watch:RegisterEvent('UNIT_FLAGS')
	scanTicker = C_Timer.NewTicker(2, QueueScan)
	QueueScan()
end

local function StopTracking()
	if not tracking then return end
	tracking = false
	watch:UnregisterAllEvents()
	if scanTicker then
		scanTicker:Cancel()
		scanTicker = nil
	end
	for slot = 1, MAX_PLATES do Release(slot) end
	wipe(alive)
end

local function ReadAll()
	local n, now = kit.Now(), GetTime()
	for id, f in pairs(feeds) do
		if f.on and f.sensors[1] and f.hold and now < f.settle then
			for i = 1, f.n do f.trackers[i].primed = false end
			stats.held = (stats.held or 0) + 1
		elseif f.on and f.sensors[1] then
			local ok, lit = pcall(ns.SensorLit, f.span)
			if ok then
				stats.reads = stats.reads + 1
				if secret(lit) then stats.hidden = stats.hidden + 1 end
				local at = n - (SPELLS[id].lag or 0)
				for i = 1, f.n do
					local okF, err = pcall(kit.Feed, f.trackers[i], lit, false, false, at)
					if not okF then Fault(err) end
				end
				f.last = lit
			else
				Fault(lit)
			end
		end
	end
end

local acc = 0
driver:SetScript('OnUpdate', function(self, elapsed)
	acc = acc + elapsed
	if acc < READ_EVERY then return end
	acc = 0
	if not tracking or (taken <= 0 and GetTime() > lingerUntil) then
		self:Hide()
		return
	end
	ReadAll()
end)

local function SetFeeds(want)
	local any = false
	for id, list in pairs(want) do
		local f = FeedOf(id)
		f.trackers, f.n = list, #list
		if not f.on then
			f.on, f.settle = true, GetTime() + SETTLE
			for i = 1, f.n do list[i].primed = false end
			for slot, s in ipairs(f.sensors) do
				local unit = unitOf[slot]
				if unit and Reads(f, slot) then
					pcall(s.SetUnit, s, unit)
					pcall(s.SetEnabled, s, true)
				end
			end
		end
		any = true
	end
	local wide = false
	for id, f in pairs(feeds) do
		if f.on and not want[id] then
			f.on, f.n, f.trackers, f.last = false, 0, EMPTY, nil
			for _, s in ipairs(f.sensors) do pcall(s.SetEnabled, s, false) end
		end
		Cover(f)
		if f.on and f.hold then wide = true end
	end
	if wide ~= loose then
		loose = wide
		if tracking then QueueScan() end
	end
	if any then
		StartTracking()
		TopUp()
	else
		StopTracking()
		builder:Hide()
	end
end

local own = CreateFrame('Frame')
local ownOn = false
own:SetScript('OnEvent', function(_, _, _, _, spellID)
	if secret(spellID) then
		stats.ownHidden = stats.ownHidden + 1
		return
	end
	local t = spellID and byCast[spellID]
	if not t then return end
	local n = kit.Now()
	stats.own = stats.own + 1
	kit.StartPlain(t, n)
	if t.cell then kit.PushCell(t, t.cell, n) end
	EnsureTicker()
end)

local function Live(cfg)
	if not cfg.enable or ns.CCUnavailable then return false end
	if IsInRaid() then return false end
	if cfg.groupOnly ~= false and not IsInGroup() then return false end
	if cfg.dungeonOnly and not ns.InDungeon() then return false, 'not in a dungeon' end
	return true
end

local function SpecOf(unit, me, guid)
	if me then
		local own = ns.CHSpecID and ns.CHSpecID()
		if type(own) == 'number' and not secret(own) and own > 0 then return own, 'your own' end
		return nil
	end
	local known = kit.Spec(guid)
	if known then return known, 'read by Party CDs' end
	local id = kit.InspectSpec(unit)
	if id then return id, 'inspected' end
	return nil
end

local function RoleOf(unit)
	local ok, role = pcall(_G.UnitGroupRolesAssigned, unit)
	if ok and not secret(role) and (role == 'TANK' or role == 'HEALER' or role == 'DAMAGER') then return role end
	return nil
end

local function Fits(sp, m, known)
	if m.class ~= sp.class then return false end
	if known and sp.need then
		local no = false
		for _, id in ipairs(sp.need) do
			no = known[id] == 0
			if not no then break end
		end
		if no then return false end
	end
	if not sp.spec then return true end
	if m.spec then return m.spec == sp.spec end
	if m.role then return m.role == sp.role end
	return true
end

local function Roster(cfg)
	local out = {}
	for i, unit in ipairs(TOKENS) do
		local me = i == 1
		if (me and cfg.showSelf ~= false) or (not me and Ask(UnitExists, unit) == true) then
			local key = kit.Key(unit)
			local m = members[key]
			if not m then
				m = { tr = {} }
				members[key] = m
			end
			m.unit, m.me = unit, me
			m.guid = key ~= unit and key or nil
			m.class = ns.ClassOf(unit) or m.class
			m.name = kit.Name(unit)
			m.spec, m.how = SpecOf(unit, me, m.guid)
			m.role = RoleOf(unit)
			if cfg.talents ~= false and talents.Wanted(m) then talents.Queue(m) end
			out[#out + 1] = m
		end
	end
	return out
end

local function Share(cfg)
	local have, take, used = {}, {}, {}
	for g = 1, GROUPS do
		local count, ids = 0, cfg['spells' .. g]
		if not cfg['off' .. g] and type(ids) == 'table' then
			for _, id in ipairs(ids) do
				if SPELLS[id] and not used[id] then
					used[id] = true
					count = count + 1
				end
			end
		end
		have[g] = count
	end
	local left = EDIT_ICONS
	for g = 1, GROUPS do
		local slots = GROUPS - g + 1
		take[g] = mmin(have[g], floor((left + slots - 1) / slots))
		left = left - take[g]
	end
	for g = 1, GROUPS do
		local more = mmin(have[g] - take[g], left)
		take[g] = take[g] + more
		left = left - more
	end
	return take
end

local function Refresh()
	if not built then return end
	local cfg = GetCfg()
	local on = Live(cfg)
	local n = kit.Now()
	local seen, want, used = {}, {}, {}
	local roster = (on and not preview) and Roster(cfg) or EMPTY
	local fakes, cells = 0, false
	local room = (preview and ns.EditModeActive and ns.EditModeActive()) and Share(cfg) or nil
	gated = false
	wipe(byCast)
	for _, m in ipairs(roster) do seen[m] = true end
	if preview then
		for _, m in pairs(members) do
			if not m.fake then seen[m] = true end
		end
	end
	for g = 1, GROUPS do
		local list = {}
		local ids = cfg['spells' .. g]
		if (preview or on) and not cfg['off' .. g] and type(ids) == 'table' then
			for _, id in ipairs(ids) do
				local sp = SPELLS[id]
				if sp and not used[id] then
					used[id] = true
					if preview then
						if not room or #list < room[g] then
							local cd = Sum(sp)
							fakes = fakes + 1
							local key = 'preview' .. id
							local m = members[key]
							if not m then
								m = { tr = {}, fake = true }
								members[key] = m
							end
							m.class, m.name = sp.class, NAME
							seen[m] = true
							local t = Tracker(m, id, cd, n)
							if t.fresh then Seed(t, fakes, n) end
							t.fresh = nil
							list[#list + 1] = { t = t, m = m }
						end
					else
						for _, m in ipairs(roster) do
							if sp.spec and m.class == sp.class then gated = true end
							local known = m.class == sp.class and talents.Of(m, cfg) or nil
							if Fits(sp, m, known) then
								local t = Tracker(m, id, Sum(sp, known), n)
								t.fresh = nil
								list[#list + 1] = { t = t, m = m }
								if m.me then
									byCast[id] = t
									for _, alt in ipairs(sp.cast or EMPTY) do byCast[alt] = t end
								else
									local w = want[id]
									if not w then
										w = {}
										want[id] = w
									end
									w[#w + 1] = t
								end
							end
						end
					end
				end
			end
		end
		local ok, err = pcall(Bind, g, list, cfg, n)
		if not ok then Fault(err) end
		ok, err = pcall(Layout, g, cfg)
		if not ok then Fault(err) end
		if #list > 0 then cells = true end
	end
	for key, m in pairs(members) do
		if not seen[m] then members[key] = nil end
	end
	local ok, err = pcall(SetFeeds, want)
	if not ok then Fault(err) end
	local wantOwn = next(byCast) ~= nil
	if wantOwn ~= ownOn then
		ownOn = wantOwn
		if wantOwn then own:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player') else own:UnregisterAllEvents() end
	end
	if cells then EnsureTicker() end
end

QueueRefresh = ns.Coalesce(Refresh)

local late
local function RefreshSoon()
	QueueRefresh()
	if late then late:Cancel() end
	late = C_Timer.NewTimer(0.5, QueueRefresh)
end

local function ApplyPosition(g)
	local bar = bars[g]
	if not bar then return end
	local cfg = GetCfg()
	bar.frame:ClearAllPoints()
	bar.frame:SetPoint('CENTER', UIParent, 'CENTER', cfg['x' .. g] or 0, cfg['y' .. g] or 0)
end

local function EnsureFrames()
	if built then return end
	kit.Ensure()
	sensHost = CreateFrame('Frame', nil, UIParent)
	sensHost:SetSize(1, 1)
	sensHost:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0)
	for g = 1, GROUPS do
		local frame = CreateFrame('Frame', 'dodoPartyCC' .. g, UIParent)
		frame:SetFrameStrata('MEDIUM')
		frame:SetSize(36, 36)
		frame:SetClampedToScreen(true)
		frame:SetMovable(true)
		frame:EnableMouse(false)
		frame:RegisterForDrag('RightButton')
		frame:Hide()
		bars[g] = { frame = frame, cells = {}, look = {}, n = 0 }
		ns.MakeDraggable(frame, GetCfg, 'x' .. g, 'y' .. g, function() ApplyPosition(g) end)
	end
	ns.OnGrabChange(function()
		local on = ns.CanGrab(GetCfg(), preview)
		for g = 1, GROUPS do bars[g].frame:EnableMouse(on) end
	end)
	built = true
end

local function ResetAll()
	local n = kit.Now()
	for _, m in pairs(members) do
		for _, t in pairs(m.tr) do
			if not t.loop then
				kit.Clear(t, n)
				t.primed = false
				if t.cell then kit.PushCell(t, t.cell, n) end
			end
		end
	end
	lastN = nil
end

local evt = CreateFrame('Frame')
local LIVE_EVENTS = {
	'GROUP_ROSTER_UPDATE', 'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED', 'CHALLENGE_MODE_START',
	'INSPECT_READY', 'PLAYER_SPECIALIZATION_CHANGED', 'PLAYER_ROLES_ASSIGNED', 'TRAIT_CONFIG_UPDATED', 'PLAYER_TALENT_UPDATE',
	'READY_CHECK',
}

local function Apply()
	local cfg = GetCfg()
	ns.CCUnavailable = Unavailable()
	local wanted = (cfg.enable and not ns.CCUnavailable) and true or false
	if wanted ~= listening then
		listening = wanted
		for _, e in ipairs(LIVE_EVENTS) do
			if wanted then evt:RegisterEvent(e) else evt:UnregisterEvent(e) end
		end
	end
	if not kit or not (wanted or preview or built) then return end
	EnsureFrames()
	for g = 1, GROUPS do ApplyPosition(g) end
	Refresh()
end

ns.CCApply = ns.Coalesce(Apply)
ns.OnPixelChange(function() ns.CCApply() end)

ns.CCIsPreview = function() return preview end
ns.CCSetPreview = function(state)
	preview = state and true or false
	Apply()
end

local function Entries(ids)
	local out = {}
	for _, id in ipairs(ids or EMPTY) do
		local sp = SPELLS[id]
		if sp then out[#out + 1] = { id = id, class = sp.class } end
	end
	return out
end

ns.CCCatalogue = function() return Entries(ORDER) end

-- dodo: 주문 목록 (/dd 전투 > 파티 주문 추적 > 주문 목록). 켜짐 = spells1 에 있음
ns.CCSpells = function()
	local have, out = {}, {}
	for _, id in ipairs(GetCfg().spells1 or EMPTY) do have[id] = true end
	for _, id in ipairs(ORDER) do
		local sp = SPELLS[id]
		if sp then out[#out + 1] = { id = id, class = sp.class, cd = sp.cd, off = not have[id] } end
	end
	return out
end

-- 켜기/끄기 후 spells1 을 ORDER 순서로 다시 만듦 (끄고 켜도 순서 유지)
ns.CCSetShown = function(id, on)
	if not SPELLS[id] then return end
	local cfg = GetCfg()
	local have = {}
	for _, v in ipairs(cfg.spells1 or EMPTY) do have[v] = true end
	have[id] = on and true or nil
	local list = {}
	for _, v in ipairs(ORDER) do
		if have[v] then list[#list + 1] = v end
	end
	cfg.spells1 = list
	ns.CCApply()
end
ns.CCBarSpells = function(g) return Entries(GetCfg()['spells' .. g]) end

local function Drop(list, id)
	for i = #list, 1, -1 do
		if list[i] == id then tremove(list, i) end
	end
end

ns.CCAdd = function(g, id)
	if not SPELLS[id] or type(g) ~= 'number' or g < 1 or g > GROUPS then return end
	local cfg = GetCfg()
	for k = 1, GROUPS do Drop(cfg['spells' .. k], id) end
	local list = cfg['spells' .. g]
	list[#list + 1] = id
	ns.CCApply()
end

ns.CCRemove = function(g, id)
	local list = GetCfg()['spells' .. g]
	if type(list) ~= 'table' then return end
	Drop(list, id)
	ns.CCApply()
end

ns.CCMove = function(g, id, dir)
	if not kit.Swap(GetCfg()['spells' .. g], id, dir) then return false end
	ns.CCApply()
	return true
end

evt:RegisterEvent('PLAYER_ENTERING_WORLD')
evt:SetScript('OnEvent', function(_, event, arg1)
	if event == 'PLAYER_ENTERING_WORLD' then
		if ns.InDungeon() then talents.Again() end
		C_Timer.After(0.5, ns.CCApply)
		return
	end
	local cfg = GetCfg()
	if not cfg.enable then return end
	if event == 'READY_CHECK' then
		if cfg.talents ~= false and ns.InDungeon() and not ns.KeyActive() then
			talents.Again()
			RefreshSoon()
		end
	elseif event == 'GROUP_ROSTER_UPDATE' then
		for _, m in pairs(members) do m.asks = nil end
		RefreshSoon()
	elseif event == 'CHALLENGE_MODE_START' then
		ResetAll()
	elseif event == 'PLAYER_REGEN_ENABLED' then
		if waitBuild then TopUp() end
		QueueScan()
	elseif event == 'PLAYER_REGEN_DISABLED' then
		QueueScan()
	elseif event == 'INSPECT_READY' then
		local changed = cfg.talents ~= false and talents.Ready(arg1)
		if changed or gated then RefreshSoon() end
	elseif event == 'PLAYER_SPECIALIZATION_CHANGED' then
		if secret(arg1) or type(arg1) ~= 'string' or arg1 == 'player' then
			talents.own = nil
		else
			for _, m in pairs(members) do
				if m.unit == arg1 and m.guid and talents.byGUID[m.guid] then
					talents.stale[m.guid], m.asks = true, nil
				end
			end
		end
		RefreshSoon()
	elseif event == 'TRAIT_CONFIG_UPDATED' or event == 'PLAYER_TALENT_UPDATE' then
		talents.own = nil
		RefreshSoon()
	elseif gated then
		RefreshSoon()
	end
end)

_G.SLASH_DODOPTCC1 = '/ptcc'
_G.SlashCmdList.DODOPTCC = function(msg)
	local function p(...) print('[dodo] 군중제어', ...) end
	local cmd = (msg or ''):lower():match('^%s*(%S*)')
	local cfg = GetCfg()
	if not kit then
		p(ns.CCWhy())
		return
	end
	if cmd == 'test' or cmd == 'reset' then
		local n, count = kit.Now(), 0
		for g = 1, GROUPS do
			local bar = bars[g]
			for i = 1, bar and bar.n or 0 do
				local c = bar.cells[i]
				local t = c and c.t
				if t and not t.loop then
					if cmd == 'test' then kit.StartPlain(t, n) else kit.Clear(t, n) end
					kit.PushCell(t, c, n)
					count = count + 1
				end
			end
		end
		if count > 0 then EnsureTicker() end
		p(cmd == 'test' and 'started' or 'cleared', count, 'timers')
		return
	end
	local live, why = Live(cfg)
	p('enabled =', tostring(cfg.enable), '| preview =', preview and 'ON' or 'off',
		'| in a party =', tostring(IsInGroup() and not IsInRaid()),
		'| only in dungeons =', cfg.dungeonOnly and 'on' or 'off',
		'| watching =', live and 'yes' or (why and ('no, ' .. why) or 'no'))
	p('bars take a right-drag =', ns.CanGrab(cfg, preview) and 'yes' or 'no', '| lock position =', cfg.lock and 'on' or 'off')
	if ns.CCUnavailable then p('|cffff5555not available:|r', ns.CCWhy()) end
	local plates, still = 0, 0
	for _ in pairs(alive) do plates = plates + 1 end
	for _ in pairs(calm) do still = still + 1 end
	p(format('enemies watched = %d of %d (%d out of combat, read for long crowd control only) | area CC watch at most %d', taken, Cap(cfg), still, Reach(true, cfg)),
		'| nameplates up =', plates, '| only enemies in combat =', rulesHold and 'yes' or 'set aside (nobody on screen is in combat)')
	local made, live = 0, 0
	for _, f in pairs(feeds) do
		made = made + #f.sensors
		if f.aoe then
			for _ in pairs(f.by) do live = live + 1 end
		elseif f.on then
			for slot in ipairs(f.sensors) do
				if unitOf[slot] and Reads(f, slot) then live = live + 1 end
			end
		end
	end
	p('sensors on enemies = switched on', live, '| made', made)
	p('debuffs read =', filter == NOT_MINE and 'cast by anyone but you' or 'cast by anyone',
		filterNote and ('(the client refused the other filter: ' .. filterNote .. ')') or '')
	p('reads =', stats.reads, '| hidden from addons =', stats.hidden, '| own casts =', stats.own,
		'| own casts hidden =', stats.ownHidden, '| scans =', stats.scans, '| errors =', stats.errors)
	if stats.lastErr then p('last error =', stats.lastErr) end
	local n = kit.Now()
	for _, id in ipairs(ORDER) do
		local f = feeds[id]
		if f then
			local last = 'not read yet'
			if secret(f.last) then last = 'hidden' elseif f.last ~= nil then last = f.last and 'on an enemy' or 'not on any enemy' end
			p(format('  %s (%d): %s | %s | sensors %d | members %d | last read: %s%s', ns.CdSpellName(id), id,
				f.on and 'watching' or 'parked', f.aoe and 'area stop' or 'single target', #f.sensors, f.n, last,
				f.failed and (' | |cffff5555stopped: ' .. f.failed .. '|r') or ''))
		end
	end
	for g = 1, GROUPS do
		local bar = bars[g]
		p(format('bar %d: %s, %d icons', g, cfg['off' .. g] and 'off' or 'on', bar and bar.n or 0))
		for i = 1, bar and bar.n or 0 do
			local c = bar.cells[i]
			local t, m = c.t, c.m
			if t and m then
				local state = 'ready'
				for k = 1, 2 do
					local sl = t.slot[k]
					if secret(sl.v) or secret(sl.c) then
						state = 'timer hidden from addons'
					elseif sl.v ~= 0 then
						state = format('%d s left', mmax(0, kit.Left(t, sl, n)))
					end
				end
				local name = m.name
				if secret(name) or type(name) ~= 'string' then name = '(name hidden)' end
				p(format('  %s - %s (%d s): %s%s', name, ns.CdSpellName(t.def.id), t.cd, state,
					m.me and ' | your own, from the cast' or (m.fake and ' | sample' or '')))
			end
		end
	end
	for _, m in pairs(members) do
		if not m.fake then
			local name = m.name
			if secret(name) or type(name) ~= 'string' then name = '(name hidden)' end
			local read = 'not read yet, asked ' .. (m.asks or 0) .. ' times'
			if cfg.talents == false then
				read = 'switched off'
			elseif m.me then
				read = 'your own'
			elseif not talents.ids[m.class or ''] then
				read = 'nothing to read for this class'
			elseif m.guid and talents.byGUID[m.guid] then
				local found, taken = 0, 0
				for _, rank in pairs(talents.byGUID[m.guid]) do
					found = found + 1
					if type(rank) == 'number' and rank > 0 then taken = taken + 1 end
				end
				read = format('read, %d of %d taken%s', taken, found, talents.stale[m.guid] and (ns.InDungeon() and ' (asking again)' or ' (asked again inside a dungeon)') or '')
			elseif not ns.InDungeon() then
				read = 'not read yet, asked only inside a dungeon'
			end
			p(format('member %s: %s | spec %s | role %s | talents %s', name, tostring(m.class),
				m.spec and (m.spec .. ' (' .. tostring(m.how) .. ')') or 'not known', m.role or 'not set', read))
		end
	end
	p('talents = read', talents.reads, 'times | inspects asked for', talents.asks)
	if stats.held then p('reads skipped right after a new enemy came up (long crowd control) =', stats.held) end
end
