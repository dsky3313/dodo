-- ==============================
-- Inspired
-- ==============================
-- ActionBarsEnhanced (https://www.curseforge.com/wow/addons/actionbarsenhanced)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- ==============================
-- 설정 및 테이블
-- ==============================
local FeatureTextHideBars = {
    ["MainActionBar"]       = true,
    ["MultiBarBottomLeft"]  = true,
    ["MultiBarBottomRight"] = true,
    ["MultiBarRight"]       = false,
    ["MultiBarLeft"]        = false,
    ["MultiBar5"]           = false,
    ["MultiBar6"]           = false,
    ["MultiBar7"]           = true,
    ["StanceBar"]           = true,
    ["PetActionBar"]        = true,
}

local FeatureTextShortenBars = {
    ["MainActionBar"]       = true,
    ["MultiBarBottomLeft"]  = true,
    ["MultiBarBottomRight"] = true,
    ["MultiBarRight"]       = false,
    ["MultiBarLeft"]        = false,
    ["MultiBar5"]           = false,
    ["MultiBar6"]           = false,
    ["MultiBar7"]           = true,
    ["StanceBar"]           = true,
    ["PetActionBar"]        = true,
}

local ReplaceTextRules = {
    { "SHIFT[%-%+]", "S" },
    { "CTRL[%-%+]", "C" },
    { "ALT[%-%+]", "A" },
    { "NUMPADMINUS", "N-" },
    { "NUMPADPLUS", "N+" },
    { "SPACE", "SP" },
    { "MOUSEWHEELUP", "MWU" },
    { "MOUSEWHEELDOWN", "MWD" },
    { "[%s%-]", "" }
}

-- ==============================
-- 캐싱
-- ==============================
local Enum = Enum
local ipairs = ipairs
local pairs = pairs

local registeredButtons = dodo.registeredButtons

local key_cache = {}

-- ==============================
-- 기능 구현
-- ==============================
local function get_shortened_key(text)
    local RANGE_INDICATOR = "●"
    if not text or text == "" or text == RANGE_INDICATOR then return text end
    if key_cache[text] then return key_cache[text] end
    local result = text:upper()
    for _, rule in ipairs(ReplaceTextRules) do result = result:gsub(rule[1], rule[2]) end
    key_cache[text] = result
    return result
end

local function update_button_text(btn)
    if not btn.HotKey then return end

    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then return end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not FeatureTextHideBars[barName] then return end
    
    local hideHotkeys = (dodoDB and dodoDB.useActionbarHideHotkeys ~= false)
    local hideMacroNames = (dodoDB and dodoDB.useActionbarHideMacroNames == true)
    
    local RANGE_INDICATOR = "●"
    local text = btn.HotKey:GetText()

    if hideHotkeys then
        btn.HotKey:SetAlpha(text == RANGE_INDICATOR and 1 or 0)
    else
        btn.HotKey:SetAlpha(1)
        if FeatureTextShortenBars[barName] then
            local short = get_shortened_key(text)
            if text ~= short then btn.HotKey:SetText(short) end
        end
    end
    if btn.Name and not (btn:GetName() or ""):find("Pet") then
        btn.Name:SetAlpha(hideMacroNames and 0 or 1)
    end
end
dodo.ActionbarUpdateButtonText = update_button_text

dodo.ActionbarApplyText = function()
    for btn in pairs(registeredButtons) do
        local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
        if isEnabled then
            if btn:IsVisible() then update_button_text(btn) end
        else
            if btn.HotKey then
                btn.HotKey:SetAlpha(1)
                if _G.ActionButton_UpdateHotkeys then
                    _G.ActionButton_UpdateHotkeys(btn)
                end
            end
            if btn.Name then
                btn.Name:SetAlpha(1)
            end
        end
    end
end

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ActionBar, {
        {
            name = "텍스트: 단축키",
            get = function() return dodoDB and dodoDB.useActionbarHideHotkeys ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useActionbarHideHotkeys = checked end
                dodo.ActionbarApplyText()
            end,
            disabled = function() return dodoDB and dodoDB.enableActionbar == false end
        },
        {
            name = "텍스트: 매크로",
            get = function() return dodoDB and dodoDB.useActionbarHideMacroNames == true end,
            set = function(checked)
                if dodoDB then dodoDB.useActionbarHideMacroNames = checked end
                dodo.ActionbarApplyText()
            end,
            disabled = function() return dodoDB and dodoDB.enableActionbar == false end
        }
    })
end
