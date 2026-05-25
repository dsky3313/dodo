-- ==============================
-- 테이블 /run dodoDB = nil; ReloadUI()
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
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
dodo.mainCategory = mainCategory

-- 하위
dodo.subCategoryGeneral = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "일반")
dodo.subCategoryInterface = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "인터페이스")
dodo.subCategoryCombat = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "전투")
dodo.subCategoryParty = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "파티")

function dodoCreateOptions()
    if dodoOptionsCreated then return end

    if dodo.ModuleRegistry then
        for _, module in ipairs(dodo.ModuleRegistry) do
            if type(module.CreateOptions) == "function" then
                local ok, err = pcall(function()
                    module:CreateOptions()
                end)
                if not ok then
                    print("|cffff0000dodo 설정 UI 생성 실패 (" .. tostring(module.Name) .. "):|r", err)
                end
            end
        end
    end

    dodoOptionsCreated = true
end

-- ==============================
-- 이벤트 및 지연 로딩 (Lazy Load)
-- ==============================
local initOptionFrame = CreateFrame("Frame")
initOptionFrame:RegisterEvent("ADDON_LOADED")
initOptionFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == addonName then
        dodoDB = dodo.DB or dodoDB or {}
        dodo.DB = dodoDB
        -- 리로드 스파이크 방지: 로딩 화면(PLAYER_LOGIN)에서 무거운 설정창 UI를 만들지 않습니다.
    end
end)

-- 설정창을 열 때 최초 1회만 옵션 UI를 생성합니다. (로딩 스파이크 제거의 핵심)
if SettingsPanel then
    SettingsPanel:HookScript("OnShow", function()
        if dodoCreateOptions then dodoCreateOptions() end
    end)
end

-- ==============================
-- 명령어
-- ==============================
SLASH_dodo1 = "/dd"
SLASH_dodo2 = "/ㅇㅇ"
SLASH_dodo3 = "/dodo"
SlashCmdList["dodo"] = function(msg)
    if InCombatLockdown() then
        print("|cffff0000dodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end

    -- 명령어로 열 때도 옵션 UI가 생성되어 있는지 확인
    if dodoCreateOptions then dodoCreateOptions() end
    Settings.OpenToCategory(mainCategory:GetID())
end
