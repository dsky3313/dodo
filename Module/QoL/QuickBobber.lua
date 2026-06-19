-- ==============================
-- Inspired
-- ==============================
-- dodo

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
local Checkbox = Checkbox
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
    local is_ui_open = (ProfessionsBookFrame and ProfessionsBookFrame:IsShown())

    if is_known and is_enabled and is_ui_open then
        bobber_button:RegisterEvent("BAG_UPDATE_DELAYED")
        bobber_button:RegisterEvent("BAG_UPDATE_COOLDOWN")
        bobber_button:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        bobber_button:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        bobber_button:ApplyConfig(BobberConfig)
        bobber_button:Show()
    else
        bobber_button:UnregisterAllEvents()
        bobber_button:Hide()
    end
end

local function on_bobber_event(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        quick_bobber()
    else
        if self.UpdateStatus then self:UpdateStatus() end
    end
end

bobber_button:SetScript("OnEvent", on_bobber_event)

-- ==============================
-- 이벤트
-- ==============================
local init_quick_bobber = CreateFrame("Frame")

-- OFF시 PLAYER_ENTERING_WORLD 해제로 자원소모 0
local function update_events()
    local is_enabled = dodoDB and dodoDB.useQuickBobber ~= false
    if is_enabled then
        init_quick_bobber:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        init_quick_bobber:UnregisterEvent("PLAYER_ENTERING_WORLD")
        bobber_button:UnregisterAllEvents()
        bobber_button:Hide()
    end
end

local function on_init_event(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ProfessionsBook" then
        ProfessionsBookFrame:HookScript("OnShow", quick_bobber)
        ProfessionsBookFrame:HookScript("OnHide", quick_bobber)
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if dodoDB.useQuickBobber == nil then dodoDB.useQuickBobber = true end
        update_events()
        quick_bobber()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        quick_bobber()
    end
end

init_quick_bobber:RegisterEvent("ADDON_LOADED")
init_quick_bobber:RegisterEvent("PLAYER_LOGIN")
init_quick_bobber:SetScript("OnEvent", on_init_event)

-- 리로드 시 ProfessionsBookFrame이 이미 로드된 경우 즉시 훅
if ProfessionsBookFrame then
    ProfessionsBookFrame:HookScript("OnShow", quick_bobber)
    ProfessionsBookFrame:HookScript("OnHide", quick_bobber)
end

-- ==============================
-- 설정 등록
-- ==============================
dodo.OptionRegistrations = dodo.OptionRegistrations or {}
dodo.OptionRegistrations["인터페이스.편의기능"] = dodo.OptionRegistrations["인터페이스.편의기능"] or {}
table.insert(dodo.OptionRegistrations["인터페이스.편의기능"], function(category)
    Checkbox(category, "useQuickBobber", "낚시찌 장난감", "직업 창이 열려 있을 때 낚시찌 아이템 버튼을 표시합니다.", true, function()
        update_events()
        quick_bobber()
    end)
end)
