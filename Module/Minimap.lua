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

local C_Timer = C_Timer
local CreateFrame = CreateFrame
local format = string.format
local GetFramerate = GetFramerate
local GetInstanceInfo = GetInstanceInfo
local GetNetStats = GetNetStats
local issecretvalue = issecretvalue
local Minimap = Minimap
local MinimapCluster = MinimapCluster
local NineSliceUtil = NineSliceUtil
local PlaySound = PlaySound
local _G = _G

local function GetMinimapShapeSquare() return "SQUARE" end

-- ==============================
-- 사각형 미니맵
-- ==============================
-- 원본 값 및 마스크 경로
local originalGetMinimapShape = _G.GetMinimapShape
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local ROUND_MASK  = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- 사각형 테두리 생성 (NineSlice)
local minimapBorder = CreateFrame("Frame", nil, Minimap, "NineSliceCodeTemplate")
local mapSize = Minimap:GetWidth()
if mapSize == 0 then mapSize = 198 end
minimapBorder:SetSize(mapSize, mapSize)
minimapBorder:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
minimapBorder:SetFrameLevel(Minimap:GetFrameLevel() + 5)

local layout = {
    TopLeftCorner     = { atlas = "UI-HUD-ActionBar-Frame-NineSlice-CornerTopLeft",     x = -4, y = 4  },
    TopRightCorner    = { atlas = "UI-HUD-ActionBar-Frame-NineSlice-CornerTopRight",    x = 4,  y = 4  },
    BottomLeftCorner  = { atlas = "UI-HUD-ActionBar-Frame-NineSlice-CornerBottomLeft",  x = -4, y = -4 },
    BottomRightCorner = { atlas = "UI-HUD-ActionBar-Frame-NineSlice-CornerBottomRight", x = 4,  y = -4 },
    TopEdge           = { atlas = "_UI-HUD-ActionBar-Frame-NineSlice-EdgeTop",    y = 4  },
    BottomEdge        = { atlas = "_UI-HUD-ActionBar-Frame-NineSlice-EdgeBottom",  y = -4 },
    LeftEdge          = { atlas = "!UI-HUD-ActionBar-Frame-NineSlice-EdgeLeft",   x = -4 },
    RightEdge         = { atlas = "!UI-HUD-ActionBar-Frame-NineSlice-EdgeRight",  x = 4  },
}

NineSliceUtil.ApplyLayout(minimapBorder, layout)

local scale = 0.8
local corners = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
for _, key in ipairs(corners) do
    local piece = minimapBorder[key]
    if piece then
        local w, h = piece:GetSize()
        piece:SetSize(w * scale, h * scale)
    end
end

local hEdges = { "TopEdge", "BottomEdge" }
for _, key in ipairs(hEdges) do
    local piece = minimapBorder[key]
    if piece then
        local _, h = piece:GetSize()
        piece:SetHeight(h * scale)
    end
end

local vEdges = { "LeftEdge", "RightEdge" }
for _, key in ipairs(vEdges) do
    local piece = minimapBorder[key]
    if piece then
        local w = piece:GetWidth()
        piece:SetWidth(w * scale)
    end
end

minimapBorder:Hide() -- 기본 숨김

-- 사각형 미니맵 적용 함수
local function ApplyMinimapSquare()
    local isEnabled = (dodoDB and dodoDB.useMinimapSquare ~= false)
    if isEnabled then
        Minimap:SetMaskTexture(SQUARE_MASK)
        _G.GetMinimapShape = GetMinimapShapeSquare
        if _G.MinimapBorder then _G.MinimapBorder:Hide() end
        if _G.MinimapBorderTop then _G.MinimapBorderTop:Hide() end
        if _G.MinimapNorthTag then _G.MinimapNorthTag:Hide() end
        if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Hide() end
        if _G.MinimapBackdrop then _G.MinimapBackdrop:Hide() end

        local hm = _G.HybridMinimap
        if hm and hm.CircleMask then hm.CircleMask:SetTexture(SQUARE_MASK) end
        if not minimapBorder:IsShown() then minimapBorder:Show() end
    else
        Minimap:SetMaskTexture(ROUND_MASK)
        _G.GetMinimapShape = originalGetMinimapShape
        if _G.MinimapBorder then _G.MinimapBorder:Show() end
        if _G.MinimapBorderTop then _G.MinimapBorderTop:Show() end
        if _G.MinimapNorthTag then _G.MinimapNorthTag:Show() end
        if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Show() end
        if _G.MinimapBackdrop then _G.MinimapBackdrop:Show() end

        local hm = _G.HybridMinimap
        if hm and hm.CircleMask then hm.CircleMask:SetTexture(ROUND_MASK) end
        if minimapBorder:IsShown() then minimapBorder:Hide() end
    end
end

-- ==============================
-- 미니맵 줌 초기화
-- ==============================
local function UpdateMinimapZoomReset()
    if not initMinimap then return end
    local isEnabled = (dodoDB and dodoDB.useResetMinimapZoom ~= false)
    local _, instanceType, difficultyID = GetInstanceInfo()
    local inInstance = (difficultyID == 8 or instanceType == "raid")

    if isEnabled and not inInstance then
        initMinimap:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    else
        initMinimap:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
    end
end

local isZoomTimerRunning = false

