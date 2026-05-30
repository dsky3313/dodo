-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
local lib_icon = dodo.LibIcon

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
local bobber_button = lib_icon:Create("quickBobber", UIParent, BobberConfig)
bobber_button:Hide()

local function quick_bobber()
    if InCombatLockdown() then
        bobber_button:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local is_enabled = (dodoDB and dodoDB.useQuickBobber ~= false)
    local is_known = C_SpellBook.IsSpellKnown(131474) -- 낚시 숙련 여부
    
    -- [수정] 프레임 존재 여부 안전하게 확인
    local is_ui_open = (ProfessionsBookFrame and ProfessionsBookFrame:IsShown())

    -- [핵심] 낚시 숙련도가 있고 활성화 상태일 때 작동
    if is_known and is_enabled and is_ui_open then
        -- Icon.lua에서 개별 이벤트를 지웠으므로 여기서 직접 관리
        bobber_button:RegisterEvent("BAG_UPDATE_DELAYED")
        bobber_button:RegisterEvent("BAG_UPDATE_COOLDOWN")
        bobber_button:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        bobber_button:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        
        bobber_button:ApplyConfig(BobberConfig)
        bobber_button:Show()
    else
        -- 창이 닫히면 모든 이벤트 해제 및 숨김
        bobber_button:UnregisterAllEvents()
        bobber_button:Hide()
    end
end

-- [수정] 이벤트 핸들러: Icon.lua의 업데이트 로직 호출
local function on_bobber_event(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        quick_bobber()
    else
        if self.UpdateStatus then 
            self:UpdateStatus() 
        end
    end
end

bobber_button:SetScript("OnEvent", on_bobber_event)

-- ==============================
-- 이벤트
-- ==============================
local init_quick_bobber = CreateFrame("Frame")
init_quick_bobber:RegisterEvent("ADDON_LOADED")
init_quick_bobber:RegisterEvent("PLAYER_ENTERING_WORLD")

local function on_init_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        ProfessionsBookFrame:HookScript("OnShow", quick_bobber)
        ProfessionsBookFrame:HookScript("OnHide", quick_bobber)
    elseif event == "PLAYER_ENTERING_WORLD" then
        quick_bobber()
    end
end

init_quick_bobber:SetScript("OnEvent", on_init_event)

-- 이미 로드되어 있을 경우를 대비한 즉시 훅 (예: 리로드 시)
if ProfessionsBookFrame then
    ProfessionsBookFrame:HookScript("OnShow", quick_bobber)
    ProfessionsBookFrame:HookScript("OnHide", quick_bobber)
end

-- ==============================
-- 외부 노출 및 설정 동적 등록 (RegisterEditModeModuleSetting 이관)
-- ==============================
dodo.quickBobber = quick_bobber

if dodo.RegisterEditModeModuleSetting then
    dodo.RegisterEditModeModuleSetting("편의기능", {
        {
            name = "낚시찌 장난감",
            get = function() return dodoDB and dodoDB.useQuickBobber ~= false end,
            set = function(checked)
                if dodoDB then dodoDB.useQuickBobber = checked end
                quick_bobber()
            end
        }
    })
end