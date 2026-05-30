-- ==============================
-- Inspired
-- ==============================
-- CDMButtonAuras (https://www.curseforge.com/wow/addons/cdmbuttonauras)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local FeaturePotionBars = {
    ["MultiBar7"]           = true,
}

local PotionIds = {
    [241308] = true, [241309] = true,
}

-- ==============================
-- 캐싱
-- ==============================
local C_Container = C_Container
local C_Item = C_Item
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local Enum = Enum
local GetActionInfo = GetActionInfo
local InCombatLockdown = InCombatLockdown

-- ==============================
-- 기능 구현
-- ==============================
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
    
    local isEnabled = (dodoDB and dodoDB.useActionbarPotionProc ~= false)
    if not isEnabled then
        if btn.potionOverlay then btn.potionOverlay:Update(false) end
        return
    end

    local barName = dodo.get_bar_name_by_button(btn)
    if not barName or not FeaturePotionBars[barName] then
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
    for i = 1, 12 do
        local btn = _G["MultiBar7Button" .. i]
        if btn and btn:IsVisible() then
            update_potion_proc(btn)
        end
    end
end
dodo.ActionbarUpdateAllPotionProcs = update_all_potion_procs

local is_potion_pending = false
dodo.TriggerBagUpdate = function()
    if not is_potion_pending then
        is_potion_pending = true
        C_Timer.After(0.1, function()
            is_potion_pending = false
            update_all_potion_procs()
        end)
    end
end

dodo.ActionbarInitPotionProc = function()
    update_all_potion_procs()
end

dodo.ActionbarApplyPotionProc = function()
    update_all_potion_procs()
end

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ActionBar, {
        {
            name = "오버레이: 물약",
            get = function() return dodoDB and dodoDB.useActionbarPotionProc ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useActionbarPotionProc = checked end
                dodo.ActionbarApplyPotionProc()
            end,
            disabled = function() return dodoDB and dodoDB.enableActionbar == false end
        }
    })
end
