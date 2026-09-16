-- ==============================
-- Inspired
-- ==============================
-- CDMButtonAuras (https://www.curseforge.com/wow/addons/cdmbuttonauras)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local dodo = _G.dodo
dodoDB = dodoDB or {}

local POTION_DB_KEYS   = dodo.AB_DB_KEYS.potion
local POTION_DEFAULTS  = dodo.AB_DEFAULTS.potion

local PotionIds = { -- 물약 사용가능 알림
    [241308] = true, -- 빛의 잠재력 2성
    [241309] = true, -- 빛의 잠재력 1성
    [241289] = true, -- 무모함의 물약 1성
    [241288] = true, -- 무모함의 물약 2성
}

-- ==============================
-- 캐싱
-- ==============================
local C_Container = C_Container
local C_Item = C_Item
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetActionInfo = GetActionInfo
local ipairs = ipairs
local pairs = pairs

-- ==============================
-- 기능 구현
-- ==============================
local bar_potion_cache = {}
local function is_bar_potion_proc_enabled(barName)
    if not barName then return false end
    local cached = bar_potion_cache[barName]
    if cached ~= nil then return cached end
    local dbKey = POTION_DB_KEYS[barName]
    local result
    if not dbKey then
        result = POTION_DEFAULTS[barName] or false
    elseif not dodoDB then
        result = POTION_DEFAULTS[barName] or false
    else
        local val = dodoDB[dbKey]
        result = (val == nil) and (POTION_DEFAULTS[barName] or false) or val
    end
    bar_potion_cache[barName] = result
    return result
end
dodo.ActionbarInvalidatePotionCache = function() bar_potion_cache = {} end
dodo.ActionbarInvalidatePotionButtonCache = function()
    for btn in pairs(dodo.registeredButtons) do
        btn.__isPotion = nil
        btn.__potionItemID = nil
    end
end
dodo.is_bar_potion_proc_enabled = is_bar_potion_proc_enabled

PotionOverlayMixin = {}
function PotionOverlayMixin:Update(active)
    if active then
        if not self.ProcLoop:IsPlaying() then self.ProcLoop:Play() end
        self:Show()
    else
        if self.ProcLoop:IsPlaying() then self.ProcLoop:Stop() end
        self:Hide()
    end
end

local function update_potion_proc(btn)
    if not btn.action then return end

    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if not isEnabled then
        if btn.potionOverlay then btn.potionOverlay:Update(false) end
        return
    end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not is_bar_potion_proc_enabled(barName) then
        if btn.potionOverlay then btn.potionOverlay:Update(false) end
        return
    end

    if btn.__isPotion == nil then
        local actionType, id = GetActionInfo(btn.action)
        btn.__isPotion = (actionType == "item" and PotionIds[id] == true)
        btn.__potionItemID = btn.__isPotion and id or nil
    end

    if btn.__isPotion then
        local id = btn.__potionItemID
        if not btn.potionOverlay then
            btn.potionOverlay = CreateFrame("Frame", nil, btn, "PotionOverlayTemplate")
            btn.potionOverlay:SetAllPoints(btn)
            local w, h = btn:GetSize()
            btn.potionOverlay.Proc:SetSize(w * 1.4, h * 1.4)
        end

        local count = C_Item.GetItemCount(id)
        local start, duration = C_Container.GetItemCooldown(id)
        local isUsable = dodo.inCombat and (count > 0) and (start == 0 or duration == 0)
        btn.potionOverlay:Update(isUsable)
    elseif btn.potionOverlay then
        btn.potionOverlay:Update(false)
    end
end
dodo.ActionbarUpdatePotionProc = update_potion_proc

local function update_all_potion_procs()
    if not dodo.barButtons then return end
    for _, barInfo in ipairs(dodo.AB_BAR_ORDER) do
        if is_bar_potion_proc_enabled(barInfo.name) then
            local btns = dodo.barButtons[barInfo.name]
            if btns then
                for _, btn in ipairs(btns) do
                    if btn:IsVisible() then update_potion_proc(btn) end
                end
            end
        end
    end
end
dodo.ActionbarUpdateAllPotionProcs = update_all_potion_procs

local is_potion_pending = false
local function on_bag_update_tick()
    is_potion_pending = false
    update_all_potion_procs()
end
dodo.TriggerBagUpdate = function()
    if not is_potion_pending then
        is_potion_pending = true
        C_Timer.After(0.1, on_bag_update_tick)
    end
end

dodo.ActionbarInitPotionProc = function()
    update_all_potion_procs()
end

dodo.ActionbarApplyPotionProc = function()
    update_all_potion_procs()
end

