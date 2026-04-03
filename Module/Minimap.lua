-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local GetInstanceInfo = GetInstanceInfo
local GetNetStats = GetNetStats
local format = string.format
local PlaySound = PlaySound
local C_Timer = C_Timer
local isZoomTimerRunning = false
local Minimap = Minimap
local textGreen = "44ff44"
local textRed = "ff4444"
local textYellow = "ffff44"

local function isIns()
    local _, instanceType, difficultyID = GetInstanceInfo()
    return (difficultyID == 8 or instanceType == "raid")
end

-- ==============================
-- 디스플레이
-- ==============================
-- 사각형 미니맵
Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
_G.GetMinimapShape = function() return "SQUARE" end

-- 기본 원형 테두리 제거
if _G.MinimapBorder then _G.MinimapBorder:Hide() end
if _G.MinimapBorderTop then _G.MinimapBorderTop:Hide() end
if _G.MinimapNorthTag then _G.MinimapNorthTag:Hide() end
if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Hide() end
if _G.MinimapBackdrop then _G.MinimapBackdrop:Hide() end

-- 사각형 테두리 (NineSlice)
local minimapBorder = CreateFrame("Frame", nil, Minimap, "NineSliceCodeTemplate")
local mapSize = Minimap:GetWidth()
if mapSize == 0 then mapSize = 198 end
minimapBorder:SetSize(mapSize, mapSize)
minimapBorder:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
minimapBorder:SetFrameLevel(Minimap:GetFrameLevel() + 5)

local layout = {
    TopLeftCorner     = { atlas = "UI-Frame-DiamondMetal-CornerTopLeft",     x = -8, y = 8  },
    TopRightCorner    = { atlas = "UI-Frame-DiamondMetal-CornerTopRight",    x = 8,  y = 8  },
    BottomLeftCorner  = { atlas = "UI-Frame-DiamondMetal-CornerBottomLeft",  x = -8, y = -8 },
    BottomRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomRight", x = 8,  y = -8 },
    TopEdge           = { atlas = "_UI-Frame-DiamondMetal-EdgeTop",    y = 8  },
    BottomEdge        = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom",  y = -8 },
    LeftEdge          = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft",   x = -8 },
    RightEdge         = { atlas = "!UI-Frame-DiamondMetal-EdgeRight",  x = 8  },
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

-- 상/하 엣지: 높이만 축소
local hEdges = { "TopEdge", "BottomEdge" }
for _, key in ipairs(hEdges) do
    local piece = minimapBorder[key]
    if piece then
        local _, h = piece:GetSize()
        piece:SetHeight(h * scale)
    end
end

-- 좌/우 엣지: 너비만 축소
local vEdges = { "LeftEdge", "RightEdge" }
for _, key in ipairs(vEdges) do
    local piece = minimapBorder[key]
    if piece then
        local w = piece:GetWidth()
        piece:SetWidth(w * scale)
    end
end

-- fps
local frame = CreateFrame("Frame", "fpsFrame", UIParent)
frame:SetSize(98, 16)
frame:Hide()

if MinimapCluster then
    frame:SetPoint("TOPLEFT", MinimapCluster.BorderTop, "BOTTOMLEFT", 0, -2)
end

local border = CreateFrame("Frame", nil, frame, "NineSliceCodeTemplate")
border:SetAllPoints(frame)
border.layoutType = "UniqueCornersLayout"
border.layoutTextureKit = "ui-hud-minimap-button"
NineSliceUtil.ApplyLayout(border, NineSliceUtil.GetLayout(border.layoutType), border.layoutTextureKit)

local text = border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("RIGHT", border, "RIGHT", -5, 0)
text:SetJustifyH("RIGHT")
frame.text = text

-- ==============================
-- 동작
-- ==============================
-- 미니맵 줌
local function resetMinimapZoom()
    if not dodoDB or dodoDB.useResetMinimapZoom == false then return end
    if isIns() or isZoomTimerRunning then return end

    isZoomTimerRunning = true

    C_Timer.After(10, function()
        isZoomTimerRunning = false

        if not isIns() and Minimap:GetZoom() ~= 0 then
            Minimap:SetZoom(0)
            PlaySound(113, "Master")
        end
    end)
end

-- fps
local elapsed = 0
local lastText = ""

local function OnUpdateHandler(self, delta)
    elapsed = elapsed + delta
    if elapsed < 1.0 then return end -- 1초마다 실행
    elapsed = 0

    local fps = GetFramerate()
    local _, _, latency = GetNetStats() -- home Latency
    -- local _, _, _, latency = GetNetStats() -- World Latency

    -- 색상 판정
    local fpsColor = (fps >= 60) and textGreen or (fps >= 30 and textYellow or textRed)
    local msColor = (latency <= 100) and textGreen or (latency <= 200 and textYellow or textRed)

    -- 문자열 생성
    local currentText = format("|cff%s%.0f|r fps | |cff%s%d|r ms", fpsColor, fps, msColor, latency)

    -- [핵심] 텍스트가 변했을 때만 UI 업데이트를 수행하여 CPU 부하 및 스터터링 방지
    if lastText ~= currentText then
        self.text:SetText(currentText)
        lastText = currentText
    end
end

local function UpdateFPSDisplay()
    local isEnabled = (dodoDB and dodoDB.useFPSFrame ~= false)
    if isEnabled then
        frame:Show()
        frame:SetScript("OnUpdate", OnUpdateHandler)
    else
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
    end
end

-- ==============================
-- 이벤트
-- ==============================
local initMinimap = CreateFrame("Frame")
initMinimap:RegisterEvent("ADDON_LOADED")

initMinimap:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("MINIMAP_UPDATE_ZOOM")
        UpdateFPSDisplay()
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HybridMinimap" then
        local HybridMinimap = _G.HybridMinimap
        if HybridMinimap then
            HybridMinimap:SetFrameStrata("BACKGROUND")
            HybridMinimap:SetFrameLevel(100)
            HybridMinimap.MapCanvas:SetUseMaskTexture(false)
            HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            HybridMinimap.MapCanvas:SetUseMaskTexture(true)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if isIns() then
            self:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
        else
            self:RegisterEvent("MINIMAP_UPDATE_ZOOM")
        end
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        resetMinimapZoom()
    end
end)

dodo.UpdateFPSDisplay = UpdateFPSDisplay
dodo.resetMinimapZoom = resetMinimapZoom
