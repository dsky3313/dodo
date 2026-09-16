-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

local init_frame = nil
local zoom_timer = nil

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetInstanceInfo = GetInstanceInfo
local Minimap = Minimap
local PlaySound = PlaySound
local issecretvalue = issecretvalue or function() return false end

-- ==============================
-- 줌 초기화 로직
-- ==============================
local function on_zoom_timer_tick()
    zoom_timer = nil
    local _, i_type, d_id = GetInstanceInfo()
    if not (d_id == 8 or i_type == "raid") then
        local current_zoom = Minimap:GetZoom()
        if not issecretvalue(current_zoom) and current_zoom ~= 0 then
            Minimap:SetZoom(0)
            PlaySound(113, "Master")
        end
    end
end

local function reset_minimap_zoom()
    if not dodoDB or dodoDB.useResetMinimapZoom == false then return end
    local _, instance_type, difficulty_id = GetInstanceInfo()
    if difficulty_id == 8 or instance_type == "raid" then return end
    if zoom_timer then return end

    zoom_timer = C_Timer.NewTimer(10, on_zoom_timer_tick)
end

local function update_minimap_zoom_reset()
    if not init_frame then return end
    local is_enabled = (dodoDB and dodoDB.useMinimap ~= false and dodoDB.useResetMinimapZoom ~= false)
    local _, instance_type, difficulty_id = GetInstanceInfo()
    local in_instance = (difficulty_id == 8 or instance_type == "raid")

    if is_enabled then
        init_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if not in_instance then
            init_frame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
        else
            init_frame:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
            if zoom_timer then zoom_timer:Cancel() zoom_timer = nil end
        end
    else
        init_frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        init_frame:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
        if zoom_timer then zoom_timer:Cancel() zoom_timer = nil end
    end
end

dodo.UpdateMinimapZoomState = update_minimap_zoom_reset
dodo.useResetMinimapZoom = update_minimap_zoom_reset

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "MINIMAP_UPDATE_ZOOM" then
        reset_minimap_zoom()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_minimap_zoom_reset()
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.useResetMinimapZoom == nil then dodoDB.useResetMinimapZoom = true end
        update_minimap_zoom_reset()
    end
end

init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", on_event)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.Minimap, {
        {
            name = "미니맵 줌 초기화",
            get = function() return dodoDB.useResetMinimapZoom ~= false end,
            set = function(v) dodoDB.useResetMinimapZoom = v; update_minimap_zoom_reset() end,
            disabled = function() return dodoDB and dodoDB.useMinimap == false end,
        }
    })
end
