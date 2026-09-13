-- ==============================
-- Inspired
-- ==============================
-- Method Raid Tools (https://www.curseforge.com/wow/addons/method-raid-tools)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global

-- 설정창 제목 (XML의 header="WMB"와 매칭)
_G["BINDING_HEADER_WMB"] = "dodo WMarker"

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local format      = format

local CURSOR_LABEL = "Cursor"

-- ==============================
-- 기능: 월드마커 키바인딩 버튼 생성
-- ==============================
local function Binding(name, label, macrotext)
    _G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = label
    local btn = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macrotext)
    btn:RegisterForClicks("AnyUp", "AnyDown")
end

for i = 1, 8 do
    local markerName = _G["WORLD_MARKER" .. i] or ("마커 " .. i)
    Binding("WMB_WM" .. i .. "CURSOR", markerName .. " @ " .. CURSOR_LABEL, format("/wm [@cursor] %d", i))
end
