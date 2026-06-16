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

dodo.customCDMAuras = {}
dodo.customCDMSpellMap = {}
dodo.registeredButtons = {}
dodo.inCombat = false

dodo.BAR_INDEX_MAP = {
    [1] = "MainActionBar",
    [2] = "MultiBarBottomLeft",
    [3] = "MultiBarBottomRight",
    [4] = "MultiBarRight",
    [5] = "MultiBarLeft",
    [6] = "MultiBar5",
    [7] = "MultiBar6",
    [8] = "MultiBar7",
}

local registeredButtons = dodo.registeredButtons

-- ==============================
-- 캐싱
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local next = next
local pairs = pairs

-- 공통 헬퍼
function dodo.get_bar_name_by_button(btn)
    if not btn then return nil end
    if btn.__barName then return btn.__barName end

    local name = btn:GetName()
    if not name then return nil end

    local barName
    if name:find("^ActionButton") then
        barName = "MainActionBar"
    elseif name:find("^MultiBarBottomLeftButton") then
        barName = "MultiBarBottomLeft"
    elseif name:find("^MultiBarBottomRightButton") then
        barName = "MultiBarBottomRight"
    elseif name:find("^MultiBarRightButton") then
        barName = "MultiBarRight"
    elseif name:find("^MultiBarLeftButton") then
        barName = "MultiBarLeft"
    elseif name:find("^MultiBar5Button") then
        barName = "MultiBar5"
    elseif name:find("^MultiBar6Button") then
        barName = "MultiBar6"
    elseif name:find("^MultiBar7Button") then
        barName = "MultiBar7"
    elseif name:find("^StanceButton") then
        barName = "StanceBar"
    elseif name:find("^PetActionButton") then
        barName = "PetActionBar"
    end

    btn.__barName = barName
    return barName
end

-- 이벤트 & 메인 루프 프레임
local f = CreateFrame("Frame")
dodo.ActionbarMainFrame = f

local function update_visual()
    local isEnabled = (dodoDB and dodoDB.enableActionbar ~= false)
    if isEnabled then
        f:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        f:RegisterEvent("ACTION_RANGE_CHECK_UPDATE")
        f:RegisterEvent("PLAYER_REGEN_ENABLED")
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        f:RegisterEvent("UNIT_DIED")
        f:RegisterEvent("PLAYER_DEAD")
        f:RegisterEvent("BAG_UPDATE")

        if dodo.ActionbarApplyInterrupt then dodo.ActionbarApplyInterrupt() end
        if dodo.ActionbarApplyColor then dodo.ActionbarApplyColor() end
        if dodo.ActionbarApplyText then dodo.ActionbarApplyText() end
        if dodo.ActionbarApplyPadding then dodo.ActionbarApplyPadding() end
        if dodo.ActionbarApplyCDM then dodo.ActionbarApplyCDM() end
        if dodo.ActionbarApplyPotionProc then dodo.ActionbarApplyPotionProc() end
    else
        f:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
        f:UnregisterEvent("ACTION_RANGE_CHECK_UPDATE")
        f:UnregisterEvent("PLAYER_REGEN_ENABLED")
        f:UnregisterEvent("PLAYER_REGEN_DISABLED")
        f:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        f:UnregisterEvent("UNIT_DIED")
        f:UnregisterEvent("PLAYER_DEAD")
        f:UnregisterEvent("BAG_UPDATE")

        if dodo.DisableInterruptController then dodo.DisableInterruptController() end
        if dodo.ActionbarApplyColor then dodo.ActionbarApplyColor() end
        if dodo.ActionbarApplyText then dodo.ActionbarApplyText() end
        if dodo.ActionbarApplyPadding then dodo.ActionbarApplyPadding() end

        local cdmBars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBar7Button" }
        for _, group in ipairs(cdmBars) do
            for i = 1, 12 do
                local btn = _G[group .. i]
                if btn then
                    if btn.cdmOverlay then btn.cdmOverlay:StopCustomCDM() end
                    if btn.potionOverlay then btn.potionOverlay:Update(false) end
                end
            end
        end
    end
