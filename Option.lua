-- ==============================
-- 테이블 /run dodoDB = nil; ReloadUI()
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...

local CreateFrame = CreateFrame
local CreateSettingsListSectionHeaderInitializer = CreateSettingsListSectionHeaderInitializer
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local type = type
local ReloadUI = ReloadUI
local Settings = Settings
local SettingsPanel = SettingsPanel
local SlashCmdList = SlashCmdList

-- ==============================
-- 디스플레이
-- ==============================
-- 메인
local mainCategory = Settings.RegisterVerticalLayoutCategory("dodo")
Settings.RegisterAddOnCategory(mainCategory)

-- 하위
local subCategoryInterface = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "인터페이스")
local subCategoryCommands  = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "명령어")

-- 인터페이스 카테고리 섹션 순서 (헤더 관리 일괄화)
local interface_sections = {
    { key = "인터페이스.편의기능", header = "편의기능" },
    { key = "인터페이스.대화창",   header = "대화창"   },
}

-- 설정 생성
function dodoCreateOptions()
    if dodoOptionsCreated then return end
    dodoOptionsCreated = true

    local layout = SettingsPanel:GetLayout(subCategoryInterface)
    if layout then
        for _, section in ipairs(interface_sections) do
            local funcs = dodo.OptionRegistrations[section.key]
            if funcs and #funcs > 0 then
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section.header))
                for _, fn in ipairs(funcs) do
                    if type(fn) == "function" then fn(subCategoryInterface) end
                end
            end
        end
    end

    local commands_funcs = dodo.OptionRegistrations["명령어"]
    if commands_funcs then
        for _, fn in ipairs(commands_funcs) do
            if type(fn) == "function" then fn(subCategoryCommands) end
        end
    end
end

-- ==============================
-- 이벤트 및 지연 로딩 (Lazy Load)
-- ==============================
local initOptionFrame = CreateFrame("Frame")
initOptionFrame:RegisterEvent("ADDON_LOADED")
initOptionFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodoDB

        -- 리로드/로그인 시점에 모든 설정 변수를 블리자드 시스템에 즉시 동기화 및 로드
        if dodoCreateOptions then dodoCreateOptions() end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ==============================
-- 명령어
-- ==============================
SLASH_dodo1 = "/dd"
SLASH_dodo2 = "/ㅇㅇ"
SlashCmdList["dodo"] = function()
    if InCombatLockdown() then
        print("|cffff0000dodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end
    if dodoCreateOptions then dodoCreateOptions() end
    Settings.OpenToCategory(mainCategory:GetID())
end

