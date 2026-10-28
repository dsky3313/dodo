local _, ns = ...
local _G = _G
local IsSecret = ns.IsSecret
local GetPhysicalScreenSize, hooksecurefunc, C_Timer = GetPhysicalScreenSize, hooksecurefunc, C_Timer

function ns.PixelScale(region)
	local ok, es = pcall(region.GetEffectiveScale, region)
	local _, ph = GetPhysicalScreenSize()
	if not ok or IsSecret(es) or type(es) ~= 'number' or es <= 0 or type(ph) ~= 'number' or ph <= 0 then return nil end
	return es * ph / 768
end

function ns.PixelSize(units, region)
	local ppu = ns.PixelScale(region)
	if not ppu or units == 0 then return units end
	local px = math.floor(math.abs(units) * ppu + 0.5 + 0.001)
	if px < 1 then px = 1 end
	return (units < 0 and -px or px) / ppu
end

function ns.PixelPoint(frame, point, rel, relPoint, x, y)
	x, y = x or 0, y or 0
	frame:SetPoint(point, rel, relPoint, x, y)
	local ppu = ns.PixelScale(frame)
	local ok, l, b = pcall(frame.GetRect, frame)
	if not (ppu and ok) or IsSecret(l) or IsSecret(b) or type(l) ~= 'number' or type(b) ~= 'number' then return false end
	l, b = l * ppu, b * ppu
	local dx, dy = math.floor(l + 0.5 + 0.001) - l, math.floor(b + 0.5 + 0.001) - b
	if math.abs(dx) < 0.001 then dx = 0 end
	if math.abs(dy) < 0.001 then dy = 0 end
	if dx ~= 0 or dy ~= 0 then frame:SetPoint(point, rel, relPoint, x + dx / ppu, y + dy / ppu) end
	return true
end

function ns.Coalesce(fn)
	fn = ns.ProbeCoalesced(fn)
	local queued = false
	local function run()
		queued = false
		fn()
	end
	return function()
		if queued then return end
		queued = true
		_G.C_Timer.After(0, run)
	end
end

do
	local held = setmetatable({}, { __mode = 'k' })
	local listeners = {}
	local queued, waiting, force, lastPpu = false, false, false, nil
	local SIDES = {
		TOP = { 'TOPLEFT', -1, 1, 'TOPRIGHT', 1, 1, true },
		BOTTOM = { 'BOTTOMLEFT', -1, -1, 'BOTTOMRIGHT', 1, -1, true },
		LEFT = { 'TOPLEFT', -1, 1, 'BOTTOMLEFT', -1, -1, false },
		RIGHT = { 'TOPRIGHT', 1, 1, 'BOTTOMRIGHT', 1, -1, false },
	}

	function ns.OnePixel(region)
		local ppu = region and ns.PixelScale(region)
		if not ppu or math.abs(ppu - 1) < 0.0005 then return 1 end
		return 1 / ppu
	end

	local function Put(region, h)
		local d = h.n * ns.OnePixel(region)
		local a, pts = h.anchor, {}
		if h.side then
			local s, o = SIDES[h.side], h.out and d or 0
			region:SetPoint(s[1], a, s[1], s[2] * o, s[3] * o)
			region:SetPoint(s[4], a, s[4], s[5] * o, s[6] * o)
			if s[7] then region:SetHeight(d) else region:SetWidth(d) end
			pts[s[1]] = { s[2] * o, s[3] * o }
			pts[s[4]] = { s[5] * o, s[6] * o }
		else
			region:SetPoint('TOPLEFT', a, 'TOPLEFT', d, -d)
			region:SetPoint('BOTTOMRIGHT', a, 'BOTTOMRIGHT', -d, d)
			pts.TOPLEFT = { d, -d }
			pts.BOTTOMRIGHT = { -d, d }
		end
		h.pts = pts
		return d
	end

	local function Holds(region, h)
		if region:GetNumPoints() ~= 2 then return false end
		for i = 1, 2 do
			local p, rel, rp, x, y = region:GetPoint(i)
			local want = h.pts[p]
			if not want or rel ~= h.anchor or rp ~= p or IsSecret(x) or IsSecret(y) then return false end
			if math.abs(x - want[1]) > 0.01 or math.abs(y - want[2]) > 0.01 then return false end
		end
		return true
	end

	function ns.PixelInset(region, anchor, n, fixed)
		local h = { anchor = anchor or region:GetParent(), n = n or 1 }
		if not fixed then held[region] = h end
		return Put(region, h)
	end

	function ns.OnPixelChange(fn)
		listeners[#listeners + 1] = fn
	end

	local function Run()
		queued = false
		if _G.InCombatLockdown() then
			waiting = true
			return
		end
		waiting = false
		local ppu = ns.PixelScale(_G.UIParent)
		local moved = not (ppu and lastPpu and math.abs(ppu - lastPpu) < 0.00001)
		if force or moved then
			for region, h in pairs(held) do
				local ok, yes = pcall(Holds, region, h)
				if not (ok and yes and pcall(Put, region, h)) then held[region] = nil end
			end
		end
		force = false
		if not moved then return end
		lastPpu = ppu
		for i = 1, #listeners do
			local ok, err = pcall(listeners[i])
			if not ok then _G.geterrorhandler()(err) end
		end
	end

	local function Queue()
		if queued then return end
		queued = true
		C_Timer.After(0, Run)
	end

	function ns.PixelRefresh()
		force = true
		Queue()
	end

	function ns.PixelSetScale(frame, scale)
		if math.abs(frame:GetScale() - scale) > 0.0001 then ns.PixelRefresh() end
		frame:SetScale(scale)
	end

	local watch = CreateFrame('Frame')
	watch:RegisterEvent('UI_SCALE_CHANGED')
	watch:RegisterEvent('DISPLAY_SIZE_CHANGED')
	watch:RegisterEvent('PLAYER_ENTERING_WORLD')
	watch:RegisterEvent('PLAYER_REGEN_ENABLED')
	watch:SetScript('OnEvent', function(_, event)
		if event == 'PLAYER_REGEN_ENABLED' and not waiting then return end
		Queue()
	end)
	if _G.UIParent then
		lastPpu = ns.PixelScale(_G.UIParent)
		hooksecurefunc(_G.UIParent, 'SetScale', Queue)
	end
end

