-- ==============================
-- Minimap 좌표 모듈
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local coord_frame  = nil
local coord_ticker = nil
local init_frame   = nil

-- ==============================
-- 캐싱
-- ==============================
local C_Map          = C_Map
local C_Timer        = C_Timer
local CreateFrame    = CreateFrame
local IsInInstance   = IsInInstance
local MinimapCluster = MinimapCluster
local NineSliceUtil  = NineSliceUtil
local format         = string.format
local issecretvalue  = issecretvalue or function() return false end

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

    coord_frame = CreateFrame("Frame", "dodoMinimapCoordFrame", MinimapCluster)
    coord_frame:SetSize(52, 16)
    coord_frame:Hide()

    if MinimapCluster then
        coord_frame:SetPoint("TOPRIGHT", MinimapCluster.BorderTop, "BOTTOMRIGHT", 0, -2)
    end

    local coord_border = CreateFrame("Frame", nil, coord_frame, "NineSliceCodeTemplate")
    coord_border:SetAllPoints(coord_frame)
    coord_border.layoutType        = "UniqueCornersLayout"
    coord_border.layoutTextureKit  = "ui-hud-minimap-button"
    NineSliceUtil.ApplyLayout(coord_border, NineSliceUtil.GetLayout(coord_border.layoutType), coord_border.layoutTextureKit)

    coord_frame.text = coord_border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coord_frame.text:SetPoint("CENTER", coord_border, "CENTER", 0, 0)
    coord_frame.text:SetJustifyH("CENTER")
end

-- ==============================
-- 상태 업데이트
-- ==============================
local function update_coord_display()
    create_ui()
    if not coord_frame then return end

    local is_enabled  = (dodoDB and dodoDB.useCoord ~= false)
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
            if coord_ticker then coord_ticker:Cancel(); coord_ticker = nil end
        end
    else
        if init_frame then init_frame:UnregisterEvent("PLAYER_ENTERING_WORLD") end
        coord_frame:Hide()
        if coord_ticker then coord_ticker:Cancel(); coord_ticker = nil end
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

