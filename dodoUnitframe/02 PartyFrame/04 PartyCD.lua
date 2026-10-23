---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local dodo = _G.dodo

local CreateFrame        = CreateFrame
local UIParent           = UIParent
local GetTime            = GetTime
local InCombatLockdown   = InCombatLockdown
local UnitExists         = UnitExists
local UnitGUID           = UnitGUID
local UnitClass          = UnitClass
local UnitRace           = UnitRace
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local IsInGroup          = IsInGroup
local IsInRaid           = IsInRaid
local CanInspect         = CanInspect
local NotifyInspect      = NotifyInspect
local C_SpecializationInfo = C_SpecializationInfo
local ipairs, pairs, pcall, type, tostring, wipe = ipairs, pairs, pcall, type, tostring, wipe
local floor, ceil, abs, max, min = math.floor, math.ceil, math.abs, math.max, math.min
local tconcat, tremove   = table.concat, table.remove
local format             = string.format
local issecretvalue      = issecretvalue

-- ==============================
-- 데이터 (01 Data.lua)
-- ==============================
local ptc    = dodo._ptc
local SPELLS = ptc.SPELLS
local SPECS  = ptc.SPECS

-- ==============================
-- 로컬 헬퍼
-- ==============================
local function secret(v) return issecretvalue and issecretvalue(v) end

local EvalBool = _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorValueFromBoolean

-- Door 테스트 (EvaluateColorValueFromBoolean 정확도 검증)
local DOOR_SLACK, DOOR_PASSES = 1e-6, 16
local DOOR_BYTES = { 0, 1, 48, 85, 127, 200, 254, 255 }

local function test_door()
    local d = { state = 'error' }
    if not EvalBool then d.detail = 'no EvaluateColorValueFromBoolean' return d end
    local off = 0
    for _, k in ipairs(DOOR_BYTES) do
        local want = k / 255
        local v = want
        for pass = 1, DOOR_PASSES do
            local ok, w
            if pass % 2 == 1 then ok, w = pcall(EvalBool, true, v, 0)
            else                    ok, w = pcall(EvalBool, false, 0, v) end
            if not ok then d.detail = tostring(w) return d end
            if secret(w) then d.state = 'hidden' return d end
            if type(w) ~= 'number' then d.detail = 'not number: ' .. type(w) return d end
            v = w
            local gap = abs(v - want)
            if gap >= off then off, d.sent, d.got = gap, want, v end
        end
    end
    d.off = off
    d.state = off == 0 and 'exact' or (off <= DOOR_SLACK and 'close' or 'coarse')
    return d
end

local door
local HAS_WIDGETS = false
local UNAVAILABLE = true  -- PLAYER_LOGIN에서 재평가

-- AuraContainer 헬퍼
local function init_sensor_button(b)
    pcall(b.SetSize, b, 1, 1)
    pcall(b.SetMouseClickEnabled, b, false)
    pcall(b.SetMouseMotionEnabled, b, false)
end

