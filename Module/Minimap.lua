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
local module = {}
dodo:RegisterModule("Minimap", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

-- 원본 값 및 마스크 경로
local originalGetMinimapShape = _G.GetMinimapShape
local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local ROUND_MASK  = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function get_minimap_shape_square() return "SQUARE" end

-- ==============================
-- 프레임 및 이벤트 핸들러 정의
-- ==============================
local fpsFrame
local fpsTicker
local initMinimap
local minimapBorder

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local format = string.format
local GetFramerate = GetFramerate
local GetInstanceInfo = GetInstanceInfo
local GetNetStats = GetNetStats
local ipairs = ipairs
local IsInInstance = IsInInstance
local issecretvalue = issecretvalue or function() return false end
local Minimap = Minimap
local MinimapCluster = MinimapCluster
local NineSliceUtil = NineSliceUtil
local PlaySound = PlaySound
local UIParent = UIParent
local _G = _G

-- ==============================
-- 기능 1: 사각형 미니맵
-- ==============================
-- 사각형 미니맵 적용 함수
local function apply_minimap_square()
    if not minimapBorder then return end
    local isEnabled = (dodo.DB and dodo.DB.enableMinimapModule ~= false and dodo.DB.useMinimapSquare ~= false)
    if isEnabled then
        Minimap:SetMaskTexture(SQUARE_MASK)
        _G.GetMinimapShape = get_minimap_shape_square
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
local function update_minimap_zoom_reset()
    if not initMinimap then return end
    local isEnabled = (dodo.DB and dodo.DB.enableMinimapModule ~= false and dodo.DB.useResetMinimapZoom ~= false)
    local _, instanceType, difficultyID = GetInstanceInfo()
    local inInstance = (difficultyID == 8 or instanceType == "raid")

    if isEnabled and not inInstance then
        initMinimap:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    else
        initMinimap:UnregisterEvent("MINIMAP_UPDATE_ZOOM")
    end
end

local isZoomTimerRunning = false
local function reset_minimap_zoom()
    if not dodo.DB or dodo.DB.enableMinimapModule == false or dodo.DB.useResetMinimapZoom == false then return end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if difficultyID == 8 or instanceType == "raid" then return end
    if isZoomTimerRunning then return end

    isZoomTimerRunning = true

    C_Timer.After(10, function()
        isZoomTimerRunning = false
        local _, iType, dID = GetInstanceInfo()
        if not (dID == 8 or iType == "raid") then
            local currentZoom = Minimap:GetZoom()
            if not issecretvalue(currentZoom) and currentZoom ~= 0 then
                Minimap:SetZoom(0)
                PlaySound(113, "Master")
            end
        end
    end)
end

-- ==============================
-- 기능 3: FPS/지연 시간 표시
-- ==============================
local textGreen, textRed, textYellow = "44ff44", "ff4444", "ffff44"
local lastText = ""

local function update_fps_text()
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

local function update_fps_display()
    if not fpsFrame then return end
    local isEnabled = (dodo.DB and dodo.DB.enableMinimapModule ~= false and dodo.DB.useFPSFrame ~= false)
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
            fpsTicker = C_Timer.NewTicker(interval, update_fps_text)
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
-- 모듈 On/Off 활성화 상태 제어
-- ==============================
local function update_module_state()
    apply_minimap_square()
    update_fps_display()
    
    local enabled = (dodo.DB and dodo.DB.enableMinimapModule ~= false)
    if enabled then
        if initMinimap then
            initMinimap:RegisterEvent("ADDON_LOADED")
            initMinimap:RegisterEvent("PLAYER_ENTERING_WORLD")
            update_minimap_zoom_reset()
        end
    else
        if initMinimap then
            initMinimap:UnregisterAllEvents()
        end
    end
end

dodo.UpdateMinimapModuleState = update_module_state

-- ==============================
-- 초기화
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

    minimapBorder:Hide() -- 기본 숨김

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

    -- zoom 리셋용 프레임 생성
    initMinimap = CreateFrame("Frame")
end

local function initialize()
    create_ui()
end

local function update_feature()
    apply_minimap_square()
    update_fps_display()
    update_minimap_zoom_reset()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
function module:OnEnable()
    initialize()
    update_feature()
    update_module_state()

    -- zoom 리셋용 프레임 스크립트 연결
    initMinimap:SetScript("OnEvent", function(self, event, arg1)
        if dodo.DB and dodo.DB.enableMinimapModule == false then return end
        if event == "ADDON_LOADED" and arg1 == "Blizzard_HybridMinimap" then
            local hm = _G.HybridMinimap
            if hm then
                hm:SetFrameStrata("BACKGROUND")
                hm:SetFrameLevel(100)
                hm.MapCanvas:SetUseMaskTexture(false)
                hm.CircleMask:SetTexture(SQUARE_MASK) -- 하이브리드 미니맵 초기 마스크
                hm.MapCanvas:SetUseMaskTexture(true)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            update_minimap_zoom_reset()
            update_fps_display() -- 인스턴스 상태에 따라 Ticker 간격 재조정
        elseif event == "MINIMAP_UPDATE_ZOOM" then
            reset_minimap_zoom()
        end
    end)

    -- LibEditMode 등록
    if LibEditMode then
        local settingType = LibEditMode.SettingType
        local minimapSystem = Enum.EditModeSystem.Minimap or 2

        LibEditMode:AddSystemSettings(minimapSystem, {
            {
                kind = settingType.Checkbox,
                name = "사각형 미니맵",
                desc = "미니맵을 사각형으로 변경합니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useMinimapSquare ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useMinimapSquare = newValue end
                    if dodo.DB and dodo.DB.enableMinimapModule ~= false then
                        apply_minimap_square()
                    end
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "미니맵 줌 초기화",
                desc = "미니맵 줌 조작 후 10초가 지나면 자동으로 가장 넓은 시야로 초기화합니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useResetMinimapZoom ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useResetMinimapZoom = newValue end
                    if dodo.DB and dodo.DB.enableMinimapModule ~= false then
                        update_minimap_zoom_reset()
                    end
                end,
            },
            {
                kind = settingType.Checkbox,
                name = "FPS, 핑 표시",
                desc = "미니맵 상단에 현재 프레임(FPS)과 지연 시간(ms)을 표시합니다.",
                default = true,
                get = function()
                    return (dodo.DB and dodo.DB.useFPSFrame ~= false)
                end,
                set = function(_, newValue)
                    if dodo.DB then dodo.DB.useFPSFrame = newValue end
                    if dodo.DB and dodo.DB.enableMinimapModule ~= false then
                        update_fps_display()
                    end
                end,
            },
        })
    end
end