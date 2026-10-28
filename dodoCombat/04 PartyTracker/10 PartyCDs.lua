local _, ns = ...
local hooksecurefunc, C_Timer = ns.Probe('PartyCDs', hooksecurefunc, C_Timer)
local _G = _G

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetTime = GetTime
local GetPhysicalScreenSize = GetPhysicalScreenSize
local UnitExists, UnitName, UnitGUID = UnitExists, UnitName, UnitGUID
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local IsInGroup, IsInRaid = IsInGroup, IsInRaid
local InCombatLockdown = InCombatLockdown
local ipairs, pairs, pcall, type, tostring = ipairs, pairs, pcall, type, tostring
local mmax, mmin, floor, ceil, abs, pi = math.max, math.min, math.floor, math.ceil, math.abs, math.pi
local tconcat, tsort, tremove = table.concat, table.sort, table.remove
local format = string.format
local wipe = wipe

local secret = ns.IsSecret
local EvalBool = _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorValueFromBoolean

local DOOR_SLACK, DOOR_PASSES = 1e-6, 16
local DOOR_BYTES = { 0, 1, 48, 85, 127, 200, 254, 255 }

local function TestDoor()
	local d = { state = 'error' }
	if not EvalBool then
		d.detail = 'the client has no EvaluateColorValueFromBoolean'
		return d
	end
	local off = 0
	for _, k in ipairs(DOOR_BYTES) do
		local want = k / 255
		local v = want
		for pass = 1, DOOR_PASSES do
			local ok, w
			if pass % 2 == 1 then ok, w = pcall(EvalBool, true, v, 0) else ok, w = pcall(EvalBool, false, 0, v) end
			if not ok then
				d.detail = tostring(w)
				return d
			end
			if secret(w) then
				d.state = 'hidden'
				return d
			end
			if type(w) ~= 'number' then
				d.detail = 'the answer was a ' .. type(w) .. ', not a number'
				return d
			end
			v = w
			local gap = abs(v - want)
			if gap >= off then off, d.sent, d.got = gap, want, v end
		end
	end
	d.off = off
	d.state = off == 0 and 'exact' or (off <= DOOR_SLACK and 'close' or 'coarse')
	return d
end

local door = TestDoor()
local HAS_WIDGETS = (ns.IS_121 and ns.HasTemplate('CustomAuraContainerTemplate')) and true or false

local function DoorOpen() return door.state == 'exact' or door.state == 'close' or door.state == 'hidden' end

ns.hasPartyCDs = true
ns.PTCUnavailable = not (HAS_WIDGETS and DoorOpen())

local function DoorLine()
	if door.state == 'exact' then return 'whole steps come back exact' end
	if door.state == 'close' then return format('whole steps come back, off by %.1e at most', door.off) end
	if door.state == 'hidden' then return 'the answer is hidden, so it cannot be checked from here' end
	if door.state == 'coarse' then
		return format('|cffff5555even whole steps are rounded: sent %.10f, got %.10f (off by %.1e)|r',
			door.sent, door.got, door.off)
	end
	return '|cffff5555refused: ' .. tostring(door.detail) .. '|r'
end

ns.PTCWhy = function()
	if not HAS_WIDGETS then return ns.L["The game's aura container widgets are not available on this client."] end
	if door.state == 'coarse' then
		return format(ns.L['This client rounds the numbers the timers are kept in (off by %.1e). Type /ptcd door and send what it prints.'], door.off)
	end
	if door.state == 'error' then
		return format(ns.L['The client refused the value check: %s. Type /ptcd door and send what it prints.'], tostring(door.detail))
	end
	return ''
end

local TOKENS = { 'player', 'party1', 'party2', 'party3', 'party4' }
local MAX = ns.PTCData.maxSpells
local READ_EVERY, READS_AFTER, HOLD, KEY_HOLD = 0.2, 2, 0.5, 2
local TICK = 0.25
local CD_MIN, CD_MAX = 5, 900
local CODES, LINGER = 254, 4
local DIM, GREY = 0.5, 0.5
local ARC = 256
local PROBE = { 0.25, 0.5, 0.375, 0.625 }
local WHITE = 'Interface\\Buttons\\WHITE8X8'

local data = ns.PTCData
local SPELLS, SPECS, EXTERNALS = data.spells, data.specs, data.externals
local bars, CLASSES, ROLE_SPEC = data.bars, data.classes, data.roleSpecs

