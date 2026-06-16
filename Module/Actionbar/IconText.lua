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

local BAR_INDEX_MAP = dodo.BAR_INDEX_MAP

local HOTKEY_DB_KEYS = {
    ["MainActionBar"]       = "useActionbarHideHotkeysBar1",
    ["MultiBarBottomLeft"]  = "useActionbarHideHotkeysBar2",
    ["MultiBarBottomRight"] = "useActionbarHideHotkeysBar3",
    ["MultiBarRight"]       = "useActionbarHideHotkeysBar4",
    ["MultiBarLeft"]        = "useActionbarHideHotkeysBar5",
    ["MultiBar5"]           = "useActionbarHideHotkeysBar6",
    ["MultiBar6"]           = "useActionbarHideHotkeysBar7",
    ["MultiBar7"]           = "useActionbarHideHotkeysBar8",
}

local HOTKEY_DEFAULTS = {
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

local MACRO_DB_KEYS = {
    ["MainActionBar"]       = "useActionbarHideMacroNamesBar1",
    ["MultiBarBottomLeft"]  = "useActionbarHideMacroNamesBar2",
    ["MultiBarBottomRight"] = "useActionbarHideMacroNamesBar3",
    ["MultiBarRight"]       = "useActionbarHideMacroNamesBar4",
    ["MultiBarLeft"]        = "useActionbarHideMacroNamesBar5",
    ["MultiBar5"]           = "useActionbarHideMacroNamesBar6",
    ["MultiBar6"]           = "useActionbarHideMacroNamesBar7",
    ["MultiBar7"]           = "useActionbarHideMacroNamesBar8",
}

local RANGE_INDICATOR = "●"

-- ==============================
-- 캐싱
-- ==============================
local Enum = Enum
local pairs = pairs

local registeredButtons = dodo.registeredButtons

-- ==============================
-- 기능 구현
-- ==============================
local function is_bar_hotkey_enabled(barName)
    if not barName then return false end
    local dbKey = HOTKEY_DB_KEYS[barName]
    if not dbKey then return HOTKEY_DEFAULTS[barName] or false end
    if not dodoDB then return HOTKEY_DEFAULTS[barName] or false end
    local val = dodoDB[dbKey]
    if val == nil then return HOTKEY_DEFAULTS[barName] or false end
    return val
end

local function is_bar_macro_enabled(barName)
    if not barName then return false end
    local dbKey = MACRO_DB_KEYS[barName]
    if not dbKey then return false end
    if not dodoDB then return false end
    local val = dodoDB[dbKey]
    return val == true
end

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
    for idx, barName in pairs(BAR_INDEX_MAP) do
        local sysID = string.format("%d_%d", Enum.EditModeSystem.ActionBar, idx)
        local hotkeyKey = HOTKEY_DB_KEYS[barName]
        local macroKey  = MACRO_DB_KEYS[barName]
        dodo.RegisterEditModeSystemSetting(sysID, {
            {
                name = "텍스트: 단축키",
                get = function()
                    if not dodoDB then return HOTKEY_DEFAULTS[barName] or false end
                    local val = dodoDB[hotkeyKey]
                    return val == nil and (HOTKEY_DEFAULTS[barName] or false) or val
                end,
                set = function(checked)
                    if dodoDB then dodoDB[hotkeyKey] = checked end
                    dodo.ActionbarApplyText()
                end,
                disabled = function() return dodoDB and dodoDB.enableActionbar == false end
            },
            {
                name = "텍스트: 매크로",
                get = function()
                    return dodoDB and dodoDB[macroKey] == true
                end,
                set = function(checked)
                    if dodoDB then dodoDB[macroKey] = checked end
                    dodo.ActionbarApplyText()
                end,
                disabled = function() return dodoDB and dodoDB.enableActionbar == false end
            }
        })
    end
end
