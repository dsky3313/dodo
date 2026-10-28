local _, ns = ...
local _G = _G
local CreateFrame, UIParent = CreateFrame, UIParent
local secret = ns.IsSecret
local floor, mmax = math.floor, math.max
local format, tremove = string.format, table.remove
local WHITE, DIM = 'Interface\\Buttons\\WHITE8X8', 0.5

function ns.InitCharges(charge, free, swipe, Fault, Now, Roll, Stamp, Left, StartPlain, Pick, EvalBool, getLayer, T0)
	charge.New = function()
		local cmp = tremove(charge.pool)
		if cmp then return cmp end
		local bar = CreateFrame('StatusBar', nil, getLayer())
		bar:SetStatusBarTexture(WHITE)
		bar:SetStatusBarColor(0, 0, 0, 0)
		bar:SetOrientation('VERTICAL')
		bar:SetSize(1, charge.H)
		bar:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 0)
		bar:SetMinMaxValues(charge.LO, charge.HI)
		bar:SetValue(1)
		local probe = CreateFrame('Frame', nil, getLayer())
		probe:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', 0, 0)
		probe:SetPoint('TOPRIGHT', bar:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
		return { bar = bar, probe = probe }
	end

	charge.Free = function(t)
		local cmp = t.cmp
		if not cmp then return end
		t.cmp = nil
		local pool = charge.pool
		pool[#pool + 1] = cmp[1]
		pool[#pool + 1] = cmp[2]
		pool[#pool + 1] = cmp.b
	end

	charge.Ensure = function(t)
		if t.cmp then return end
		t.cmp = { charge.New(), charge.New(), b = charge.New() }
		charge.WriteCmp(t)
	end

	charge.WriteCmp = function(t)
		local cmp = t.cmp
		if not cmp then return end
		for k = 1, 2 do
			local ok, err = pcall(cmp[k].bar.SetValue, cmp[k].bar, t.slot[k].c)
			if not ok then Fault(err) end
		end
		local ok, err = pcall(cmp.b.bar.SetValue, cmp.b.bar, t.b or 0)
		if not ok then Fault(err) end
	end

	charge.Past = function(cmp, v)
		local bottom = cmp.bar:GetBottom()
		local _, y = _G.GetCursorPosition()
		local es = cmp.probe:GetEffectiveScale()
		if type(bottom) ~= 'number' or secret(bottom) or type(y) ~= 'number' or secret(y)
			or type(es) ~= 'number' or secret(es) or es <= 0 then
			return nil
		end
		local at = bottom + charge.H * (v - charge.LO) / (charge.HI - charge.LO)
		return cmp.probe:IsMouseOver(y / es - at, -1e5, -1e5, 1e5)
	end

	charge.Th = function(t, sl, n)
		local th = (254.5 - floor((n - sl.epoch - t.cd) / t.u)) / 255
		if th > 254.5 / 255 then th = 254.5 / 255 end
		return th
	end

	charge.Fin = function(t, k, n)
		local sl = t.slot[k]
		if not secret(sl.c) then
			if sl.c == 1 or Left(t, sl, n) <= 0 then return true end
			if not secret(sl.v) and sl.v == 0 then return true end
			return false
		end
		local cmp = t.cmp and t.cmp[k]
		if charge.ok ~= true or not cmp then return nil end
		return charge.Past(cmp, charge.Th(t, sl, n))
	end

	charge.Has = function(t)
		if not secret(t.b) then return (t.b or 0) > 0.5 end
		local cmp = t.cmp and t.cmp.b
		if charge.ok ~= true or not cmp then return nil end
		return charge.Past(cmp, 0.5)
	end

	charge.Plain = function(t)
		if secret(t.b) then return false end
		for k = 1, 2 do
			local sl = t.slot[k]
			if secret(sl.c) or secret(sl.v) then return false end
		end
		return true
	end

	charge.Count = function(t, n)
		local run = not (charge.Fin(t, 1, n) and charge.Fin(t, 2, n))
		local have = run and ((t.b or 0) > 0.5 and 0 or 1) or 2
		t.a0, t.a1, t.a2 = have == 0 and 1 or 0, have == 1 and 1 or 0, have == 2 and 1 or 0
	end

	charge.Start = function(t, n)
		StartPlain(t, n)
		if not t.charges then return end
		t.b = 1
		charge.Count(t, n)
		charge.WriteCmp(t)
	end

	charge.Try = function(fn, t, ...)
		local ok, r = pcall(fn, t, ...)
		if ok then return r end
		Fault(r)
		t.legacy = true
		return nil, true
	end

	charge.UsePlain = function(t, n)
		Roll(t, n)
		if charge.Fin(t, 1, n) and charge.Fin(t, 2, n) then
			local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
			sl.c, sl.v, other.v, t.b = Stamp(t, n), 1, 0, 0
		elseif (t.b or 0) < 0.5 then
			t.b = 1
		end
		charge.Count(t, n)
		charge.WriteCmp(t)
	end

	charge.Use = function(t, cur, dual, short, prev, prevShort, open, n)
		if open and charge.Plain(t) and free.Plain(t) then
			if not free.Vetoed(t) then charge.UsePlain(t, n) end
			return true
		end
		local f1, f2 = charge.Fin(t, 1, n), charge.Fin(t, 2, n)
		if f1 == nil or f2 == nil then
			t.legacy = true
			return false
		end
		local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
		local c = EvalBool(f1, EvalBool(f2, Stamp(t, n), sl.c), sl.c)
		local v = EvalBool(f1, EvalBool(f2, 1, sl.v), sl.v)
		local o = EvalBool(f1, EvalBool(f2, 0, other.v), other.v)
		local b = EvalBool(f1, EvalBool(f2, 0, 1), 1)
		local a1 = EvalBool(f1, EvalBool(f2, 1, 0), 0)
		local function Set(old, new)
			local x = new
			if not open then x = Pick(cur, dual, short, Pick(prev, dual, prevShort, old, new), old) end
			return free.Veto(t, x, old)
		end
		sl.c, sl.v, other.v = Set(sl.c, c), Set(sl.v, v), Set(other.v, o)
		t.a0, t.a1, t.a2, t.b = Set(t.a0, b), Set(t.a1, a1), Set(t.a2, 0), Set(t.b, b)
		charge.WriteCmp(t)
		return true
	end

	charge.Fall = function(t, a, x)
		local q = EvalBool(t.f1, EvalBool(t.f2, a, x), x)
		return EvalBool(t.p1, EvalBool(t.p2, x, q), q)
	end

	charge.TickPlain = function(t, n)
		local moved = false
		if (t.b or 0) > 0.5 then
			local run, fin = false, nil
			for k = 1, 2 do
				local sl = t.slot[k]
				if sl.v ~= 0 and sl.c ~= 1 then
					local left = Left(t, sl, n)
					if left > 0 then
						run = true
					elseif not fin or n + left > fin then
						fin = n + left
					end
				end
			end
			if not run then
				if fin then
					local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
					sl.c, sl.v, other.v = Stamp(t, fin), 1, 0
				end
				t.b, moved = 0, true
			end
		end
		local a0, a1, a2 = t.a0, t.a1, t.a2
		charge.Count(t, n)
		if a0 ~= t.a0 or a1 ~= t.a1 or a2 ~= t.a2 then moved = true end
		t.f1, t.f2 = charge.Fin(t, 1, n), charge.Fin(t, 2, n)
		if moved then charge.WriteCmp(t) end
		return moved
	end

	charge.Tick = function(t, n)
		if charge.Plain(t) then
			t.legacy = nil
			return charge.TickPlain(t, n)
		end
		if t.legacy then return false end
		local f1, f2, has = charge.Fin(t, 1, n), charge.Fin(t, 2, n), charge.Has(t)
		if f1 == nil or f2 == nil or has == nil then
			if charge.ok ~= nil then
				t.legacy = true
				return true
			end
			return false
		end
		local p1, p2 = t.f1, t.f2
		t.f1, t.f2 = f1, f2
		if p1 == nil or p2 == nil then return false end
		t.p1, t.p2 = p1, p2
		local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
		local Fall = charge.Fall
		sl.c = Fall(t, EvalBool(has, Stamp(t, n), sl.c), sl.c)
		sl.v = Fall(t, EvalBool(has, 1, sl.v), sl.v)
		other.v = Fall(t, EvalBool(has, 0, other.v), other.v)
		t.a0 = Fall(t, 0, t.a0)
		t.a1 = Fall(t, EvalBool(has, 1, 0), t.a1)
		t.a2 = Fall(t, EvalBool(has, 0, 1), t.a2)
		t.b = Fall(t, 0, t.b)
		charge.WriteCmp(t)
		return true
	end

	charge.Reload = function(t, c, n)
		local at
		if not t.legacy and charge.Plain(t) then
			for k = 1, 2 do
				local sl = t.slot[k]
				if sl.v ~= 0 and sl.c ~= 1 then
					local s = sl.epoch + t.u * (255 - floor(sl.c * 255 + 0.5))
					if s + t.cd > n and (not at or s > at) then at = s end
				end
			end
		end
		if at == c.rcAt and t.cd == c.rcCd then return end
		c.rcAt, c.rcCd = at, t.cd
		if at then
			c.rc:SetCooldown(T0 - 0.5 + at, t.cd)
		else
			c.rc:Clear()
		end
	end

	charge.Wedge = function(t, c)
		if not t.exact and (t.legacy or not charge.Plain(t)) then
			c.wz = nil
			return true
		end
		if not c.wz then
			c.wz = true
			for k = 1, 2 do c.dim[k]:SetRadialProgressBarPercent(0) end
		end
		return false
	end

	charge.Cell = function(t, c, n)
		local b, a0, a1, a2 = t.b or 0, t.a0 or 0, t.a1 or 0, t.a2 or 1
		if t.legacy then b, a0, a1, a2 = 1, 0, 0, 0 end
		c.win:SetAlpha(b)
		c.cover:SetAlpha(b)
		c.cnt[1]:SetAlpha(a0)
		c.cnt[2]:SetAlpha(a1)
		c.cnt[3]:SetAlpha(a2)
		charge.Reload(t, c, n or Now())
	end

	charge.Dress = function(c, on, font, ts)
		if not on then
			if c.cnt then
				for i = 1, 3 do c.cnt[i]:Hide() end
				c.rc:Clear()
				c.rcAt, c.rcCd = nil, nil
			end
			return
		end
		if not c.cnt then
			c.cnt = {}
			for i = 1, 3 do
				local f = CreateFrame('Frame', nil, c)
				f:SetAllPoints(c)
				f:SetAlpha(0)
				f.fs = f:CreateFontString(nil, 'OVERLAY')
				f.fs:SetJustifyH('RIGHT')
				c.cnt[i] = f
			end
			c.rc = charge.NewClock(c)
		end
		local level = c:GetFrameLevel()
		c.rc:SetFrameLevel(level + 2)
		local cs = mmax(8, floor(ts * 0.85 + 0.5))
		for i = 1, 3 do
			local f = c.cnt[i]
			f:SetFrameLevel(level + 7)
			f.fs:SetFont(font, cs, 'OUTLINE')
			f.fs:SetTextColor(1, 1, 1)
			f.fs:ClearAllPoints()
			f.fs:SetPoint('BOTTOMRIGHT', c, 'BOTTOMRIGHT', -1, 1)
			f.fs:SetText(tostring(i - 1))
			f:Show()
		end
	end

	charge.NewClock = function(c)
		local rc = CreateFrame('Cooldown', nil, c.clip, 'CooldownFrameTemplate')
		rc:SetAllPoints(c.icon)
		rc:SetDrawSwipe(true)
		rc:SetDrawEdge(false)
		rc:SetDrawBling(false)
		rc:SetReverse(false)
		rc:SetHideCountdownNumbers(true)
		rc.noCooldownCount = true
		return rc
	end

	charge.Check = function()
		local pr = charge.probe
		local want = charge.want
		if want then
			local okA, a = pcall(charge.Past, pr, want - 0.05)
			local okB, b = pcall(charge.Past, pr, want + 0.05)
			if not (okA and okB) then
				charge.ok, charge.why = false, tostring(okA and b or a)
				return
			end
			if secret(a) or secret(b) then
				charge.ok, charge.note = true, 'the answer is hidden, so it cannot be checked from here'
				return
			end
			if a == true and b == false then
				charge.pass = (charge.pass or 0) + 1
				if charge.pass >= 2 then
					charge.ok = true
					return
				end
			else
				charge.pass = 0
				if charge.try >= 6 then
					charge.ok = false
					charge.why = format('a bar set to %.2f read as %s / %s against %.2f / %.2f',
						want, tostring(a), tostring(b), want - 0.05, want + 0.05)
					return
				end
			end
		end
		charge.try = charge.try + 1
		charge.want = charge.try % 2 == 1 and 0.3 or 0.7
		pr.bar:SetValue(charge.want)
	end

	charge.Line = function()
		if charge.ok == nil then return charge.probe and 'not checked yet' or 'not built' end
		if charge.ok then return charge.note or 'read check passed' end
		return '|cffff5555off, a hidden use is timed from the latest one: ' .. tostring(charge.why) .. '|r'
	end

	charge.Say = function(t, n)
		if t.legacy then return 'charges not counted, timed from the latest use' end
		if not charge.Plain(t) then return swipe.on and 'charges hidden from addons, reload drawn as the wedge' or 'charges hidden from addons, no reload (wedge off)' end
		local left
		for k = 1, 2 do
			local sl = t.slot[k]
			if sl.v ~= 0 and sl.c ~= 1 and Left(t, sl, n) > 0 then left = Left(t, sl, n) end
		end
		if not left then return t.charges .. ' charges' end
		if (t.b or 0) > 0.5 then return format('0 charges, one back in %d s', left) end
		return format('1 charge, the other back in %d s', left)
	end

end
