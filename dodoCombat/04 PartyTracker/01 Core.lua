-- H3ndall, kira

local _, ns = ...
local _G = _G
local format, pcall, ipairs, pairs = string.format, pcall, ipairs, pairs
local UnitClass = UnitClass
local IsInInstance = IsInInstance
local function IsSecret(v) return issecretvalue and issecretvalue(v) or false end
ns.IsSecret = IsSecret

if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, 'Blizzard_AuraContainer')
end
function ns.Probe(_, hook, timer) return hook, timer end
function ns.ProbeCoalesced(fn) return fn end
function ns.GetFont() return STANDARD_TEXT_FONT end
-- dodo: Locale.lua 제외, 키 그대로 반환
ns.L = setmetatable({}, { __index = function(_, key) return key end })

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = Copy(item) end
    return out
end

local cfgOwner, cfgCache
function ns.ModuleCfg(key, defaults, migrate)
    -- dodo: 저장소 dodoDB.partyTracker
    if type(dodoDB) ~= 'table' then dodoDB = {} end
    if type(dodoDB.partyTracker) ~= 'table' then dodoDB.partyTracker = {} end
    if cfgOwner ~= dodoDB.partyTracker then
        cfgOwner, cfgCache = dodoDB.partyTracker, {}
    end
    if cfgCache[key] then return cfgCache[key] end
    local cfg = cfgOwner[key]
    if type(cfg) ~= 'table' then cfg = {} cfgOwner[key] = cfg end
    for name, value in pairs(defaults) do
        if cfg[name] == nil then cfg[name] = Copy(value) end
    end
    if migrate then migrate(cfg) end
    cfgCache[key] = cfg
    return cfg
end

function ns.CHSpecID()
    local api = C_SpecializationInfo
    local getIndex = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index = getIndex and getIndex()
    if not index or IsSecret(index) or not getInfo then return nil end
    local ok, id = pcall(getInfo, index)
    if ok and not IsSecret(id) then return id end
end

function ns.KeyActive()
    return ns.Ask(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) == true
end

-- ==============================
-- dodo: Kira 모듈(공생기/차단기/군중제어)용 헬퍼 (KiraUI-Plugin.lua 원본)
-- ==============================
function ns.PlayerSpec()
    local CSI = _G.C_SpecializationInfo
    local get = (CSI and CSI.GetSpecialization) or _G.GetSpecialization
    if not get then return nil, false end
    local ok, spec = pcall(get)
    if not ok then return nil, false end
    if IsSecret(spec) then return nil, true end
    return spec, false
end

-- LSM 없음 → nil (차단기는 기본 텍스처 사용)
function ns.LSM() return nil end
function ns.BarTexture(fallback) return fallback or 'Interface\\TargetingFrame\\UI-StatusBar' end

function ns.Msg(text) print('[dodo] ' .. tostring(text)) end

-- 05 Dragging.lua 제거 → 원본 우클릭 드래그 비활성 (위치 이동은 14 EditMode.lua)
function ns.MakeDraggable() end
function ns.CanGrab() return false end
function ns.OnGrabChange() end

-- Kira 편집모드 → LibEditMode
function ns.EditModeActive()
    local LEM = _G.LibStub and _G.LibStub('LibEditMode', true)
    return (LEM and LEM:IsInEditMode()) and true or false
end

-- dodo: 바 그룹을 붙일 블리자드 파티 프레임 (레이드 스타일). 없으면 nil → UIParent 좌표 폴백
function ns.PartyAnchor()
    return _G.CompactPartyFrame
end

function ns.CdSpellName(id)
    local name = C_Spell.GetSpellName(id)
    if not IsSecret(name) and name then return name end
    return string.format(ns.L['Spell %s'], tostring(id))
end

function ns.CdSpellTexture(id)
    local texture = C_Spell.GetSpellTexture(id)
    if not IsSecret(texture) and texture then return texture end
    return 134400
