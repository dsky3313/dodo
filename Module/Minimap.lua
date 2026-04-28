-- ==============================
-- Inspired
-- ==============================
-- Leatrix Plus (https://www.curseforge.com/wow/addons/leatrix-plus)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
-- 함수
local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local GetInstanceInfo = GetInstanceInfo
local GetNetStats = GetNetStats
local format = string.format
local PlaySound = PlaySound

-- 변수
local C_Timer = C_Timer
local Minimap = Minimap

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
        _G.GetMinimapShape = function() return "SQUARE" end
        if _G.MinimapBorder then _G.MinimapBorder:Hide() end
        if _G.MinimapBorderTop then _G.MinimapBorderTop:Hide() end
        if _G.MinimapNorthTag then _G.MinimapNorthTag:Hide() end
        if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Hide() end
        if _G.MinimapBackdrop then _G.MinimapBackdrop:Hide() end

        local hm = _G.HybridMinimap
        if hm and hm.CircleMask then hm.CircleMask:SetTexture(SQUARE_MASK) end
        minimapBorder:Show()
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
        minimapBorder:Hide()
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

local function resetMinimapZoom()
    if not dodoDB or dodoDB.useResetMinimapZoom == false then return end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if difficultyID == 8 or instanceType == "raid" then return end
    if isZoomTimerRunning then return end

    isZoomTimerRunning = true

    C_Timer.After(10, function()
        isZoomTimerRunning = false
        local _, iType, dID = GetInstanceInfo()
        if not (dID == 8 or iType == "raid") and Minimap:GetZoom() ~= 0 then
            Minimap:SetZoom(0)
            PlaySound(113, "Master")
        end
    end)
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

-- 업데이트 핸들러
local function OnUpdateHandler(self, delta)
    elapsed = elapsed + delta
    if elapsed < 1.0 then return end
    elapsed = 0

    local fps = GetFramerate()
    local _, _, latency = GetNetStats()
    local fpsColor = (fps >= 60) and textGreen or (fps >= 30 and textYellow or textRed)
    local msColor = (latency <= 100) and textGreen or (latency <= 200 and textYellow or textRed)

    local currentText = format("|cff%s%.0f|r fps | |cff%s%d|r ms", fpsColor, fps, msColor, latency)
    if lastText ~= currentText then
        self.text:SetText(currentText)
        lastText = currentText
    end
end

-- 토글 함수
local function UpdateFPSDisplay()
    local isEnabled = (dodoDB and dodoDB.useFPSFrame ~= false)
    if isEnabled then
        fpsFrame:Show()
        fpsFrame:SetScript("OnUpdate", OnUpdateHandler)
    else
        fpsFrame:Hide()
        fpsFrame:SetScript("OnUpdate", nil)
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
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        resetMinimapZoom()
    end
end)

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================
dodo.UpdateFPSDisplay     = UpdateFPSDisplay
dodo.useResetMinimapZoom  = UpdateMinimapZoomReset
dodo.MinimapSquare        = ApplyMinimapSquare