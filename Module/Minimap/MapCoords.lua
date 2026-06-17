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
local init_frame = nil

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
    local map_id = WorldMapFrame:GetMapID()
    local player_map_id = C_Map.GetBestMapForUnit("player")

    local player_text = "Player: --"
    if player_map_id then
        local player_pos = C_Map.GetPlayerMapPosition(player_map_id, "player")
        if player_pos then
            local x, y = player_pos:GetXY()
            if x and y and not issecretvalue(x) and not issecretvalue(y) then
                player_text = format("Player: [#%d] %.2f, %.2f", player_map_id, x * 100, y * 100)
            else
                player_text = format("Player: [#%d] --, --", player_map_id)
            end
        else
            player_text = format("Player: [#%d] --, --", player_map_id)
        end
    end

    local cursor_text = "Cursor: --"
    if map_id and WorldMapFrame.ScrollContainer:IsMouseOver() then
        local x, y = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if x and y and not issecretvalue(x) and not issecretvalue(y) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            cursor_text = format("Cursor: [#%d] %.2f, %.2f", map_id, x * 100, y * 100)
        else
            cursor_text = format("Cursor: [#%d] --, --", map_id)
        end
    end

    if world_map_coord_frame.player_text then world_map_coord_frame.player_text:SetText(player_text) end
    if world_map_coord_frame.cursor_text then world_map_coord_frame.cursor_text:SetText(cursor_text) end
end

local function update_worldmap_coords(self, elap)
    elapsed_tick = elapsed_tick + elap
    if elapsed_tick >= 0.1 then
        elapsed_tick = 0
        actual_worldmap_coords_update()
    end
end

local function on_worldmap_show(self)
    self:SetScript("OnUpdate", update_worldmap_coords)
end

local function on_worldmap_hide(self)
    self:SetScript("OnUpdate", nil)
    elapsed_tick = 0
end

-- ==============================
-- 미니맵 좌표 로직
-- ==============================
local function update_coord_text()
    if not coord_frame then return end
    local player_map_id = C_Map.GetBestMapForUnit("player")
    if player_map_id then
        local player_pos = C_Map.GetPlayerMapPosition(player_map_id, "player")
        if player_pos then
            local x, y = player_pos:GetXY()
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

    local coord_border = CreateFrame("Frame", nil, coord_frame, "NineSliceCodeTemplate")
    coord_border:SetAllPoints(coord_frame)
    coord_border.layoutType = "UniqueCornersLayout"
    coord_border.layoutTextureKit = "ui-hud-minimap-button"
    NineSliceUtil.ApplyLayout(coord_border, NineSliceUtil.GetLayout(coord_border.layoutType), coord_border.layoutTextureKit)

    coord_frame.text = coord_border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coord_frame.text:SetPoint("CENTER", coord_border, "CENTER", 0, 0)
    coord_frame.text:SetJustifyH("CENTER")

    -- 월드맵 좌표 프레임
    if not world_map_coord_frame and WorldMapFrame then
        world_map_coord_frame = CreateFrame("Frame", "dodoWorldMapCoordFrame", WorldMapFrame)
        world_map_coord_frame:SetSize(200, 30)
        world_map_coord_frame:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -40, 4)
        world_map_coord_frame:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 1)

        local player_text = world_map_coord_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        player_text:SetPoint("BOTTOMLEFT", world_map_coord_frame, "BOTTOMLEFT", 0, 0)
        player_text:SetShadowOffset(0, 0)
        world_map_coord_frame.player_text = player_text

        local cursor_text = world_map_coord_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
        cursor_text:SetPoint("BOTTOMLEFT", world_map_coord_frame, "BOTTOMLEFT", 0, 16)
        cursor_text:SetShadowOffset(0, 0)
        world_map_coord_frame.cursor_text = cursor_text

        world_map_coord_frame:SetScript("OnShow", on_worldmap_show)
        world_map_coord_frame:SetScript("OnHide", on_worldmap_hide)
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

    if is_enabled then
        if init_frame then init_frame:RegisterEvent("PLAYER_ENTERING_WORLD") end
        if not in_instance then
            coord_frame:Show()
            if not coord_ticker then
                coord_ticker = C_Timer.NewTicker(0.5, update_coord_text)
            end
        else
            coord_frame:Hide()
            if coord_ticker then coord_ticker:Cancel() coord_ticker = nil end
        end
    else
        if init_frame then init_frame:UnregisterEvent("PLAYER_ENTERING_WORLD") end
        coord_frame:Hide()
        if coord_ticker then coord_ticker:Cancel() coord_ticker = nil end
    end

    if world_map_coord_frame then
        if is_enabled then
            world_map_coord_frame:Show()
        else
            world_map_coord_frame:Hide()
        end
    end
end

dodo.UpdateMinimapCoordState = update_coord_display

-- ==============================
-- 이벤트 핸들러
-- ==============================
local function initialize()
    if dodoDB.useCoord == nil then dodoDB.useCoord = true end
    update_coord_display()
end

local function on_event(self, event)
    if event == "PLAYER_LOGIN" then
        initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_coord_display()
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
            name = "좌표 표시",
            get = function() return dodoDB.useCoord ~= false end,
            set = function(v) dodoDB.useCoord = v; update_coord_display() end,
            disabled = function() return dodoDB and dodoDB.useMinimap == false end,
        }
    })
end
