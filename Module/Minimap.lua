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

-- ==============================
-- 캐싱 (알파벳 순 정렬)
-- ==============================
local C_AddOns = C_AddOns
local C_Map = C_Map
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetFramerate = GetFramerate
local GetInstanceInfo = GetInstanceInfo
local GetNetStats = GetNetStats
local IsInInstance = IsInInstance
local Minimap = Minimap
local MinimapCluster = MinimapCluster
local NineSliceUtil = NineSliceUtil
local PlaySound = PlaySound
local WorldMapFrame = WorldMapFrame
local _G = _G
local format = string.format
local ipairs = ipairs
local issecretvalue = issecretvalue

local function GetMinimapShapeSquare() return "SQUARE" end

-- 원본 값 및 마스크 경로
local originalGetMinimapShape = _G.GetMinimapShape
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local ROUND_MASK  = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- UI 요소 프레임들
local minimapBorder = nil
local fpsFrame = nil
local coordFrame = nil
local worldMapCoordFrame = nil

-- Ticker 타이머들
local fpsTicker = nil
local coordTicker = nil

-- ==============================
-- 기능 1: 사각형 미니맵
-- ==============================
local function ApplyMinimapSquare()
    if not minimapBorder then return end
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
-- 기능 2: 미니맵 줌 초기화
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
-- 기능 3: FPS, 핑 표시
-- ==============================
local textGreen, textRed, textYellow = "44ff44", "ff4444", "ffff44"
local lastText = ""

local function UpdateFPSText()
    if not fpsFrame then return end
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

