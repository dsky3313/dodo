-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
local Lib = dodo.IconLib

local function isIns()
    local _, instanceType = GetInstanceInfo()
    return IsInInstance() or (instanceType ~= "none")
end

local BobberConfig = {
    isAction = true,
    type = "item",
    id = 202207, -- 낚시찌 아이템 ID
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

-- ==============================
-- 디스플레이
-- ==============================
local BobberButton = Lib:Create("quickBobber", UIParent, BobberConfig)
BobberButton:Hide()

local function quickBobber()
    if InCombatLockdown() then
        BobberButton:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local isEnabled = (dodoDB and dodoDB.useQuickBobber ~= false)
    local isKnown = C_SpellBook.IsSpellKnown(131474) -- 낚시 숙련 여부
    
    -- [수정] 프레임 존재 여부 안전하게 확인
    local isUIOpen = (ProfessionsBookFrame and ProfessionsBookFrame:IsShown())

    -- [핵심] 인스턴스가 아닐 때만 작동하도록 강화
    if isKnown and isEnabled and not isIns() and isUIOpen then
        -- Icon.lua에서 개별 이벤트를 지웠으므로 여기서 직접 관리
        BobberButton:RegisterEvent("BAG_UPDATE_DELAYED")
        BobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        
        BobberButton:ApplyConfig(BobberConfig)
        BobberButton:Show()
    else
        -- 인스턴스 안이거나 창이 닫히면 모든 이벤트 해제 및 숨김
        BobberButton:UnregisterAllEvents()
        BobberButton:Hide()
    end
end

-- [수정] 이벤트 핸들러: Icon.lua의 업데이트 로직 호출
BobberButton:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        quickBobber()
    else
        -- Icon.lua에 작성된 UpdateStatus를 직접 호출 (매우 중요)
        if self.UpdateStatus then 
            self:UpdateStatus() 
        end
    end
end)

-- ==============================
-- 이벤트
-- ==============================
local initQuickBobber = CreateFrame("Frame")
initQuickBobber:RegisterEvent("ADDON_LOADED")
initQuickBobber:RegisterEvent("PLAYER_ENTERING_WORLD")

initQuickBobber:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        -- 전문기술 창이 로드되는 시점에 훅 연결
        ProfessionsBookFrame:HookScript("OnShow", quickBobber)
        ProfessionsBookFrame:HookScript("OnHide", quickBobber)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 지역 이동(던전 입장 등) 시 상태 업데이트
        quickBobber()
    end
end)

-- 이미 로드되어 있을 경우를 대비한 즉시 훅 (예: 리로드 시)
if ProfessionsBookFrame then
    ProfessionsBookFrame:HookScript("OnShow", quickBobber)
    ProfessionsBookFrame:HookScript("OnHide", quickBobber)
end

-- ==============================
-- 외부 노출 (Option.lua용)
-- ==============================