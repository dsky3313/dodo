-- ==============================
-- Inspired
-- ==============================
-- ActionBarsEnhanced (https://www.curseforge.com/wow/addons/actionbarsenhanced)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local HOTKEY_DB_KEYS  = dodo.AB_DB_KEYS.hotkey
local HOTKEY_DEFAULTS = dodo.AB_DEFAULTS.hotkey
local MACRO_DB_KEYS   = dodo.AB_DB_KEYS.macro
local MACRO_DEFAULTS  = dodo.AB_DEFAULTS.macro

local RANGE_INDICATOR = "●"

-- ==============================
-- 캐싱
-- ==============================
local ipairs = ipairs
local pairs = pairs
local registeredButtons = dodo.registeredButtons

-- ==============================
-- 기능 구현
-- ==============================
local bar_hotkey_cache = {}
local function is_bar_hotkey_enabled(barName)
    if not barName then return false end
    local cached = bar_hotkey_cache[barName]
    if cached ~= nil then return cached end
    local dbKey = HOTKEY_DB_KEYS[barName]
    local result
    if not dbKey then
        result = HOTKEY_DEFAULTS[barName] or false
    elseif not dodoDB then
        result = HOTKEY_DEFAULTS[barName] or false
    else
        local val = dodoDB[dbKey]
        result = (val == nil) and (HOTKEY_DEFAULTS[barName] or false) or val
    end
    bar_hotkey_cache[barName] = result
    return result
end
dodo.ActionbarInvalidateHotkeyCache = function() bar_hotkey_cache = {} end

local bar_macro_cache = {}
local function is_bar_macro_enabled(barName)
    if not barName then return false end
    local cached = bar_macro_cache[barName]
    if cached ~= nil then return cached end
    local dbKey = MACRO_DB_KEYS[barName]
    local result
    if not dbKey then
        result = MACRO_DEFAULTS[barName] or false
    elseif not dodoDB then
        result = MACRO_DEFAULTS[barName] or false
    else
        local val = dodoDB[dbKey]
        result = (val == nil) and (MACRO_DEFAULTS[barName] or false) or val
    end
    bar_macro_cache[barName] = result
    return result
end
dodo.ActionbarInvalidateMacroCache = function() bar_macro_cache = {} end

local function update_button_text(btn)
    if not btn.HotKey then return end

    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then return end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName then return end

    local hideHotkeys = is_bar_hotkey_enabled(barName)
    local hideMacroNames = is_bar_macro_enabled(barName)

    local text = btn.HotKey:GetText()
    if hideHotkeys then
        btn.HotKey:SetAlpha(text == RANGE_INDICATOR and 1 or 0)
    else
        btn.HotKey:SetAlpha(1)
    end

    if btn.Name then
        if btn.__isPetButton == nil then
            local name = btn:GetName()
            btn.__isPetButton = name ~= nil and name:find("Pet") ~= nil
        end
        if not btn.__isPetButton then
            btn.Name:SetAlpha(hideMacroNames and 0 or 1)
        end
    end
end
dodo.ActionbarUpdateButtonText = update_button_text

dodo.ActionbarApplyText = function()
    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then
        for btn in pairs(registeredButtons) do
            if btn.HotKey then
                btn.HotKey:SetAlpha(1)
                if _G.ActionButton_UpdateHotkeys then
                    _G.ActionButton_UpdateHotkeys(btn)
                end
            end
            if btn.Name then btn.Name:SetAlpha(1) end
        end
        return
    end
    if not dodo.barButtons then return end
    for _, barInfo in ipairs(dodo.AB_BAR_ORDER) do
        local btns = dodo.barButtons[barInfo.name]
        if btns then
            for _, btn in ipairs(btns) do
                if btn:IsVisible() then update_button_text(btn) end
            end
        end
    end
end