local function UpdateFPSDisplay()
    if not fpsFrame then return end
    local isEnabled = (dodoDB and dodoDB.useFPSFrame ~= false)
    if isEnabled then
        fpsFrame:Show()
        
        local inInstance = IsInInstance()
        local interval = inInstance and 2 or 1
        
        if fpsTicker then
            if fpsTicker._interval ~= interval then
                fpsTicker:Cancel()
                fpsTicker = nil
            end
        end
        
        if not fpsTicker then
            fpsTicker = C_Timer.NewTicker(interval, UpdateFPSText)
            fpsTicker._interval = interval
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
-- 기능 4: 좌표 표시 (인스턴스 예외 가드 및 월드맵 OnUpdate 가드)
-- ==============================
local function actual_worldmap_coords_update()
    if not worldMapCoordFrame then return end
    local mapID = WorldMapFrame:GetMapID()
    local playerMapID = C_Map.GetBestMapForUnit("player")

    local playerText = "Player: --"
    if playerMapID then
        local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if playerPos then
            local x, y = playerPos:GetXY()
            if x and y and not issecretvalue(x) and not issecretvalue(y) then
                playerText = format("Player: [#%d] %.2f, %.2f", playerMapID, x * 100, y * 100)
            else
                playerText = format("Player: [#%d] --, --", playerMapID)
            end
        else
            playerText = format("Player: [#%d] --, --", playerMapID)
        end
    end

    local cursorText = "Cursor: --"
    if mapID and WorldMapFrame.ScrollContainer:IsMouseOver() then
        local x, y = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if x and y and not issecretvalue(x) and not issecretvalue(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            cursorText = format("Cursor: [#%d] %.2f, %.2f", mapID, x * 100, y * 100)
        else
            cursorText = format("Cursor: [#%d] --, --", mapID)
        end
    end

    if worldMapCoordFrame.PlayerText then worldMapCoordFrame.PlayerText:SetText(playerText) end
    if worldMapCoordFrame.CursorText then worldMapCoordFrame.CursorText:SetText(cursorText) end
end

-- 수동 OnUpdate 시간 계산 가비지 프리 틱 처리
local elapsedTick = 0
local function update_worldmap_coords(self, elap)
    elapsedTick = elapsedTick + elap
    if elapsedTick >= 0.1 then
        elapsedTick = 0
        actual_worldmap_coords_update()
    end
end

local function update_coord_text()
    if not coordFrame then return end
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if playerMapID then
        local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if playerPos then
            local x, y = playerPos:GetXY()
            if x and y and not issecretvalue(x) and not issecretvalue(y) then
                coordFrame.text:SetText(format("%d, %d", x * 100, y * 100))
                return
            end
        end
    end
    coordFrame.text:SetText("--, --")
end

local function UpdateCoordDisplay()
    if not coordFrame then return end
    local isEnabled = (dodoDB and dodoDB.useCoord ~= false)
    local inInstance = IsInInstance()

    -- 1. 미니맵 좌표 가드 (인스턴스 내부에서는 작동 금지)
    if isEnabled and not inInstance then
        coordFrame:Show()
        if not coordTicker then
            coordTicker = C_Timer.NewTicker(0.5, update_coord_text)
        end
    else
        coordFrame:Hide()
        if coordTicker then
            coordTicker:Cancel()
            coordTicker = nil
        end
    end

    -- 2. 월드맵 좌표 표시 여부 제어
    if worldMapCoordFrame then
        if isEnabled then
            worldMapCoordFrame:Show()
        else
            worldMapCoordFrame:Hide()
        end
    end
end

-- ==============================
-- 초기화 및 UI 생성
-- ==============================
local function create_ui()
    if minimapBorder then return end

    -- 사각형 테두리 생성 (NineSlice)
    minimapBorder = CreateFrame("Frame", nil, Minimap, "NineSliceCodeTemplate")
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

    minimapBorder:Hide()

    -- FPS, 핑 표시 프레임 생성
    fpsFrame = CreateFrame("Frame", "dodoFPSFrame", UIParent)
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

    -- 플레이어 미니맵 좌표 프레임 생성
    coordFrame = CreateFrame("Frame", "dodoMinimapCoordFrame", UIParent)
    coordFrame:SetSize(52, 16)
    coordFrame:Hide()

    if MinimapCluster then
        coordFrame:SetPoint("TOPRIGHT", MinimapCluster.BorderTop, "BOTTOMRIGHT", 0, -2)
    end

    local coordBorder = CreateFrame("Frame", nil, coordFrame, "NineSliceCodeTemplate")
    coordBorder:SetAllPoints(coordFrame)
    coordBorder.layoutType = "UniqueCornersLayout"
    coordBorder.layoutTextureKit = "ui-hud-minimap-button"
    NineSliceUtil.ApplyLayout(coordBorder, NineSliceUtil.GetLayout(coordBorder.layoutType), coordBorder.layoutTextureKit)

    coordFrame.text = coordBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordFrame.text:SetPoint("CENTER", coordBorder, "CENTER", 0, 0)
    coordFrame.text:SetJustifyH("CENTER")

    -- 플레이어 월드맵 좌표 프레임 생성 (OnShow/OnHide 동적 틱 가드 적용)
    if not worldMapCoordFrame and WorldMapFrame then
        worldMapCoordFrame = CreateFrame("Frame", "dodoWorldMapCoordFrame", WorldMapFrame)
        worldMapCoordFrame:SetSize(200, 30)
        worldMapCoordFrame:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -40, 4)
        worldMapCoordFrame:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 1)

        local playerText = worldMapCoordFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        playerText:SetPoint("BOTTOMLEFT", worldMapCoordFrame, "BOTTOMLEFT", 0, 0)
        playerText:SetShadowOffset(0, 0)
        worldMapCoordFrame.PlayerText = playerText

        local cursorText = worldMapCoordFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        cursorText:SetPoint("BOTTOMLEFT", worldMapCoordFrame, "BOTTOMLEFT", 0, 16)
        cursorText:SetShadowOffset(0, 0)
        worldMapCoordFrame.CursorText = cursorText

        -- 월드맵 오픈 여부에 따른 동적 틱 제어 (리소스 절약)
        worldMapCoordFrame:SetScript("OnShow", function(self)
            self:SetScript("OnUpdate", update_worldmap_coords)
        end)
        worldMapCoordFrame:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            elapsedTick = 0
        end)
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function on_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        
        -- UI 미리 생성하여 사각형 마스크 적용 보장
        create_ui()

        if dodoDB.useCoord == nil then dodoDB.useCoord = true end

        -- 초기 상태 적용
        ApplyMinimapSquare()
        UpdateFPSDisplay()
        UpdateCoordDisplay()
        UpdateMinimapZoomReset()

        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("MINIMAP_UPDATE_ZOOM")

        -- Blizzard_HybridMinimap 로드 여부 체크
        if C_AddOns.IsAddOnLoaded("Blizzard_HybridMinimap") then
            local hm = _G.HybridMinimap
            if hm then
                hm:SetFrameStrata("BACKGROUND")
                hm:SetFrameLevel(100)
                hm.MapCanvas:SetUseMaskTexture(false)
                hm.CircleMask:SetTexture(SQUARE_MASK)
                hm.MapCanvas:SetUseMaskTexture(true)
            end
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_HybridMinimap" then
        local hm = _G.HybridMinimap
        if hm then
            hm:SetFrameStrata("BACKGROUND")
            hm:SetFrameLevel(100)
            hm.MapCanvas:SetUseMaskTexture(false)
            hm.CircleMask:SetTexture(SQUARE_MASK)
            hm.MapCanvas:SetUseMaskTexture(true)
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateMinimapZoomReset()
        UpdateFPSDisplay()
        UpdateCoordDisplay() -- 인던 내부 상태 체크
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
dodo.UpdateCoordDisplay   = UpdateCoordDisplay
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

    create_ui() -- 설정창 로딩 시 UI 생성 보장

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("미니맵"))
    Checkbox(category, "useMinimapSquare", "사각형 미니맵", "미니맵 모양을 사각형으로 변경하고 테두리를 적용합니다.", true, dodo.MinimapSquare)
    Checkbox(category, "useResetMinimapZoom", "미니맵 줌 초기화", "실외에서 일정 시간 후 미니맵 줌을 기본값(0)으로 자동 초기화합니다.", true, dodo.useResetMinimapZoom)
    Checkbox(category, "useFPSFrame", "미니맵 FPS/MS 표시", "미니맵 하단에 현재 FPS 및 지연 시간(ms)을 표시합니다.", true, dodo.UpdateFPSDisplay)
    Checkbox(category, "useCoord", "좌표 표시", "미니맵 우측 상단 및 월드맵 우측 하단에 좌표를 표시합니다.", true, dodo.UpdateCoordDisplay)
end)