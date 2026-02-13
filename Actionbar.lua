-- ==============================
-- 테이블
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}

-- 1. 기본 설정 및 색상
local Config = {
    Enabled = true,
    DesaturateUnusable = true,
    DesaturatePet = true,
    GCD = 1.88, -- 펫 버튼 판정용
    Colors = {
        Range = { r = 0.9, g = 0.1, b = 0.1 }, -- 사거리 부족 (빨강)
        Mana = { r = 0.1, g = 0.3, b = 1.0 },  -- 자원 부족 (파랑)
        Normal = { r = 1, g = 1, b = 1 }       -- 정상 상태 (흰색)
    }
}

-- API 캐싱
local _G = _G
local IsActionInRange = IsActionInRange
local GetPetActionInfo = GetPetActionInfo
local GetPetActionSlotUsable = GetPetActionSlotUsable
local GetPetActionCooldown = GetPetActionCooldown
local C_ActionBar_IsUsableAction = C_ActionBar.IsUsableAction
local C_ActionBar_GetActionCooldown = C_ActionBar.GetActionCooldown
local C_ActionBar_GetActionCooldownDuration = C_ActionBar.GetActionCooldownDuration
local C_Spell_IsSpellUsable = C_Spell.IsSpellUsable
local C_Spell_GetSpellCooldown = C_Spell.GetSpellCooldown
local C_Spell_GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration

local GOC = CreateFrame("Frame")
GOC.RegisteredButtons = {}

-- 2. Desaturation Curves (보안 값 비교 에러 해결의 핵심)
local DesaturationCurve = C_CurveUtil.CreateCurve()
DesaturationCurve:SetType(Enum.LuaCurveType.Step)
DesaturationCurve:AddPoint(0, 0)
DesaturationCurve:AddPoint(0.001, 1)

-- ------------------------------------------------------------ --
-- Core Logic: Action Button Update
-- ------------------------------------------------------------ --
local function UpdateActionButton(self)
    if not Config.Enabled or not self.icon then return end

    local action = self.action
    local spellID = self.spellID
    local icon = self.icon

    -- [1] 사용 가능성 및 사거리/자원 체크 (Vertex Color)
    local isUsable, notEnoughMana
    local inRange = true

    if action then
        isUsable, notEnoughMana = C_ActionBar_IsUsableAction(action)
        inRange = (IsActionInRange(action) ~= false)
    elseif spellID then
        isUsable, notEnoughMana = C_Spell_IsSpellUsable(spellID)
    end

    -- 색상 적용 (사거리 > 자원 > 정상)
    if not inRange then
        icon:SetVertexColor(Config.Colors.Range.r, Config.Colors.Range.g, Config.Colors.Range.b)
    elseif notEnoughMana then
        icon:SetVertexColor(Config.Colors.Mana.r, Config.Colors.Mana.g, Config.Colors.Mana.b)
    else
        icon:SetVertexColor(Config.Colors.Normal.r, Config.Colors.Normal.g, Config.Colors.Normal.b)
    end

    -- [2] 회색화 처리 (Desaturation)
    -- 사용 불가능 체크
    if Config.DesaturateUnusable and isUsable ~= nil and not (isUsable or notEnoughMana) then
        icon:SetDesaturation(1)
        return
    end

    -- 쿨타임 체크 (Taint-Free 로직)
    local duration
    local isOnGCD = false

    if action then
        local cdInfo = C_ActionBar_GetActionCooldown(action)
        isOnGCD = cdInfo and cdInfo.isOnGCD or false
        duration = C_ActionBar_GetActionCooldownDuration(action)
    elseif spellID then
        local cdInfo = C_Spell_GetSpellCooldown(spellID)
        isOnGCD = cdInfo and cdInfo.isOnGCD or false
        duration = C_Spell_GetSpellCooldownDuration(spellID)
    end

    if duration then
        if isOnGCD then
            icon:SetDesaturation(0)
        elseif duration:HasSecretValues() then
            -- 숫자를 직접 비교하지 않고 커브를 통해 0 또는 1을 가져옴 (Taint 방지)
            icon:SetDesaturation(duration:EvaluateRemainingDuration(DesaturationCurve))
        else
            icon:SetDesaturation(duration:GetRemainingDuration() > 0 and 1 or 0)
        end
    else
        icon:SetDesaturation(0)
    end
end

-- ------------------------------------------------------------ --
-- Core Logic: Pet Action Button Update
-- ------------------------------------------------------------ --
local function UpdatePetActionButton(self)
    if not Config.DesaturatePet or not self.icon then return end
    
    local index = self.index or self.id
    if not (index and GetPetActionInfo(index)) then return end

    if Config.DesaturateUnusable then
        if not GetPetActionSlotUsable(index) then
            self.icon:SetDesaturation(1)
            return
        end
    end

    local _, duration, enable = GetPetActionCooldown(index)
    -- 펫 바는 아직 SecretValue 시스템이 적용되지 않아 숫자 비교가 가능함
    if enable and duration and duration > Config.GCD then
        self.icon:SetDesaturation(1)
    else
        self.icon:SetDesaturation(0)
    end
end

-- ------------------------------------------------------------ --
-- Hooking & Event System
-- ------------------------------------------------------------ --
local function HookButton(button, isPet)
    if not button or GOC.RegisteredButtons[button] then return end
    GOC.RegisteredButtons[button] = true

    if isPet then
        button.IsPetButton = true
        if type(button.Update) == "function" then
            hooksecurefunc(button, "Update", UpdatePetActionButton)
        end
    else
        if type(button.Update) == "function" then
            hooksecurefunc(button, "Update", UpdateActionButton)
        end
        if type(button.UpdateUsable) == "function" then
            hooksecurefunc(button, "UpdateUsable", UpdateActionButton)
        end
        
        if button.cooldown then
            button.cooldown:HookScript("OnCooldownDone", function(s) 
                local parent = s:GetParent()
                if parent then
                    if parent.IsPetButton then UpdatePetActionButton(parent) else UpdateActionButton(parent) end
                end
            end)
        end
    end
end

GOC:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local bars = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", 
                       "MultiBarLeftButton", "MultiBarRightButton", "MultiBar5Button", 
                       "MultiBar6Button", "MultiBar7Button", "StanceButton", "ExtraActionButton" }
        for _, bar in ipairs(bars) do
            for i = 1, 12 do HookButton(_G[bar..i]) end
        end
        for i = 1, 10 do HookButton(_G["PetActionButton"..i], true) end

        if SpellFlyout then
            hooksecurefunc(SpellFlyout, "Toggle", function()
                local i = 1
                while _G["SpellFlyoutPopupButton"..i] do
                    HookButton(_G["SpellFlyoutPopupButton"..i])
                    i = i + 1
                end
            end)
        end
    else
        for button in pairs(GOC.RegisteredButtons) do
            if button:IsVisible() then
                if button.IsPetButton then UpdatePetActionButton(button) else UpdateActionButton(button) end
            end
        end
    end
end)

GOC:RegisterEvent("PLAYER_LOGIN")
GOC:RegisterEvent("SPELL_UPDATE_COOLDOWN")
GOC:RegisterEvent("ACTIONBAR_UPDATE_STATE")
GOC:RegisterEvent("PLAYER_TARGET_CHANGED")
GOC:RegisterEvent("UNIT_POWER_UPDATE")