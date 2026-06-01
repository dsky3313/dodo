-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 캐싱
-- ==============================
local CharacterFrame = CharacterFrame
local CharacterFrameInset = CharacterFrameInset
local CharacterHeadSlot = CharacterHeadSlot
local CharacterModelScene = CharacterModelScene
local CharacterTrinket1Slot = CharacterTrinket1Slot
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local PaperDollFrame = PaperDollFrame
local PaperDollItemsFrame = PaperDollItemsFrame
local _G = _G

local configs = {
    wide_width   = 650,
    normal_width = 448,
}

local fexOriginalHeight = nil

-- ==============================
-- 동작
-- ==============================
function dodo.HideCharacterFrameBackgrounds()
    if dodoDB.enableCharacterFrame == false or dodoDB.useEnhancedCharFrame == false then return end

    local bgs = {
        "CharacterModelFrameBackgroundOverlay",
        "CharacterModelFrameBackgroundTopLeft",
        "CharacterModelFrameBackgroundTopRight",
        "CharacterModelFrameBackgroundBotLeft",
        "CharacterModelFrameBackgroundBotRight",
    }
    for _, name in ipairs(bgs) do
        local f = _G[name]
        if f then 
            f:SetAlpha(0)
            if f.Hide then f:Hide() end
        end
    end
end

local function reset_layout()
    CharacterFrame:SetWidth(configs.normal_width)
    if fexOriginalHeight then
        CharacterFrame:SetHeight(fexOriginalHeight)
    end
end

dodo.ResetCharacterFrameLayout = reset_layout

local function apply_wide_layout()
    if not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    if dodoDB.enableCharacterFrame == false or dodoDB.useEnhancedCharFrame == false then
        reset_layout()
        return
    end

    if not fexOriginalHeight then
        fexOriginalHeight = CharacterFrame:GetHeight()
    end
    CharacterFrame:SetWidth(configs.wide_width)
    
    CharacterFrameInset:ClearAllPoints()
    CharacterFrameInset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
    CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", configs.wide_width - 206, 4)

    if CharacterMainHandSlot then
        CharacterMainHandSlot:SetPoint("BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 185, 14)
    end
    if CharacterSecondaryHandSlot then
        CharacterSecondaryHandSlot:SetPoint("BOTTOMLEFT", CharacterMainHandSlot, "BOTTOMRIGHT", 5, 0)
    end

    if CharacterModelScene then
        local LeftSlot = CharacterHeadSlot
        local RightSlot = CharacterTrinket1Slot
        if LeftSlot and RightSlot then
            CharacterModelScene:ClearAllPoints()
            CharacterModelScene:SetPoint("TOPLEFT", LeftSlot, "TOPRIGHT", 0, -4)
            CharacterModelScene:SetPoint("BOTTOMRIGHT", RightSlot, "BOTTOMLEFT", 0, 0)
        end
    end
end

dodo.UpdateCharacterFrameLayout = apply_wide_layout

-- 훅 설치
local function on_character_frame_show()
    dodo.HideCharacterFrameBackgrounds()
    apply_wide_layout()
end

CharacterFrame:HookScript("OnShow", on_character_frame_show)

hooksecurefunc(CharacterFrame, "Expand", apply_wide_layout)
hooksecurefunc(CharacterFrame, "UpdateSize", apply_wide_layout)
hooksecurefunc(CharacterFrame, "Collapse", reset_layout)
