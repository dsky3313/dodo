-- ==============================
-- Inspired
-- ==============================
-- dodo WMarker Module

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("WMarker", module)

local CURSOR_LABEL = "Cursor"

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local format = format
local _G = _G

-- ==============================
-- 프레임 및 이벤트
-- ==============================
local secureButtons = {}

-- ==============================
-- 기능 1: 키바인딩 및 보안 버튼 생성
-- ==============================
local function create_binding_button(name, label, macrotext)
    _G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = label
    
    local btn = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macrotext)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    
    secureButtons[name] = btn
end

-- ==============================
-- 초기화
-- ==============================
local function create_ui()
    _G["BINDING_HEADER_WMB"] = "dodo WMarker"

    for i = 1, 8 do
        local internalName = "WMB_WM" .. i .. "CURSOR"
        local markerName = _G["WORLD_MARKER" .. i] or ("마커 " .. i)
        local macrotext = format("/wm [@cursor] %d", i)
        
        create_binding_button(internalName, markerName .. " @ " .. CURSOR_LABEL, macrotext)
    end
end

local function initialize()
    create_ui()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
end