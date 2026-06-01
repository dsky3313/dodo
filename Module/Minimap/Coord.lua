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

local coord_frame = nil
local world_map_coord_frame = nil
local coord_ticker = nil
local elapsed_tick = 0

-- ==============================
-- 캐싱
-- ==============================
local C_Map = C_Map
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local MinimapCluster = MinimapCluster
local NineSliceUtil = NineSliceUtil
local WorldMapFrame = WorldMapFrame
local format = string.format
local issecretvalue = issecretvalue or function() return false end

-- ==============================
-- 월드맵 좌표 로직
-- ==============================
local function actual_worldmap_coords_update()
    if not world_map_coord_frame then return end
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

    if world_map_coord_frame.PlayerText then world_map_coord_frame.PlayerText:SetText(playerText) end
    if world_map_coord_frame.CursorText then world_map_coord_frame.CursorText:SetText(cursorText) end
end

local function update_worldmap_coords(self, elap)
    elapsed_tick = elapsed_tick + elap
    if elapsed_tick >= 0.1 then
        elapsed_tick = 0
        actual_worldmap_coords_update()
    end
end

-- ==============================
-- 미니맵 좌표 로직
-- ==============================
local function update_coord_text()
    if not coord_frame then return end
    local playerMapID = C_Map.GetBestMapForUnit("player")
    if playerMapID then
        local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if playerPos then
            local x, y = playerPos:GetXY()
            if x and y and not issecretvalue(x) and not issecretvalue(y) then
                coord_frame.text:SetText(format("%d, %d", x * 100, y * 100))
                return
            end
        end
    end
    coord_frame.text:SetText("--, --")
end

-- ==============================
-- UI 생성
-- ==============================
local function create_ui()
    if coord_frame then return end

    -- 미니맵 좌표 프레임
    coord_frame = CreateFrame("Frame", "dodoMinimapCoordFrame", MinimapCluster)
    coord_frame:SetSize(52, 16)
    coord_frame:Hide()

    if MinimapCluster then
        coord_frame:SetPoint("TOPRIGHT", MinimapCluster.BorderTop, "BOTTOMRIGHT", 0, -2)
    end

    local coordBorder = CreateFrame("Frame", nil, coord_frame, "NineSliceCodeTemplate")
    coordBorder:SetAllPoints(coord_frame)
    coordBorder.layoutType = "UniqueCornersLayout"
    coordBorder.layoutTextureKit = "ui-hud-minimap-button"
    NineSliceUtil.ApplyLayout(coordBorder, NineSliceUtil.GetLayout(coordBorder.layoutType), coordBorder.layoutTextureKit)

    coord_frame.text = coordBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coord_frame.text:SetPoint("CENTER", coordBorder, "CENTER", 0, 0)
    coord_frame.text:SetJustifyH("CENTER")

    -- 월드맵 좌표 프레임
    if not world_map_coord_frame and WorldMapFrame then
        world_map_coord_frame = CreateFrame("Frame", "dodoWorldMapCoordFrame", WorldMapFrame)
        world_map_coord_frame:SetSize(200, 30)
        world_map_coord_frame:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -40, 4)
        world_map_coord_frame:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 1)

        local playerText = world_map_coord_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        playerText:SetPoint("BOTTOMLEFT", world_map_coord_frame, "BOTTOMLEFT", 0, 0)
        playerText:SetShadowOffset(0, 0)
        world_map_coord_frame.PlayerText = playerText

        local cursorText = world_map_coord_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        cursorText:SetPoint("BOTTOMLEFT", world_map_coord_frame, "BOTTOMLEFT", 0, 16)
        cursorText:SetShadowOffset(0, 0)
        world_map_coord_frame.CursorText = cursorText

        world_map_coord_frame:SetScript("OnShow", function(self)
            self:SetScript("OnUpdate", update_worldmap_coords)
        end)
        world_map_coord_frame:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            elapsed_tick = 0
        end)
    end
end

-- ==============================
-- 상태 업데이트
-- ==============================
local function update_coord_display()
    create_ui()
    if not coord_frame then return end

    local is_enabled = (dodoDB and dodoDB.useMinimap ~= false and dodoDB.useCoord ~= false)
    local in_instance = IsInInstance()

    if is_enabled and not in_instance then
        coord_frame:Show()
        if not coord_ticker then
            coord_ticker = C_Timer.NewTicker(0.5, update_coord_text)
        end
    else
        coord_frame:Hide()
        if coord_ticker then
            coord_ticker:Cancel()
            coord_ticker = nil
        end
    end

    if world_map_coord_frame then
        if is_enabled then
            world_map_coord_frame:Show()
        else
            world_map_coord_frame:Hide()
        end
    end
end

dodo.UpdateCoordDisplay = update_coord_display
dodo.UpdateMinimapCoordState = update_coord_display

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if dodoDB.useCoord == nil then dodoDB.useCoord = true end
        update_coord_display()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_coord_display()
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.Minimap, {
        {
            name = "좌표 표시",
            get = function() return dodoDB.useCoord ~= false end,
            set = function(v) dodoDB.useCoord = v; update_coord_display() end,
            disabled = function() return dodoDB and dodoDB.useMinimap == false end,
        }
    })
end
