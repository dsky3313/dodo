-- ==============================
-- PartyTracker 편집모드 연결 (LibEditMode)
-- ==============================
-- 공생기/차단기/군중제어 떠있는 프레임을 편집모드로 이동.
-- 좌표는 각 모듈 cfg 의 x/y (UIParent CENTER 기준 오프셋) 에 그대로 저장.
-- 편집모드 중엔 켜진 모듈만 미리보기로 표시.

---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local _, ns = ...

local CreateFrame = CreateFrame
local UIParent = UIParent

---@class PTEditEntry
---@field name string 전역 프레임 이름
---@field label string 편집모드 표시 이름
---@field get_cfg fun(): table
---@field x string
---@field y string
---@field preview fun(on: boolean)
---@field apply fun()

---@type PTEditEntry[]
local ENTRIES = {
    { name = "dodoPartyDefensives", label = "공생기", get_cfg = ns.PDFGetCfg, x = "x", y = "y", preview = ns.PDFSetPreview, apply = ns.PDFApply, party = { "TOPLEFT", "TOPRIGHT", "px", "py" } },
    -- dodo: party = { 내 앵커, 파티 프레임 앵커, x키, y키 } → 파티 프레임 기준 오프셋으로 저장
    { name = "dodoPartyInterrupts", label = "차단기", get_cfg = ns.IKGetCfg, x = "x", y = "y", preview = ns.IKSetPreview, apply = ns.IKApply, party = { "TOPLEFT", "TOPRIGHT", "px", "py" } },
    { name = "dodoPartyCC1", label = "군중제어", get_cfg = ns.CCGetCfg, x = "x1", y = "y1", preview = ns.CCSetPreview, apply = ns.CCApply },
    -- dodo: 군중제어 하나로 합침
    -- { name = "dodoPartyCC2", label = "군중제어 2", get_cfg = ns.CCGetCfg, x = "x2", y = "y2", preview = ns.CCSetPreview, apply = ns.CCApply },
}

local by_frame = {}

-- 프레임의 앵커 지점 화면 좌표 (effective scale 반영)
local function point_xy(f, point)
    local l, b, w, h = f:GetRect()
    if not l or ns.IsSecret(l) or ns.IsSecret(w) then return nil end
    local s = f:GetEffectiveScale()
    local x = point:find("LEFT") and l or point:find("RIGHT") and l + w or l + w / 2
    local y = point:find("TOP") and b + h or point:find("BOTTOM") and b or b + h / 2
    return x * s, y * s
end

-- 드래그 종료 → 파티 프레임 기준 오프셋 (dodo) / 중심 오프셋 저장
local function on_moved(frame)
    local e = by_frame[frame]
    if not e then return end
    local party = e.party and ns.PartyAnchor()
    if party then
        local p = e.party
        local fx, fy = point_xy(frame, p[1])
        local ax, ay = point_xy(party, p[2])
        if fx and ax then
            local s = frame:GetEffectiveScale()
            local cfg = e.get_cfg()
            cfg[p[3]], cfg[p[4]] = (fx - ax) / s, (fy - ay) / s
            e.apply()
            return
        end
    end
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and ux) then return end
    local cfg = e.get_cfg()
    cfg[e.x], cfg[e.y] = cx - ux, cy - uy
    e.apply()
end

-- 켜진 모듈만 미리보기 on/off (군중제어는 바 2개가 한 모듈)
local function set_previews(on)
    local done = {}
    for _, e in ipairs(ENTRIES) do
        if not done[e.preview] then
            done[e.preview] = true
            if not on or e.get_cfg().enable then e.preview(on) end
        end
    end
end

local function on_enter() set_previews(true) end
local function on_exit() set_previews(false) end

local function register()
    local LEM = LibStub and LibStub("LibEditMode", true)
    if not LEM then return end
    -- 프레임은 모듈이 지연 생성 → 미리보기 한 번 켰다 꺼서 생성
    for _, e in ipairs(ENTRIES) do
        if not _G[e.name] then
            e.preview(true)
            e.preview(false)
        end
    end
    for _, e in ipairs(ENTRIES) do
        local frame = _G[e.name]
        if frame and not by_frame[frame] then
            by_frame[frame] = e
            local cfg = e.get_cfg()
            LEM:AddFrame(frame, on_moved, { point = "CENTER", x = cfg[e.x] or 0, y = cfg[e.y] or 0 }, e.label)
        end
    end
    LEM:RegisterCallback("enter", on_enter)
    LEM:RegisterCallback("exit", on_exit)
end

local login_frame = CreateFrame("Frame")
local function on_login(self)
    self:UnregisterAllEvents()
    register()
end
login_frame:RegisterEvent("PLAYER_LOGIN")
login_frame:SetScript("OnEvent", on_login)
