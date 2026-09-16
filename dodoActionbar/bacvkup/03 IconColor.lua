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

local COLOR_DB_KEYS  = dodo.AB_DB_KEYS.color
local COLOR_DEFAULTS = dodo.AB_DEFAULTS.color

-- ==============================
-- 캐싱
-- ==============================
local C_ActionBar = C_ActionBar
local C_CurveUtil = C_CurveUtil
local Enum = Enum
local ipairs = ipairs
local pairs = pairs

local dodoColors = dodo.Colors
local registeredButtons = dodo.registeredButtons

local DesatCurve = C_CurveUtil.CreateCurve()
DesatCurve:SetType(Enum.LuaCurveType.Step)
DesatCurve:AddPoint(0, 0)
DesatCurve:AddPoint(0.001, 1)

-- ==============================
-- 기능 구현
-- ==============================
local bar_color_cache = {}
local function is_bar_color_enabled(barName)
    if not barName then return false end
    local cached = bar_color_cache[barName]
    if cached ~= nil then return cached end
    local dbKey = COLOR_DB_KEYS[barName]
    local result
    if not dbKey then
        result = COLOR_DEFAULTS[barName] or false
    elseif not dodoDB then
        result = COLOR_DEFAULTS[barName] or false
    else
        local val = dodoDB[dbKey]
        result = (val == nil) and (COLOR_DEFAULTS[barName] or false) or val
    end
    bar_color_cache[barName] = result
    return result
end
dodo.ActionbarInvalidateColorCache = function() bar_color_cache = {} end
dodo.ActionbarIsBarColorEnabled = is_bar_color_enabled

local function update_icon_color(btn)
    if not btn.icon then return end

    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then return end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_color_enabled(barName) then
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturation(0)
        return
    end

    local r, g, b, desat = 1, 1, 1, 0
    if btn.__isOutOfRange then
        local c = dodoColors.ActionbarIconColor.Range
        r, g, b, desat = c.r, c.g, c.b, 1
    elseif btn.__isNotEnoughMana then
        local c = dodoColors.ActionbarIconColor.Mana
        r, g, b, desat = c.r, c.g, c.b, 1
    else
        r, g, b = 1, 1, 1
        if btn.__isUsable == false then
            desat = 1
        elseif btn.__cdVal then
            desat = btn.__cdVal:EvaluateRemainingDuration(DesatCurve)
        else
            desat = 0
        end
    end

    btn.icon:SetVertexColor(r, g, b)
    btn.icon:SetDesaturation(desat)
end
dodo.ActionbarUpdateIconColor = update_icon_color

local function update_state(btn)
    if not btn.action then return end
    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then
        if btn.icon then
            btn.icon:SetVertexColor(1, 1, 1)
            btn.icon:SetDesaturation(0)
        end
        if dodo.ActionbarUpdateButtonText then dodo.ActionbarUpdateButtonText(btn) end
        return
    end
    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_color_enabled(barName) then
        update_icon_color(btn)
        if dodo.ActionbarUpdateButtonText then dodo.ActionbarUpdateButtonText(btn) end
        return
    end
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(btn.action)
    btn.__isUsable = isUsable
    btn.__isNotEnoughMana = notEnoughMana
    update_icon_color(btn)
    if dodo.ActionbarUpdateButtonText then dodo.ActionbarUpdateButtonText(btn) end
end
dodo.ActionbarUpdateState = update_state

local function update_range_state(btn)
    if not btn.action then return end
    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then return end
    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_color_enabled(barName) then return end
    local inRange = C_ActionBar.IsActionInRange(btn.action)
    btn.__isOutOfRange = (inRange == false)
    update_icon_color(btn)
end
dodo.ActionbarUpdateRangeState = update_range_state

local function update_cooldown_state(btn)
    if not btn.action then return end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_color_enabled(barName) then
        btn.__cdVal = nil
        update_icon_color(btn)
        return
    end

    local info = C_ActionBar.GetActionCooldown(btn.action)
    if not info or info.isOnGCD then
        btn.__cdVal = nil
    else
        btn.__cdVal = C_ActionBar.GetActionCooldownDuration(btn.action)
    end
    update_icon_color(btn)
end
dodo.ActionbarUpdateCooldownState = update_cooldown_state

dodo.ActionbarApplyColor = function()
    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then
        for btn in pairs(registeredButtons) do
            if btn.icon then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.icon:SetDesaturation(0)
            end
        end
        return
    end
    if not dodo.barButtons then return end
    for _, barInfo in ipairs(dodo.AB_BAR_ORDER) do
        local btns = dodo.barButtons[barInfo.name]
        if btns then
            if is_bar_color_enabled(barInfo.name) then
                for _, btn in ipairs(btns) do
                    if btn:IsVisible() then update_state(btn) end
                end
            else
                for _, btn in ipairs(btns) do
                    update_icon_color(btn)
                end
            end
        end
    end
end
