-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
local Lib = dodo.IconLib

-- ==============================
-- 캐싱
-- ==============================
local C_SpellBook = C_SpellBook
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown


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

    -- [핵심] 낚시 숙련도가 있고 활성화 상태일 때 작동
    if isKnown and isEnabled and isUIOpen then
        -- Icon.lua에서 개별 이벤트를 지웠으므로 여기서 직접 관리
        BobberButton:RegisterEvent("BAG_UPDATE_DELAYED")
        BobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        
        BobberButton:ApplyConfig(BobberConfig)
        BobberButton:Show()
    else
        -- 창이 닫히면 모든 이벤트 해제 및 숨김
        BobberButton:UnregisterAllEvents()
        BobberButton:Hide()
    end
end

-- [수정] 이벤트 핸들러: Icon.lua의 업데이트 로직 호출
local function on_bobber_event(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        quickBobber()
    else
        if self.UpdateStatus then 
            self:UpdateStatus() 
        end
    end
end

BobberButton:SetScript("OnEvent", on_bobber_event)

-- ==============================
-- 이벤트
-- ==============================
local initQuickBobber = CreateFrame("Frame")
initQuickBobber:RegisterEvent("ADDON_LOADED")
initQuickBobber:RegisterEvent("PLAYER_ENTERING_WORLD")

local function on_init_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        ProfessionsBookFrame:HookScript("OnShow", quickBobber)
        ProfessionsBookFrame:HookScript("OnHide", quickBobber)
    elseif event == "PLAYER_ENTERING_WORLD" then
        quickBobber()
    end
end

initQuickBobber:SetScript("OnEvent", on_init_event)

-- 이미 로드되어 있을 경우를 대비한 즉시 훅 (예: 리로드 시)
if ProfessionsBookFrame then
    ProfessionsBookFrame:HookScript("OnShow", quickBobber)
    ProfessionsBookFrame:HookScript("OnHide", quickBobber)
end

-- ==============================
-- 외부 노출 및 설정 동적 등록 (Option.lua 연동)
-- ==============================
dodo.quickBobber = quickBobber

local SettingsPanel = SettingsPanel
local Checkbox = Checkbox

dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["interface"] = dodo.OptionRegistrations["interface"] or {}
table.insert(dodo.OptionRegistrations["interface"], function(category)
    local layout = SettingsPanel:GetLayout(category)
    if not layout then return end

    Checkbox(category, "useQuickBobber", "낚시찌 장난감", "낚시버튼 옆에 낚시찌 장난감 버튼을 배치합니다.", true, dodo.quickBobber)
end)