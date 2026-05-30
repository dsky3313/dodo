-- ==============================
-- Inspired
-- ==============================
-- Simple FPS Ping (https://www.curseforge.com/wow/addons/simple-fps-ping)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

local fps_frame = nil
local fps_ticker = nil
local text_green, text_red, text_yellow
local last_text = ""

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local GetNetStats = GetNetStats
local IsInInstance = IsInInstance
local MinimapCluster = MinimapCluster
local NineSliceUtil = NineSliceUtil
local format = string.format

-- ==============================
-- UI 생성
-- ==============================
local function create_ui()
    if fps_frame then return end

    fps_frame = CreateFrame("Frame", "dodoFPSFrame", MinimapCluster)
    fps_frame:SetSize(98, 16)
    fps_frame:Hide()

    if MinimapCluster then
        fps_frame:SetPoint("TOPLEFT", MinimapCluster.BorderTop, "BOTTOMLEFT", 0, -2)
    end

    local border = CreateFrame("Frame", nil, fps_frame, "NineSliceCodeTemplate")
    border:SetAllPoints(fps_frame)
    border.layoutType = "UniqueCornersLayout"
    border.layoutTextureKit = "ui-hud-minimap-button"
    NineSliceUtil.ApplyLayout(border, NineSliceUtil.GetLayout(border.layoutType), border.layoutTextureKit)

    fps_frame.text = border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fps_frame.text:SetPoint("RIGHT", border, "RIGHT", -5, 0)
    fps_frame.text:SetJustifyH("RIGHT")
end

-- ==============================
-- FPS / MS 업데이트
-- ==============================
local function update_fps_text()
    if not fps_frame then return end
    local fps = GetFramerate()
    local _, _, latency = GetNetStats()
    local fps_color = (fps >= 60) and text_green or (fps >= 30 and text_yellow or text_red)
    local ms_color = (latency <= 100) and text_green or (latency <= 200 and text_yellow or text_red)

    local current_text = format("|cff%s%.0f|r fps | |cff%s%d|r ms", fps_color, fps, ms_color, latency)
    if last_text ~= current_text then
        fps_frame.text:SetText(current_text)
        last_text = current_text
    end
end

local function update_fps_display()
    create_ui()
    if not fps_frame then return end

    local is_enabled = (dodoDB and dodoDB.useMinimap ~= false and dodoDB.useFPSFrame ~= false)
    if is_enabled then
        fps_frame:Show()
        
        local in_instance = IsInInstance()
        local interval = in_instance and 2 or 1
        
        if fps_ticker then
            if fps_ticker._interval ~= interval then
                fps_ticker:Cancel()
                fps_ticker = nil
            end
        end
        
        if not fps_ticker then
            fps_ticker = C_Timer.NewTicker(interval, update_fps_text)
            fps_ticker._interval = interval
        end
    else
        fps_frame:Hide()
        if fps_ticker then
            fps_ticker:Cancel()
            fps_ticker = nil
        end
    end
end

dodo.UpdateFPSDisplay = update_fps_display
dodo.UpdateMinimapFPSState = update_fps_display

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function initialize()
    local Colors = dodo.Colors
    if Colors then
        text_green  = Colors.SoftGreen and Colors.SoftGreen.hex:sub(3) or "b2ffb2"
        text_red    = Colors.SoftRed and Colors.SoftRed.hex:sub(3) or "ffb2b2"
        text_yellow = Colors.LemonYellow and Colors.LemonYellow.hex:sub(3) or "ffffb2"
    else
        text_green, text_red, text_yellow = "b2ffb2", "ffb2b2", "ffffb2"
    end

    if dodoDB.useFPSFrame == nil then dodoDB.useFPSFrame = true end
    update_fps_display()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_fps_display()
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.Minimap, {
        {
            name = "FPS/MS 표시",
            get = function() return dodoDB.useFPSFrame ~= false end,
            set = function(v) dodoDB.useFPSFrame = v; update_fps_display() end,
            disabled = function() return dodoDB and dodoDB.useMinimap == false end,
        }
    })
end
