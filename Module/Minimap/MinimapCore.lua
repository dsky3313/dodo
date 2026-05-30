-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame

-- ==============================
-- 전체 상태 제어 및 초기화
-- ==============================
local function update_minimap_state()
    if dodo.UpdateMinimapSquareState then
        dodo.UpdateMinimapSquareState()
    end
    if dodo.UpdateMinimapZoomState then
        dodo.UpdateMinimapZoomState()
    end
    if dodo.UpdateMinimapFPSState then
        dodo.UpdateMinimapFPSState()
    end
    if dodo.UpdateMinimapCoordState then
        dodo.UpdateMinimapCoordState()
    end
end

dodo.Minimap = update_minimap_state

local function initialize()
    if dodoDB.useMinimap == nil then dodoDB.useMinimap = true end
    update_minimap_state()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    initialize()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "미니맵",
            get = function() return dodoDB and dodoDB.useMinimap ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useMinimap = checked end
                update_minimap_state()
            end
        }
    })
end
