-- ==============================
-- WorldMap 좌표 보강 모듈
-- Blizzard WorldMapCoordsPanel에 mapID + 소수 2자리 포맷 적용
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...

local PANEL_WIDTH = 160

-- ==============================
-- 캐싱
-- ==============================
local C_Map         = C_Map
local WorldMapFrame = WorldMapFrame
local format        = string.format
local issecretvalue = issecretvalue or function() return false end

-- ==============================
-- OnUpdate 후크 — 텍스트 포맷 덮어쓰기
-- ==============================
local function on_coords_update(self)
    local map_id = self:GetParent():GetMapID()

    if self.CursorCoords:IsShown() then
        local x, y = self:GetParent():GetNormalizedCursorPosition()
        if x and y and not issecretvalue(x) and not issecretvalue(y) then
            self.CursorCoords.Label:SetText(format("커서: [#%d] %.2f, %.2f", map_id, x * 100, y * 100))
        end
    end

    if self.PlayerCoords:IsShown() then
        local pos = C_Map.GetPlayerMapPosition(map_id, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and y and not issecretvalue(x) and not issecretvalue(y) then
                self.PlayerCoords.Label:SetText(format("플레이어: [#%d] %.2f, %.2f", map_id, x * 100, y * 100))
            end
        else
            -- 현재 보고 있는 맵과 플레이어 위치가 다를 때
            local player_map_id = C_Map.GetBestMapForUnit("player")
            if player_map_id then
                local actual_pos = C_Map.GetPlayerMapPosition(player_map_id, "player")
                if actual_pos then
                    local x, y = actual_pos:GetXY()
                    if x and y and not issecretvalue(x) and not issecretvalue(y) then
                        self.PlayerCoords.Label:SetText(format("플레이어: [#%d] %.2f, %.2f", player_map_id, x * 100, y * 100))
                    end
                end
            end
        end
    end
end

-- ==============================
-- 패널 탐색 및 초기화
-- ==============================
local function setup_coords_panel()
    if not WorldMapFrame.overlayFrames then return end
    for _, frame in ipairs(WorldMapFrame.overlayFrames) do
        if frame.CursorCoords and frame.PlayerCoords then
            frame:SetWidth(PANEL_WIDTH)
            frame.CursorCoords:SetWidth(PANEL_WIDTH)
            frame.PlayerCoords:SetWidth(PANEL_WIDTH)
            frame:HookScript("OnUpdate", on_coords_update)
            return
        end
    end
end

-- ==============================
-- 이벤트 핸들러
-- ==============================
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self)
    setup_coords_panel()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