local function new_unit_sensor(host, unit)
    local ok, c = pcall(CreateFrame, 'AuraContainer', nil, host, 'CustomAuraContainerTemplate')
    if not ok or not c then return nil end
    c:SetSize(1, 1)
    c:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -11, 0)
    pcall(c.EnableMouse, c, false)
    local okG = pcall(c.AddAuraGroup, c, 'cd', 'HELPFUL', {
        maxFrameCount    = 1,
        candidateFilters = { includeSpellIDs = {} },
        initializeFrame  = init_sensor_button,
        layout           = { elementWidth = 50000, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
    })
    if not okG then return nil end
    pcall(c.SetUnit, c, unit)
    pcall(c.SetEnabled, c, false)
    return c
end

-- KiraUI Aim 패턴: SetAuraGroupCandidateFilters로 필터 세팅 후 활성화
local function aim_sensor(c, sig, filters)
    if c.aim ~= sig then
        if not pcall(c.SetAuraGroupCandidateFilters, c, 'cd', filters) then
            return false  -- pending_build 호출측에서 처리
        end
        c.aim = sig
    end
    if not c.on then
        c.on = true
        pcall(c.SetEnabled, c, true)
    end
    pcall(c.UpdateAllAuras, c)
    return true
end

local function sensor_lit(c) return c:IsMouseOver(1e5, -1e5, 0, 0) end

local function aura_payload_churns(info)
    local issecrettable = _G.issecrettable
    local function check(i)
        if secret(i) or i == nil or (issecrettable and issecrettable(i)) then return true end
        local full, added, removed = i.isFullUpdate, i.addedAuras, i.removedAuraInstanceIDs
        if secret(full) or secret(added) or secret(removed) then return true end
        return (full or added or removed) and true or false
    end
    local ok, v = pcall(check, info)
    return not ok or v
end

local function coalesce(fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        C_Timer.After(0, function() pending = false fn() end)
    end
end

-- ==============================
-- 상수
-- ==============================
local TOKENS     = { 'player', 'party1', 'party2', 'party3', 'party4' }
local MAX_SPELLS = 5
local READ_EVERY = 0.2
local READS_AFTER = 2
local HOLD       = 0.5
local TICK       = 0.25
local CD_MIN, CD_MAX = 5, 900
local CODES, LINGER  = 254, 4
local DIM, GREY      = 0.5, 0.5
local WHITE = 'Interface\\Buttons\\WHITE8X8'

-- ==============================
-- 상태
-- ==============================
local holder, layer, sens_host
local slots  = {}   -- slot[1..5]
local built  = false
local failed = nil  -- sensor 생성 실패 이유
local pending_build = false
local ticker

local T0 = GetTime() - 1024
local function now_int() return floor(GetTime() - T0 + 0.5) end

-- ==============================
-- Strip 타이머 캐시
-- ==============================
local strips  = {}
local metrics = {}
local meter_fs

local function strip_text(cd)
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

local function measure_line(size)
    local key = tostring(size)
    local m = metrics[key]
    if m then return m[1], m[2] end
    if not meter_fs then return size, size end
    meter_fs:SetFont(STANDARD_TEXT_FONT, size, 'OUTLINE')
    meter_fs:SetText('0')
    local one = meter_fs:GetStringHeight()
    meter_fs:SetText('0\n0\n0\n0\n0\n0\n0\n0\n0')
    local nine = meter_fs:GetStringHeight()
    if not (one and nine and nine > one and not secret(one) and not secret(nine)) then
        return size, size
    end
    local step = (nine - one) / 8
    metrics[key] = { step, one }
    return step, one
end

-- ==============================
-- 타이머 수학
-- ==============================
local function unit_size(cd) return max(1, ceil(cd / CODES)) end

local function stamp(t, n)
    local code = floor((n - t.slot[t.cur].epoch) / t.u)
    if code < 0 then code = 0 elseif code > CODES then code = CODES end
    return (255 - code) / 255
end

local function left(t, sl, n)
    local code = 255 - floor(sl.c * 255 + 0.5)
    return t.cd - ((n - sl.epoch) - t.u * code)
end

local function roll(t, n)
    local k = t.cur
    if n - t.slot[k].epoch < t.P then return false end
    k = 3 - k
    local sl = t.slot[k]
    sl.c, sl.v, sl.epoch = 1, 0, n
    t.cur = k
    return true
end

local function range_update(c, k, sl, u, n)
    local m = (254 - (n - sl.epoch) / u) / 255
    c.pos[k]:SetMinMaxValues(m, m + 1)
    c.gate[k]:SetMinMaxValues(m, m + 1)
end

local function write_slot(c, k, sl, u, n)
    c.pos[k]:SetMinMaxValues(0, 1)
    c.pos[k]:SetValue(sl.c)
    c.gate[k]:SetMinMaxValues(0, 1)
    c.gate[k]:SetValue(sl.c)
    c.text[k]:SetAlpha(sl.v)
    c.veil[k]:SetAlpha(sl.v)
    c.shade[k]:SetAlpha(sl.v)
    range_update(c, k, sl, u, n)
end

local function push_cell(t, c, n)
    for k = 1, 2 do
        pcall(write_slot, c, k, t.slot[k], t.u, n)
    end
end

local function push(t)
    local n = now_int()
    if t.cell then push_cell(t, t.cell, n) end
end

local function start_plain(t, n)
    roll(t, n)
    local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
    sl.c, sl.v, other.v = stamp(t, n), 1, 0
end

local function clear_timer(t, n)
    local a, b = t.slot[1], t.slot[2]
    a.c, a.v, a.epoch = 1, 0, n
    b.c, b.v, b.epoch = 1, 0, n
    t.cur = 1
end

local function pick(cur, a, b)
    if not EvalBool then return b end
    return EvalBool(cur, a, b)
end

local function feed(t, cur, n)
    if t.primed then
        if roll(t, n) then push(t) end
        local cur_known = not secret(cur)
        local prev_known = not secret(t.prev)
        local up  = cur_known and cur or false
        local was = prev_known and t.prev or false
        local idle = (cur_known and not up) or (prev_known and was)
        if not idle then
            if cur_known and prev_known then
                start_plain(t, n)
            else
                local sl, other = t.slot[t.cur], t.slot[3 - t.cur]
                sl.c    = pick(cur,  pick(t.prev, sl.c,    stamp(t, n)), sl.c)
                sl.v    = pick(cur,  pick(t.prev, sl.v,    1),           sl.v)
                other.v = pick(cur,  pick(t.prev, other.v, 0),           other.v)
            end
            push(t)
        end
    end
    t.prev, t.primed = cur, true
end

-- ==============================
-- 셀 생성
-- ==============================
local GLOW_EDGES = {
    { 'TOPLEFT',   'TOPRIGHT',    'SetHeight' },
    { 'BOTTOMLEFT','BOTTOMRIGHT', 'SetHeight' },
    { 'TOPLEFT',   'BOTTOMLEFT',  'SetWidth'  },
    { 'TOPRIGHT',  'BOTTOMRIGHT', 'SetWidth'  },
}

local function new_cell(row)
    local c = CreateFrame('Frame', nil, row)
    c:Hide()

    local border = c:CreateTexture(nil, 'BACKGROUND')
    border:SetColorTexture(0, 0, 0, 1)
    border:SetAllPoints()
    c.icon = c:CreateTexture(nil, 'ARTWORK')
    c.icon:SetPoint('TOPLEFT',     c, 'TOPLEFT',      1, -1)
    c.icon:SetPoint('BOTTOMRIGHT', c, 'BOTTOMRIGHT', -1,  1)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local glow = CreateFrame('Frame', nil, c)
    glow:SetAllPoints(c)
    glow:SetAlpha(0)
    for _, e in ipairs(GLOW_EDGES) do
        local edge = glow:CreateTexture(nil, 'OVERLAY')
        edge:SetColorTexture(1, 0.82, 0.1, 1)
        edge:SetPoint(e[1], glow, e[1], 0, 0)
        edge:SetPoint(e[2], glow, e[2], 0, 0)
        edge[e[3]](edge, 2)
    end
    c.glow = glow

    local clip = CreateFrame('Frame', nil, layer)
    clip:SetClipsChildren(true)
    clip:Hide()
    c.clip = clip

    local win = CreateFrame('Frame', nil, layer)
    win:SetClipsChildren(true)
    win:Hide()
    c.win = win

    c.pos, c.fill, c.text, c.strip = {}, {}, {}, {}
    c.veil, c.grey, c.shade, c.gate = {}, {}, {}, {}

    for k = 1, 2 do
        local pos = CreateFrame('StatusBar', nil, layer)
        pos:SetStatusBarTexture(WHITE)
        pos:SetStatusBarColor(0, 0, 0, 0)
        pos:SetOrientation('VERTICAL')
        pos:SetMinMaxValues(0, 1)
        pos:SetValue(1)
        c.pos[k]  = pos
        c.fill[k] = pos:GetStatusBarTexture()

        local gate = CreateFrame('StatusBar', nil, layer)
        gate:SetStatusBarTexture(WHITE)
        gate:SetStatusBarColor(0, 0, 0, 0)
        gate:SetOrientation('VERTICAL')
        gate:SetMinMaxValues(0, 1)
        gate:SetValue(1)
        c.gate[k] = gate

        local text_fr = CreateFrame('Frame', nil, win)
        text_fr:SetAllPoints(win)
        text_fr:SetAlpha(0)
        local strip_fs = text_fr:CreateFontString(nil, 'OVERLAY')
        strip_fs:SetJustifyH('CENTER')
        strip_fs:SetPoint('BOTTOM', c.fill[k], 'TOP', 0, 0)
        c.text[k]  = text_fr
        c.strip[k] = strip_fs

        local veil = CreateFrame('Frame', nil, clip)
        veil:SetClipsChildren(true)
        veil:SetAlpha(0)
        local grey_tex = veil:CreateTexture(nil, 'ARTWORK')
        grey_tex:SetAllPoints(clip)
        grey_tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        grey_tex:SetDesaturated(true)
        grey_tex:SetVertexColor(GREY, GREY, GREY)
        c.veil[k] = veil
        c.grey[k] = grey_tex

        local shade = CreateFrame('Frame', nil, clip)
        shade:SetAllPoints(clip)
        shade:SetAlpha(0)
        local dim_tex = shade:CreateTexture(nil, 'ARTWORK')
        dim_tex:SetTexture(WHITE)
        dim_tex:SetVertexColor(0, 0, 0, DIM)
        dim_tex:SetAllPoints(clip)
        c.shade[k] = shade
    end
    return c
end

local function scrap(c)
    c:Hide()
    c.clip:Hide()
    c.win:Hide()
    for k = 1, 2 do
        c.pos[k]:Hide()
        c.gate[k]:Hide()
    end
end

local function dress_cell(c, def, cfg)
    local size = cfg.partyCDsSize or 28
    local ts   = cfg.partyCDsTextSize or 12
    local sig  = tostring(size) .. '|' .. tostring(ts) .. '|' .. tostring(def.cd)
    if c.sig == sig then return end

    c:SetSize(size, size)
    local lv = c:GetFrameLevel()
    local tex_id = def.show or def.id
    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(tex_id)
    if not tex or secret(tex) then tex = 134400 end
    c.icon:SetTexture(tex)
    c.clip:SetFrameLevel(lv + 1)
    c.win:SetFrameLevel(lv + 4)
    c.glow:SetFrameLevel(lv + 6)
    for k = 1, 2 do
        c.veil[k]:SetFrameLevel(lv + 2)
        c.shade[k]:SetFrameLevel(lv + 3)
        c.text[k]:SetFrameLevel(lv + 5)
        c.grey[k]:SetTexture(tex)
    end

    local step, one = measure_line(ts)
    local line = min(one, step)
    local cd, u = def.cd, unit_size(def.cd)
    local jump = size + 2

    c.clip:ClearAllPoints()
    c.clip:SetPoint('TOPLEFT',     c, 'TOPLEFT',     1, -1)
    c.clip:SetPoint('BOTTOMRIGHT', c, 'BOTTOMRIGHT', -1, 1)
    c.win:ClearAllPoints()
    c.win:SetPoint('CENTER', c, 'CENTER', 0, 0)
    c.win:SetSize(size + 6, line)
    c.line = line

    for k = 1, 2 do
        local pos, strip, gate = c.pos[k], c.strip[k], c.gate[k]
        local edge = gate:GetStatusBarTexture()
        pos:ClearAllPoints()
        pos:SetPoint('BOTTOM', c.win, 'BOTTOM', 0, -(cd - 1 + u) * step)
        pos:SetSize(1, 255 * u * step)
        pos:SetMinMaxValues(0, 1)
        pos:SetValue(1)
        strip:SetFont(STANDARD_TEXT_FONT, ts, 'OUTLINE')
        strip:SetTextColor(1, 1, 1)
        strip:SetText(strip_text(cd))
        gate:ClearAllPoints()
        gate:SetPoint('BOTTOM', c.clip, 'BOTTOM', 0, -(cd - 1 + u) * jump)
        gate:SetSize(1, 255 * u * jump)
        gate:SetMinMaxValues(0, 1)
        gate:SetValue(1)
        c.veil[k]:ClearAllPoints()
        c.veil[k]:SetPoint('BOTTOM', edge, 'TOP',  0, -1)
        c.veil[k]:SetPoint('TOP',    edge, 'TOP',  0, (cd - 1) * jump + size + 1)
        c.veil[k]:SetWidth(size)
    end
    c.sig = sig
end

-- ==============================
-- 레이아웃
-- ==============================
local function layout_row(s, cfg)
    local size    = cfg.partyCDsSize    or 28
    local spacing = cfg.partyCDsSpacing or 2
    local step    = size + spacing
    local n       = s.n or 0
    for j = 1, MAX_SPELLS do
        local c = s.cells[j]
        if c then
            local show = (j <= n) and not (s.def[j] and s.def[j].spell.others)
            if show then
                c:ClearAllPoints()
                c:SetPoint('LEFT', s.row, 'LEFT', (j - 1) * step, 0)
                c:Show()
                c.clip:Show()
                c.win:SetShown(cfg.partyCDsShowTimer ~= false)
            else
                scrap(c)
            end
        end
    end
    local total_w = n > 0 and (n * step - spacing) or 0
    s.row:SetSize(total_w > 0 and total_w or 1, size)
end

local function get_member_frame(unit)
    -- 공격대 스타일 파티프레임 (플레이어 포함)
    local cpf = _G.CompactPartyFrame
    if cpf and cpf:IsShown() then
        for i = 1, 5 do
            local f = _G['CompactPartyFrameMember' .. i]
            if f and f:IsShown() and f.unit == unit then return f end
        end
        return nil
    end
    if unit == 'player' then return nil end  -- 플레이어는 파티프레임에만 표시
    local pf = _G.PartyFrame
    if not pf then return nil end
    for i = 1, 5 do
        local f = pf['MemberFrame' .. i]
        if f and f.unit == unit then return f end
    end
    return nil
end

local function layout_all(cfg)
    if not holder then return end
    for i = 1, #slots do
        local s = slots[i]
        if s.row and s.n and s.n > 0 then
            local uf = get_member_frame(s.unit)
            if uf then
                s.row:ClearAllPoints()
                s.row:SetPoint('TOPRIGHT', uf, 'TOPLEFT', 0, 0)
                s.row:Show()
                layout_row(s, cfg)
            else
                s.row:Hide()
            end
        elseif s.row then
            s.row:Hide()
        end
    end
end

-- ==============================
-- 멤버 관리
-- ==============================
local inspect_queue   = {}
local inspect_pending = nil
local inspect_next    -- forward ref

-- 스펙 → 스펠 목록 결정
local function spell_list_for(m)
    local list
    if m.spec and SPECS[m.spec] then
        list = ptc.spec_list(m.spec)
    elseif m.class then
        list = ptc.class_list(m.class)
    end
    return ptc.racial_add(list, m.race) or {}
end

local QueueRefresh

local function rebuild_slot(s, cfg)
    local m = s.member
    if not m then
        s.n, s.def = 0, {}
        for j = 1, MAX_SPELLS do if s.cells[j] then scrap(s.cells[j]) end end
        if s.row then s.row:Hide() end
        return
    end

    local list = spell_list_for(m)
    local n = math.min(#list, MAX_SPELLS)
    s.n, s.def = n, list

    -- 타이머 상태 재사용 또는 생성
    for j = 1, n do
        local def = list[j]
        local t = m.tr[def.id]
        if not t then
            t = { slot = { {c=1,v=0,epoch=0}, {c=1,v=0,epoch=0} }, cur = 1, primed = false }
            t.cd, t.u = def.cd, unit_size(def.cd)
            t.P = CODES * t.u
            clear_timer(t, now_int())
            m.tr[def.id] = t
        elseif t.cd ~= def.cd then
            t.cd, t.u = def.cd, unit_size(def.cd)
            t.P = CODES * t.u
            clear_timer(t, now_int())
        end
        t.def = def

        -- 셀 생성/재활용
        local c = s.cells[j]
        if not c then
            c = new_cell(s.row)
            s.cells[j] = c
        end
        dress_cell(c, def, cfg)
        t.cell = c
        s.tr[j] = t
        push(t)
    end

    -- 초과 셀 숨김
    for j = n + 1, MAX_SPELLS do
        s.tr[j] = nil
        if s.cells[j] then scrap(s.cells[j]) end
    end

    -- 센서/이벤트 설정
    wipe(s.by_cast)
    local watch = false
    local want_event = nil
    if s.sensored and not UNAVAILABLE and not failed then
        for j = 1, n do
            local def = list[j]
            local sp  = def.spell
            local live = false
            if not sp.others then
                local c_sens = s.sens[j]
                if c_sens then
                    if aim_sensor(c_sens, sp.sig, sp.filters) then
                        live = true
                        watch = true
                    else
                        pending_build = true
                    end
                else
                    -- ensure_engine가 아직 실행 안 됨 (전투 중 blocked)
                    pending_build = true
                end
            end
            s.live[j] = live
        end
        -- 남은 센서 비활성화
        for j = n + 1, #s.sens do
            local c_sens = s.sens[j]
            if c_sens and c_sens.on then
                c_sens.on = false
                pcall(c_sens.SetEnabled, c_sens, false)
            end
            s.live[j] = false
        end
        if watch then want_event = 'UNIT_AURA' end
    else
        -- 플레이어: cast 이벤트
        for j = 1, n do
            local def = list[j]
            for cast_id in pairs(def.spell.casts) do
                s.by_cast[cast_id] = s.tr[j]
            end
            s.live[j] = false
        end
        if n > 0 then want_event = 'UNIT_SPELLCAST_SUCCEEDED' end
    end
    if s.event ~= want_event then
        if s.event then s.evt:UnregisterEvent(s.event) end
        if want_event then s.evt:RegisterUnitEvent(want_event, s.unit) end
        s.event = want_event
    end
    s.n = n
    if watch then
        s.hold  = GetTime() + HOLD
        s.reads = READS_AFTER
    end
end

local function ensure_ticker()
    if not ticker then ticker = C_Timer.NewTicker(TICK, function() -- tick 아래에서 정의
        local n = now_int()
        local any = false
        for i = 1, #slots do
            local s = slots[i]
            for j = 1, MAX_SPELLS do
                local t = s.tr[j]
                if t and t.cell then
                    any = true
                    if roll(t, n) then push(t) end
                    for k = 1, 2 do
                        local sl = t.slot[k]
                        if secret(sl.v) or sl.v ~= 0 then
                            if not secret(sl.v) and not secret(sl.c) and left(t, sl, n) <= -LINGER then
                                sl.v = 0
                                push(t)
                            else
                                pcall(range_update, t.cell, k, sl, t.u, n)
                            end
                        end
                    end
                end
            end
        end
        if not any and ticker then ticker:Cancel() ticker = nil end
    end) end
end

-- ==============================
-- 읽기 드라이버
-- ==============================
local driver = CreateFrame('Frame')
driver:Hide()
local acc = 0
driver:SetScript('OnUpdate', function(self, elapsed)
    acc = acc + elapsed
    if acc < READ_EVERY then return end
    acc = 0
    local n, busy = now_int(), false
    local glow_on = dodoDB.partyCDsHighlight ~= false
    for i = 1, #slots do
        local s = slots[i]
        if s.reads > 0 then
            if not s.member then
                s.reads = 0
            elseif GetTime() >= s.hold then
                s.reads = s.reads - 1
                -- ReadSlot
                for j = 1, MAX_SPELLS do
                    local t = s.tr[j]
                    if t and s.live[j] then
                        local cur = sensor_lit(s.sens[j])
                        feed(t, cur, n)
                        if t.cell then
                            local lit = 0
                            if glow_on then lit = pick(cur, 1, 0) end
                            t.cell.glow:SetAlpha(lit)
                        end
                    end
                end
            end
            if s.reads > 0 then busy = true end
        end
    end
    if not busy then self:Hide() end
end)

local function wake()
    if driver:IsShown() then return end
    acc = 0
    driver:Show()
end

-- ==============================
-- 슬롯 초기화
-- ==============================
for i, unit in ipairs(TOKENS) do
    local s = {
        index    = i,
        unit     = unit,
        sensored = (i > 1),  -- party1~4만 센서 사용
        member   = nil,
        n        = 0,
        def      = {},
        cells    = {},
        tr       = {},
        sens     = {},
        live     = {},
        by_cast  = {},
        event    = nil,
        reads    = 0,
        hold     = 0,
    }
    s.evt = CreateFrame('Frame')
    s.evt:SetScript('OnEvent', function(_, event, _, a, b)
        if event == 'UNIT_AURA' then
            if s.member and (s.reads >= READS_AFTER or aura_payload_churns(a)) then
                s.reads = READS_AFTER
                wake()
            end
        elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
            -- 플레이어 직접 시전
            if secret(b) then return end
            local t = s.by_cast[b]
            if t then
                start_plain(t, now_int())
                push(t)
                ensure_ticker()
            end
        end
    end)
    slots[i] = s
end

-- ==============================
-- 멤버 갱신 (GROUP_ROSTER_UPDATE)
-- ==============================
local spec_by_guid = {}

local function get_unit_spec(unit)
    local ok, spec
    if C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization then
        ok, spec = pcall(C_SpecializationInfo.GetInspectSpecialization, unit)
    end
    if ok and spec and not secret(spec) and type(spec) == 'number' and spec > 0 then
        return spec
    end
    return nil
end

-- 종족 토큰 (UnitRace → GetPlayerInfoByGUID 순)
local function get_unit_race(unit, guid)
    local ok, _, token = pcall(UnitRace, unit)
    if ok and not secret(token) and type(token) == 'string' then return token end
    if guid and GetPlayerInfoByGUID then
        ok, _, _, _, token = pcall(GetPlayerInfoByGUID, guid)
        if ok and not secret(token) and type(token) == 'string' then return token end
    end
    return nil
end

local function update_members()
    if not built then return end
    local cfg = dodoDB

    -- 인원 파악
    local in_group = IsInGroup() and not IsInRaid()
    local group_only = cfg.partyCDsGroupOnly ~= false

    if group_only and not in_group then
        for i = 1, #slots do
            slots[i].member = nil
            rebuild_slot(slots[i], cfg)
        end
        holder:Hide()
        return
    end

    wipe(inspect_queue)
    for i, unit in ipairs(TOKENS) do
        local s = slots[i]
        if i > 1 and not in_group then
            s.member = nil
        else
            local ok_e, exists = pcall(UnitExists, unit)
            if ok_e and exists and not secret(exists) then
                local ok_g, guid = pcall(UnitGUID, unit)
                local ok_c, _, class = pcall(UnitClass, unit)
                local g   = (ok_g and not secret(guid)) and guid or nil
                local cls = (ok_c and not secret(class)) and class or nil
                local spec = g and spec_by_guid[g]
                if not spec then
                    -- inspect 요청
                    inspect_queue[unit] = true
                end
                local race = get_unit_race(unit, g)
                local m = s.member
                if not m or m.guid ~= g then
                    m = { unit = unit, guid = g, class = cls, spec = spec, race = race, tr = {} }
                    s.member = m
                else
                    m.class = cls
                    if spec then m.spec = spec end
                    m.race = race or m.race
                end
                rebuild_slot(s, cfg)
            else
                s.member = nil
                rebuild_slot(s, cfg)
            end
        end
    end

    if cfg.enablePartyCDs then
        holder:Show()
    end
    layout_all(cfg)
    ensure_ticker()
    -- rebuild 후 드라이버 시작 — OFF 상태를 먼저 읽어야 onset 감지 가능 (KiraUI 패턴)
    local any_reads = false
    for i = 1, #slots do
        if slots[i].reads > 0 then any_reads = true break end
    end
    if any_reads then wake() end
    C_Timer.After(0.2, inspect_next)
end

QueueRefresh = coalesce(update_members)

-- Inspect 결과 처리
local inspect_frame = CreateFrame('Frame')
inspect_frame:RegisterEvent('INSPECT_READY')
inspect_frame:SetScript('OnEvent', function(_, _, guid)
    inspect_pending = nil
    if secret(guid) or not guid then
        C_Timer.After(0.5, inspect_next)
        return
    end
    for i, unit in ipairs(TOKENS) do
        local ok_g, g = pcall(UnitGUID, unit)
        if ok_g and not secret(g) and g == guid then
            local spec = get_unit_spec(unit)
            if spec then
                spec_by_guid[guid] = spec
                local s = slots[i]
                if s.member and s.member.guid == guid then
                    s.member.spec = spec
                    rebuild_slot(s, dodoDB)
                    layout_all(dodoDB)
                    if s.reads > 0 then wake() end
                end
            end
            break
        end
    end
    C_Timer.After(0.3, inspect_next)
end)

inspect_next = function()
    if inspect_pending then return end
    for unit, _ in pairs(inspect_queue) do
        local ok, can = pcall(CanInspect, unit, false)
        if ok and can and not secret(can) then
            inspect_pending = unit
            inspect_queue[unit] = nil
            pcall(NotifyInspect, unit)
            return
        end
    end
end

-- ==============================
-- EnsureEngine — 전투 전 센서 전부 미리 생성 (KiraUI 패턴)
-- ==============================
local function ensure_engine()
    if failed or UNAVAILABLE then return end
    if InCombatLockdown() then
        pending_build = true
        return
    end
    pending_build = false
    for i = 1, #slots do
        local s = slots[i]
        if s.sensored then
            for j = 1, MAX_SPELLS do
                if not s.sens[j] then
                    s.sens[j] = new_unit_sensor(sens_host, s.unit)
                    if not s.sens[j] then
                        failed = 'sensor 생성 실패'
                        return
                    end
                end
            end
        end
    end
end

-- ==============================
-- 프레임 초기화 (PLAYER_LOGIN)
-- ==============================
local function init_frames()
    -- 가용성 체크
    local IS_121 = (select(4, GetBuildInfo()) or 0) >= 120100
    local ok_tpl, tpl_info = pcall(_G.C_XMLUtil and _G.C_XMLUtil.GetTemplateInfo or function() end, 'CustomAuraContainerTemplate')
    HAS_WIDGETS = IS_121 and ok_tpl and tpl_info ~= nil
    door = test_door()
    UNAVAILABLE = not (HAS_WIDGETS and (door.state == 'exact' or door.state == 'close' or door.state == 'hidden'))

    if UNAVAILABLE then
        local why = not HAS_WIDGETS
            and 'CustomAuraContainerTemplate 없음 (12.1+ 전용)'
            or  ('door: ' .. tostring(door.state))
        print('|cffff7d0adodo PartyCDs|r 이 클라이언트에서 사용 불가: ' .. why)
    end

    -- 센서 호스트 (KiraUI 동일 위치)
    sens_host = CreateFrame('Frame', nil, UIParent)
    sens_host:SetSize(1, 1)
    sens_host:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0)

    -- 메트릭 측정용 FontString
    local meter_host = CreateFrame('Frame', nil, UIParent)
    meter_host:SetSize(1, 1)
    meter_host:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -2000, 0)
    meter_fs = meter_host:CreateFontString(nil, 'OVERLAY')
    meter_fs:SetPoint('TOPLEFT')

    -- 오버레이 레이어 (pos/win/clip 부모)
    layer = CreateFrame('Frame', nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata('MEDIUM')
    layer:SetFrameLevel(10)

    -- 드래그 앵커
    holder = CreateFrame('Frame', 'DodoPartyCDs', UIParent)
    holder:SetSize(1, 1)
    holder:SetFrameStrata('MEDIUM')
    holder:SetFrameLevel(5)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    holder:Hide()
    holder:SetPoint('CENTER', UIParent, 'CENTER', dodoDB.partyCDsX or -320, dodoDB.partyCDsY or 0)

    -- 드래그 (Lock 없을 때)
    local drag_target = CreateFrame('Frame', nil, holder)
    drag_target:SetAllPoints(holder)
    drag_target:EnableMouse(true)
    drag_target:RegisterForDrag('LeftButton')
    drag_target:SetScript('OnDragStart', function()
        if dodoDB.partyCDsLock then return end
        holder:StartMoving()
    end)
    drag_target:SetScript('OnDragStop', function()
        holder:StopMovingOrSizing()
        local cx, cy = holder:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if cx and ux then
            dodoDB.partyCDsX = floor(cx - ux + 0.5)
            dodoDB.partyCDsY = floor(cy - uy + 0.5)
        end
    end)

    -- 행 프레임 (유닛별)
    for i, unit in ipairs(TOKENS) do
        local s = slots[i]
        local row = CreateFrame('Frame', nil, holder)
        row:SetSize(1, dodoDB.partyCDsSize or 28)
        row:Hide()
        s.row = row

        -- 이름 레이블
        local name_fs = row:CreateFontString(nil, 'OVERLAY')
        name_fs:SetFont(STANDARD_TEXT_FONT, 10, 'OUTLINE')
        name_fs:SetPoint('BOTTOMLEFT', row, 'TOPLEFT', 0, 2)
        name_fs:SetTextColor(1, 1, 1)
        s.name_fs = name_fs
    end

end

-- ==============================
-- 설정 적용 콜백
-- ==============================
function dodo.PartyCDs_Apply()
    if not built then return end
    local cfg = dodoDB
    if cfg.enablePartyCDs then
        holder:Show()
    else
        holder:Hide()
        return
    end
    holder:ClearAllPoints()
    holder:SetPoint('CENTER', UIParent, 'CENTER', cfg.partyCDsX or -320, cfg.partyCDsY or 0)
    for i = 1, #slots do
        rebuild_slot(slots[i], cfg)
    end
    layout_all(cfg)
    ensure_ticker()
    local any_reads = false
    for i = 1, #slots do
        if slots[i].reads > 0 then any_reads = true break end
    end
    if any_reads then wake() end
end

-- ==============================
-- 이벤트
-- ==============================
local evt = CreateFrame('Frame')
evt:RegisterEvent('ADDON_LOADED')
evt:SetScript('OnEvent', function(self, event, arg1)
    if event == 'ADDON_LOADED' and arg1 == 'dodoUnitframe' then
        self:UnregisterEvent('ADDON_LOADED')
        self:RegisterEvent('PLAYER_LOGIN')
        self:RegisterEvent('PLAYER_ENTERING_WORLD')
        self:RegisterEvent('GROUP_ROSTER_UPDATE')
        self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
        self:RegisterEvent('PLAYER_REGEN_ENABLED')
    elseif event == 'PLAYER_LOGIN' then
        init_frames()
        self:UnregisterEvent('PLAYER_LOGIN')
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- KiraUI 패턴: 월드 로드 후 0.5초 대기 → 파티 유닛 데이터 확보 후 센서 초기화
        C_Timer.After(0.5, function()
            ensure_engine()
            built = true
            QueueRefresh()
        end)
    elseif event == 'GROUP_ROSTER_UPDATE' then
        QueueRefresh()
    elseif event == 'PLAYER_SPECIALIZATION_CHANGED' then
        local guid
        local ok, g = pcall(UnitGUID, 'player')
        if ok and not secret(g) then guid = g end
        if guid then spec_by_guid[guid] = nil end
        QueueRefresh()
    elseif event == 'PLAYER_REGEN_ENABLED' then
        if pending_build then
            ensure_engine()
            QueueRefresh()
        end
    end
end)
