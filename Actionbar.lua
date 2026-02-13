-- ==============================
-- 테이블 및 설정
-- ==============================
local addonName, dodo = ...
dodoDB = dodoDB or {}

local actionbarConfig = {
    Enabled = true,
    DesaturateUnusable = true,
    DesaturatePet = true,
    GCD = 1.5,
    Colors = {
        Range = { r = 0.9, g = 0.1, b = 0.1 },
        Mana = { r = 0.1, g = 0.3, b = 1.0 },
        Normal = { r = 1, g = 1, b = 1 },
    }
}

local _G = _G
local C_ActionBar = _G.C_ActionBar
local C_Spell = _G.C_Spell

-- ==============================
-- 디스플레이 및 보조 함수
-- ==============================
local actionbar = CreateFrame("Frame")
actionbar.RegisteredButtons = {}

local function GetIsInRange(action)
    if not action then return true end
    if C_ActionBar and C_ActionBar.IsActionInRange then
        local inRange = C_ActionBar.IsActionInRange(action)
        return inRange ~= false
    end
    return true
end

-- 쿨타임 우회용 곡선
local DesaturationCurve = C_CurveUtil.CreateCurve()
DesaturationCurve:SetType(Enum.LuaCurveType.Step)
DesaturationCurve:AddPoint(0, 0)
DesaturationCurve:AddPoint(0.001, 1)

-- ==============================
-- 메인 동작: 행동단축바 업데이트
-- ==============================
local function UpdateActionButton(self)
    if not actionbarConfig.Enabled or not self.icon then return end

    local action = self.action
    local spellID = self.spellID
    local icon = self.icon

    local isUsable, notEnoughMana
    local inRange = true
    local desaturationValue = 0 -- 최종 적용할 흑백 수치 (0 or 1)

    -- [1] 상태 체크
    if action then
        isUsable, notEnoughMana = C_ActionBar.IsUsableAction(action)
        inRange = GetIsInRange(action)
    elseif spellID then
        isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
    end

    -- [2] 색상 적용 (Vertex Color)
    if not inRange then
        icon:SetVertexColor(actionbarConfig.Colors.Range.r, actionbarConfig.Colors.Range.g, actionbarConfig.Colors.Range.b)
    elseif notEnoughMana then
        icon:SetVertexColor(actionbarConfig.Colors.Mana.r, actionbarConfig.Colors.Mana.g, actionbarConfig.Colors.Mana.b)
        -- 🌟 고통 감내 등 노란색 아이콘의 녹색 변색 방지를 위해 자원 부족 시 흑백화 강제
        desaturationValue = 1
    else
        icon:SetVertexColor(actionbarConfig.Colors.Normal.r, actionbarConfig.Colors.Normal.g, actionbarConfig.Colors.Normal.b)
    end

    -- [3] 사용 불가(DesaturateUnusable) 시 흑백 처리
    if actionbarConfig.DesaturateUnusable and isUsable ~= nil and not (isUsable or notEnoughMana) then
        desaturationValue = 1
    end

    -- [4] 쿨타임 체크 (보안 에러 방지 로직)
    local duration
    local isOnGCD = false

    if action then
        local cdInfo = C_ActionBar.GetActionCooldown(action)
        isOnGCD = cdInfo and cdInfo.isOnGCD or false
        duration = C_ActionBar.GetActionCooldownDuration(action)
    elseif spellID then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        isOnGCD = cdInfo and cdInfo.isOnGCD or false
        duration = C_Spell.GetSpellCooldownDuration(spellID)
    end

    if duration and not isOnGCD then
        if duration:HasSecretValues() then
            -- 🌟 보안 숫자를 직접 비교(>0)하지 않고 커브 결과값(0 or 1)을 사용
            local cdDesat = duration:EvaluateRemainingDuration(DesaturationCurve)
            -- 기존 desaturationValue가 1(자원부족 등)이면 유지, 아니면 커브값 적용
            desaturationValue = (desaturationValue == 1) and 1 or cdDesat
        else
            if duration:GetRemainingDuration() > 0 then
                desaturationValue = 1
            end
        end
    end

    -- [5] 최종 흑백 적용
    icon:SetDesaturation(desaturationValue)
end

-- 펫 행동단축바
local function UpdatePetActionButton(self)
    if not actionbarConfig.DesaturatePet or not self.icon then return end
    local index = self.index or self.id
    if not (index and GetPetActionInfo(index)) then return end

    local isUsable = GetPetActionSlotUsable(index)
    local _, duration, enable = GetPetActionCooldown(index)
    
    local desat = 0
    if actionbarConfig.DesaturateUnusable and not isUsable then
        desat = 1
    elseif enable and duration and duration > actionbarConfig.GCD then
        desat = 1
    end
    
    self.icon:SetDesaturation(desat)
end

-- ==============================
-- 후킹 및 이벤트
-- ==============================
local function HookButton(button, isPet)
    if not button or actionbar.RegisteredButtons[button] then return end
    actionbar.RegisteredButtons[button] = true

    if isPet then
        button.IsPetButton = true
        if type(button.Update) == "function" then hooksecurefunc(button, "Update", UpdatePetActionButton) end
    else
        if type(button.Update) == "function" then hooksecurefunc(button, "Update", UpdateActionButton) end
        if type(button.UpdateUsable) == "function" then hooksecurefunc(button, "UpdateUsable", UpdateActionButton) end
        if button.cooldown then
            button.cooldown:HookScript("OnCooldownDone", function(s) 
                local p = s:GetParent()
                if p then if p.IsPetButton then UpdatePetActionButton(p) else UpdateActionButton(p) end end
            end)
        end
    end
end

actionbar:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        local bars = {
            "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
            "MultiBarLeftButton", "MultiBarRightButton", "MultiBar5Button",
            "MultiBar6Button", "MultiBar7Button", "StanceButton", "ExtraActionButton"
        }
        for _, bar in ipairs(bars) do for i = 1, 12 do HookButton(_G[bar..i]) end end
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
        for button in pairs(actionbar.RegisteredButtons) do
            if button:IsVisible() then
                if button.IsPetButton then UpdatePetActionButton(button) else UpdateActionButton(button) end
            end
        end
    end
end)

-- ==============================
-- 이벤트
-- ==============================
actionbar:RegisterEvent("PLAYER_LOGIN")
actionbar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
actionbar:RegisterEvent("ACTIONBAR_UPDATE_STATE")
actionbar:RegisterEvent("PLAYER_TARGET_CHANGED")
actionbar:RegisterEvent("UNIT_POWER_UPDATE")