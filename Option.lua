-- ==============================
-- 테이블 /run dodoDB = nil; ReloadUI()
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local table_sort = table.sort
local type = type
local ReloadUI = ReloadUI
local Settings = Settings
local SettingsPanel = SettingsPanel
local SlashCmdList = SlashCmdList

-- ==============================
-- 디스플레이
-- ==============================
local mainCategory = Settings.RegisterVerticalLayoutCategory("dodo")
Settings.RegisterAddOnCategory(mainCategory)

-- 설정창 → 편집모드 진입 (설정창 먼저 닫고 /ed 슬래시 재사용, 전투 가드 포함)
local function open_edit_mode_from_options()
    HideUIPanel(SettingsPanel)
    local handler = SlashCmdList["EDITMODE"]
    if handler then handler("") end
end

-- 설정 생성
function dodoCreateOptions()
    if dodoOptionsCreated then return end
    dodoOptionsCreated = true

    -- 메인 페이지: 편집모드 열기 버튼
    local main_layout = SettingsPanel:GetLayout(mainCategory)
    if main_layout and CreateSettingsButtonInitializer then
        main_layout:AddInitializer(CreateSettingsButtonInitializer("", "UI설정 열기", open_edit_mode_from_options, "dodo 모듈 편집이 포함된 편집모드를 엽니다.", false))
    end

    -- subCategory 캐시 (중복 생성 방지)
    local subCats = {}
    local function get_subcat(name)
        if not subCats[name] then
            subCats[name] = Settings.RegisterVerticalLayoutSubcategory(mainCategory, name)
        end
        return subCats[name]
    end

    -- SectionHeader 중복 방지
    local rendered_headers = {}

    -- 새 등록 API (_optionRegistry)
    table_sort(dodo._optionRegistry, function(a, b) return a.order < b.order end)
    for _, entry in ipairs(dodo._optionRegistry) do
        local dot = entry.path:find(".", 1, true)
        if dot then
            local parent = entry.path:sub(1, dot - 1)
            local header = entry.path:sub(dot + 1)
            local subCat = get_subcat(parent)
            if not rendered_headers[entry.path] then
                dodo.UI:SettingsSectionHeader(subCat, header)
                rendered_headers[entry.path] = true
            end
            entry.build(subCat)
        else
            entry.build(get_subcat(entry.path))
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
-- 외부(편집모드 패널 등)에서 설정창을 직접 열 수 있는 공개 API
function dodo.OpenOptions()
    if InCombatLockdown() then
        print("|cffff0000dodo: 전투 중에는 설정창을 열 수 없습니다.|r")
        return
    end
    if dodoCreateOptions then dodoCreateOptions() end
    Settings.OpenToCategory(mainCategory:GetID())
end

SLASH_dodo1 = "/dd"
SLASH_dodo2 = "/ㅇㅇ"
SlashCmdList["dodo"] = dodo.OpenOptions
