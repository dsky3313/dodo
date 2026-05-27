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

-- 하위
local subCategoryGeneral = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "일반")
local subCategorySound = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "음성")
local subCategoryInterface = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "인터페이스")
local subCategoryCombat = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "전투")
local subCategoryParty = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "파티")
local subCategoryActionbar = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "행동 단축바")
local subCategorySettingProfile = Settings.RegisterVerticalLayoutSubcategory(mainCategory, "설정 & 프로필")

-- 설정 생성
function dodoCreateOptions()
    if dodoOptionsCreated then return end

    -- 메인
    local layoutMain = SettingsPanel:GetLayout(mainCategory)
    -- 이름표
    layoutMain:AddInitializer(CreateSettingsListSectionHeaderInitializer("이름표"))
    Checkbox(mainCategory, "useNameplateFriendly", "아군 이름표 자동 설정", "아군 이름표에 클래스 색상을 적용하고 이름만 표시합니다.", true,
        dodo.nameplateFriendly)


    -- [ 일반 ]
    local layoutGeneral = SettingsPanel:GetLayout(subCategoryGeneral)
    if dodo.OptionRegistrations and dodo.OptionRegistrations["general"] then
        for _, callback in ipairs(dodo.OptionRegistrations["general"]) do
            if type(callback) == "function" then
                callback(subCategoryGeneral)
            end
        end
    end



    -- [ 인터페이스 ]
    local layoutInterface = SettingsPanel:GetLayout(subCategoryInterface)
    layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("말풍선"))
    DropDown(subCategoryInterface, "chatbubbleFontPath", "말풍선 글꼴", "말풍선에 적용할 글꼴를 선택하세요.", dodo.chatbubbleFontTable, dodo.chatbubbleFontTable[1].value, dodo.ChatBubble)
    Slider(subCategoryInterface, "chatbubbleFontSize", "말풍선 글꼴 크기", "말풍선 글꼴 크기를 변경합니다.", 8, 14, 1, 10, "Integer", dodo.ChatBubble)

    if dodo.OptionRegistrations and dodo.OptionRegistrations["minimap"] then
        for _, callback in ipairs(dodo.OptionRegistrations["minimap"]) do
            if type(callback) == "function" then
                callback(subCategoryInterface)
            end
        end
    end

    layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("프레임 크기"))
    Slider(subCategoryInterface, "frameScale_gmf", "게임 메뉴", "게임 메뉴 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.9", 0.5, 1.5, 0.1, 1.0, "Percent", dodo.FrameScale)
    Slider(subCategoryInterface, "frameScale_mmbbb", "가방버튼", "가방버튼 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.7", 0.5, 1.5, 0.1, 1.0, "Percent", dodo.FrameScale)
    Slider(subCategoryInterface, "frameScale_th", "말머리", "말머리 크기를 조절합니다.\n\n|cffaaffaa추천 : 0.8", 0.5, 1.5, 0.1, 1.0, "Percent", dodo.FrameScale)

    layoutInterface:AddInitializer(CreateSettingsListSectionHeaderInitializer("편의기능"))
    if dodo.OptionRegistrations and dodo.OptionRegistrations["interface"] then
        for _, callback in ipairs(dodo.OptionRegistrations["interface"]) do
            if type(callback) == "function" then
                callback(subCategoryInterface)
            end
        end
    end
    Checkbox(subCategoryInterface, "useItemLevel", "아이템 레벨 표시", "장비창 및 가방 아이템에 아이템 레벨을 표시합니다.", true, dodo.ItemLevelDisplay)

    Checkbox(subCategoryInterface, "useEnhancedCharFrame", "장비창+", "장비창에 마법부여, 보석 정보를 표시하고 창 크기를 넓힙니다.", true, dodo.EnhancedCharFrame)


    -- [ 음성 ]
    if dodo.OptionRegistrations and dodo.OptionRegistrations["sound"] then
        for _, callback in ipairs(dodo.OptionRegistrations["sound"]) do
            if type(callback) == "function" then
                callback(subCategorySound)
            end
        end
    end



    -- [ 파티 ]
    local layoutParty = SettingsPanel:GetLayout(subCategoryParty)
    if dodo.OptionRegistrations and dodo.OptionRegistrations["party"] then
        for _, callback in ipairs(dodo.OptionRegistrations["party"]) do
            if type(callback) == "function" then
                callback(subCategoryParty)
            end
        end
    end
    Checkbox(subCategoryParty, "useKeyRoll", "쐐기돌 굴림 알림", "쐐기 완료 후, 파티원의 돌목록과 돌변경 알림을 띄웁니다.", true, dodo.KeyRoll)



    -- [ 전투 ]
    local layoutCombat = SettingsPanel:GetLayout(subCategoryCombat)
    if dodo.OptionRegistrations and dodo.OptionRegistrations["combat"] then
        for _, callback in ipairs(dodo.OptionRegistrations["combat"]) do
            if type(callback) == "function" then
                callback(subCategoryCombat)
            end
        end
    end







    -- [ 행동 단축바 ]
    if dodo.OptionRegistrations and dodo.OptionRegistrations["actionbar"] then
        for _, callback in ipairs(dodo.OptionRegistrations["actionbar"]) do
            if type(callback) == "function" then
                callback(subCategoryActionbar)
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
        dodoDB = dodoDB or {}
        dodo.DB = dodoDB
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
SlashCmdList["dodo"] = function()
    if InCombatLockdown() then
        print("|cffff0000dodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end
    -- 명령어로 열 때도 옵션 UI가 생성되어 있는지 확인
    if dodoCreateOptions then dodoCreateOptions() end
    Settings.OpenToCategory(mainCategory:GetID())
end

