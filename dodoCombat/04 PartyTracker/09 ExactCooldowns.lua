local _, ns = ...
local _G = _G
local CreateFrame, C_Timer, GetTime = CreateFrame, C_Timer, GetTime
local secret, mmax, floor = ns.IsSecret, math.max, math.floor
local DIM, GREY = 0.5, 0.5

-- Initialize against the engine's existing tables so timers keep their identity.
function ns.InitExactCooldowns(exact, charge, Clear, Now, Fault, EvalBool)
	exact.Fmt = function()
		if exact.fmt == nil then
			exact.fmt = false
			local CSU = _G.C_StringUtil
			if CSU and CSU.CreateNumericRuleFormatter then
				local R = _G.Enum and _G.Enum.NumericRuleFormatRounding
				local up, down = (R and R.Up) or 1, (R and R.Down) or 2
				local ok, f = pcall(CSU.CreateNumericRuleFormatter)
				if ok and f and f.SetBreakpoints and pcall(f.SetBreakpoints, f, {
					{ threshold = 0, format = '%d', components = { { step = 1, rounding = up } } },
					{ threshold = 59.001, step = 1, rounding = up, format = '%d:%02d',
						components = { { div = 60, step = 1, rounding = down }, { mod = 60, step = 1, rounding = down } } },
				}) then
					exact.fmt = f
				end
			end
			if not exact.fmt then exact.fmt = ns.WholeSecondsFormatter() or false end
		end
		return exact.fmt or nil
	end

	exact.Id = function(def)
		local find = _G.C_SpellBook and _G.C_SpellBook.FindSpellOverrideByID
		if find then
			local ok, ov = pcall(find, def.id)
			if ok and type(ov) == 'number' and not secret(ov) and ov > 0 then return ov end
		end
		return def.id
	end

	exact.Can = function(def)
		local S, DU = _G.C_Spell, _G.C_DurationUtil
		if def.spell.item or not (S and S.GetSpellCooldown and S.GetSpellCooldownDuration and S.GetSpellCharges) then return nil end
		if not (DU and DU.CreateDurationTextBinding) then return nil end
		local id = exact.Id(def)
		local ok, info = pcall(S.GetSpellCooldown, id)
		if not ok or type(info) ~= 'table' then return nil end
		return id
	end

	exact.Build = function(c)
		if c.ex then return c.ex end
		local ex = {}
		ex.textF = CreateFrame('Frame', nil, c)
		ex.textF:SetAllPoints(c)
		ex.text = ex.textF:CreateFontString(nil, 'OVERLAY')
		ex.text:SetPoint('CENTER', c, 'CENTER', 0, 0)
		ex.text:SetJustifyH('CENTER')
		ex.cntF = CreateFrame('Frame', nil, c)
		ex.cntF:SetAllPoints(c)
		ex.cnt = ex.cntF:CreateFontString(nil, 'OVERLAY')
		ex.cnt:SetPoint('BOTTOMRIGHT', c, 'BOTTOMRIGHT', -1, 1)
		ex.cnt:SetJustifyH('RIGHT')
		ex.rc = charge.NewClock(c)
		ex.bind = ns.DurationTextBinding(ex.text, exact.Fmt)
		ex.cmp = charge.New()
		c.ex = ex
		return ex
	end

	exact.Drop = function(c, t)
		if t then t.exact = nil end
		local ex = c.ex
		if not ex then return end
		ex.idle = nil
		exact.Grey(c, ex, 0, 1)
		ex.textF:Hide()
		ex.cntF:Hide()
		ex.rc:Clear()
		ex.rc:Hide()
		ex.due, ex.max = nil, nil
		if ex.bind then pcall(ex.bind.SetEnabled, ex.bind, false) end
	end

	exact.Take = function(t, def, c, ts)
		local id = exact.Can(def)
		if not id then
			exact.Drop(c, t)
			return false
		end
		if not t.exact then Clear(t, Now()) end
		t.exact = id
		local ex = exact.Build(c)
		local level = c:GetFrameLevel()
		ex.rc:SetFrameLevel(level + 2)
		ex.textF:SetFrameLevel(level + 6)
		ex.cntF:SetFrameLevel(level + 7)
		local font = ns.GetFont()
		ex.text:SetFont(font, ts, 'OUTLINE')
		ex.text:SetTextColor(1, 1, 1)
		ex.cnt:SetFont(font, mmax(8, floor(ts * 0.85 + 0.5)), 'OUTLINE')
		ex.cnt:SetTextColor(1, 1, 1)
		ex.textF:Show()
		ex.cntF:Show()
		ex.rc:Show()
		if c.cnt then
			for i = 1, 3 do c.cnt[i]:SetAlpha(0) end
		end
		if c.rc then
			c.rc:Clear()
			c.rcAt, c.rcCd = nil, nil
		end
		exact.on[t] = true
		ex.idle = nil
		exact.Update(t)
		return true
	end

	exact.Bind = function(ex, d)
		local b = ex.bind
		if not b then return end
		if d then
			pcall(b.SetDuration, b, d)
			pcall(b.SetEnabled, b, true)
		else
			pcall(b.SetEnabled, b, false)
			ex.text:SetText('')
		end
	end

	exact.Grey = function(c, ex, a, v)
		-- dodo: noShade(공생기 바) 셀은 아이콘 원래 색 유지
		if c.noShade then
			c.icon:SetDesaturation(0)
			c.icon:SetVertexColor(1, 1, 1)
		else
			c.icon:SetDesaturation(a)
			c.icon:SetVertexColor(v, v, v)
		end
		ex.textF:SetAlpha(a)
	end

	exact.Zero = function(c, ex, on)
		exact.Grey(c, ex, on and 1 or 0, on and GREY or 1)
	end

	exact.Clock = function(ex, d, chg)
		if ex.chg ~= chg then
			ex.chg = chg
			ex.rc:SetSwipeColor(0, 0, 0, chg and 0.64 or DIM)
		end
		if d then
			pcall(ex.rc.SetCooldownFromDurationObject, ex.rc, d)
		else
			ex.rc:Clear()
		end
	end

	exact.Update = function(t)
		local c = t.cell
		local ex = c and c.ex
		local id = t.exact
		if not (ex and id) then return end
		local S = _G.C_Spell
		local ok, info = pcall(S.GetSpellCooldown, id)
		if not ok or type(info) ~= 'table' then return end
		exact.updates = exact.updates + 1
		local on = info.isActive == true and info.isOnGCD ~= true
		if ex.idle and not on then return end
		local okC, ch = pcall(S.GetSpellCharges, id)
		local max = okC and type(ch) == 'table' and ch.maxCharges or nil
		if type(max) == 'number' and not secret(max) and max > 1 then
			ex.max, ex.idle = max, nil
			local d
			if ch.isActive == true and S.GetSpellChargeDuration then
				local okD, dd = pcall(S.GetSpellChargeDuration, id)
				if okD then d = dd end
			end
			exact.Clock(ex, d, true)
			exact.Bind(ex, d)
			local cc = ch.currentCharges
			pcall(ex.cnt.SetText, ex.cnt, cc)
			ex.cntF:SetAlpha(1)
			if type(cc) == 'number' and not secret(cc) then
				ex.due = nil
				exact.Zero(c, ex, cc < 1)
			else
				ex.cmp.bar:SetMinMaxValues(charge.LO * max, charge.HI * max)
				pcall(ex.cmp.bar.SetValue, ex.cmp.bar, cc)
				ex.due = GetTime() + 0.05
				if not exact.later then
					exact.later = true
					C_Timer.After(0.1, exact.ReadAll)
				end
			end
		else
			ex.max, ex.due = nil, nil
			ex.cntF:SetAlpha(0)
			local d
			if on then
				local okD, dd = pcall(S.GetSpellCooldownDuration, id, true)
				if okD then d = dd end
			end
			exact.Clock(ex, d, false)
			exact.Bind(ex, d)
			exact.Zero(c, ex, on)
			ex.idle = not on or nil
		end
	end

	exact.Read = function(t)
		local c = t.cell
		local ex = c and c.ex
		if not (ex and ex.due and ex.max) or GetTime() < ex.due or charge.ok ~= true then return end
		local ok, has = pcall(charge.Past, ex.cmp, 0.5 / ex.max)
		if not ok or type(has) == 'nil' then return end
		exact.reads = exact.reads + 1
		local okG, err = pcall(exact.Grey, c, ex, EvalBool(has, 0, 1), EvalBool(has, 1, GREY))
		if not okG then Fault(err) end
	end

	exact.ReadAll = function()
		exact.later = nil
		for t in pairs(exact.on) do exact.Read(t) end
	end

	exact.Hit = function(t, id)
		if id == t.exact then return true end
		local def = t.def
		local sp = def and def.spell
		return def ~= nil and (id == def.id or id == def.show or (sp and sp.casts and sp.casts[id]) == true)
	end

	exact.Charged = function(t)
		local ex = t.cell and t.cell.ex
		return (ex and ex.max) or t.charges or (t.def and t.def.spell and t.def.spell.charge) or false
	end

	exact.Pass = ns.Coalesce(function()
		local all, chg = exact.all, exact.chg
		exact.all, exact.chg = nil, nil
		for t in pairs(exact.on) do
			if all or exact.want[t] or (chg and exact.Charged(t)) then exact.Update(t) end
		end
		wipe(exact.want)
	end)

	exact.evt = CreateFrame('Frame')
	exact.evt:SetScript('OnEvent', function(_, event, id, base)
		local ev = exact.ev
		if event == 'SPELL_UPDATE_CHARGES' then
			exact.chg = true
			ev.charges = ev.charges + 1
		elseif type(id) == 'number' and not secret(id) then
			if type(base) ~= 'number' or secret(base) or base == id then base = nil end
			local hit = false
			for t in pairs(exact.on) do
				if exact.Hit(t, id) or (base and exact.Hit(t, base)) then
					exact.want[t] = true
					hit = true
				end
			end
			if not hit then
				ev.other = ev.other + 1
				return
			end
			ev.named = ev.named + 1
		else
			exact.all = true
			ev.all = ev.all + 1
		end
		exact.Pass()
	end)
	exact.Listen = function(on)
		if on == exact.listening then return end
		exact.listening = on
		for _, e in ipairs({ 'SPELL_UPDATE_COOLDOWN', 'SPELL_UPDATE_CHARGES' }) do
			if on then exact.evt:RegisterEvent(e) else exact.evt:UnregisterEvent(e) end
		end
	end

end