end
dodo.ActionbarUpdateVisual = update_visual

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
    elseif event == "PLAYER_LOGIN" then
        local groups = {
            "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
            "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
            "StanceButton", "PetActionButton"
        }
        for _, group in ipairs(groups) do
            for i = 1, 12 do
                local btn = _G[group .. i]
                if btn then
                    registeredButtons[btn] = true
                    if btn.UpdateUsable and dodo.ActionbarUpdateState then
                        hooksecurefunc(btn, "UpdateUsable", dodo.ActionbarUpdateState)
                    end
                    if (group == "StanceButton" or group == "PetActionButton") and btn.UpdateState and dodo.ActionbarUpdateState then
                        hooksecurefunc(btn, "UpdateState", dodo.ActionbarUpdateState)
                    end
                    if btn.cooldown then
                        btn.cooldown:HookScript("OnCooldownDone", function()
                            btn.__cdVal = nil
                            if dodo.ActionbarUpdateIconColor then dodo.ActionbarUpdateIconColor(btn) end
                        end)
                    end
                    if dodo.ActionbarUpdateState then dodo.ActionbarUpdateState(btn) end
                    if dodo.ActionbarUpdateCooldownState then dodo.ActionbarUpdateCooldownState(btn) end
                end
            end
        end

        local pendingCooldownButtons = {}
        local function process_pending_cooldowns()
            for btn in pairs(pendingCooldownButtons) do
                if btn:IsVisible() and dodo.ActionbarUpdateCooldownState then
                    dodo.ActionbarUpdateCooldownState(btn)
                end
                pendingCooldownButtons[btn] = nil
            end
        end

        hooksecurefunc("ActionButton_ApplyCooldown", function(cd)
            local btn = cd:GetParent()
            if btn and registeredButtons[btn] then
                if not next(pendingCooldownButtons) then
                    C_Timer.After(0, process_pending_cooldowns)
                end
                pendingCooldownButtons[btn] = true
            end
        end)

        local bars = {
            MainActionBar, MultiBarBottomLeft, MultiBarBottomRight,
            MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7,
            StanceBar, PetActionBar
        }
        for _, bar in ipairs(bars) do
            if bar and dodo.ActionbarUpdatePadding then
                hooksecurefunc(bar, "UpdateGridLayout", dodo.ActionbarUpdatePadding)
                dodo.ActionbarUpdatePadding(bar)
            end
        end

        if dodo.ActionbarInitCDM then dodo.ActionbarInitCDM() end
        if dodo.ActionbarInitPotionProc then dodo.ActionbarInitPotionProc() end

        if dodoDB and dodoDB.enableActionbar == nil then
            dodoDB.enableActionbar = true
        end
        update_visual()

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        local slot = ...
        if not slot or slot <= 72 then
            if dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end
        end

    elseif event == "ACTION_RANGE_CHECK_UPDATE" then
        local slot = ...
        local slotButtons = ActionBarButtonRangeCheckFrame.actions and ActionBarButtonRangeCheckFrame.actions[slot]
        if slotButtons and dodo.ActionbarUpdateState then
            for _, btn in pairs(slotButtons) do
                if btn:IsVisible() then dodo.ActionbarUpdateState(btn) end
            end
        end

    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        dodo.inCombat = (event == "PLAYER_REGEN_DISABLED")
        if dodo.ActionbarUpdateAllPotionProcs then dodo.ActionbarUpdateAllPotionProcs() end
        if not dodo.inCombat and dodo.BuildSpecialButtonCache then dodo.BuildSpecialButtonCache() end

    elseif event == "BAG_UPDATE" then
        if dodo.TriggerBagUpdate then dodo.TriggerBagUpdate() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if dodo.ActionbarOnSpellcastSucceeded then dodo.ActionbarOnSpellcastSucceeded(...) end

    elseif event == "UNIT_DIED" or event == "PLAYER_DEAD" then
        local guid = ...
        if event == "PLAYER_DEAD" or (guid and not issecretvalue(guid) and guid == UnitGUID("player")) then
            wipe(dodo.customCDMAuras)
            if dodo.ActionbarApplyCDM then dodo.ActionbarApplyCDM() end
        end
    end
end)

-- 설정 등록
if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("전투", {
        {
            name = "행동단축바",
            get = function() return dodoDB and dodoDB.enableActionbar ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.enableActionbar = checked end
                update_visual()
            end
        }
    })
end
