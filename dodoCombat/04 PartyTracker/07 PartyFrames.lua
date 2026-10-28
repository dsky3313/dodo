local _, ns = ...
local _G = _G
local UIParent, GetTime, C_Timer = UIParent, GetTime, C_Timer
local IsInGroup, IsInRaid, UnitExists = IsInGroup, IsInRaid, UnitExists
local secret, abs, mmax = ns.IsSecret, math.abs, math.max
local format = string.format

-- Callbacks keep changing display state out of the discovery module.
function ns.NewPartyFrameFinder(GetCfg, TOKENS, MapSig, QueueRefresh, Fault, isActive, getRF)
	local frames = { sets = {}, known = {}, scans = 0, tries = 0, next = 0, seen = 0, cost = 0, sig = '', how = 'none' }
	do
		local clock = _G.debugprofilestop
		local WANT = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }
		local GAPS = { 2, 8 }
		local stack, deep, found, top = {}, {}, {}, 0
		local scanning, waking, later = false, false, false

		local function Want()
			local w = GetCfg().frames
			if type(w) == 'string' and w ~= '' then return w end
			return nil
		end

		local function Size(f)
			local ok, w, h = pcall(f.GetSize, f)
			if ok and not secret(w) and not secret(h) and type(w) == 'number' and type(h) == 'number' and w > 0 and h > 0 then
				return w, h
			end
			return nil
		end

		local function Unit(f)
			if f:IsForbidden() or not f:IsVisible() or f:GetObjectType() ~= 'Button' then return nil end
			local u = f:GetAttribute('unit')
			if secret(u) or type(u) ~= 'string' then return nil end
			u = u:lower()
			return WANT[u] and u or nil
		end

		local function Trim(set)
			local units = set.units
			local own = units.player
			if not own then return end
			local pw, ph = Size(own)
			if not pw then return end
			for u, f in pairs(units) do
				if u ~= 'player' then
					local w, h = Size(f)
					if w then
						if abs(pw - w) > w * 0.1 or abs(ph - h) > h * 0.1 then units.player = nil end
						return
					end
				end
			end
		end

		local function Reread(set)
			local units, n = set.units, 0
			local rf = getRF()
			local eui = rf and rf._partyUnitToButton
			wipe(units)
			for _, host in ipairs(set.hosts) do
				local kids = { pcall(host.GetChildren, host) }
				if kids[1] then
					for i = 2, #kids do
						local f = kids[i]
						local ok, u = pcall(Unit, f)
						if ok and u and not units[u] and not (eui and eui[u] == f) then
							units[u] = f
							if u ~= 'player' then n = n + 1 end
						end
					end
				end
			end
			set.n = n
			Trim(set)
			return n
		end

		local function Name(set)
			local key = set.key
			local ok, name = pcall(key.GetName, key)
			if ok and key ~= UIParent and type(name) == 'string' and name ~= '' then return name end
			for _, f in pairs(set.units) do
				ok, name = pcall(f.GetName, f)
				if ok and type(name) == 'string' and name ~= '' then return (name:gsub('%d+$', '')) end
			end
			return nil
		end

		local function Stock(f)
			local a, b, c = _G.CompactPartyFrame, _G.PartyFrame, _G.CompactRaidFrameContainer
			for _ = 1, 4 do
				if not f then return false end
				if f == a or f == b or f == c then return true end
				local ok, p = pcall(f.GetParent, f)
				f = ok and p or nil
			end
			return false
		end

		local function Pick(want)
			local best
			for _, set in ipairs(frames.sets) do
				if want and set.name == want then return set end
				if not best or set.n > best.n or (set.n == best.n and (set.rank > best.rank
					or (set.rank == best.rank and (set.name or '') < (best.name or '')))) then
					best = set
				end
			end
			return best
		end

		local function Group()
			local rf = getRF()
			local eui = rf and rf._partyUnitToButton
			local count, lifted, byKey, sets = {}, {}, {}, {}
			for f in pairs(found) do
				local p = f:GetParent()
				if p then count[p] = (count[p] or 0) + 1 end
			end
			for f, u in pairs(found) do
				local p = f:GetParent()
				local gp = (p and count[p] == 1 and u ~= 'player') and p:GetParent() or nil
				if gp then lifted[gp] = (lifted[gp] or 0) + 1 end
			end
			for f, u in pairs(found) do
				local p = f:GetParent()
				if p and not (eui and eui[u] == f) then
					local key = p
					if count[p] == 1 then
						local gp = p:GetParent()
						if gp and (lifted[gp] or 0) >= 2 then key = gp end
					end
					local set = byKey[key]
					if not set then
						set = { key = key, units = {}, hosts = {}, n = 0 }
						byKey[key] = set
						sets[#sets + 1] = set
					end
					if not set.units[u] then
						set.units[u] = f
						if u ~= 'player' then set.n = set.n + 1 end
					end
					local known = false
					for _, h in ipairs(set.hosts) do
						if h == p then known = true end
					end
					if not known then set.hosts[#set.hosts + 1] = p end
				end
			end
			local keep = {}
			for _, set in ipairs(sets) do
				if set.n > 0 then
					local area = 0
					for u, f in pairs(set.units) do
						if u ~= 'player' and area == 0 then
							local w, h = Size(f)
							if w then area = w * h end
						end
					end
					set.name = Name(set)
					set.rank = (Stock(set.key) and 0 or 1e9) + area
					Trim(set)
					keep[#keep + 1] = set
					local name, listed = set.name, false
					for _, k in ipairs(frames.known) do
						if k == name then listed = true end
					end
					if name and not listed and #frames.known < 12 then frames.known[#frames.known + 1] = name end
				end
			end
			return keep
		end

		local function Finish()
			local now = GetTime()
			scanning = false
			frames.scans, frames.at = frames.scans + 1, now
			frames.tries = frames.tries + 1
			frames.next = now + (GAPS[frames.tries] or 0)
			local cands = 0
			for _ in pairs(found) do cands = cands + 1 end
			frames.sets = Group()
			wipe(found)
			local cfg = GetCfg()
			local old = frames.set
			local had = (old and old.n > 0) and true or false
			local best = Pick(Want())
			if best then
				frames.set, frames.none, frames.owed = best, false, not had
			else
				frames.none, frames.owed = true, false
			end
			local say, done = frames.say, frames.done
			frames.say, frames.done = nil, nil
			if say then
				say(format('looked at %d frames in %.1f ms: %d carry a party unit, %d sets of party frames', frames.seen, frames.cost, cands, #frames.sets))
				for _, set in ipairs(frames.sets) do
					say(format('   %s: %d party members%s%s%s', set.name or 'no name', set.n, set.units.player and ' and you' or '',
						set.rank < 1e9 and ', the game\'s own' or '', set == best and ' | picked' or ''))
				end
			end
			if done then C_Timer.After(0, done) end
			if cfg.attach == false or (frames.how == 'eui' and not Want()) then return end
			local sig = best and MapSig(best.units) or ''
			if sig ~= frames.sig or frames.how == 'wait' then QueueRefresh() end
		end

		local function Visit(f, d)
			if f:IsForbidden() or not f:IsVisible() then return end
			local kind = f:GetObjectType()
			if kind == 'Button' then
				local u = f:GetAttribute('unit')
				if not secret(u) and type(u) == 'string' and WANT[u:lower()] then
					found[f] = u:lower()
					return
				end
			elseif kind ~= 'Frame' then
				return
			end
			if d >= 12 or f:GetNumChildren() == 0 then return end
			local kids = { f:GetChildren() }
			for i = 1, #kids do
				top = top + 1
				stack[top], deep[top] = kids[i], d + 1
			end
		end

		local function Slice()
			local t0 = clock and clock() or 0
			local n = 0
			while top > 0 do
				local f, d = stack[top], deep[top]
				stack[top] = nil
				top = top - 1
				pcall(Visit, f, d)
				n = n + 1
				if n % 25 == 0 and (clock and clock() - t0 or n / 400) >= 1 then break end
			end
			frames.seen = frames.seen + n
			frames.cost = frames.cost + (clock and clock() - t0 or 0)
			if top > 0 then
				C_Timer.After(0, Slice)
				return
			end
			local ok, err = pcall(Finish)
			if not ok then
				scanning = false
				Fault(err)
			end
		end

		local function Start()
			scanning = true
			wipe(found)
			top, frames.seen, frames.cost = 0, 0, 0
			local kids = { UIParent:GetChildren() }
			for i = 1, #kids do
				top = top + 1
				stack[top], deep[top] = kids[i], 1
			end
			Slice()
		end

		local function Others()
			local n = 0
			for i = 2, #TOKENS do
				if ns.Ask(UnitExists, TOKENS[i]) == true then n = n + 1 end
			end
			return n
		end

		local function Recheck()
			local cfg = GetCfg()
			if cfg.attach == false or not IsInGroup() or IsInRaid() then return end
			if not isActive() then return end
			local sig, was = frames.sig, frames.how
			local _, how = frames.Use(cfg, frames.eui)
			if frames.sig ~= sig or how ~= was then QueueRefresh() end
		end

		local function Wake(delay)
			if waking then return end
			waking = true
			C_Timer.After(delay, function()
				waking = false
				local ok, err = pcall(Recheck)
				if not ok then Fault(err) end
			end)
		end

		frames.Later = function()
			if later then return end
			later = true
			C_Timer.After(0.5, function()
				later = false
				local ok, err = pcall(Recheck)
				if not ok then Fault(err) end
			end)
		end

		local function Short(set, want)
			local n = set and set.n or 0
			return n == 0 or n < Others() or (want ~= nil and set.name ~= want)
		end

		frames.Live = function(want)
			local set, now = frames.set, GetTime()
			if set then Reread(set) end
			if Short(set, want) or frames.owed then
				if not scanning and frames.tries < 3 and now >= frames.next then
					Start()
					set = frames.set
				end
				if scanning then
					Wake(1)
				elseif frames.tries < 3 and (Short(set, want) or frames.owed) then
					Wake(mmax(frames.next - now, 0.1))
				elseif not set or set.n == 0 then
					if now - (frames.at or 0) >= 60 then frames.tries = 2 end
					Wake(10)
				end
			end
			if set and set.n > 0 then
				frames.none = false
				return set
			end
			return nil
		end

		frames.Use = function(cfg, euiOn)
			local want = Want()
			frames.eui, frames.sig = euiOn, ''
			if not IsInGroup() or (euiOn and not want) then return nil, euiOn and 'eui' or 'none' end
			local set = frames.Live(want)
			if set and (not euiOn or set.name == want) then
				frames.sig = MapSig(set.units)
				return set.units, 'found'
			end
			if euiOn then return nil, 'eui' end
			return nil, (scanning and not frames.none) and 'wait' or 'none'
		end

		frames.Fresh = function()
			frames.tries = 0
			frames.next = (frames.at or -1) + 1
		end

		frames.Ask = function(done, say)
			if scanning then return false end
			if not say and (not IsInGroup() or IsInRaid() or GetTime() - (frames.at or -60) < 30) then return false end
			frames.done, frames.say = done, say
			Start()
			return true
		end

		frames.Line = function(cfg)
			if cfg.attach == false then return 'not used' end
			local how = frames.how
			if how == 'eui' then return 'EllesmereUI' end
			if how == 'found' then return (frames.set and frames.set.name or 'no name') .. ', found by search' end
			if how == 'wait' then return 'searching' end
			return IsInGroup() and 'none found, loose block' or 'not in a party'
		end
	end

	return frames
end
