-- ==============================
-- 설정 및 테이블
-- ==============================
-- DestroyTotem() = SecretArguments "AllowedWhenUntainted" → 애드온 코드에서 직접 호출 불가.
-- 해결: Blizzard TotemFrame 자체를 re-parent. 버튼·클릭핸들러·툴팁 전부 Blizzard 코드(untainted) 유지.
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 로컬 상태
-- ==============================
local container    = nil
local _orig_parent = nil  -- nil = 바 미활성
local _hooked      = false

-- ==============================
-- 레이아웃 (정적 참조, GC 프리)
-- ==============================
local function on_totem_updated()
    if not container or not _orig_parent then return end
    if TotemFrame:GetParent() ~= container then
        TotemFrame:SetParent(container)  -- Blizzard가 Update 중 parent를 reset할 수 있음
    end
    TotemFrame:ClearAllPoints()
    TotemFrame:SetPoint("LEFT", container, "LEFT", -15, 0)
    container:SetShown(TotemFrame:IsShown())
end

local function on_totem_hide()
    if container then container:Hide() end
end

-- ==============================
-- 활성화 / 비활성화
-- ==============================
local function build_bar()
    if _orig_parent or not container or not TotemFrame then return end

    _orig_parent = TotemFrame:GetParent()
    TotemFrame:SetParent(container)
    on_totem_updated()

    if not _hooked then
        _hooked = true
        hooksecurefunc(TotemFrame, "Update", on_totem_updated)
        TotemFrame:HookScript("OnShow", on_totem_updated)
        TotemFrame:HookScript("OnHide", on_totem_hide)
    end
end

-- ==============================
-- 이벤트
-- ==============================
local event_frame = CreateFrame("Frame")

local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            dodoDB = dodoDB or {}
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if container then return end  -- 이미 생성됨

        container = CreateFrame("Frame", "dodoTotemContainer", dodo.PlayerFrame)
        container:SetSize(37, 37)
        container:SetPoint("TOPLEFT", dodo.PlayerFrame, "BOTTOMLEFT", 0, -5)
        container:SetFrameStrata("MEDIUM")
        container:Hide()

        build_bar()

        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
event_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 디버그
-- ==============================
local function p(msg) print("|cff00ccff[TotemDBG]|r " .. tostring(msg)) end
dodo.TotemDebug = function()
    p("container: "        .. tostring(container))
    p("_orig_parent: "     .. tostring(_orig_parent))
    p("PlayerFrame: "      .. tostring(dodo.PlayerFrame))
    if dodo.PlayerFrame then
        p("PlayerFrame shown: "   .. tostring(dodo.PlayerFrame:IsShown()))
        p("PlayerFrame visible: " .. tostring(dodo.PlayerFrame:IsVisible()))
    end
    if not TotemFrame then p("TotemFrame: NIL!"); return end
    p("TotemFrame parent: "   .. tostring(TotemFrame:GetParent()))
    p("TotemFrame IsShown: "  .. tostring(TotemFrame:IsShown()))
    p("TotemFrame IsVisible: ".. tostring(TotemFrame:IsVisible()))
    p("TotemFrame.activeTotems: " .. tostring(TotemFrame.activeTotems))
    if container then
        p("container parent: "   .. tostring(container:GetParent()))
        p("container IsShown: "  .. tostring(container:IsShown()))
        p("container IsVisible: ".. tostring(container:IsVisible()))
        local pt, relFrame, rpt, x, y = container:GetPoint(1)
        p("container anchor: "   .. tostring(pt) .. " relFrame=" .. tostring(relFrame) .. " relPt=" .. tostring(rpt) .. " "..tostring(x)..","..tostring(y))
        p("container screen pos: L=" .. tostring(container:GetLeft()) .. " T=" .. tostring(container:GetTop()))
    end
    if TotemFrame then
        p("TotemFrame screen pos: L=" .. tostring(TotemFrame:GetLeft()) .. " T=" .. tostring(TotemFrame:GetTop()))
    end
    for i = 1, MAX_TOTEMS do
        local have, name, _, dur = GetTotemInfo(i)
        p("slot["..i.."]: have="..tostring(have).." dur="..tostring(dur))
    end
end
_G.dodoTotemDebug = dodo.TotemDebug

