-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)
-- Simple FPS Ping (https://www.curseforge.com/wow/addons/simple-fps-ping)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 전체 상태 제어 및 초기화
-- ==============================
local function update_minimap_state()
    if dodo.UpdateMinimapSquareState then
        dodo.UpdateMinimapSquareState()
    end
    if dodo.UpdateMinimapZoomState then
        dodo.UpdateMinimapZoomState()
    end
    if dodo.UpdateMinimapFPSState then
        dodo.UpdateMinimapFPSState()
    end
    if dodo.UpdateMinimapCoordState then
        dodo.UpdateMinimapCoordState()
    end
end

dodo.Minimap = update_minimap_state

local function initialize()
    update_minimap_state()
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event)
    if event == "PLAYER_LOGIN" then
        initialize()
        self:UnregisterAllEvents()
    end
end

local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
dodo.RegisterOption("인터페이스.미니맵", function(category)
    dodo.UI:SettingsCheckbox(category, "useFPSFrame",        "FPS/MS 표시",        "", true, dodo.UpdateMinimapFPSState)
    dodo.UI:SettingsCheckbox(category, "useIconAddons",    "애드온 아이콘 모음", "", true, dodo.UpdateMinimapIconAddonsState)
    dodo.UI:SettingsCheckbox(category, "useCoord",           "좌표 표시",          "", true, dodo.UpdateMinimapCoordState)
    dodo.UI:SettingsCheckbox(category, "useMinimapSquare",   "사각형 미니맵",      "", true, dodo.UpdateMinimapSquareState)
    dodo.UI:SettingsCheckbox(category, "useResetMinimapZoom","줌 초기화",          "", true, dodo.UpdateMinimapZoomState)
end, 3800)
