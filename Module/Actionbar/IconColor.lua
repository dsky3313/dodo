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

local FeatureColorBars = {
    ["MainActionBar"]       = true,
    ["MultiBarBottomLeft"]  = true,
    ["MultiBarBottomRight"] = true,
    ["MultiBarRight"]       = false,
    ["MultiBarLeft"]        = false,
    ["MultiBar5"]           = false,
    ["MultiBar6"]           = false,
    ["MultiBar7"]           = true,
    ["StanceBar"]           = true,
    ["PetActionBar"]        = false,
}

local Colors = {
    range  = { r = 0.9, g = 0.1, b = 0.1 },
    mana   = { r = 0.1, g = 0.3, b = 1.0 },
    normal = { r = 1.0, g = 1.0, b = 1.0 }
}

-- ==============================
-- 캐싱
-- ==============================
local C_ActionBar = C_ActionBar
local C_CurveUtil = C_CurveUtil
local Enum = Enum
local pairs = pairs

local registeredButtons = dodo.registeredButtons

local DesatCurve = C_CurveUtil.CreateCurve()
DesatCurve:SetType(Enum.LuaCurveType.Step)
DesatCurve:AddPoint(0, 0)
DesatCurve:AddPoint(0.001, 1)

-- ==============================
-- 기능 구현
-- ==============================
local function update_icon_color(btn)
    if not btn.icon then return end

    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then return end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not FeatureColorBars[barName] then
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturation(0)
        return
    end

    local useColor = (dodoDB and dodoDB.useActionbarColor ~= false)
    if not useColor then
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetDesaturation(0)
        return
    end

    local r, g, b, desat = 1, 1, 1, 0
    if btn.__isOutOfRange then
        r, g, b, desat = Colors.range.r, Colors.range.g, Colors.range.b, 1
    elseif btn.__isNotEnoughMana then
        r, g, b, desat = Colors.mana.r, Colors.mana.g, Colors.mana.b, 1
    else
        r, g, b = Colors.normal.r, Colors.normal.g, Colors.normal.b
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
    local isUsable, notEnoughMana = C_ActionBar.IsUsableAction(btn.action)
    local inRange = C_ActionBar.IsActionInRange(btn.action)
    btn.__isUsable = isUsable
    btn.__isNotEnoughMana = notEnoughMana
    btn.__isOutOfRange = (inRange == false)
    update_icon_color(btn)
    if dodo.ActionbarUpdateButtonText then dodo.ActionbarUpdateButtonText(btn) end
    if dodo.ActionbarUpdatePotionProc then dodo.ActionbarUpdatePotionProc(btn) end
end
dodo.ActionbarUpdateState = update_state

local function update_cooldown_state(btn)
    if not btn.action then return end
    local dur  = C_ActionBar.GetActionCooldownDuration(btn.action)
    local info = C_ActionBar.GetActionCooldown(btn.action)
    btn.__cdVal = (dur and info and not info.isOnGCD) and dur or nil
    update_icon_color(btn)
    if dodo.ActionbarUpdatePotionProc then dodo.ActionbarUpdatePotionProc(btn) end
end
dodo.ActionbarUpdateCooldownState = update_cooldown_state

dodo.ActionbarApplyColor = function()
    for btn in pairs(registeredButtons) do
        local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
        if isEnabled then
            if btn:IsVisible() then update_icon_color(btn) end
        else
            if btn.icon then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.icon:SetDesaturation(0)
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
            name = "아이콘: 색상",
            get = function() return dodoDB and dodoDB.useActionbarColor ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useActionbarColor = checked end
                dodo.ActionbarApplyColor()
            end,
            disabled = function() return dodoDB and dodoDB.enableActionbar == false end
        }
    })
end