local function on_zoom_timer_tick()
    isZoomTimerRunning = false
    local _, iType, dID = GetInstanceInfo()
    if not (dID == 8 or iType == "raid") then
        local currentZoom = Minimap:GetZoom()
        if not issecretvalue(currentZoom) and currentZoom ~= 0 then
            Minimap:SetZoom(0)
            PlaySound(113, "Master")
        end
    end
end

local function resetMinimapZoom()
    if not dodoDB or dodoDB.useResetMinimapZoom == false then return end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if difficultyID == 8 or instanceType == "raid" then return end
    if isZoomTimerRunning then return end

    isZoomTimerRunning = true
    C_Timer.After(10, on_zoom_timer_tick)
end

-- ==============================
-- FPS, 핑 표시
-- ==============================
local textGreen, textRed, textYellow = "44ff44", "ff4444", "ffff44"
local lastText = ""
local elapsed = 0

-- 프레임 생성
local fpsFrame = CreateFrame("Frame", "dodoFPSFrame", UIParent)
fpsFrame:SetSize(98, 16)
fpsFrame:Hide()

if MinimapCluster then
    fpsFrame:SetPoint("TOPLEFT", MinimapCluster.BorderTop, "BOTTOMLEFT", 0, -2)
end

local border = CreateFrame("Frame", nil, fpsFrame, "NineSliceCodeTemplate")
border:SetAllPoints(fpsFrame)
border.layoutType = "UniqueCornersLayout"
border.layoutTextureKit = "ui-hud-minimap-button"
NineSliceUtil.ApplyLayout(border, NineSliceUtil.GetLayout(border.layoutType), border.layoutTextureKit)

fpsFrame.text = border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpsFrame.text:SetPoint("RIGHT", border, "RIGHT", -5, 0)
fpsFrame.text:SetJustifyH("RIGHT")

-- 업데이트 함수
local function UpdateFPSText()
    local fps = GetFramerate()
    local _, _, latency = GetNetStats()
    local fpsColor = (fps >= 60) and textGreen or (fps >= 30 and textYellow or textRed)
    local msColor = (latency <= 100) and textGreen or (latency <= 200 and textYellow or textRed)

    local currentText = format("|cff%s%.0f|r fps | |cff%s%d|r ms", fpsColor, fps, msColor, latency)
    if lastText ~= currentText then
        fpsFrame.text:SetText(currentText)
        lastText = currentText
    end
end

local fpsTicker

-- 토글 함수
local function UpdateFPSDisplay()
    local isEnabled = (dodoDB and dodoDB.useFPSFrame ~= false)
    if isEnabled then
        fpsFrame:Show()
        
        -- 인스턴스 여부에 따른 간격 결정 (인스턴스 내부 2초, 외부 1초)
        local inInstance = IsInInstance()
        local interval = inInstance and 2 or 1
        
        -- 기존 Ticker가 있고 간격이 다르면 취소 후 재생성
        if fpsTicker then
            if fpsTicker._interval ~= interval then
                fpsTicker:Cancel()
                fpsTicker = nil
            end
        end
        
        if not fpsTicker then
            fpsTicker = C_Timer.NewTicker(interval, UpdateFPSText)
            fpsTicker._interval = interval -- 현재 간격 저장
        end
    else
        fpsFrame:Hide()
        if fpsTicker then
            fpsTicker:Cancel()
            fpsTicker = nil
        end
    end
end

-- ==============================
-- 이벤트
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("MINIMAP_UPDATE_ZOOM")

        -- 초기 상태 적용
        ApplyMinimapSquare()
        UpdateFPSDisplay()
        UpdateMinimapZoomReset()

    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HybridMinimap" then
        local hm = _G.HybridMinimap
        if hm then
            hm:SetFrameStrata("BACKGROUND")
            hm:SetFrameLevel(100)
            hm.MapCanvas:SetUseMaskTexture(false)
            hm.CircleMask:SetTexture(SQUARE_MASK) -- 하이브리드 미니맵 초기 마스크
            hm.MapCanvas:SetUseMaskTexture(true)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateMinimapZoomReset()
        UpdateFPSDisplay() -- 인스턴스 상태에 따라 Ticker 간격 재조정
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        resetMinimapZoom()
    end
end

local initMinimap = CreateFrame("Frame")
initMinimap:RegisterEvent("ADDON_LOADED")
initMinimap:SetScript("OnEvent", on_event)

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
dodo.UpdateFPSDisplay     = UpdateFPSDisplay
dodo.useResetMinimapZoom  = UpdateMinimapZoomReset
dodo.MinimapSquare        = ApplyMinimapSquare

local SettingsPanel = SettingsPanel
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["minimap"] = dodo.OptionRegistrations["minimap"] or {}
table.insert(dodo.OptionRegistrations["minimap"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("미니맵"))
    Checkbox(category, "useMinimapSquare", "사각형 미니맵", "미니맵 모양을 사각형으로 변경하고 테두리를 적용합니다.", true, dodo.MinimapSquare)
    Checkbox(category, "useResetMinimapZoom", "미니맵 줌 초기화", "실외에서 일정 시간 후 미니맵 줌을 기본값(0)으로 자동 초기화합니다.", true, dodo.useResetMinimapZoom)
    Checkbox(category, "useFPSFrame", "미니맵 FPS/MS 표시", "미니맵 하단에 현재 FPS 및 지연 시간(ms)을 표시합니다.", true, dodo.UpdateFPSDisplay)
end)