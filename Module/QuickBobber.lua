-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
local Lib = dodo.IconLib

local BobberConfig = {
    isAction = true,
    type = "item",
    id = 202207,
    icon = nil,
    iconsize = {34, 34},
    iconposition = {"TOPLEFT", "SecondaryProfession2", "TOPLEFT", 250, -7},
    label = "낚시찌",
    fontsize = 12,
    fontposition = {"BOTTOMRIGHT", "self", "BOTTOMLEFT", -2, 2},
    fontcolor = "yellow",
    cooldownSize = 12,
    outline = false,
    framestrata = "HIGH",
}

local function isIns()
    local _, instanceType = GetInstanceInfo()
    return IsInInstance() or (instanceType ~= "none")
end

-- ==============================
-- 디스플레이 (보안 버튼 생성)
-- ==============================
local BobberButton = Lib:Create("quickBobber", UIParent, BobberConfig)
BobberButton:Hide()

local function quickBobber()
    if InCombatLockdown() then
        BobberButton:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local ProfFrame = _G["ProfessionsBookFrame"]
    if not ProfFrame or not ProfFrame:IsShown() then 
        BobberButton:Hide()
        return 
    end

    -- [핵심 수정] 앵커가 아직 생성되지 않았다면 0.1초 후에 다시 실행
    local anchor = _G["SecondaryProfession4"] or _G["SecondaryProfession3"]
    if not anchor then
        C_Timer.After(0.1, quickBobber) -- 자기 자신을 0.1초 뒤에 다시 호출
        return
    end

    local isEnabled = (dodoDB and dodoDB.useQuickBobber ~= false)
    local isKnown = C_SpellBook.IsSpellKnown(131474)

    if isKnown and isEnabled and not isIns() then
        BobberButton:SetParent(ProfFrame)
        BobberButton:SetFrameStrata("HIGH")
        BobberButton:SetFrameLevel(ProfFrame:GetFrameLevel() + 20)

        -- 이제 anchor가 확실히 존재하므로 좌표 설정
        BobberButton:ClearAllPoints()
        BobberButton:SetPoint("LEFT", anchor, "LEFT", 225, -5) 

        BobberButton:RegisterEvent("BAG_UPDATE_DELAYED")
        BobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        
        if BobberButton.ApplyConfig then
            BobberButton:ApplyConfig(BobberConfig)
        end
        
        BobberButton:Show()
        if BobberButton.UpdateStatus then BobberButton:UpdateStatus() end
    else
        BobberButton:UnregisterAllEvents()
        BobberButton:Hide()
    end
end

-- ==============================
-- 이벤트 (메인 제어)
-- ==============================
local initQuickBobber = CreateFrame("Frame")
initQuickBobber:RegisterEvent("ADDON_LOADED")
initQuickBobber:RegisterEvent("PLAYER_ENTERING_WORLD")

-- 중복 훅 방지를 위한 플래그
local isHooked = false

local function ApplyHooks()
    local ProfFrame = _G["ProfessionsBookFrame"]
    if ProfFrame and not isHooked then
        ProfFrame:HookScript("OnShow", quickBobber)
        ProfFrame:HookScript("OnHide", quickBobber)
        isHooked = true
    end
end

initQuickBobber:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        -- [해결] 0.1초 대기 후 프레임이 확실히 생성되었을 때 훅 연결
        C_Timer.After(0.1, ApplyHooks)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 훅이 확실히 연결되도록 먼저 ApplyHooks 실행
        ApplyHooks()
        quickBobber()
    end
end)

-- 리로드 시 이미 로드되어 있을 경우 대비
if _G["ProfessionsBookFrame"] then
    ApplyHooks()
end