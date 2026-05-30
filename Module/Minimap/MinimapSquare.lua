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

local function get_minimap_shape_square() return "SQUARE" end

local original_get_minimap_shape = _G.GetMinimapShape
local square_mask = "Interface\\BUTTONS\\WHITE8X8"
local round_mask  = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local minimap_border = nil

-- ==============================
-- 캐싱
-- ==============================
local C_AddOns = C_AddOns
local CreateFrame = CreateFrame
local Minimap = Minimap
local NineSliceUtil = NineSliceUtil
local _G = _G
local ipairs = ipairs

-- ==============================
-- UI 생성
-- ==============================
local function create_ui()
    if minimap_border then return end

    minimap_border = CreateFrame("Frame", nil, Minimap, "NineSliceCodeTemplate")
    local mapSize = Minimap:GetWidth()
    if mapSize == 0 then mapSize = 198 end
    minimap_border:SetSize(mapSize, mapSize)
    minimap_border:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    minimap_border:SetFrameLevel(Minimap:GetFrameLevel() + 5)

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

    NineSliceUtil.ApplyLayout(minimap_border, layout)

    local scale = 0.8
    local corners = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
    for _, key in ipairs(corners) do
        local piece = minimap_border[key]
        if piece then
            local w, h = piece:GetSize()
            piece:SetSize(w * scale, h * scale)
        end
    end

    local hEdges = { "TopEdge", "BottomEdge" }
    for _, key in ipairs(hEdges) do
        local piece = minimap_border[key]
        if piece then
            local _, h = piece:GetSize()
            piece:SetHeight(h * scale)
        end
    end

    local vEdges = { "LeftEdge", "RightEdge" }
    for _, key in ipairs(vEdges) do
        local piece = minimap_border[key]
        if piece then
            local w = piece:GetWidth()
            piece:SetWidth(w * scale)
        end
    end

    minimap_border:Hide()
end

-- ==============================
-- 상태 업데이트
-- ==============================
local function apply_minimap_square()
    create_ui()
    if not minimap_border then return end

    local is_enabled = (dodoDB and dodoDB.useMinimap ~= false and dodoDB.useMinimapSquare ~= false)
    if is_enabled then
        Minimap:SetMaskTexture(square_mask)
        _G.GetMinimapShape = get_minimap_shape_square
        if _G.MinimapBorder then _G.MinimapBorder:Hide() end
        if _G.MinimapBorderTop then _G.MinimapBorderTop:Hide() end
        if _G.MinimapNorthTag then _G.MinimapNorthTag:Hide() end
        if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Hide() end
        if _G.MinimapBackdrop then _G.MinimapBackdrop:Hide() end

        local hm = _G.HybridMinimap
        if hm and hm.CircleMask then hm.CircleMask:SetTexture(square_mask) end
        if not minimap_border:IsShown() then minimap_border:Show() end
    else
        Minimap:SetMaskTexture(round_mask)
        _G.GetMinimapShape = original_get_minimap_shape
        if _G.MinimapBorder then _G.MinimapBorder:Show() end
        if _G.MinimapBorderTop then _G.MinimapBorderTop:Show() end
        if _G.MinimapNorthTag then _G.MinimapNorthTag:Show() end
        if _G.MinimapCompassTexture then _G.MinimapCompassTexture:Show() end
        if _G.MinimapBackdrop then _G.MinimapBackdrop:Show() end

        local hm = _G.HybridMinimap
        if hm and hm.CircleMask then hm.CircleMask:SetTexture(round_mask) end
        if minimap_border:IsShown() then minimap_border:Hide() end
    end
end

dodo.UpdateMinimapSquareState = apply_minimap_square
dodo.MinimapSquare = apply_minimap_square

-- ==============================
-- 이벤트 핸들러
-- ==============================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if dodoDB.useMinimapSquare == nil then dodoDB.useMinimapSquare = true end
        create_ui()
        apply_minimap_square()

        if C_AddOns.IsAddOnLoaded("Blizzard_HybridMinimap") then
            local hm = _G.HybridMinimap
            if hm then
                hm:SetFrameStrata("BACKGROUND")
                hm:SetFrameLevel(100)
                hm.MapCanvas:SetUseMaskTexture(false)
                hm.CircleMask:SetTexture(square_mask)
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
            hm.CircleMask:SetTexture(square_mask)
            hm.MapCanvas:SetUseMaskTexture(true)
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        apply_minimap_square()
    end
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.Minimap, {
        {
            name = "사각형 미니맵",
            get = function() return dodoDB.useMinimapSquare ~= false end,
            set = function(v) dodoDB.useMinimapSquare = v; apply_minimap_square() end,
            disabled = function() return dodoDB and dodoDB.useMinimap == false end,
        }
    })
end
