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

local BAR_INDEX_MAP  = dodo.BAR_INDEX_MAP
local COLOR_DB_KEYS  = dodo.AB_DB_KEYS.color
local COLOR_DEFAULTS = dodo.AB_DEFAULTS.color

-- ==============================
-- 캐싱
-- ==============================
local C_ActionBar = C_ActionBar
local C_CurveUtil = C_CurveUtil
local Enum = Enum
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
local function is_bar_color_enabled(barName)
    if not barName then return false end
    local dbKey = COLOR_DB_KEYS[barName]
    if not dbKey then
        return COLOR_DEFAULTS[barName] or false
    end
    if not dodoDB then return COLOR_DEFAULTS[barName] or false end
    local val = dodoDB[dbKey]
    if val == nil then return COLOR_DEFAULTS[barName] or false end
    return val
end

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
    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_color_enabled(barName) then
        update_icon_color(btn)
        if dodo.ActionbarUpdateButtonText then dodo.ActionbarUpdateButtonText(btn) end
        if dodo.ActionbarUpdatePotionProc then dodo.ActionbarUpdatePotionProc(btn) end
        return
    end
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

	local barName = dodo.get_bar_name_by_button(btn)
	if not barName or not is_bar_color_enabled(barName) then
		btn.__cdVal = nil
		update_icon_color(btn)
		if dodo.ActionbarUpdatePotionProc then dodo.ActionbarUpdatePotionProc(btn) end
		return
	end

	local dur = C_ActionBar.GetActionCooldownDuration(btn.action)
	local info = C_ActionBar.GetActionCooldown(btn.action)

	if not dur then
		btn.__cdVal = nil
	elseif info and not info.isOnGCD then
		btn.__cdVal = dur
	end
	-- isOnGCD 중에는 __cdVal 유지 (가속 환경에서 GCD 판정 타이밍 겹침 방지)

	update_icon_color(btn)
	if dodo.ActionbarUpdatePotionProc then dodo.ActionbarUpdatePotionProc(btn) end
end
dodo.ActionbarUpdateCooldownState = update_cooldown_state

dodo.ActionbarApplyColor = function()
    for btn in pairs(registeredButtons) do
        local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
        if isEnabled then
            if btn:IsVisible() then update_state(btn) end
        else
            if btn.icon then
                btn.icon:SetVertexColor(1, 1, 1)
                btn.icon:SetDesaturation(0)
            end
        end
    end
end