local PREVIEW = {
	{ name = '플레이어', class = 'DRUID', spec = 104 },
	{ name = '플레이어', class = 'PALADIN', spec = 65, race = 'Dwarf', items = { [250255] = true } },
	{ name = '플레이어', class = 'WARRIOR', spec = 71 },
	{ name = '플레이어', class = 'ROGUE', spec = 261 },
	{ name = '플레이어', class = 'SHAMAN', spec = 262 },
}
PREVIEW.base = { PREVIEW[1], PREVIEW[2], PREVIEW[3], PREVIEW[4], PREVIEW[5] }
PREVIEW.deck, PREVIEW.n, PREVIEW.fresh = {}, 0, true
PREVIEW.Deal = function(base)
	PREVIEW.n = PREVIEW.n + 1
	if base then
		for i, p in ipairs(PREVIEW.base) do PREVIEW[i] = p end
		return
	end
	local deck, used = PREVIEW.deck, {}
	for i = 1, #PREVIEW.base do
		local spec
		while not spec do
			if not deck[1] then
				for _, c in ipairs(CLASSES) do
					for _, id in ipairs(c.specs) do deck[#deck + 1] = id end
				end
				for k = #deck, 2, -1 do
					local r = math.random(k)
					deck[k], deck[r] = deck[r], deck[k]
				end
			end
			spec = tremove(deck)
			if used[spec] then
				table.insert(deck, 1, spec)
				spec = nil
			end
		end
		used[spec] = true
		local class = data.specClass[spec]
		local race
		if math.random(3) == 1 then
			local pick = (class ~= 'DEMONHUNTER' and class ~= 'DRUID' and class ~= 'EVOKER') and { 'Dwarf', 'DarkIronDwarf' } or {}
			if class ~= 'PALADIN' and class ~= 'SHAMAN' and class ~= 'EVOKER' then pick[#pick + 1] = 'NightElf' end
			race = pick[1] and pick[math.random(#pick)] or nil
		end
		local items = math.random(4) == 1 and { [math.random(2) == 1 and 250255 or 270162] = true } or nil
		PREVIEW[i] = { name = '플레이어', class = class, spec = spec, race = race, items = items }
	end
end
if ns.OnGrabChange then
	ns.OnGrabChange(function()
		local w = _G.H3ndallPartyCdsConfig
		if not (w and w:IsShown()) then PREVIEW.fresh = true end
	end)
end
local PREVIEW_AT = { 0.15, 1, 0.6 }

local DEFAULTS = {
	enable = false,
	lock = false,
	x = -320,
	y = 0,
	showSelf = false,
	groupOnly = true,
	dungeonOnly = false,
	attach = true,
	side = 'RIGHT',
	offX = 1,
	offY = 0,
	growth = 'DOWN',
	size = 28,
	spacing = 2,
	rowSpacing = 6,
	wrap = false,
	perRow = 4,
	size2 = 24,
	textSize2 = 10,
	showName = true,
	showTimer = true,
	textSize = 12,
	highlight = true,
	tooltip = false,
	off = {},
	order = {},
}

local function Migrate(cfg)
	cfg.talents = nil -- Talent reading is always enabled; discard the old toggle.
	cfg.cds, cfg.extSeeded, cfg.glowStyle, cfg.glowColor = nil, nil, nil, nil
	if type(cfg.off) ~= 'table' then cfg.off = {} end
	if type(cfg.order) ~= 'table' then cfg.order = {} end
end

local function GetCfg() return ns.ModuleCfg('partyCDs', DEFAULTS, Migrate) end
ns.PTCGetCfg = GetCfg

local function CdKey(spec, id) return spec .. ':' .. id end

-- dodo: 아이콘 역순 정렬 (제자리 뒤집기). ghost(외생기/공생기 바 항목)는 제자리
local function Reverse(list)
	local i, j = 1, #list
	while i < j do
		if list[i].ghost then
			i = i + 1
		elseif list[j].ghost then
			j = j - 1
		else
			list[i], list[j] = list[j], list[i]
			i, j = i + 1, j - 1
		end
	end
end

-- dodo: 아이콘 개수 제한 (ghost 제외). keepRace 면 종족 특성이 한 칸 차지하고 항상 남음
local function Limit(list, cfg)
	local max = cfg.maxIcons
	if not max then return end
	local n, race = 0, nil
	for i = 1, #list do
		local def = list[i]
		if not def.ghost then
			n = n + 1
			if def.spell.race then race = def end
		end
	end
	if n <= max then return end
	if not cfg.keepRace then race = nil end
	local keep = race and max - 1 or max
	local kept, j = 0, 0
	for i = 1, #list do
		local def = list[i]
		local stay = def.ghost or def == race
		if not stay and kept < keep then stay, kept = true, kept + 1 end
		if stay then
			j = j + 1
			list[j] = def
		end
	end
	for i = #list, j + 1, -1 do list[i] = nil end
end

local function SpecList(spec, cfg, all)
	local src = SPECS[spec]
	if not src then return nil end
	local order, rank = cfg.order and cfg.order[spec], nil
	if type(order) == 'table' then
		rank = {}
		for i, id in ipairs(order) do
			if not rank[id] then rank[id] = i end
		end
	end
	local out = {}
	for i, e in ipairs(src) do
		local id, base, charges = e, nil, nil
		if type(e) == 'table' then id, base, charges = e[1], e[2], e[3] end
		local sp = SPELLS[id]
		local off = (cfg.off and cfg.off[CdKey(spec, id)]) and true or false
		if sp and (all or not off) then
			base = base or sp.cooldown
			local cd = floor(mmax(CD_MIN, mmin(CD_MAX, base)))
			local sw = sp.swap
			if sw and sw.specs and not sw.specs[spec] then sw = nil end
			local show = (sw and sw.likely) and sw.id or id
			out[#out + 1] = { id = id, show = show, cd = cd, base = base, spell = sp, off = off, swap = sw,
				charges = charges, spec = spec, at = rank and (rank[id] or #order + i) or i }
		end
	end
	if rank then tsort(out, function(a, b) return a.at < b.at end) end
	return out
end

local racial = { ids = { 20594, 265221, 58984 }, byRace = {} }
for _, id in ipairs(racial.ids) do racial.byRace[SPELLS[id].race] = id end

racial.Def = function(id, cfg, all, kind)
	local sp = SPELLS[id]
	local off = (cfg.off and cfg.off[CdKey(kind or 'race', id)]) and true or false
	if not sp or (off and not all) then return nil end
	return { id = id, show = id, cd = floor(mmax(CD_MIN, mmin(CD_MAX, sp.cooldown))), base = sp.cooldown, spell = sp, off = off }
end

racial.List = function(cfg, kind, ids)
	local out = {}
	for _, id in ipairs(ids or racial.ids) do out[#out + 1] = racial.Def(id, cfg, true, kind) end
	return out
end

racial.Add = function(list, race, cfg)
	local id = race and racial.byRace[race]
	local def = id and racial.Def(id, cfg)
	if not def then return list end
	list = list or {}
	list[#list + 1] = def
	return list
end

racial.Of = function(unit, guid)
	local ok, _, token = pcall(_G.UnitRace, unit)
	if ok and not secret(token) and type(token) == 'string' then return token end
	if guid and _G.GetPlayerInfoByGUID then
		ok, _, _, _, token = pcall(_G.GetPlayerInfoByGUID, guid)
		if ok and not secret(token) and type(token) == 'string' then return token end
	end
	return nil
end

local trinket = { ids = {}, byGUID = {}, stale = {}, reads = 0, deaths = 0, cuts = 0, quiet = 0, QUIET = 3 }
for id, sp in pairs(SPELLS) do
	if sp.item then trinket.ids[#trinket.ids + 1] = id end
end
tsort(trinket.ids)

trinket.On = function(cfg)
	for _, id in ipairs(trinket.ids) do
		if not (cfg.off and cfg.off[CdKey('item', id)]) then return true end
	end
	return false
end

trinket.Items = function(unit)
	local get = _G.GetInventoryItemID
	if not get then return nil end
	local out = {}
	for slot = 13, 14 do
		local ok, item = pcall(get, unit, slot)
		if not ok or secret(item) then return nil end
		if type(item) == 'number' then out[item] = true end
	end
	return out
end

trinket.Of = function(s, m)
	if s.index == 1 then
		if not trinket.own then trinket.own = trinket.Items('player') end
		return trinket.own
	end
	return m.guid and trinket.byGUID[m.guid] or nil
end

trinket.Add = function(list, items, cfg)
	if not items then return list end
	for _, id in ipairs(trinket.ids) do
		if items[SPELLS[id].item] then
			local def = racial.Def(id, cfg, nil, 'item')
			if def then
				list = list or {}
				list[#list + 1] = def
				if def.spell.deathCut then trinket.cut = true end
			end
		end
	end
	return list
end

trinket.Quiet = function(t)
	if GetTime() < t.quiet then
		trinket.quiet = trinket.quiet + 1
		return true
	end
	t.quiet = nil
	return false
end

trinket.Wanted = function(m)
	local guid = m.guid
	if m.fake or not guid or not _G.GetInventoryItemID then return false end
	if trinket.byGUID[guid] ~= nil and not trinket.stale[guid] then return false end
	return (trinket.On(GetCfg()) and ns.InDungeon()) and true or false
end

trinket.Read = function(s, m)
	if not m.guid then return false end
	local got = trinket.Items(s.unit)
	local old = trinket.byGUID[m.guid]
	if not got then
		m.trinketMiss = (m.trinketMiss or 0) + 1
		if m.trinketMiss < 3 then return false end
		got = old or {}
	end
	m.trinketMiss = nil
	trinket.byGUID[m.guid], trinket.stale[m.guid] = got, nil
	trinket.reads = trinket.reads + 1
	for _, id in ipairs(trinket.ids) do
		local item = SPELLS[id].item
		if (old and old[item] or false) ~= (got[item] or false) then return true end
	end
	return false
end

trinket.Line = function(s, m)
	local items = trinket.Of(s, m)
	if not items then return ns.InDungeon() and 'not read yet' or 'not read yet, asked only inside a dungeon' end
	local names = {}
	for _, id in ipairs(trinket.ids) do
		if items[SPELLS[id].item] then names[#names + 1] = ns.CdSpellName(id) end
	end
	local line = #names > 0 and tconcat(names, ', ') or 'none tracked'
	if s.index ~= 1 and m.guid and trinket.stale[m.guid] then line = line .. ' (asking again)' end
	return line
end

ns.PTCIcon = function(id)
	local get = _G.C_Spell and _G.C_Spell.GetSpellTexture
	if get then
		local ok, _, own = pcall(get, id)
		if ok and own and not secret(own) and type(own) == 'number' and own > 0 then return own end
	end
	return ns.CdSpellTexture(id)
end
ns.PTCClasses = function() return CLASSES end
ns.PTCSpecSpells = function(spec)
	if spec == 'race' then return racial.List(GetCfg()) end
	if spec == 'item' then return racial.List(GetCfg(), 'item', trinket.ids) end
	return SpecList(spec, GetCfg(), true) or {}
end

local ClassOf, ClassRGB = ns.ClassOf, ns.ClassRGB

local function NameOf(unit)
	local ok, name = pcall(UnitName, unit)
	if not ok then return nil end
	return name
end

local function Key(unit)
	local ok, guid = pcall(UnitGUID, unit)
	if ok and not secret(guid) and guid then return guid end
	return unit
end

local function RoleOf(unit)
	local ok, role = pcall(UnitGroupRolesAssigned, unit)
	if ok and not secret(role) and type(role) == 'string' then return role end
	return nil
end

local T0 = GetTime() - 1024
local function Now() return floor(GetTime() - T0 + 0.5) end

local holder, layer, meter, sensHost, arcHost
local QueueRefresh, RefreshSoon
local swipe = { failHidden = 0, failOpen = 0, hidden = 0, checks = 0, bad = 0, last = 0, try = 0 }
local slots, members = {}, {}
local built, failed, waitBuild, pending, fought = false, nil, false, false, false
local preview, selfSensors = false, false
local ticker, lastN
local stats = { reads = 0, secret = 0, errors = 0, edges = 0, own = 0, ownHidden = 0, quick = 0, quickEdges = 0 }
local specByGUID = {}

local function Fault(err)
	stats.errors = stats.errors + 1
	stats.lastErr = tostring(err)
end

local swaps = { byGUID = {}, stale = {}, ids = {}, all = {}, bySpec = {}, misses = {}, reads = 0, asks = 0 }
local zone = { want = {}, owners = {} }
local ext = { look = {}, sig = '', count = 0 }
local charge = { try = 0, pool = {}, LO = -0.02, HI = 1.02, H = 520 }
local exact = { on = {}, want = {}, updates = 0, reads = 0, ev = { other = 0, named = 0, charges = 0, all = 0 } }
local free = { refills = 0, skipped = 0, procs = 0, undone = 0,
	WHI = { isFromPlayerOrPlayerPet = true, isBossAura = false, maxDuration = 121,
		excludeDispelTypes = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true, Enrage = true } } }
do
	local Want = ns.TalentWant
	for _, c in ipairs(CLASSES) do
		for _, spec in ipairs(c.specs) do
			local ids = {}
			for _, b in ipairs(bars) do
				for _, id in ipairs(b.class[c.token] or {}) do
					if (b.specs[id] or spec) == spec then ids[#ids + 1] = id end
				end
			end
			for _, e in ipairs(SPECS[spec] or {}) do ids[#ids + 1] = type(e) == 'table' and e[1] or e end
			for _, id in ipairs(ids) do
				local sp = SPELLS[id]
				local sw = sp and sp.swap
				if sw and (not sw.specs or sw.specs[spec]) then
					for talent in pairs(sw.talents) do Want(swaps, c.token, talent) end
					swaps.bySpec[spec] = true
				end
				for _, mod in ipairs(sp and sp.mods or {}) do
					if mod[1] then
						Want(swaps, c.token, mod[1])
						swaps.bySpec[spec] = true
					end
				end
				if sp then
					for _, tal in pairs({ sp.shortIf, sp.chargeIf, sp.proc and sp.proc.talent or nil }) do
						Want(swaps, c.token, tal)
						swaps.bySpec[spec] = true
					end
				end
			end
		end
	end

	local function Taken(ranks, set)
		local on
		for talent in pairs(set) do
			local rank = ranks[talent]
			if type(rank) == 'number' then
				if rank > 0 then return true end
				on = false
			end
		end
		return on
	end

	local function Mine(sw, id)
		local on
		local get = _G.C_Spell and _G.C_Spell.GetOverrideSpell
		if get and sw.known then
			local ok, ov = pcall(get, id)
			if ok and type(ov) == 'number' and not secret(ov) and ov ~= id
				and ns.Ask(_G.IsPlayerSpell, ov) == true then return true end
		end
		if get and sw.id ~= id then
			local ok, ov = pcall(get, id)
			if ok and type(ov) == 'number' and not secret(ov) then on = (ov == sw.id) end
		end
		if on then return true end
		for talent in pairs(sw.talents) do
			local known = ns.Ask(_G.IsPlayerSpell, talent)
			if known then return true end
			if known == false then on = false end
		end
		return on
	end

	swaps.Own = function(class)
		local own = swaps.own
		if not own then
			local config = ns.TalentConfig()
			local ok, read = false, nil
			if config then ok, read = pcall(ns.TalentRanks, swaps, class, config) end
			own = (ok and read) or {}
			swaps.own = own
		end
		return own
	end

	swaps.Wanted = function(m)
		local guid = m.guid
		if m.fake or not guid or not swaps.ids[m.class or ''] or (m.spec and not swaps.bySpec[m.spec]) then return false end
		if not ns.InDungeon() then return false end
		local T = _G.C_Traits
		if not (T and T.GetConfigInfo and T.GetNodeInfo) then return false end
		return swaps.byGUID[guid] == nil or swaps.stale[guid] == true
	end

	swaps.Stale = function(m)
		if m.guid and swaps.byGUID[m.guid] then swaps.stale[m.guid] = true end
		m.swapMiss = nil
	end

	swaps.Again = function()
		for guid in pairs(swaps.byGUID) do swaps.stale[guid] = true end
		for guid in pairs(trinket.byGUID) do trinket.stale[guid] = true end
		for _, s in ipairs(slots) do
			if s.member then s.member.tries = nil end
		end
	end

	swaps.Read = function(m, spec)
		local guid = m.guid
		local want = guid and swaps.ids[m.class or '']
		spec = spec or m.spec
		if not want or (spec and not swaps.bySpec[spec]) then return false end
		local ok, got = pcall(ns.TalentRanks, swaps, m.class)
		if not ok then
			Fault(got)
			got = nil
		end
		local old = swaps.byGUID[guid]
		if not got then
			m.swapMiss = (m.swapMiss or 0) + 1
			if m.swapMiss < 3 then return false end
			got = old or {}
		end
		swaps.reads = swaps.reads + 1
		swaps.byGUID[guid], swaps.stale[guid], m.swapMiss = got, nil, nil
		for _, id in ipairs(want) do
			if (old and old[id]) ~= got[id] then return true end
		end
		return false
	end

	swaps.Mark = function(list, s, m)
		local ranks, how
		local own = s.index == 1 and {} or nil
		if s.index == 1 then
			ranks, how = swaps.Own(m.class), 'your talents'
		elseif m.guid and swaps.byGUID[m.guid] then
			ranks, how = swaps.byGUID[m.guid], 'their talents'
		end
		m.gated = nil
		for i = #list, 1, -1 do
			local def = list[i]
			local sw = def.swap
			local keep = true
			if def.spell.selfOnly and s.index ~= 1 then
				tremove(list, i)
				keep, sw = false, nil
			end
			if sw then
				local on, said
				if s.index == 1 then on, said = Mine(sw, def.id), 'your talents' end
				if on == nil and ranks then on, said = Taken(ranks, sw.talents), how end
				if on == nil then on, said = sw.likely and true or false, 'assumed, talents not read' end
				if not sw.known then
					def.show, def.how = on and sw.id or def.id, said
				elseif on then
					def.how = said
				else
					tremove(list, i)
					keep = false
					m.gated = format('%s (%s)%s', ns.CdSpellName(def.id), said, m.gated and (', ' .. m.gated) or '')
				end
			end
			local sp = def.spell
			if keep and ranks then
				local cd = sp.mods and ns.TalentLength(sp.cooldown, sp.mods, ranks, def.spec)
				if cd then def.cd, def.cdHow = cd, how end
				if sp.shortIf then def.noShort = ranks[sp.shortIf] == 0 or nil end
				if def.charges and sp.chargeIf and ranks[sp.chargeIf] == 0 then def.charges = nil end
				if sp.proc then def.noProc = ranks[sp.proc.talent] == 0 or nil end
			end
			if keep and own then
				local id = exact.Id(def)
				if own[id] then
					tremove(list, i)
				else
					own[id] = true
					if id ~= def.id then def.show = id end
				end
			end
		end
	end
end

local function PerUnit(region)
	local es = region:GetEffectiveScale()
	local _, ph = GetPhysicalScreenSize()
	if type(es) ~= 'number' or secret(es) or es <= 0 or type(ph) ~= 'number' or ph <= 0 then return nil end
	return es * ph / 768
end

local metrics, strips = {}, {}

local function Height(text)
	meter:SetText(text)
	local h = meter:GetStringHeight()
	if type(h) ~= 'number' or secret(h) or h <= 0 then return nil end
	return h
end

local function LineMetrics(font, size)
	local ppu = PerUnit(layer)
	local key = format('%s|%s|%.4f', tostring(font), tostring(size), ppu or 0)
	local m = metrics[key]
	if m then return m[1], m[2], m[3] end
	meter:SetFont(font, size, 'OUTLINE')
	meter:SetSpacing(0)
	local one, nine = Height('0'), Height('0\n0\n0\n0\n0\n0\n0\n0\n0')
	if not (one and nine and nine > one) then return size, size, 0 end
	local step, gap = (nine - one) / 8, 0
	local px = ppu and step * ppu
	if px and abs(px - floor(px + 0.5)) > 0.02 then
		local base = step
		for want = ceil(px), ceil(px) + 1 do
			local s = want / ppu - base
			meter:SetSpacing(s)
			nine = Height('0\n0\n0\n0\n0\n0\n0\n0\n0')
			local got = nine and nine > one and (nine - one) / 8 * ppu
			if got and abs(got - floor(got + 0.5)) <= 0.02 then
				step, gap = got / ppu, s
				break
			end
		end
		meter:SetSpacing(0)
	end
	metrics[key] = { step, one, gap }
	return step, one, gap
end

local function StripText(cd)
	local s = strips[cd]
	if s then return s end
	local out = {}
	for r = cd, 1, -1 do
		out[#out + 1] = r >= 60 and format('%d:%02d', floor(r / 60), r % 60) or tostring(r)
	end
	s = tconcat(out, '\n')
	strips[cd] = s
	return s
end

local GLOW_EDGES = {
	{ 'TOPLEFT', 'TOPRIGHT', 'SetHeight' }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', 'SetHeight' },
	{ 'TOPLEFT', 'BOTTOMLEFT', 'SetWidth' }, { 'TOPRIGHT', 'BOTTOMRIGHT', 'SetWidth' },
}

local function NewArc(wide)
	local arc = CreateFrame('StatusBar', nil, wide and layer or arcHost)
	arc:SetStatusBarTexture(WHITE)
	arc:SetStatusBarColor(0, 0, 0, 0)
	arc:SetOrientation('VERTICAL')
	if wide then arc:SetSize(1, ARC) else arc:SetSize(1 / ARC, 1) end
	arc:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 0)
	arc:SetMinMaxValues(0, 1)
	arc:SetValue(1)
	local gap = arcHost:CreateTexture(nil, 'BACKGROUND')
	gap:SetColorTexture(0, 0, 0, 0)
	gap:SetPoint('BOTTOM', arc:GetStatusBarTexture(), 'TOP', 0, 0)
	gap:SetPoint('TOP', arc, 'TOP', 0, 0)
	gap:SetWidth(1 / ARC)
	return arc, gap
end

-- dodo: 아이콘 외형 dodo.LibIcon 사용
local LibIcon = _G.dodo.LibIcon
local cellCount = 0

local function NewCell(row)
	cellCount = cellCount + 1
	local c = LibIcon:Create('dodoPartyCDCell' .. cellCount, row, { iconsize = { 28, 28 } })
	c:Hide()
	c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c:SetScript('OnEnter', function(self)
		if InCombatLockdown() then return end -- dodo: 전투 중 툴팁 끔
		local tip = _G.GameTooltip
		if not (self.tipOn and tip) then return end
		tip:SetOwner(self, 'ANCHOR_RIGHT')
		if self.tipItem then tip:SetItemByID(self.tipItem) else tip:SetSpellByID(self.tipID) end
		tip:Show()
	end)
	c:SetScript('OnLeave', function(self)
		local tip = _G.GameTooltip
		if tip and tip:IsOwned(self) then tip:Hide() end
	end)

	local glow = CreateFrame('Frame', nil, c)
	glow:SetAllPoints(c)
	glow:SetAlpha(0)
	for _, e in ipairs(GLOW_EDGES) do
		local edge = glow:CreateTexture(nil, 'OVERLAY')
		edge:SetColorTexture(0.12, 0.86, 0.76, 1)
		edge:SetPoint(e[1], glow, e[1], 0, 0)
		edge:SetPoint(e[2], glow, e[2], 0, 0)
		edge[e[3]](edge, 2)
	end
	c.glow = glow

	local clip = CreateFrame('Frame', nil, layer)
	clip:SetClipsChildren(true)
	clip:Hide()
	local cover = CreateFrame('Frame', nil, clip)
	cover:SetAllPoints(clip)
	local win = CreateFrame('Frame', nil, layer)
	win:SetClipsChildren(true)
	win:Hide()
	c.clip, c.win, c.cover = clip, win, cover
	c.pos, c.fill, c.text, c.strip, c.shade, c.dim = {}, {}, {}, {}, {}, {}
	c.veil, c.grey, c.gate = {}, {}, {}
	c.arc, c.gap = {}, {}
	for k = 1, 2 do
		local pos = CreateFrame('StatusBar', nil, layer)
		pos:SetStatusBarTexture(WHITE)
		pos:SetStatusBarColor(0, 0, 0, 0)
		pos:SetOrientation('VERTICAL')
		pos:SetMinMaxValues(0, 1)
		pos:SetValue(1)
		local fill = pos:GetStatusBarTexture()
		local gate = CreateFrame('StatusBar', nil, layer)
		gate:SetStatusBarTexture(WHITE)
		gate:SetStatusBarColor(0, 0, 0, 0)
		gate:SetOrientation('VERTICAL')
		gate:SetMinMaxValues(0, 1)
		gate:SetValue(1)
		c.gate[k] = gate
		local text = CreateFrame('Frame', nil, win)
		text:SetAllPoints(win)
		text:SetAlpha(0)
		local strip = text:CreateFontString(nil, 'OVERLAY')
		strip:SetJustifyH('CENTER')
		strip:SetPoint('BOTTOM', fill, 'TOP', 0, 0)
		local veil = CreateFrame('Frame', nil, cover)
		veil:SetClipsChildren(true)
		veil:SetAlpha(0)
		local grey = veil:CreateTexture(nil, 'ARTWORK')
		grey:SetAllPoints(c.icon)
		grey:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		grey:SetDesaturated(true)
		grey:SetVertexColor(GREY, GREY, GREY)
		local shade = CreateFrame('Frame', nil, clip)
		shade:SetAllPoints(clip)
		shade:SetAlpha(0)
		local dim = shade:CreateTexture(nil, 'ARTWORK')
		dim:SetTexture(WHITE)
		dim:SetVertexColor(0, 0, 0, DIM)
		dim:SetAllPoints(c.icon)
		dim:Hide()
		c.pos[k], c.fill[k], c.text[k], c.strip[k], c.shade[k], c.dim[k] = pos, fill, text, strip, shade, dim
		c.veil[k], c.grey[k] = veil, grey
	end
	return c
end

local function Scrap(c)
	c:Hide()
	c.clip:Hide()
	c.win:Hide()
	for k = 1, 2 do
		c.pos[k]:Hide()
		c.gate[k]:Hide()
		if c.arc[k] then c.arc[k]:Hide() end
	end
end

local function Unit(cd) return mmax(1, ceil(cd / CODES)) end

local function Dress(c, def, cfg, size, text)
	size = ns.PixelSize(size or cfg.size or 28, c)
	c:SetSize(size, size)
	if c.RescaleIcon then c:RescaleIcon() end -- dodo: LibIcon 여백 재계산
	local level = c:GetFrameLevel()
	local tex = ns.PTCIcon(def.show or def.id)
	c.clip:SetFrameLevel(level + 1)
	c.cover:SetFrameLevel(level + 3)
	c.win:SetFrameLevel(level + 5)
	c.glow:SetFrameLevel(level + 8)
	c.icon:SetTexture(tex)
	c.tipID, c.tipItem = def.show or def.id, def.spell and def.spell.item or nil
	local tipOn = cfg.tooltip == true
	if c.tipOn ~= tipOn then
		c.tipOn = tipOn
		c:SetMouseClickEnabled(false)
		c:SetMouseMotionEnabled(tipOn)
		local tip = _G.GameTooltip
		if not tipOn and tip and tip:IsOwned(c) then tip:Hide() end
	end
	for k = 1, 2 do
		c.veil[k]:SetFrameLevel(level + 3)
		c.shade[k]:SetFrameLevel(level + 4)
		c.text[k]:SetFrameLevel(level + 6)
		c.grey[k]:SetTexture(tex)
	end
	local font, ts = ns.GetFont(), text or cfg.textSize or 12
	local step, one, gap = LineMetrics(font, ts)
	c.ts = ts
	local chg = def.charges and true or false
	local radial = swipe.on == true
	local sig = tconcat({ tostring(font), ts, def.cd, size, format('%.3f', step), format('%.3f', one),
		radial and (swipe.wide and 'w' or 'r') or 'f', swipe.turn and 't' or '', swipe.mirror and 'm' or '',
		chg and 'c' or '' }, '|')
	if c.sig == sig then return end
	local cd, u = def.cd, Unit(def.cd)
	c.chg, c.wz = chg, nil
	c.win:SetAlpha(1)
	c.cover:SetAlpha(1)
	charge.Dress(c, chg, font, ts)
	local line = mmin(one, step)
	local jump = size + 4
	c.clip:ClearAllPoints()
	c.clip:SetPoint('TOPLEFT', c, 'TOPLEFT', -2, 2)
	c.clip:SetPoint('BOTTOMRIGHT', c, 'BOTTOMRIGHT', 2, -2)
	c.win:ClearAllPoints()
	c.win:SetPoint('CENTER', c, 'CENTER', c.winX or 0, 0) -- dodo: winX = 타이머 가로 이동 (공생기 바)
	c.win:SetSize(size + 6, line)
	c.line, c.seat = line, nil
	for k = 1, 2 do
		local pos, strip, dim, veil, gate = c.pos[k], c.strip[k], c.dim[k], c.veil[k], c.gate[k]
		local edge = gate:GetStatusBarTexture()
		pos:SetMinMaxValues(0, 1)
		pos:SetValue(1)
		pos:ClearAllPoints()
		pos:SetPoint('BOTTOM', c.win, 'BOTTOM', 0, -(cd - 1 + u) * step)
		pos:SetSize(1, 255 * u * step)
		strip:SetFont(font, ts, 'OUTLINE')
		strip:SetSpacing(gap)
		strip:SetTextColor(1, 1, 1)
		strip:SetText(StripText(cd))
		gate:SetMinMaxValues(0, 1)
		gate:SetValue(1)
		gate:ClearAllPoints()
		gate:SetPoint('BOTTOM', c.icon, 'BOTTOM', 0, -(cd - 1 + u) * jump)
		gate:SetSize(1, 255 * u * jump)
		veil:ClearAllPoints()
		veil:SetPoint('BOTTOM', edge, 'TOP', 0, -3)
		veil:SetPoint('TOP', edge, 'TOP', 0, (cd - 1) * jump + size + 1)
		veil:SetWidth(jump)
		if radial then
			if c.arcWide ~= swipe.wide or not c.arc[k] then
				if c.arc[k] then c.arc[k]:Hide() end
				c.arc[k], c.gap[k] = NewArc(swipe.wide)
			end
			dim:SetRotation(swipe.turn and 0 or pi)
			dim:SetRadialProgressBarReverse(not swipe.mirror)
			dim:SetRadialProgressBarPercent(1)
			dim:Show()
		else
			if c.arc[k] then
				dim:ClearRadialProgressBar()
				dim:SetRotation(0)
			end
			dim:Hide()
		end
	end
	if radial then c.arcWide = swipe.wide end
	c.sig = sig
end

local function SeatNow(c)
	local line, ppu = c.line, PerUnit(c)
	if not (line and ppu) then return end
	local _, y = c:GetCenter()
	local seat = 0.25 / ppu
	if type(y) == 'number' and not secret(y) then
		local base = (y - line / 2) * ppu
		if c.seat then
			local at = base + c.seat * ppu
			if abs(at - floor(at) - 0.25) < 0.1 then return end
		end
		local f = base - floor(base)
		seat = ((f < 0.75 and 0.25 or 1.25) - f) / ppu
	elseif c.seat then
		return
	end
	c.win:SetPoint('CENTER', c, 'CENTER', c.winX or 0, seat) -- dodo: winX
	c.seat = seat
end

local function Seat(c)
	local ok, err = pcall(SeatNow, c)
	if not ok then Fault(err) end
end

local function SeatLine(cfg)
	for _, s in ipairs(slots) do
		for j = 1, MAX do
			local c = s.cells[j]
			if c and c.line and c:IsShown() then
				local ppu = PerUnit(c)
				if not ppu then return 'the screen scale cannot be read' end
				local step, one, gap = LineMetrics(ns.GetFont(), c.ts or cfg.textSize or 12)
				local _, y = c:GetCenter()
				local at = 'unknown'
				if type(y) == 'number' and not secret(y) then
					local px = (y - c.line / 2 + (c.seat or 0)) * ppu
					at = format('%.3f', px - floor(px))
				end
				return format('%.4f px per unit | line step %.3f px (%.3f px added), one line %.3f px | window edge at pixel + %s, moved %.3f px',
					ppu, step * ppu, gap * ppu, one * ppu, at, (c.seat or 0) * ppu)
			end
		end
	end
	return 'no icon on screen'
end

local function Clear(t, n)
	local a, b = t.slot[1], t.slot[2]
	a.c, a.v, a.epoch = 1, 0, n
	b.c, b.v, b.epoch = 1, 0, n
	t.cur = 1
	if t.charges then
		t.b, t.a0, t.a1, t.a2, t.f1, t.f2, t.legacy = 0, 0, 0, 1, nil, nil, nil
		charge.WriteCmp(t)
	end
end

local function Roll(t, n)
	local k = t.cur
	if n - t.slot[k].epoch < t.P then return false end
	k = 3 - k
	local sl = t.slot[k]
	sl.c, sl.v, sl.epoch = 1, 0, n
	t.cur = k
	return true
end

local function Stamp(t, n)
	local code = floor((n - t.slot[t.cur].epoch) / t.u)
	local low = t.charges and 1 or 0
	if code < low then code = low elseif code > CODES then code = CODES end
	return (255 - code) / 255
end

local function Left(t, sl, n)
	local code = 255 - floor(sl.c * 255 + 0.5)
	return t.cd - ((n - sl.epoch) - t.u * code)
end

local function Range(c, k, sl, u, n)
	local m = (254 - (n - sl.epoch) / u) / 255
	c.pos[k]:SetMinMaxValues(m, m + 1)
	c.gate[k]:SetMinMaxValues(m, m + 1)
end

local function Clock() return GetTime() - T0 + 0.5 end

local function Sweep(c, k, sl, t, now)
	local span = 255 * t.u
	local m = 1 - (now - sl.epoch) / span
	c.arc[k]:SetMinMaxValues(m, m + t.cd / span)
	local h = c.gap[k]:GetHeight()
	if secret(sl.c) then
		c.dim[k]:SetRadialProgressBarPercent(h)
		swipe.hidden = swipe.hidden + 1
		return
	end
	local r = (t.cd - (now - sl.epoch) + t.u * (255 - floor(sl.c * 255 + 0.5))) / t.cd
	if r < 0 then r = 0 elseif r > 1 then r = 1 end
	c.dim[k]:SetRadialProgressBarPercent(r)
	if type(h) == 'number' and not secret(h) then
		swipe.checks, swipe.last = swipe.checks + 1, abs(h - r)
		if swipe.last > 0.05 then swipe.bad = swipe.bad + 1 end
	end
end

local function Arc(c, k, sl, t, now)
	local ok, err = pcall(Sweep, c, k, sl, t, now)
	local key = secret(sl.c) and 'failHidden' or 'failOpen'
	if ok then
		swipe[key] = 0
		return
	end
	Fault(err)
	swipe[key] = swipe[key] + 1
	if swipe[key] >= 5 then
		swipe.on, swipe.why = false, tostring(err)
		QueueRefresh()
	end
end

local function WriteSlot(c, k, sl, u, n)
	c.pos[k]:SetMinMaxValues(0, 1)
	c.pos[k]:SetValue(sl.c)
	c.gate[k]:SetMinMaxValues(0, 1)
	c.gate[k]:SetValue(sl.c)
	c.text[k]:SetAlpha(sl.v)
	c.veil[k]:SetAlpha(sl.v)
	c.shade[k]:SetAlpha(sl.v)
	Range(c, k, sl, u, n)
	local arc = c.arc[k]
	if arc then
		arc:SetMinMaxValues(0, 1)
		arc:SetValue(sl.c)
	end
end

local function PushCell(t, c, n)
	local arc = swipe.on and c.arc[1] and (not c.chg or charge.Wedge(t, c))
	for k = 1, 2 do
		local ok, err = pcall(WriteSlot, c, k, t.slot[k], t.u, n)
		if not ok then Fault(err) end
		if arc then Arc(c, k, t.slot[k], t, Clock()) end
	end
	if c.chg and not t.exact then
		local ok, err = pcall(charge.Cell, t, c, n)
		if not ok then Fault(err) end
	end
end

local function Push(t)
	t.redraw = nil
	local n = Now()
	if t.cell then PushCell(t, t.cell, n) end
	if t.twin then PushCell(t, t.twin, n) end
end

trinket.Died = function(who)
	trinket.deaths = trinket.deaths + 1
	local quiet = GetTime() + trinket.QUIET
	for _, s in ipairs(slots) do
		if s ~= who and s.member and not s.member.fake then
			for _, t in pairs(s.tr) do
				local cut = t.def and t.def.spell.deathCut
				if cut then
					t.slot[1].epoch = t.slot[1].epoch - cut
					t.slot[2].epoch = t.slot[2].epoch - cut
					t.quiet = quiet
					trinket.cuts = trinket.cuts + 1
					Push(t)
				end
			end
		end
	end
end

trinket.Deaths = function()
	if not trinket.cut then return end
	for _, s in ipairs(slots) do
		local m = s.member
		if m and not m.fake then
			local dead = ns.Ask(_G.UnitIsDeadOrGhost, s.unit) == true and ns.Ask(_G.UnitIsFeignDeath, s.unit) ~= true
			if dead and m.dead == false then trinket.Died(s) end
			m.dead = dead
		end
	end
end

local function StartPlain(t, n)
	Roll(t, n)
	local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
	sl.c, sl.v, other.v = Stamp(t, n), 1, 0
end

local function Plain(v)
	if secret(v) then return 'hidden' end
	if type(v) == 'number' then return format('%.3f', v) end
	return tostring(v)
end

local function CheckSwipe()
	local want = swipe.want
	if want then
		for _, pr in ipairs(swipe.probe) do
			local ok, h = pcall(pr.gap.GetHeight, pr.gap)
			pr.got = ok and h or nil
			if ok and type(h) == 'number' and not secret(h) and abs(h - (1 - want)) < 0.02 then
				swipe.on, swipe.wide = true, pr.wide
				QueueRefresh()
				return
			end
		end
		if swipe.try >= #PROBE then
			swipe.on = false
			swipe.why = format('a bar set to %.3f read back as %s and %s', 1 - want, Plain(swipe.probe[1].got), Plain(swipe.probe[2].got))
			QueueRefresh()
			return
		end
	end
	swipe.try = swipe.try + 1
	swipe.want = PROBE[swipe.try]
	for _, pr in ipairs(swipe.probe) do
		pr.arc:SetMinMaxValues(0, 1)
		pr.arc:SetValue(swipe.want)
	end
end

local function SwipeDump(p)
	if not swipe.probe then return end
	local _, sc = pcall(arcHost.GetScale, arcHost)
	local _, es = pcall(arcHost.GetEffectiveScale, arcHost)
	local _, ui = pcall(UIParent.GetEffectiveScale, UIParent)
	p('   measuring frame: scale', Plain(sc), '| effective', Plain(es), '| screen', Plain(ui), '| tries', swipe.try)
	for _, pr in ipairs(swipe.probe) do
		local fill = pr.arc:GetStatusBarTexture()
		local _, bar = pcall(pr.arc.GetHeight, pr.arc)
		local _, fh = pcall(fill.GetHeight, fill)
		local _, gh = pcall(pr.gap.GetHeight, pr.gap)
		p(format('   %s bar: height %s, fill %s, gap %s, gap wanted %s', pr.wide and 'screen-size' or 'small',
			Plain(bar), Plain(fh), Plain(gh), swipe.want and format('%.3f', 1 - swipe.want) or 'nothing yet'))
	end
	for _, s in ipairs(slots) do
		for j = 1, MAX do
			local c = s.cells[j]
			if c and c:IsShown() then
				for k = 1, 2 do
					local dim = c.dim[k]
					local _, pc = pcall(dim.GetRadialProgressBarPercent, dim)
					local _, so = pcall(dim.GetRadialProgressBarStartOffset, dim)
					local _, eo = pcall(dim.GetRadialProgressBarEndOffset, dim)
					local _, rv = pcall(dim.GetRadialProgressBarReverse, dim)
					local _, al = pcall(c.veil[k].GetAlpha, c.veil[k])
					p(format('   first icon, timer %d: wedge %s, percent %s, start %s, end %s, reverse %s | grey cover alpha %s',
						k, dim:IsShown() and 'shown' or 'not shown', Plain(pc), Plain(so), Plain(eo), tostring(rv), Plain(al)))
				end
				return
			end
		end
	end
end

local function SweepAll()
	local now = Clock()
	for i = 1, #slots + #bars do
		local s = slots[i] or bars[i - #slots].slot
		for j = 1, s.n do
			local t = s.tr[j]
			local c = t and t.cell
			if c and c.arc[1] and (not c.chg or charge.Wedge(t, c)) then
				for k = 1, 2 do
					local sl = t.slot[k]
					if secret(sl.v) or sl.v ~= 0 then Arc(c, k, sl, t, now) end
				end
			end
			local w = t and t.twin
			if w and w.arc[1] and not w.chg then
				for k = 1, 2 do
					local sl = t.slot[k]
					if secret(sl.v) or sl.v ~= 0 then Arc(w, k, sl, t, now) end
				end
			end
		end
	end
end

local function SwipeLine()
	if swipe.on == nil then return 'not checked yet' end
	if not swipe.on then return 'off: ' .. tostring(swipe.why) end
	return format('on (%s bar) | open timers checked %d, off by over 5%% %d, last off by %.4f | hidden timers drawn %d',
		swipe.wide and 'screen-size' or 'small', swipe.checks, swipe.bad, swipe.last, swipe.hidden)
end

local function Tick()
	local n = Now()
	if swipe.on == nil and swipe.probe then CheckSwipe() end
	if charge.ok == nil and charge.probe then
		local ok, err = pcall(charge.Check)
		if not ok then charge.ok, charge.why = false, tostring(err) end
	end
	if swipe.on then SweepAll() end
	if n == lastN then return end
	lastN = n
	trinket.Deaths()
	local any = false
	for i = 1, #slots + #bars do
		local s = slots[i] or bars[i - #slots].slot
		for j = 1, s.n do
			local t = s.tr[j]
			local c = t and t.cell
			if c then
				any = true
				if Roll(t, n) then Push(t) end
				if t.exact then
					exact.Read(t)
					exact.Update(t)
				elseif t.charges then
					local moved, failed = charge.Try(charge.Tick, t, n)
					if moved or failed then Push(t) end
				end
				local running = false
				for k = 1, 2 do
					local sl = t.slot[k]
					if secret(sl.v) or sl.v ~= 0 then
						if not secret(sl.v) and not secret(sl.c) and Left(t, sl, n) <= -LINGER then
							sl.v = 0
							if t.loop then charge.Start(t, n) end
							Push(t)
						else
							local ok, err = pcall(Range, c, k, sl, t.u, n)
							if not ok then Fault(err) end
							if t.twin then
								ok, err = pcall(Range, t.twin, k, sl, t.u, n)
								if not ok then Fault(err) end
							end
							running = true
						end
					end
				end
				if running then
					Seat(c)
					if t.twin then Seat(t.twin) end
				end
			end
		end
		local m = s.member
		if i > 1 and m and not m.fake then
			if ns.Ask(_G.UnitIsVisible, s.unit) == false or ns.Ask(_G.UnitIsConnected, s.unit) == false then
				s.away = true
			elseif s.away then
				s.away = nil
				stats.backs = (stats.backs or 0) + 1
				zone.Stale(s)
				QueueRefresh()
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

local function Pick(cur, dual, short, a, b)
	if not dual then return EvalBool(cur, a, b) end
	if dual == 'any' then
		local r = EvalBool(cur, a, b)
		for i = 1, short.n do r = EvalBool(short[i], a, r) end
		return r
	end
	return EvalBool(cur, EvalBool(short, b, a), b)
end

local function State(cur, dual, short)
	if secret(cur) then return false, false end
	if dual == 'any' then
		local up = cur and true or false
		for i = 1, short.n do
			local v = short[i]
			if secret(v) then return false, false end
			if v then up = true end
		end
		return true, up
	end
	if secret(short) then return false, false end
	return true, (cur and not (dual and short)) and true or false
end

ns.InitCharges(charge, free, swipe, Fault, Now, Roll, Stamp, Left, StartPlain, Pick, EvalBool,
	function() return layer end, T0)

local function Feed(t, cur, dual, short, n)
	if t.primed then
		if Roll(t, n) then Push(t) end
		local prev, prevShort = t.prev, t.prevShort
		local curKnown, up = State(cur, dual, short)
		local prevKnown, was = State(prev, dual, prevShort)
		local idle = (curKnown and not up) or (prevKnown and was)
		if not idle then
			local known = curKnown and prevKnown
			if not (t.charges and charge.Try(charge.Use, t, cur, dual, short, prev, prevShort, known, n)) then
				if known and free.Plain(t) then
					if not free.Vetoed(t) then StartPlain(t, n) end
				else
					local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
					local V = free.Veto
					sl.c = V(t, Pick(cur, dual, short, Pick(prev, dual, prevShort, sl.c, Stamp(t, n)), sl.c), sl.c)
					sl.v = V(t, Pick(cur, dual, short, Pick(prev, dual, prevShort, sl.v, 1), sl.v), sl.v)
					other.v = V(t, Pick(cur, dual, short, Pick(prev, dual, prevShort, other.v, 0), other.v), other.v)
				end
			end
			if known then stats.edges = stats.edges + 1 end
			Push(t)
		end
	end
	t.prev, t.prevShort, t.primed = cur, short, true
end

local function ReadOne(s, j, t, n, glowOn)
	if t.def.bar then glowOn = t.def.bar.look.highlight ~= false end
	local cur = not t.def.spell.others and ns.SensorLit(s.sens[j])
	local dual, short = s.dual[j], false
	if dual then short = ns.SensorLit(s.short[j]) end
	local sig = s.any[j]
	if sig then dual, short = 'any', zone.Read(s, t, sig) end
	stats.reads = stats.reads + 1
	if secret(cur) then stats.secret = stats.secret + 1 end
	if t.quiet and trinket.Quiet(t) then t.primed = false end
	local sp = t.def.spell
	if sp.free or sp.proc then free.Before(s, j, t, n) end
	Feed(t, cur, dual, short, n)
	if sp.free or sp.proc then
		t.pf, t.pp = t.vf, t.vp
		if t.redraw then Push(t) end
	end
	t.last = cur
	local c = t.cell
	if not c then return end
	local lit = 0
	if glowOn then lit = Pick(cur, dual, short, 1, 0) end
	c.glow:SetAlpha(lit)
	if t.twin then t.twin.glow:SetAlpha(lit) end
end

local function ReadSlot(s, n)
	local glowOn = GetCfg().highlight ~= false
	for j = 1, s.n do
		local t = s.tr[j]
		if t and s.live[j] then
			local ok, err = pcall(ReadOne, s, j, t, n, glowOn)
			if not ok then Fault(err) end
		end
	end
end

local driver = CreateFrame('Frame')
driver:Hide()
local acc = 0
driver:SetScript('OnUpdate', function(self, elapsed)
	acc = acc + elapsed
	local now, n = GetTime(), nil
	for i = 1, #slots do
		local s = slots[i]
		if s.quick > 0 then
			s.quick = s.quick - 1
			if s.member and now >= s.hold then
				n = n or Now()
				local glowOn = GetCfg().highlight ~= false
				for j = 1, s.n do
					local t = s.tr[j]
					if t and s.live[j] and t.def.spell.fast then
						local edges = stats.edges
						stats.quick = stats.quick + 1
						local ok, err = pcall(ReadOne, s, j, t, n, glowOn)
						if not ok then Fault(err) end
						if stats.edges > edges then stats.quickEdges = stats.quickEdges + 1 end
					end
				end
			end
		end
	end
	if acc < READ_EVERY then return end
	acc = 0
	local busy = false
	n = n or Now()
	for i = 1, #slots do
		local s = slots[i]
		if s.reads > 0 then
			if not s.member then
				s.reads = 0
			elseif now >= s.hold then
				s.reads = s.reads - 1
				ReadSlot(s, n)
			end
			if s.reads > 0 then busy = true end
		end
	end
	if not busy then self:Hide() end
end)

local function Wake()
	if driver:IsShown() then return end
	acc = 0
	driver:Show()
end

local function OwnCast(s, spellID)
	if secret(spellID) then
		stats.ownHidden = stats.ownHidden + 1
		return
	end
	local t = spellID and s.byCast[spellID]
	if not t then return end
	if t.quiet and trinket.Quiet(t) then return end
	stats.own, stats.ownLast = stats.own + 1, spellID
	local n = Now()
	if (t.def.spell.free or t.def.spell.proc) and free.Own(t, spellID, n) then
		Push(t)
		EnsureTicker()
		return
	end
	if not (t.charges and charge.Try(charge.Use, t, true, false, false, false, false, true, n)) then StartPlain(t, n) end
	Push(t)
	EnsureTicker()
end

for i, unit in ipairs(TOKENS) do
	local s = {
		index = i, unit = unit, reads = 0, quick = 0, hold = 0, n = 0, sensored = i > 1,
		cells = {}, tr = {}, sens = {}, short = {}, live = {}, dual = {}, byCast = {}, any = {}, zone = {}, fr = {}, pr = {},
		xt = {}, xcell = {}, sp = {}, ownedZones = {},
	}
	s.zevt = CreateFrame('Frame')
	s.zevt:SetScript('OnEvent', function(_, _, _, info) zone.Churn(info) end)
	s.evt = CreateFrame('Frame')
	s.evt:SetScript('OnEvent', function(_, event, _, a, b)
		if event == 'UNIT_AURA' then
			if s.member then
				local churn = (s.fast or s.reads < READS_AFTER) and ns.AuraPayloadChurns(a)
				if churn and s.fast then s.quick = 3 end
				if s.reads >= READS_AFTER or churn then
					s.reads = READS_AFTER
					Wake()
				end
			end
		else
			OwnCast(s, b)
		end
	end)
	slots[i] = s
end

local function NewSensor(unit)
	local c, why = ns.NewUnitSensor(sensHost, unit, 'cd', {})
	if not c then failed = why end
	return c
end

local function Aim(c, sig, filters, who)
	local hot = InCombatLockdown() and true or nil
	local fresh = false
	if c.aim ~= sig then
		if not pcall(c.SetAuraGroupCandidateFilters, c, 'cd', filters) then
			pending = true
			return false
		end
		c.aim, fresh = sig, true
	end
	if not c.on then
		c.on, fresh = true, true
		pcall(c.SetEnabled, c, true)
	end
	if fresh or not who or c.who ~= who or (c.hot and not hot) then
		stats.aims = (stats.aims or 0) + 1
		if pcall(c.UpdateAllAuras, c) then
			c.who, c.hot = who, hot
		else
			c.who = nil
		end
	else
		stats.aimSkips = (stats.aimSkips or 0) + 1
	end
	return true
end

zone.Stale = function(s)
	for _, list in ipairs({ s.sens, s.short, s.fr, s.pr }) do
		for j = 1, MAX do
			local c = list[j]
			if c then c.who = nil end
		end
	end
	for _, h in pairs(s.zone) do h.who = nil end
end

local function Park(c)
	if c and c.on then
		c.on = false
		pcall(c.SetEnabled, c, false)
	end
end

zone.Read = function(s, t, sig)
	local lists = t.zl
	if not lists then
		lists = { { n = 0 }, { n = 0 } }
		t.zl = lists
	end
	local list = lists[1] == t.prevShort and lists[2] or lists[1]
	local k = 0
	for i = 1, #slots do
		local o = slots[i]
		local h = o.zone[sig]
		if h and h.on and o ~= s then
			k = k + 1
			list[k] = ns.SensorLit(h)
		end
	end
	for i = k + 1, list.n do list[i] = nil end
	list.n = k
	return list
end

zone.Churn = function(info)
	local churn
	for i = 1, #slots do
		local o = slots[i]
		if o.zowner and o.member and o.reads < READS_AFTER then
			if churn == nil then churn = ns.AuraPayloadChurns(info) end
			if not churn then return end
			o.reads = READS_AFTER
		end
	end
	if churn then Wake() end
end

zone.Aim = function()
	local want = zone.want
	-- Count owners once, including spells that share an aura signature.
	local owners = zone.owners
	wipe(owners)
	for i = 1, #slots do
		local s = slots[i]
		local owned = s.ownedZones
		wipe(owned)
		for j = 1, s.n do
			local sig = s.any[j]
			if sig and not owned[sig] then
				owned[sig] = true
				owners[sig] = (owners[sig] or 0) + 1
			end
		end
	end
	for i = 1, #slots do
		local s = slots[i]
		local exists
		local lit = false
		for sig, sp in pairs(want) do
			local need = (owners[sig] or 0) > (s.ownedZones[sig] and 1 or 0)
			if need then
				if exists == nil then exists = ns.Ask(UnitExists, s.unit) == true end
				need = exists
			end
			local h = s.zone[sig]
			if need and not h then
				if InCombatLockdown() or failed then
					pending = true
				else
					h = NewSensor(s.unit)
					s.zone[sig] = h
				end
			end
			if h then
				if need and Aim(h, sig, sp.filters, s.who) then lit = true else Park(h) end
			end
		end
		for sig, h in pairs(s.zone) do
			if not want[sig] then Park(h) end
		end
		if lit ~= (s.zon or false) then
			s.zon = lit
			if lit then s.zevt:RegisterUnitEvent('UNIT_AURA', s.unit) else s.zevt:UnregisterEvent('UNIT_AURA') end
		end
	end
	for i = 1, #slots do
		local s = slots[i]
		local owner = false
		for j = 1, s.n do
			local sig, t = s.any[j], s.tr[j]
			if sig and t then
				owner = true
				local set = ''
				for k = 1, #slots do
					local h = slots[k].zone[sig]
					if k ~= i and h and h.on then set = set .. k end
				end
				if t.zset ~= set then t.zset, t.primed = set, false end
			end
		end
		s.zowner = owner
	end
end

free.NewHarm = function(unit)
	local c, why = ns.NewUnitSensor(sensHost, unit, 'cd', nil, 'HARMFUL')
	if not c then free.broken = why end
	return c
end

free.Need = function(s, list, j, make)
	local c = list[j]
	if not c then
		if InCombatLockdown() then
			pending = true
		else
			c = make(s.unit)
			list[j] = c
		end
	end
	return c
end

free.Park = function(s, j)
	Park(s.fr[j])
	Park(s.pr[j])
end

free.Aim = function(s, j, def)
	local sp = def.spell
	if sp.free then
		local c = free.Need(s, s.fr, j, NewSensor)
		if c then Aim(c, sp.free.sig, sp.free.filters, s.who) end
	else
		Park(s.fr[j])
	end
	if sp.proc and not def.noProc and not free.broken then
		local c = free.Need(s, s.pr, j, free.NewHarm)
		if c then Aim(c, 'whi', free.WHI, s.who) end
	else
		Park(s.pr[j])
	end
end

free.Before = function(s, j, t, n)
	local fc, pc = s.fr[j], s.pr[j]
	local f, p
	if fc and fc.on then f = ns.SensorLit(fc) end
	if pc and pc.on then p = ns.SensorLit(pc) end
	t.vf, t.vp, t.vpp = f, p, t.pp
	if t.primed and type(f) ~= 'nil' and type(t.pf) ~= 'nil' then free.Refill(t, f, t.pf, n) end
end

free.Plain = function(t)
	return not (secret(t.vf) or secret(t.vp) or secret(t.vpp))
end

free.Vetoed = function(t)
	if t.vf == true then
		free.skipped = free.skipped + 1
		return true
	end
	if t.vp == true and t.vpp == false then
		free.procs = free.procs + 1
		return true
	end
	return false
end

free.Veto = function(t, x, old)
	local f, p, pp = t.vf, t.vp, t.vpp
	if type(f) ~= 'nil' then x = EvalBool(f, old, x) end
	if type(p) ~= 'nil' and type(pp) ~= 'nil' then x = EvalBool(p, EvalBool(pp, x, old), x) end
	return x
end

free.Fill = function(t)
	for k = 1, 2 do
		local sl = t.slot[k]
		sl.c, sl.v = 1, 0
	end
	if t.charges then t.b, t.a0, t.a1, t.a2 = 0, 0, 0, 1 end
	charge.WriteCmp(t)
end

free.Refill = function(t, f, pf, n)
	if not secret(f) and not secret(pf) then
		if f and not pf then
			free.Fill(t)
			free.refills = free.refills + 1
			Push(t)
		end
		return
	end
	local R = free.R
	for k = 1, 2 do
		local sl = t.slot[k]
		sl.c, sl.v = R(f, pf, sl.c, 1), R(f, pf, sl.v, 0)
	end
	if t.charges then
		t.b, t.a0, t.a1, t.a2 = R(f, pf, t.b or 0, 0), R(f, pf, t.a0 or 0, 0), R(f, pf, t.a1 or 0, 0), R(f, pf, t.a2 or 1, 1)
	end
	charge.WriteCmp(t)
	t.redraw = true
end

free.R = function(f, pf, x, r) return EvalBool(f, EvalBool(pf, x, r), x) end

free.Own = function(t, id, n)
	local sp = t.def.spell
	local now = GetTime()
	local dur = sp.free and sp.free.cast[id]
	if dur then
		free.Fill(t)
		t.freeUntil = now + dur
		t.undo = nil
		free.refills = free.refills + 1
		return true
	end
	if sp.proc and sp.proc.casts[id] then
		t.procAt = now
		local u = t.undo
		if u and now - u.at <= 1 then
			for k = 1, 2 do
				local sl = t.slot[k]
				sl.c, sl.v, sl.epoch = u[k][1], u[k][2], u[k][3]
			end
			t.cur, t.b, t.a0, t.a1, t.a2 = u.cur, u.b, u.a0, u.a1, u.a2
			charge.WriteCmp(t)
			free.undone = free.undone + 1
		end
		t.undo = nil
		return true
	end
	if t.freeUntil and now < t.freeUntil then
		free.skipped = free.skipped + 1
		return true
	end
	if t.procAt and now - t.procAt <= 1 then
		free.procs = free.procs + 1
		return true
	end
	local a, b = t.slot[1], t.slot[2]
	t.undo = { at = now, cur = t.cur, b = t.b, a0 = t.a0, a1 = t.a1, a2 = t.a2,
		{ a.c, a.v, a.epoch }, { b.c, b.v, b.epoch } }
	return false
end

free.Line = function(s, j, t)
	local sp, out = t.def.spell, ''
	if sp.free then
		out = out .. ((s.fr[j] and s.fr[j].on) and ' | Incarnation and Berserk watched' or ' | |cffff5555Incarnation NOT watched|r')
	end
	if sp.proc then
		if t.def.noProc then
			out = out .. ' | Well-Honed not taken'
		elseif s.pr[j] and s.pr[j].on then
			out = out .. ' | Well-Honed watched (debuff fingerprint)'
		elseif free.broken then
			out = out .. ' | |cffff5555Well-Honed watch refused: ' .. free.broken .. '|r'
		else
			out = out .. ' | |cffff5555Well-Honed NOT watched|r'
		end
	end
	return out
end

local function AimPair(s, j, def)
	local sp = def.spell
	local main = s.sens[j]
	if sp.others then
		Park(main)
		Park(s.short[j])
		free.Park(s, j)
		return main ~= nil, false
	end
	if not main or not Aim(main, sp.sig, sp.filters, s.who) then
		Park(s.short[j])
		free.Park(s, j)
		return false, false
	end
	free.Aim(s, j, def)
	if not sp.short or def.noShort then
		Park(s.short[j])
		return true, false
	end
	local sh = s.short[j]
	if not sh then
		if InCombatLockdown() or failed then
			pending = true
			return true, false
		end
		sh = NewSensor(s.unit)
		s.short[j] = sh
		if not sh then return true, false end
	end
	if not Aim(sh, sp.shortSig, sp.shortFilters, s.who) then
		return true, false
	end
	return true, true
end

local function Seed(t, def, i, j)
	local frac = PREVIEW_AT[(i + j) % #PREVIEW_AT + 1]
	if frac < 1 then
		local began = Now() - floor(def.cd * frac)
		Clear(t, began - 1)
		charge.Start(t, began)
		t.loop = true
	end
	t.lit = (i == 2 and j == 1)
end

local function Unbind(s, j)
	local t = s.tr[j]
	if t then
		if t.cell == s.cells[j] then t.cell = nil end
		s.tr[j] = nil
	end
	Park(s.sens[j])
	Park(s.short[j])
	free.Park(s, j)
	s.live[j], s.dual[j], s.any[j] = false, false, nil
end

ext.On = function()
	if not ext.host or preview or ns.PTCUnavailable or failed or not built then return false end
	return (IsInGroup() and not IsInRaid()) and true or false
end

ext.Add = function(list, spec, cfg)
	local ids = EXTERNALS[spec]
	if not ids then return list end
	local all
	local hide = ext.look.hide
	for k, id in ipairs(ids) do
		local found = (hide and hide[id]) and true or false
		if list and not found then
			for _, def in ipairs(list) do
				if def.id == id then def.ext, found = k, true end
			end
		end
		if not found then
			all = all or SpecList(spec, cfg, true) or {}
			for _, def in ipairs(all) do
				if def.id == id then
					def.ext, def.ghost = k, true
					list = list or {}
					list[#list + 1] = def
				end
			end
		end
	end
	return list
end

ext.Bind = function(s, found)
	local cur, cells = s.xt, s.xcell
	local was, n = #cur, 0
	for k = 1, found and MAX or 0 do
		local t = found[k]
		if t then
			n = n + 1
			local old, c = cur[n], cells[n]
			if old and old ~= t and old.twin == c then old.twin = nil end
			cur[n] = t
			if not c or not pcall(Dress, c, t.def, ext.look) then
				if c then Scrap(c) end
				c = NewCell(ext.host)
				cells[n] = c
				Dress(c, t.def, ext.look)
			end
			if t.twin ~= c then c.glow:SetAlpha(0) end
			t.twin = c
			Push(t)
		end
	end
	for k = n + 1, was do
		local old = cur[k]
		if old.twin == cells[k] then old.twin = nil end
		cur[k] = nil
	end
end

ext.Place = function()
	local host, look = ext.host, ext.look
	local size, gap = look.size or 40, look.spacing or 2
	if host then size, gap = ns.PixelSize(size, host), ns.PixelSize(gap, host) end
	local at = 0
	for _, s in ipairs(slots) do
		for k, c in ipairs(s.xcell) do
			local t = s.xt[k]
			local on = (host ~= nil and t ~= nil and t.twin == c) and true or false
			if on then
				local step, x, y = at * (size + gap), 0, 0
				if look.growth == 'LEFT' then
					x = -step
				elseif look.growth == 'UP' then
					y = step
				elseif look.growth == 'DOWN' then
					y = -step
				else
					x = step
				end
				c:ClearAllPoints()
				ns.PixelPoint(c, 'TOPLEFT', host, 'TOPLEFT', x, y)
				at = at + 1
				Seat(c)
			end
			c:SetShown(on)
			c.clip:SetShown(on)
			c.win:SetShown(on and look.timer ~= false)
		end
	end
	ext.count = at
end

bars.Any = function(cfg)
	if cfg.enable or ext.host then return true end
	for _, b in ipairs(bars) do
		if b.host ~= nil and b.look.enable == true then return true end
	end
	return false
end

bars.Def = function(b, id, spec)
	local sp = SPELLS[id]
	local base = b.base[spec or 0] or sp.cooldown
	return { id = id, show = id, cd = floor(mmax(CD_MIN, mmin(CD_MAX, base))), base = base,
		spell = sp, swap = sp.swap, spec = spec, ghost = true, bar = b }
end

bars.Wants = function(i)
	for _, b in ipairs(bars) do
		if b.on and (i > 1 or b.look.showSelf ~= false) then return true end
	end
	return false
end

bars.Add = function(list, m, i)
	for _, b in ipairs(bars) do
		local off = b.look.off
		if b.on and (i > 1 or b.look.showSelf ~= false) then
			for _, id in ipairs(b.class[m.class or ''] or {}) do
				if not (off and off[id]) and (b.specs[id] or m.spec) == m.spec then
					list = list or {}
					-- An enabled auxiliary bar owns this spell's primary cell.
					for j = #list, 1, -1 do
						if list[j].id == id then tremove(list, j) end
					end
					list[#list + 1] = bars.Def(b, id, m.spec)
				end
			end
		end
	end
	return list
end

bars.Demo = function(b)
	local look, demo, tr, k = b.look, b.demo, b.slot.tr, 0
	if b.host and look.preview then
		local n = Now()
		local size, text = look.size or 36, look.textSize or 16
		for _, id in ipairs(look.order or b.order) do
			if b.who[id] and not (look.off and look.off[id]) then
				k = k + 1
				local d = demo[k]
				if not d then
					d = { m = { name = '플레이어', fake = true } }
					demo[k] = d
				end
				d.m.class = b.who[id]
				local def = bars.Def(b, id, b.specs[id])
				local t = d.t
				if not t or t.def.id ~= id then
					t = { slot = { {}, {} }, primed = false, cd = def.cd, u = Unit(def.cd), def = def }
					t.P = CODES * t.u
					Clear(t, n)
					Seed(t, def, 2, k)
					d.t = t
				end
				local c = d.c
				if not c or not pcall(Dress, c, def, look, size, text) then
					if c then Scrap(c) end
					c = NewCell(b.host)
					d.c = c
					Dress(c, def, look, size, text)
				end
				t.cell = c
				c.glow:SetAlpha((t.lit and look.highlight ~= false) and 1 or 0)
				tr[k] = t
				Push(t)
			end
		end
	end
	for i = k + 1, MAX do tr[i] = nil end
	b.slot.n = k
	return k > 0
end

bars.Place = function(b)
	local look, list, used = b.look, {}, {}
	if b.host and look.preview then
		for i, d in ipairs(b.demo) do
			if b.slot.tr[i] == d.t then list[#list + 1] = { c = d.c, m = d.m, t = d.t } end -- dodo: t 전달 (bar 모드)
		end
	elseif b.host then
		local rank = {}
		for i, id in ipairs(look.order or b.order) do rank[id] = rank[id] or i end
		for i, s in ipairs(slots) do
			for j = 1, s.n do
				local t = s.tr[j]
				local id = t and t.def.bar == b and t.def.id
				if id and t.cell == s.sp[id] then
					list[#list + 1] = { c = t.cell, m = s.member, t = t, at = (rank[id] or 99) * 10 + i }
				end
			end
		end
		tsort(list, function(x, y) return x.at < y.at end)
	end
	for _, e in ipairs(list) do used[e.c] = true end
	local cells = {}
	for _, s in ipairs(slots) do
		for id, c in pairs(s.sp) do
			if b.who[id] then cells[#cells + 1] = c end
		end
	end
	for _, d in ipairs(b.demo) do cells[#cells + 1] = d.c end
	for _, c in ipairs(cells) do
		if not used[c] then
			c:Hide()
			c.clip:Hide()
			c.win:Hide()
		end
	end
	b.count = #list
	if b.host and look.Place then look.Place(list) end
end

ns.InitExactCooldowns(exact, charge, Clear, Now, Fault, EvalBool)

local function Rows(cfg, count)
	local per = type(cfg.perRow) == 'number' and floor(cfg.perRow) or 4
	if per < 1 then per = 1 end
	if cfg.wrap and count > per then return per, cfg.size2 or 24, cfg.textSize2 or 10 end
	return nil, cfg.size or 28, cfg.textSize or 12
end

local function AssignSlot(s, m, list, cfg, now)
	local n = list and mmin(#list, MAX) or 0
	local fake = m and m.fake or false
	local sensored = s.sensored and not fake
	local watch, fast = false, false
	local xt = nil
	s.who = (m and m.guid) or (s.index == 1 and 'player') or nil
	wipe(s.byCast)
	local count = 0
	for j = 1, n do
		if not list[j].ghost then count = count + 1 end
	end
	local per, size, text = Rows(cfg, count)
	s.per, s.size, s.ts = per, size, text
	for j = 1, MAX do
		local def = j <= n and list[j] or nil
		if def then
			local t = m.tr[def.id]
			if not t then
				t = { slot = { {}, {} }, primed = false }
				m.tr[def.id] = t
			end
			if t.cd ~= def.cd or t.charges ~= def.charges then
				t.cd, t.u, t.loop, t.charges = def.cd, Unit(def.cd), nil, def.charges
				t.P = CODES * t.u
				Clear(t, Now())
				if fake then Seed(t, def, s.index, j) end
			end
			t.def = def
			if t.charges and sensored then charge.Ensure(t) elseif not t.charges then charge.Free(t) end
			local look, cs, ct, c = cfg, size, text, nil
			local bar = def.bar
			if bar then
				look = bar.look
				cs, ct, c = look.size or 36, look.textSize or 16, s.sp[def.id]
			else
				c = s.cells[j]
			end
			if not c or not pcall(Dress, c, def, look, cs, ct) then
				if c then Scrap(c) end
				if bar then
					c = NewCell(bar.host)
					s.sp[def.id] = c
				else
					c = NewCell(s.row)
					s.cells[j] = c
				end
				Dress(c, def, look, cs, ct)
			end
			local old = s.tr[j]
			local glowOn = look.highlight ~= false
			if old ~= t then
				if old and (old.cell == c or old.cell == s.cells[j]) then old.cell = nil end
				s.tr[j] = t
				t.primed, t.last = false, nil
				c.glow:SetAlpha(0)
			end
			t.cell = c
			local live, dual, any = false, false, nil
			if sensored then
				exact.Drop(c, t)
				live, dual = AimPair(s, j, def)
				if live and def.spell.zone then
					any = def.spell.sig
					zone.want[any] = def.spell
				end
				if dual ~= s.dual[j] or any ~= s.any[j] then t.primed = false end
				if live then watch = true end
				if live and def.spell.fast then fast = true end
				if not glowOn then c.glow:SetAlpha(0) end
			else
				Park(s.sens[j])
				Park(s.short[j])
				c.glow:SetAlpha((t.lit and glowOn) and 1 or 0)
				if fake then
					exact.Drop(c, t)
				elseif not exact.Take(t, def, c, ct) then
					for id in pairs(def.spell.casts) do s.byCast[id] = t end
				end
			end
			s.live[j], s.dual[j], s.any[j] = live, dual, any
			if def.ext then
				xt = xt or {}
				xt[def.ext] = t
			end
			Push(t)
		else
			Unbind(s, j)
		end
	end
	ext.Bind(s, xt)
	local want = nil
	if m and not fake and n > 0 then want = sensored and 'UNIT_AURA' or (next(s.byCast) and 'UNIT_SPELLCAST_SUCCEEDED' or nil) end
	if s.event ~= want then
		if s.event then s.evt:UnregisterEvent(s.event) end
		if want then s.evt:RegisterUnitEvent(want, s.unit) end
		s.event = want
	end
	s.member, s.n, s.vis, s.fast = m, n, count, fast
	if watch then
		s.hold, s.reads = now + HOLD, READS_AFTER
	else
		s.reads = 0
	end
end

local RF, mapSig, mapTimer

local function MapSig(map)
	local out = {}
	if type(map) ~= 'table' then return '' end
	for i, s in ipairs(slots) do
		local btn = map[s.unit]
		out[i] = tostring(btn) .. ((btn and ns.Ask(btn.IsVisible, btn) == true) and '+' or '-')
	end
	return tconcat(out, ' ')
end

local function MapLater()
	if mapTimer then return end
	mapTimer = C_Timer.NewTimer(0.5, function()
		mapTimer = nil
		if RF and MapSig(RF._partyUnitToButton) ~= mapSig then QueueRefresh() end
	end)
end

local function FindRF()
	if RF then return RF end
	local eui = _G.EllesmereUI
	local rf = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIRaidFrames
	if type(rf) ~= 'table' or type(rf._partyUnitToButton) ~= 'table' then return nil end
	RF = rf
	if type(rf._RebuildPartyUnitMap) == 'function' then
		hooksecurefunc(rf, '_RebuildPartyUnitMap', function()
			local cfg = GetCfg()
			if not (holder and holder:IsShown() or cfg.enable) or cfg.attach == false then return end
			stats.maps = (stats.maps or 0) + 1
			if MapSig(rf._partyUnitToButton) ~= mapSig then
				stats.mapMoves = (stats.mapMoves or 0) + 1
				RefreshSoon()
			else
				MapLater()
			end
		end)
	end
	return RF
end
ns.PTCCanAttach = function() return FindRF() ~= nil end

local function Seen(btn)
	return (btn and ns.Ask(btn.IsVisible, btn) == true) or false
end

local frames = ns.NewPartyFrameFinder(GetCfg, TOKENS, MapSig,
	function() QueueRefresh() end, Fault,
	function() return (holder and holder:IsShown()) or GetCfg().enable end,
	function() return RF end)

local mock = { frames = {}, map = {}, on = false }

local function HideMock()
	if mock.host and not (mock.guest and not IsInGroup()) then mock.host:Hide() end
	mock.on = false
end

local function MockFrame(i)
	local f = mock.frames[i]
	if f then return f end
	f = CreateFrame('Frame', nil, mock.host)
	local bg = f:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints(f)
	bg:SetColorTexture(0, 0, 0, 0.9)
	f.fill = f:CreateTexture(nil, 'BORDER')
	ns.PixelInset(f.fill, f)
	f.name = f:CreateFontString(nil, 'OVERLAY')
	f.name:SetPoint('LEFT', f, 'LEFT', 4, 0)
	f.name:SetPoint('RIGHT', f, 'RIGHT', -4, 0)
	f.name:SetJustifyH('CENTER')
	f.name:SetWordWrap(false)
	mock.frames[i] = f
	return f
end

local function DrawMock(rf)
	local box, prof = rf._partyContainerFrame, rf.db and rf.db.profile
	if type(box) ~= 'table' or type(prof) ~= 'table'
		or type(rf.RF_PartyDims) ~= 'function' or type(rf._PartyGrowth) ~= 'function' then
		mock.why = 'the party frame layout cannot be read'
		return nil
	end
	local w, h, gap = rf.RF_PartyDims(prof)
	local grow = rf._PartyGrowth(prof)
	if type(w) ~= 'number' or type(h) ~= 'number' or w <= 0 or h <= 0 then
		mock.why = 'the party frames have no size'
		return nil
	end
	if type(gap) ~= 'number' then gap = 0 end
	local snap = rf.PixelSnap
	if type(snap) == 'function' then w, h, gap = snap(w), snap(h), snap(gap) end
	local point, dx, dy = 'TOPLEFT', 0, 0
	if grow == 'RIGHT' then
		dx = w + gap
	elseif grow == 'LEFT' then
		dx, point = -(w + gap), 'TOPRIGHT'
	elseif grow == 'UP' then
		dy, point = h + gap, 'BOTTOMLEFT'
	else
		dy = -(h + gap)
	end
	local first = prof.partyHideSelf and 2 or 1
	local shift = prof.partyFlipGrowth == 'centered' and (first - 1) / 2 or 0
	if not mock.host then
		mock.host = CreateFrame('Frame', nil, UIParent)
		mock.host:SetFrameStrata('LOW')
		mock.host:SetFrameLevel(50)
		mock.host:SetSize(1, 1)
		mock.host:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	end
	mock.host:Show()
	wipe(mock.map)
	local font = ns.GetFont()
	for i = 1, #TOKENS do
		local f = MockFrame(i)
		if i < first then
			f:Hide()
		else
			local at, who = i - first + shift, PREVIEW[i]
			local r, g, b = ClassRGB(who.class, 1)
			f:SetSize(w, h)
			f:ClearAllPoints()
			f:SetPoint(point, box, point, dx * at, dy * at)
			f.fill:SetColorTexture(r * 0.7, g * 0.7, b * 0.7, 1)
			f.name:SetFont(font, 11, 'OUTLINE')
			f.name:SetText(who.name)
			f:Show()
			mock.map[TOKENS[i]] = f
		end
	end
	local left = mock.frames[first]:GetLeft()
	if type(left) ~= 'number' or secret(left) then
		mock.why = 'the party frames have no place on screen yet'
		return nil
	end
	mock.on, mock.why = true, nil
	return mock.map
end

ns.PTCPartyMock = function(want)
	local rf = want and not IsInGroup() and FindRF() or nil
	mock.guest = rf and true or false
	if rf then
		local on, why = mock.on, mock.why
		local ok, map = pcall(DrawMock, rf)
		mock.on, mock.why = on, why
		if ok and map then return map end
		mock.guest = false
	end
	if not mock.on then HideMock() end
	return nil
end

frames.sides = {
	RIGHT        = { at = 'TOPLEFT',     to = 'TOPRIGHT',    x = 1,  y = 0,  from = 'LEFT',   dx = 1,  dy = 0,  corner = 'TOPLEFT',     cx = 0, cy = -1 }, -- dodo: 상단 정렬
	LEFT         = { at = 'TOPRIGHT',    to = 'TOPLEFT',     x = -1, y = 0,  from = 'RIGHT',  dx = -1, dy = 0,  corner = 'TOPRIGHT',    cx = 0, cy = -1 }, -- dodo: 상단 정렬
	BELOW        = { at = 'TOP',         to = 'BOTTOM',      x = 0,  y = -1, from = 'TOP',    dx = 0,  dy = -1, corner = 'TOPLEFT',     cx = 1, cy = 0 },
	BELOW_CENTER = { at = 'TOP',         to = 'BOTTOM',      x = 0,  y = -1, from = 'LEFT',   dx = 1,  dy = 0,  corner = 'TOPLEFT',     cx = 0, cy = -1, mid = true },
	BELOW_RIGHT  = { at = 'TOPLEFT',     to = 'BOTTOMLEFT',  x = 0,  y = -1, from = 'LEFT',   dx = 1,  dy = 0,  corner = 'TOPLEFT',     cx = 0, cy = -1 },
	BELOW_LEFT   = { at = 'TOPRIGHT',    to = 'BOTTOMRIGHT', x = 0,  y = -1, from = 'RIGHT',  dx = -1, dy = 0,  corner = 'TOPRIGHT',    cx = 0, cy = -1 },
	ABOVE        = { at = 'BOTTOM',      to = 'TOP',         x = 0,  y = 1,  from = 'BOTTOM', dx = 0,  dy = 1,  corner = 'BOTTOMLEFT',  cx = 1, cy = 0 },
	ABOVE_CENTER = { at = 'BOTTOM',      to = 'TOP',         x = 0,  y = 1,  from = 'LEFT',   dx = 1,  dy = 0,  corner = 'BOTTOMLEFT',  cx = 0, cy = 1, mid = true },
	ABOVE_RIGHT  = { at = 'BOTTOMLEFT',  to = 'TOPLEFT',     x = 0,  y = 1,  from = 'LEFT',   dx = 1,  dy = 0,  corner = 'BOTTOMLEFT',  cx = 0, cy = 1 },
	ABOVE_LEFT   = { at = 'BOTTOMRIGHT', to = 'TOPRIGHT',    x = 0,  y = 1,  from = 'RIGHT',  dx = -1, dy = 0,  corner = 'BOTTOMRIGHT', cx = 0, cy = 1 },
}

ns.PTCOffsetKeys = function(side)
	local hang = frames.sides[side or GetCfg().side] or frames.sides.RIGHT
	if hang.x ~= 0 then return 'offX', 'offY' end
	return 'offY', 'offX'
end

local function PlaceRow(row, anchor, stack, cfg, prev, hang)
	row:ClearAllPoints()
	if not stack then
		local away, along = cfg.offX or 4, cfg.offY or 0
		ns.PixelPoint(row, hang.at, anchor, hang.to, hang.x ~= 0 and hang.x * away or along, hang.y ~= 0 and hang.y * away or along)
		return
	end
	local up, gap = cfg.growth == 'UP', cfg.rowSpacing or 6
	if not prev then
		ns.PixelPoint(row, up and 'BOTTOMLEFT' or 'TOPLEFT', holder, up and 'BOTTOMLEFT' or 'TOPLEFT', 0, 0)
	elseif up then
		ns.PixelPoint(row, 'BOTTOMLEFT', prev, 'TOPLEFT', 0, gap)
	else
		ns.PixelPoint(row, 'TOPLEFT', prev, 'BOTTOMLEFT', 0, -gap)
	end
end

local function Layout(cfg)
	local gap = ns.PixelSize(cfg.spacing or 2, holder)
	local attach = cfg.attach ~= false
	local rf = attach and FindRF() or nil
	local map = rf and rf._partyUnitToButton or nil
	mapSig = rf and MapSig(map) or nil
	local stack, drawn, any = true, false, false
	for _, s in ipairs(slots) do
		if (s.vis or 0) > 0 then any = true end
	end
	if map and (IsInGroup() or not preview) then
		for _, s in ipairs(slots) do
			if (s.vis or 0) > 0 and Seen(map[s.unit]) then
				stack = false
				break
			end
		end
	end
	local how = stack and 'none' or 'eui'
	frames.sig = ''
	if attach and any and IsInGroup() then
		local units
		units, how = frames.Use(cfg, not stack)
		if units then map, stack = units, false end
		if how ~= 'eui' then frames.Later() end
		if how ~= 'wait' then frames.last = how end
	end
	frames.how = how
	if stack then
		map = nil
		if preview and rf and frames.last ~= 'found' and type(cfg.frames) ~= 'string' then
			local ok, m = pcall(DrawMock, rf)
			if ok and m then
				map, stack, drawn = m, false, true
			elseif not ok then
				mock.why = tostring(m)
			end
		end
	end
	if not drawn then HideMock() end
	local attachOnly = stack and not preview and (how == 'wait' or (rf ~= nil and not IsInGroup()))
	local hang = not stack and frames.sides[cfg.side] or frames.sides.RIGHT
	local column = hang.dy ~= 0
	local timers = cfg.showTimer ~= false
	local font, ts = ns.GetFont(), cfg.textSize or 12
	local prev, rows = nil, 0
	for _, s in ipairs(slots) do
		local row, n, m = s.row, s.n, s.member
		local vis, at = s.vis or 0, 0
		local btn = map and map[s.unit] or nil
		local show = vis > 0 and not attachOnly
		local size = ns.PixelSize(s.size or cfg.size or 28, row)
		local per = s.per
		local along = per or vis
		local lines = per and ceil(vis / per) or 1
		if show and not stack then show = Seen(btn) end
		if show then
			local long = along * size + (along - 1) * gap
			local wide = lines * size + (lines - 1) * gap
			if column then row:SetSize(wide, long) else row:SetSize(long, wide) end
			if pcall(PlaceRow, row, btn, stack, cfg, prev, hang) then
				if stack then prev = row end
				rows = rows + 1
			else
				show = false
			end
		end
		row:SetShown(show)
		for j = 1, MAX do
			local c = s.cells[j]
			if c then
				local t = s.tr[j]
				local on = (show and j <= n and not (t and t.def.ghost)) and true or false
				if on then
					local pitch = size + gap
					c:ClearAllPoints()
					if per then
						local line, pos = floor(at / per), at % per
						local here = pos * pitch
						if hang.mid then here = here + (per - mmin(per, vis - line * per)) * pitch / 2 end
						local cross = line * pitch
						ns.PixelPoint(c, hang.corner, row, hang.corner, hang.dx * here + hang.cx * cross, hang.dy * here + hang.cy * cross)
					else
						local step = at * pitch
						ns.PixelPoint(c, hang.from, row, hang.from, hang.dx * step, hang.dy * step)
					end
					at = at + 1
					Seat(c)
				end
				c:SetShown(on)
				c.clip:SetShown(on)
				c.win:SetShown(on and timers)
			end
		end
		local label = row.name
		if show and stack and cfg.showName ~= false and m and type(m.name) ~= 'nil' then
			label:SetFont(font, ts, 'OUTLINE')
			label:SetTextColor(ClassRGB(m.class, 1))
			if not pcall(label.SetText, label, m.name) then label:SetText('') end
			label:Show()
		else
			label:Hide()
		end
	end
	local size = cfg.size or 28
	holder:SetSize(4 * size + 3 * (cfg.spacing or 2), size)
	holder:SetShown(rows > 0)
	holder:EnableMouse((preview and stack and not cfg.lock) and true or false)
end

local function InspectSpec(unit)
	local get = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetInspectSpecialization) or _G.GetInspectSpecialization
	if not get then return nil end
	local ok, id = pcall(get, unit)
	if ok and type(id) == 'number' and not secret(id) and id > 0 then return id end
	return nil
end

local queue, inspectTicker = {}, nil

local function StopInspects()
	wipe(queue)
	if inspectTicker then
		inspectTicker:Cancel()
		inspectTicker = nil
	end
end

local function InspectStep()
	if #queue == 0 or not bars.Any(GetCfg()) then
		StopInspects()
		return
	end
	local s = queue[1]
	local m, unit = s.member, s.unit
	if not m or m.fake or (m.spec and not swaps.Wanted(m) and not trinket.Wanted(m)) then
		tremove(queue, 1)
		return
	end
	local now = GetTime()
	if (m.tries or 0) >= 12 then
		if now - (m.triedAt or 0) < 30 then
			tremove(queue, 1)
			C_Timer.After(30, QueueRefresh)
			return
		end
		m.tries = 0
	end
	local sent, why = ns.SendInspect(unit)
	if why == 'wait' then return end
	tremove(queue, 1)
	if sent then
		m.tries, m.triedAt = (m.tries or 0) + 1, now
		swaps.asks = swaps.asks + 1
	end
	queue[#queue + 1] = s
end

local function QueueInspect(s)
	for _, q in ipairs(queue) do
		if q == s then return end
	end
	queue[#queue + 1] = s
	if not inspectTicker then inspectTicker = C_Timer.NewTicker(1, InspectStep) end
end

local function SpecFor(s, m)
	if s.index == 1 then
		m.how = 'yours'
		return ns.CHSpecID() or m.spec
	end
	local guid = m.guid
	local spec = guid and specByGUID[guid]
	if spec then
		m.how = 'inspected'
		return spec
	end
	spec = InspectSpec(s.unit)
	if spec then
		if guid then specByGUID[guid] = spec end
		m.how = 'inspected'
		return spec
	end
	local byRole = ROLE_SPEC[m.class or '']
	spec = byRole and byRole[RoleOf(s.unit) or ''] or nil
	if spec then
		m.how = 'from the role'
		return spec
	end
	QueueInspect(s)
	return nil
end

local function ApplyPosition()
	if not holder then return end
	local cfg = GetCfg()
	holder:ClearAllPoints()
	holder:SetPoint('CENTER', UIParent, 'CENTER', cfg.x or 0, cfg.y or 0)
end

local function EnsureFrame()
	if holder then return end
	holder = CreateFrame('Frame', 'dodoPartyCDs', UIParent)
	holder:SetFrameStrata('MEDIUM')
	holder:SetSize(88, 28)
	holder:SetClampedToScreen(true)
	holder:SetMovable(true)
	holder:EnableMouse(false)
	holder:RegisterForDrag('RightButton')
	holder:Hide()
	layer = CreateFrame('Frame', nil, UIParent)
	layer:SetFrameStrata('MEDIUM')
	layer:SetSize(1, 1)
	layer:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	meter = layer:CreateFontString(nil, 'OVERLAY')
	meter:SetPoint('CENTER', layer, 'CENTER', 0, 0)
	meter:SetAlpha(0)
	arcHost = CreateFrame('Frame', nil, UIParent)
	arcHost:SetSize(1, 1)
	arcHost:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 0)
	pcall(arcHost.SetScale, arcHost, ARC)
	local probe = layer:CreateTexture(nil, 'BACKGROUND')
	probe:Hide()
	if probe.SetRadialProgressBarPercent and probe.SetRadialProgressBarReverse and probe.ClearRadialProgressBar then
		swipe.probe = {}
		for i, wide in ipairs({ true, false }) do
			local arc, gap = NewArc(wide)
			swipe.probe[i] = { arc = arc, gap = gap, wide = wide }
		end
	else
		swipe.on, swipe.why = false, 'this client cannot draw a texture as a clock wipe'
	end
	charge.probe = charge.New()
	ns.MakeDraggable(holder, GetCfg, 'x', 'y', ApplyPosition)
	for _, s in ipairs(slots) do
		local row = CreateFrame('Frame', nil, holder)
		row:Hide()
		row.name = row:CreateFontString(nil, 'OVERLAY')
		row.name:SetPoint('RIGHT', row, 'LEFT', -4, 0)
		row.name:SetJustifyH('RIGHT')
		row.name:SetWordWrap(false)
		row.name:Hide()
		s.row = row
	end
	ApplyPosition()
end

local function EnsureEngine()
	if failed or ns.PTCUnavailable then return end
	if InCombatLockdown() then
		waitBuild = true
		return
	end
	waitBuild = false
	if not sensHost then
		sensHost = CreateFrame('Frame', nil, UIParent)
		sensHost:SetSize(1, 1)
		sensHost:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0)
	end
	for i, s in ipairs(slots) do
		s.sensored = i > 1 or selfSensors
		if s.sensored then
			for j = 1, MAX do
				if not s.sens[j] then
					s.sens[j] = NewSensor(s.unit)
					if not s.sens[j] then return end
				end
			end
		end
	end
	built = true
end

local function Live(cfg)
	if not cfg.enable or ns.PTCUnavailable or failed or not built then return false end
	if IsInRaid() then return false end
	if cfg.groupOnly ~= false and not IsInGroup() then return false end
	if cfg.dungeonOnly and not ns.InDungeon() then return false, 'not in a dungeon' end
	return true
end

bars.On = function(b)
	return b.host ~= nil and Live(b.look) and true or false
end

local function Refresh()
	if not holder then return end
	local cfg = GetCfg()
	local now = GetTime()
	local on = Live(cfg)
	local extOn = ext.On()
	local seen, cells, reads = {}, false, false
	pending = false
	fought = InCombatLockdown() and true or false
	wipe(zone.want)
	wipe(exact.on)
	trinket.cut = false
	for _, b in ipairs(bars) do b.on = bars.On(b) end
	for i, s in ipairs(slots) do
		local m, list
		local rows = (on and (i > 1 or cfg.showSelf)) and true or false
		local twin = extOn and i > 1
		local bar = bars.Wants(i)
		if preview then
			local p = PREVIEW[i]
			local key = 'preview' .. PREVIEW.n .. ':' .. i
			m = members[key]
			if not m then
				m = { tr = {}, fake = true, class = p.class, name = p.name, spec = p.spec, race = p.race }
				members[key] = m
			end
			list = racial.Add(trinket.Add(SpecList(p.spec, cfg), p.items, cfg), p.race, cfg)
			if i > 1 and list then
				for k = #list, 1, -1 do
					if list[k].spell.selfOnly then tremove(list, k) end
				end
			end
		elseif (rows or twin or bar) and ns.Ask(UnitExists, s.unit) == true then
			local key = Key(s.unit)
			m = members[key]
			if not m then
				m = { tr = {} }
				members[key] = m
			end
			m.guid = key ~= s.unit and key or nil
			m.class = ClassOf(s.unit) or m.class
			m.race = racial.Of(s.unit, m.guid) or m.race
			m.name = NameOf(s.unit)
			m.spec = SpecFor(s, m)
			list = (rows and m.spec) and SpecList(m.spec, cfg) or nil
			if rows then list = racial.Add(trinket.Add(list, trinket.Of(s, m), cfg), m.race, cfg) end
			if twin and m.spec then list = ext.Add(list, m.spec, cfg) end
			if bar then list = bars.Add(list, m, i) end
			if list then swaps.Mark(list, s, m) end
			if i > 1 and m.spec and (swaps.Wanted(m) or (rows and trinket.Wanted(m))) then QueueInspect(s) end
		end
		if m then seen[m] = true end
		if list then
			Limit(list, cfg)
			if cfg.reverse then Reverse(list) end
		end
		local ok, err = pcall(AssignSlot, s, m, list, cfg, now)
		if not ok then Fault(err) end
		if s.n > 0 then cells = true end
		if s.reads > 0 then reads = true end
	end
	for key, m in pairs(members) do
		if not seen[m] then
			for _, t in pairs(m.tr) do
				t.cell, t.twin = nil, nil
				charge.Free(t)
			end
			members[key] = nil
		elseif not trinket.cut then
			m.dead = nil
		end
	end
	exact.Listen(next(exact.on) ~= nil)
	local ok, err = pcall(zone.Aim)
	if not ok then Fault(err) end
	ok, err = pcall(Layout, cfg)
	if not ok then Fault(err) end
	ok, err = pcall(ext.Place)
	if not ok then Fault(err) end
	for _, b in ipairs(bars) do
		ok, err = pcall(bars.Demo, b)
		if not ok then Fault(err) elseif err then cells = true end
		ok, err = pcall(bars.Place, b)
		if not ok then Fault(err) end
	end
	if cells then EnsureTicker() end
	if reads then Wake() end
end

QueueRefresh = ns.Coalesce(Refresh)

local late
RefreshSoon = function()
	QueueRefresh()
	if late then late:Cancel() end
	late = C_Timer.NewTimer(0.5, QueueRefresh)
end

local function ResetAll(hold)
	local now = GetTime()
	local n = Now()
	for _, m in pairs(members) do
		for _, t in pairs(m.tr) do
			if not t.loop then
				Clear(t, n)
				Push(t)
			end
		end
	end
	for _, s in ipairs(slots) do
		if s.member and s.event == 'UNIT_AURA' then s.hold, s.reads = now + hold, READS_AFTER end
	end
	lastN = nil
	Wake()
end

local evt = CreateFrame('Frame')
local LIVE_EVENTS = {
	'GROUP_ROSTER_UPDATE', 'PLAYER_REGEN_ENABLED', 'CHALLENGE_MODE_START', 'INSPECT_READY',
	'PLAYER_SPECIALIZATION_CHANGED', 'PLAYER_ROLES_ASSIGNED', 'TRAIT_CONFIG_UPDATED', 'PLAYER_TALENT_UPDATE',
	'READY_CHECK', 'PLAYER_EQUIPMENT_CHANGED', 'UNIT_DIED', 'CHALLENGE_MODE_DEATH_COUNT_UPDATED',
}
local listening = false

local function Apply()
	local cfg = GetCfg()
	if door.state ~= 'exact' and door.state ~= 'close' then
		door = TestDoor()
		ns.PTCUnavailable = not (HAS_WIDGETS and DoorOpen())
	end
	local wanted = (bars.Any(cfg) and not ns.PTCUnavailable) and true or false
	if wanted ~= listening then
		listening = wanted
		for _, e in ipairs(LIVE_EVENTS) do
			if wanted then evt:RegisterEvent(e) else evt:UnregisterEvent(e) end
		end
		if not wanted then StopInspects() end
	end
	if not (wanted or preview or bars.speed.host or bars.guard.host or holder) then return end
	EnsureFrame()
	ApplyPosition()
	if wanted then EnsureEngine() end
	Refresh()
end

ns.PTCApply = ns.Coalesce(Apply)
ns.OnPixelChange(function() ns.PTCApply() end)

ns.PTCIsPreview = function() return preview end
ns.PTCSetPreview = function(state)
	state = state and true or false
	if state and not preview then
		PREVIEW.Deal(PREVIEW.fresh)
		PREVIEW.fresh = false
	elseif not state then
		local w = _G.H3ndallPartyCdsConfig
		if not (w and w:IsShown()) then PREVIEW.fresh = true end
	end
	preview = state
	Apply()
end

ns.PTCSetShown = function(spec, id, on)
	if not SPELLS[id] then return end
	GetCfg().off[CdKey(spec, id)] = (not on) and true or nil
	ns.PTCApply()
end

ns.PTCMove = function(spec, id, dir)
	local cfg = GetCfg()
	local list = SpecList(spec, cfg, true)
	if not list or (dir ~= 1 and dir ~= -1) then return false end
	local at
	for i, def in ipairs(list) do
		if def.id == id then at = i end
	end
	local to = at and at + dir
	if not to or not list[to] then return false end
	list[at], list[to] = list[to], list[at]
	local ids, moved = {}, false
	for i, def in ipairs(list) do
		local e = SPECS[spec][i]
		ids[i] = def.id
		if (type(e) == 'table' and e[1] or e) ~= def.id then moved = true end
	end
	cfg.order[spec] = moved and ids or nil
	ns.PTCApply()
	return true
end

ns.PTCExt = function(host, look)
	local sig = ''
	if host then
		look = look or {}
		local off = {}
		for id, on in pairs(look.hide or {}) do
			if on then off[#off + 1] = id end
		end
		tsort(off)
		sig = tconcat({ tostring(host), tostring(look.size), tostring(look.textSize), tostring(look.growth),
			tostring(look.spacing), tostring(look.timer), tconcat(off, ',') }, '|')
	end
	if sig == ext.sig then return end
	ext.sig, ext.host = sig, host or nil
	if host then ext.look = look end
	ns.PTCApply()
end

ns.PTCBar = function(key, host, look)
	local b = bars[key]
	b.host, b.look = host or nil, look or {}
	ns.PTCApply()
end

ns.PTCBarCatalogue = function(key)
	local b, out = bars[key], {}
	for _, id in ipairs(b.order) do out[#out + 1] = { id = id, class = b.who[id], spec = b.specs[id] } end
	return out
end

ns.PTCFrameChoices = function(done)
	if done then frames.Ask(done) end
	local out, have = { { value = 'AUTO', text = 'Auto' } }, {}
	for _, name in ipairs(frames.known) do
		out[#out + 1] = { value = name, text = name }
		have[name] = true
	end
	local want = GetCfg().frames
	if type(want) == 'string' and want ~= '' and not have[want] then out[#out + 1] = { value = want, text = want } end
	return out
end

ns.PTCSetFrames = function(name)
	GetCfg().frames = (type(name) == 'string' and name ~= '' and name ~= 'AUTO') and name or nil
	frames.Fresh()
	frames.owed = true
	ns.PTCApply()
end

ns.PTCKit = {
	Ensure = EnsureFrame, NewCell = NewCell, Dress = Dress, Scrap = Scrap, Seat = Seat,
	Unit = Unit, Clear = Clear, Roll = Roll, StartPlain = StartPlain, Left = Left, Range = Range,
	PushCell = PushCell, Feed = Feed, Arc = Arc, Now = Now, Clock = Clock,
	Swipe = function() return swipe.on == true end,
	Spec = function(guid) return guid and specByGUID[guid] or nil end,
	Name = NameOf, Key = Key, InspectSpec = InspectSpec,
	CODES = CODES, LINGER = LINGER,
	Swap = function(list, id, dir)
		if type(list) ~= 'table' or (dir ~= 1 and dir ~= -1) then return false end
		local at
		for i, v in ipairs(list) do
			if v == id then at = i end
		end
		local to = at and at + dir
		if not to or not list[to] then return false end
		list[at], list[to] = list[to], list[at]
		return true
	end,
	LayOpts = function(o, size, gap, grow, names, namePos, nameSize, letters)
		o.grow, o.names, o.font, o.nameSize, o.letters = grow, names, ns.GetFont(), nameSize, letters
		o.below = names and namePos == 'BELOW'
		o.step = ns.PixelSize(size, UIParent) + ns.PixelSize(gap, UIParent)
		o.tall = o.step + (o.below and ns.PixelSize(nameSize + 2, UIParent) or 0)
		return o
	end,
	Lay = function(c, who, m, frame, i, n, o)
		local k, x, y, step = i - 1, 0, 0, o.step
		if o.grow == 'LEFT' then
			x = -k * step
		elseif o.grow == 'UP' then
			y = k * o.tall
		elseif o.grow == 'DOWN' then
			y = -k * o.tall
		elseif o.grow == 'CENTER' then
			x = (k - (n - 1) / 2) * step
		else
			x = k * step
		end
		c:ClearAllPoints()
		ns.PixelPoint(c, 'CENTER', frame, 'CENTER', x, y)
		Seat(c)
		if not (o.names and m and type(m.name) ~= 'nil') then
			who:Hide()
			return
		end
		who:SetFont(o.font, o.nameSize, 'OUTLINE')
		who:SetTextColor(ns.ClassRGB(m.class, 1))
		who:ClearAllPoints()
		if o.below then
			who:SetPoint('TOP', c, 'BOTTOM', 0, -1)
		else
			who:SetPoint('BOTTOM', c, 'BOTTOM', 0, 2)
		end
		who:SetWidth(step)
		if not pcall(who.SetText, who, ns.Letters(m.name, o.letters)) then who:SetText('') end
		who:Show()
	end,
}

evt:RegisterEvent('PLAYER_ENTERING_WORLD')
evt:SetScript('OnEvent', function(_, event, arg1)
	if event == 'PLAYER_ENTERING_WORLD' then
		frames.Fresh()
		for i = 1, #slots do zone.Stale(slots[i]) end
		if ns.InDungeon() then swaps.Again() end
		C_Timer.After(0.5, ns.PTCApply)
		return
	end
	if not bars.Any(GetCfg()) then return end
	if event == 'UNIT_DIED' or event == 'CHALLENGE_MODE_DEATH_COUNT_UPDATED' then
		trinket.Deaths()
		return
	end
	if event == 'CHALLENGE_MODE_START' then
		ResetAll(KEY_HOLD)
	elseif event == 'PLAYER_REGEN_ENABLED' then
		if waitBuild or pending then
			ns.PTCApply()
		elseif fought then
			stats.ends = (stats.ends or 0) + 1
			QueueRefresh()
		else
			stats.endSkips = (stats.endSkips or 0) + 1
		end
	elseif event == 'INSPECT_READY' then
		if secret(arg1) or not arg1 then return end
		for _, s in ipairs(slots) do
			local m = s.member
			if m and m.guid == arg1 then
				local spec = InspectSpec(s.unit)
				local changed = swaps.Read(m, spec)
				if trinket.Read(s, m) then changed = true end
				if spec and specByGUID[arg1] ~= spec then
					specByGUID[arg1] = spec
					changed = true
				end
				if changed then QueueRefresh() end
			end
		end
	elseif event == 'PLAYER_SPECIALIZATION_CHANGED' then
		if type(arg1) == 'string' and not secret(arg1) and arg1 ~= 'player' then
			for _, s in ipairs(slots) do
				local m = s.member
				if s.unit == arg1 and m and m.guid then
					specByGUID[m.guid] = nil
					m.spec, m.tries = nil, nil
					swaps.Stale(m)
				end
			end
		else
			swaps.own = nil
		end
		QueueRefresh()
	elseif event == 'TRAIT_CONFIG_UPDATED' or event == 'PLAYER_TALENT_UPDATE' then
		swaps.own = nil
		QueueRefresh()
	elseif event == 'PLAYER_EQUIPMENT_CHANGED' then
		if arg1 == 13 or arg1 == 14 then
			trinket.own = nil
			QueueRefresh()
		end
	elseif event == 'READY_CHECK' then
		if ns.InDungeon() and not ns.KeyActive() then
			swaps.Again()
			QueueRefresh()
		end
	else
		if event == 'GROUP_ROSTER_UPDATE' then
			frames.Fresh()
			RefreshSoon()
		else
			QueueRefresh()
		end
	end
end)

_G.SLASH_DODOPARTYCDDEBUG1 = '/ptcd'
_G.SlashCmdList.DODOPARTYCDDEBUG = function(msg)
	local function p(...) print('[dodo] PartyCD', ...) end
	local cmd = (msg or ''):lower():match('^%s*(%S*)')
	local cfg = GetCfg()
	if cmd == 'test' then
		local n, count, through = Now(), 0, 0
		for _, s in ipairs(slots) do
			for j = 1, MAX do
				local t = s.tr[j]
				if t and not t.exact then
					charge.Start(t, n)
					if EvalBool and not t.loop then
						local sl = t.slot[t.cur]
						local ok1, c = pcall(EvalBool, true, sl.c, 0)
						local ok2, v = pcall(EvalBool, true, 1, 0)
						if ok1 and ok2 then
							sl.c, sl.v = c, v
							through = through + 1
						end
					end
					Push(t)
					count = count + 1
				end
			end
		end
		EnsureTicker()
		p('started', count, 'timers by hand,', through, 'of them through the value check; each should show its full length now')
		return
	end
	if cmd == 'cds' then
		local get = _G.GetSpellBaseCooldown
		if not get then
			p('this client has no base cooldown lookup, so the list cannot be checked against it')
			return
		end
		local same, differ, seen, blank, talented = 0, 0, {}, {}, {}
		local function Check(def)
			local raw = def.spell.cooldown
			if not seen[def.id] then
				seen[def.id] = true
				local ok, ms = pcall(get, def.id)
				if def.spell.charge or not ok or secret(ms) or type(ms) ~= 'number' or ms <= 0 then
					blank[#blank + 1] = ns.CdSpellName(def.id)
				else
					local sec = floor(ms / 1000 + 0.5)
					if sec == raw then
						same = same + 1
					else
						differ = differ + 1
						p(format('   %s (%d): the client says %d s, the list has %d s', ns.CdSpellName(def.id), def.id, sec, raw))
					end
				end
			end
			local line = format('%s %d > %d', ns.CdSpellName(def.id), raw, def.base)
			if def.base ~= raw and not seen[line] then
				seen[line] = true
				talented[#talented + 1] = line
			end
		end
		for _, c in ipairs(CLASSES) do
			for _, spec in ipairs(c.specs) do
				for _, def in ipairs(SpecList(spec, cfg, true) or {}) do Check(def) end
			end
		end
		for _, def in ipairs(racial.List(cfg)) do Check(def) end
		for _, b in ipairs(bars) do
			for _, id in ipairs(b.order) do Check(bars.Def(b, id, b.specs[id])) end
		end
		p(format('base cooldowns: %d match, %d differ, %d the client gave no length for', same, differ, #blank))
		if #blank > 0 then p('   no length: ' .. tconcat(blank, ', ')) end
		if #talented > 0 then p('   shortened for a spec (base > used): ' .. tconcat(talented, ', ')) end
		return
	end
	if cmd == 'door' then
		door = TestDoor()
		p('value check =', DoorLine())
		if not EvalBool then return end
		for _, v in ipairs({ 0.5, 0.123456789, 37 / 255, 1 / 3, 1 / 255, 254 / 255, 1.5, 300, -0.25 }) do
			local ok, r = pcall(EvalBool, true, v, 0)
			local got
			if not ok then
				got = 'refused: ' .. tostring(r)
			elseif secret(r) then
				got = 'hidden'
			elseif type(r) == 'number' then
				got = format('%.10f (off by %.1e)', r, abs(r - v))
			else
				got = type(r)
			end
			p(format('   %.10f ->', v), got)
		end
		return
	end
	if cmd == 'swipe' then
		local arg = (msg or ''):lower():match('^%s*%S+%s+(%S+)')
		if arg == 'turn' then
			swipe.turn = not swipe.turn
		elseif arg == 'mirror' then
			swipe.mirror = not swipe.mirror
		elseif arg == 'off' then
			swipe.on, swipe.why = false, 'turned off by hand'
		elseif arg == 'on' and swipe.probe then
			swipe.on, swipe.why, swipe.try, swipe.want = nil, nil, 0, nil
			EnsureTicker()
		end
		QueueRefresh()
		p('swipe =', SwipeLine())
		SwipeDump(p)
		p('   built to start at the', swipe.turn and 'bottom' or 'top', 'with the lit part growing', swipe.mirror and 'anticlockwise' or 'clockwise')
		p('   /ptcd swipe turn | mirror | off | on')
		return
	end
	if cmd == 'reset' then
		ResetAll(HOLD)
		p('every timer cleared')
		return
	end
	if cmd == 'frames' then
		if not frames.Ask(nil, p) then p('a search is already running, try again in a second') end
		return
	end
	if cmd == 'self' then
		if InCombatLockdown() then
			p('not in combat')
			return
		end
		selfSensors = not selfSensors
		Apply()
		p('your own row is read', selfSensors and 'from your buffs, the way a party member is' or 'from your casts')
		return
	end
	local watching = 0
	for _, s in ipairs(slots) do
		for j = 1, MAX do
			if s.live[j] and s.sens[j] and s.sens[j].on then watching = watching + 1 end
			if s.dual[j] then watching = watching + 1 end
		end
		for _, h in pairs(s.zone) do
			if h.on then watching = watching + 1 end
		end
	end
	p('enable =', cfg.enable and 'on' or 'off', '| preview =', preview and 'ON' or 'off',
		'| widgets =', HAS_WIDGETS and 'ok' or '|cffff5555no aura container widgets|r',
		'| sensors =', built and ('built, ' .. watching .. ' watching') or 'not built')
	p('value check =', DoorLine(), ns.PTCUnavailable and '| |cffff5555the module is off because of this|r' or '')
	local live, why = Live(cfg)
	p('in raid =', IsInRaid() and 'yes' or 'no', '| in group =', IsInGroup() and 'yes' or 'no',
		'| only in dungeons =', cfg.dungeonOnly and 'on' or 'off',
		'| watching =', live and 'yes' or (why and ('no, ' .. why) or 'no'),
		'| party frames =', frames.Line(cfg),
		'| preview frames =', mock.on and 'drawn' or (mock.why or 'off'))
	do
		local names = {}
		for _, set in ipairs(frames.sets) do names[#names + 1] = format('%s (%d)', set.name or 'no name', set.n) end
		p('party frame search = ran', frames.scans, '| last looked at', frames.seen, format('frames in %.1f ms', frames.cost),
			'| on screen:', #names > 0 and tconcat(names, ', ') or 'none',
			'| choice =', type(cfg.frames) == 'string' and cfg.frames or 'auto',
			'| EllesmereUI frames =', FindRF() and 'there' or 'not there')
	end
	p('reads =', stats.reads, '| hidden =', stats.secret, '| starts seen in the open =', stats.edges,
		'| errors =', stats.errors, '| your casts =', stats.own, '| last =', tostring(stats.ownLast),
		'| hidden casts =', stats.ownHidden)
	p('party frame map = rebuilt', stats.maps or 0, '| changed', stats.mapMoves or 0)
	p('refresh when a fight ends = done', stats.ends or 0, '| not needed', stats.endSkips or 0)
	p('sensor re-reads = done', stats.aims or 0, '| not needed', stats.aimSkips or 0,
		'| after a member came back', stats.backs or 0)
	p('quick reads on the 3 frames after an aura change (Vanish) =', stats.quick, '| starts they saw in the open =', stats.quickEdges)
	p('healer external icon =', ext.host and (ext.On() and (ext.count .. ' drawn') or 'asked for, not in a party of five') or 'not asked for')
	for _, b in ipairs(bars) do
		p(b.label .. ' =', not b.host and 'not asked for' or (b.look.preview and (b.count .. ' sample icons'))
			or (bars.On(b) and (b.count .. ' icons drawn')) or 'switched off, or not in a party')
	end
	local okSeat, seatLine = pcall(SeatLine, cfg)
	p('timer text =', okSeat and seatLine or ('cannot be measured: ' .. tostring(seatLine)))
	p('swipe =', SwipeLine())
	p('charges =', charge.Line())
	p('talents =', 'read ' .. swaps.reads .. ' times | inspects sent ' .. swaps.asks .. ' | asked only inside a dungeon')
	p('your own row =', next(exact.on) and format('the game\'s own cooldowns | updates %d | hidden charge reads %d', exact.updates, exact.reads) or 'from your casts')
	p('own row cooldown events = for your spells', exact.ev.named, '| charges', exact.ev.charges, '| every spell', exact.ev.all, '| other spells, skipped', exact.ev.other)
	p('frenzied regeneration =', format('charges refilled %d | presses not counted during Incarnation %d | Well-Honed procs set aside %d | your uses taken back %d',
		free.refills, free.skipped, free.procs, free.undone))
	p('trinkets =', trinket.On(cfg) and ('read ' .. trinket.reads .. ' times from inspects | asked only inside a dungeon') or 'every trinket switched off',
		format('| allied deaths seen %d, cooldowns cut %d times | barrier reads set aside after a death %d', trinket.deaths, trinket.cuts, trinket.quiet),
		'| rows =', cfg.wrap and format('%d icons per row, %d px / text %d on two rows, %d px / text %d on one', type(cfg.perRow) == 'number' and floor(cfg.perRow) or 4, cfg.size2 or 24, cfg.textSize2 or 10, cfg.size or 28, cfg.textSize or 12) or 'one row')
	local n = Now()
	for _, s in ipairs(slots) do
		local m = s.member
		if m then
			local who = s.unit
			if type(m.name) == 'string' and not secret(m.name) then who = who .. ' (' .. m.name .. ')' end
			local talented = 'not read yet'
			if s.index == 1 then
				talented = 'your own'
			elseif not swaps.ids[m.class or ''] or (m.spec and not swaps.bySpec[m.spec]) then
				talented = 'none change these spells'
			elseif m.guid and swaps.byGUID[m.guid] then
				local found, taken = 0, 0
				for _, rank in pairs(swaps.byGUID[m.guid]) do
					found = found + 1
					if type(rank) == 'number' and rank > 0 then taken = taken + 1 end
				end
				talented = format('read, %d of %d taken%s', taken, found,
					swaps.stale[m.guid] and (ns.InDungeon() and ' (asking again)' or ' (asked again inside a dungeon)') or '')
			elseif not ns.InDungeon() then
				talented = 'not read yet, asked only inside a dungeon'
			else
				talented = 'not read yet, asked ' .. (m.tries or 0) .. ' times'
			end
			p(who .. ':', m.spec and ('spec ' .. m.spec .. ', ' .. tostring(m.how)) or '|cffff5555spec not known yet|r',
				'| race', m.race or 'not read',
				'| read from', s.event == 'UNIT_AURA' and 'buffs' or (s.event and 'your casts' or 'nothing'),
				'| talents', talented,
				'| trinkets', m.fake and 'sample' or trinket.Line(s, m),
				format('| %d icons, %d px, text %d', s.vis or 0, s.size or cfg.size or 28, s.ts or cfg.textSize or 12))
			for j = 1, MAX do
				local t = s.tr[j]
				if t then
					local state = 'ready'
					if t.charges then
						state = charge.Say(t, n)
					else
						for k = 1, 2 do
							local sl = t.slot[k]
							if secret(sl.v) or secret(sl.c) then
								state = 'timer hidden from addons'
							elseif sl.v ~= 0 and Left(t, sl, n) > 0 and state == 'ready' then
								state = format('%d s left', Left(t, sl, n))
							end
						end
					end
					local read = ''
					if s.event == 'UNIT_AURA' then
						local others = t.def.spell.others
						if not s.live[j] then
							read = ' | |cffff5555not watched|r'
						elseif others then
							read = ' | not read on the caster'
						elseif type(t.last) == 'nil' then
							read = ' | not read yet'
						elseif secret(t.last) then
							read = ' | last read hidden'
						else
							read = t.last and ' | |cff66dd66buff up|r' or ' | buff down'
						end
						if t.def.spell.short then
							read = read .. (s.dual[j] and format(' | buffs of %d s or less ignored', t.def.spell.short)
								or t.def.noShort and ' | short buffs counted, talent not taken'
								or ' | short procs NOT filtered')
						end
						if t.def.spell.zone then
							read = read .. (s.any[j] and format(' | %sread on %d other members', others and '' or 'also ', #(t.zset or ''))
								or ' | other members NOT read')
						end
						if t.def.spell.free or t.def.spell.proc then read = read .. free.Line(s, j, t) end
						if t.def.spell.fast and s.live[j] then read = read .. ' | also read on the 3 frames after each aura change' end
					end
					local shown = t.def.show or t.def.id
					local which = t.def.how and format(' | drawn as %s (%s)', ns.CdSpellName(shown), t.def.how) or ''
					if t.exact then
						state = 'the game\'s own cooldown'
						which = which .. format(' | read from spell %d', t.exact)
					end
					local length = ''
					if t.def.cdHow then
						length = ' | length from ' .. t.def.cdHow
					elseif t.def.spell.mods then
						length = ' | length assumed, talents not read'
					end
					p(format('   %s (%d), %d s: %s%s | buff ids %s%s%s', ns.CdSpellName(t.def.id), t.def.id, t.cd, state, read, t.def.spell.sig, which, length))
				end
			end
			if m.gated then p('   not shown, talent not taken: ' .. m.gated) end
		end
	end
	if failed then p('|cffff5555stopped: ' .. failed .. '|r') end
	if waitBuild then p('the sensors are built when combat ends') end
	if pending then p('some buff lists are applied when combat ends') end
	if stats.lastErr then p('last error: ' .. stats.lastErr) end
end