end
function ns.Ask(fn, ...)
	if not fn then return nil end
	local ok, v = pcall(fn, ...)
	if not ok or IsSecret(v) then return nil end
	return v and true or false
end

function ns.InDungeon()
	local ok, inside, kind = pcall(IsInInstance)
	if not ok or IsSecret(inside) or IsSecret(kind) then return true end
	return (inside and kind == 'party') and true or false
end

function ns.ClassOf(unit)
	local ok, _, token = pcall(UnitClass, unit)
	if not ok or IsSecret(token) then return nil end
	return token
end

function ns.ClassRGB(class, d)
	d = d or 0.7
	local CC = _G.C_ClassColor
	local c = class and CC and CC.GetClassColor and CC.GetClassColor(class)
	if not c and class and _G.RAID_CLASS_COLORS then c = _G.RAID_CLASS_COLORS[class] end
	if c then return c.r or d, c.g or d, c.b or d end
	return d, d, d
end

do
	local issecrettable = _G.issecrettable
	local function Churns(info)
		if IsSecret(info) or info == nil or (issecrettable and issecrettable(info)) then return true end
		local full, added, removed = info.isFullUpdate, info.addedAuras, info.removedAuraInstanceIDs
		if IsSecret(full) or IsSecret(added) or IsSecret(removed) then return true end
		return (full or added or removed) and true or false
	end
	function ns.AuraPayloadChurns(info)
		local ok, churns = pcall(Churns, info)
		return not ok or churns
	end
end

ns.IS_121 = (select(4, _G.GetBuildInfo()) or 0) >= 120100
function ns.Letters(s, n)
	n = math.floor(tonumber(n) or 0)
	if IsSecret(s) or type(s) ~= 'string' or n <= 0 then return s end
	local i, count, len = 1, 0, #s
	while i <= len and count < n do
		local b = s:byte(i)
		i = i + ((b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1)
		count = count + 1
	end
	return s:sub(1, i - 1)
end

local wholeSecondsFmt
function ns.WholeSecondsFormatter()
	if wholeSecondsFmt == nil then
		wholeSecondsFmt = false
		local CSU = _G.C_StringUtil
		if CSU and CSU.CreateNumericRuleFormatter then
			local f = CSU.CreateNumericRuleFormatter()
			if f and f.SetBreakpoints then
				local up = (_G.Enum and _G.Enum.NumericRuleFormatRounding
					and _G.Enum.NumericRuleFormatRounding.Up) or 1
				local ok = pcall(f.SetBreakpoints, f, {
					{ threshold = 0, format = '%d', components = { { step = 1, rounding = up } } },
				})
				if ok then wholeSecondsFmt = f end
			end
		end
	end
	return wholeSecondsFmt or nil
end

function ns.DurationTextBinding(fs, formatter)
	local DU = _G.C_DurationUtil
	if not (DU and DU.CreateDurationTextBinding) then return nil end
	local ok, b = pcall(function()
		local b = DU.CreateDurationTextBinding()
		local f = formatter and formatter()
		if f then b:SetFormatter(f) else b:SetTextFormat('%d') end
		b:SetExpiredText('')
		b:SetZeroDurationText('')
		b:SetFontString(fs)
		return b
	end)
	return ok and b or nil
end

function ns.DurationTextOptions()
	local f = ns.WholeSecondsFormatter()
	if f then return { formatter = f, textFormatter = f } end
	if _G.C_AuraContainerUtil then return {} end
	return { textFormat = '%d' }
end

function ns.ZoomCoords(zoomPct)
	local z = (zoomPct or 0) / 100
	if z < 0 then z = 0 elseif z > 0.45 then z = 0.45 end
	return z, 1 - z
end

ns.STAT_COLORS = {
	crit    = { 0.878, 0.110, 0.110 },
	haste   = { 0.835, 0.780, 0.000 },
	mastery = { 0.573, 0.337, 1.000 },
	vers    = { 0.749, 0.749, 0.749 },
}
