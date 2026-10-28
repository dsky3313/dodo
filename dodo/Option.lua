-- ==============================
-- 테이블 /run dodoDB = nil; ReloadUI()
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local pairs = pairs
local table_sort = table.sort
local type = type
local ReloadUI = ReloadUI
local Settings = Settings
local SettingsPanel = SettingsPanel

-- ==============================
-- 디스플레이
-- ==============================
local mainCategory = Settings.RegisterVerticalLayoutCategory("dodo")
Settings.RegisterAddOnCategory(mainCategory)

StaticPopupDialogs["DODO_RESET_CONFIRM"] = {
    text = "dodo의 모든 설정을 초기화하고 UI를 재로드합니다. 계속하시겠습니까?",
    button1 = "초기화",
    button2 = "취소",
    OnAccept = function()
        dodoDB = nil
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- subCategory 캐시 (중복 생성 방지)
local subCats = {}
local function get_subcat(name)
    if not subCats[name] then
        subCats[name] = Settings.RegisterVerticalLayoutSubcategory(mainCategory, name)
    end
    return subCats[name]
end

-- 서브카테고리만 미리 등록 (좌측 목록용, 저비용). 항목 빌드는 설정창을 열 때까지 지연
local function register_subcategories()
    table_sort(dodo._optionRegistry, function(a, b) return a.order < b.order end)
    for _, entry in ipairs(dodo._optionRegistry) do
        local dot = entry.path:find(".", 1, true)
        get_subcat(dot and entry.path:sub(1, dot - 1) or entry.path)
    end
end

-- 설정 생성
function dodoCreateOptions()
    if dodoOptionsCreated then return end
    dodoOptionsCreated = true

    dodo.UI:SettingsButton(mainCategory, "설정 초기화", "초기화", function()
        StaticPopup_Show("DODO_RESET_CONFIRM")
    end)

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
-- 설정창 첫 표시 때 항목 빌드. 이미 dodo 카테고리가 선택된 채로 열렸다면 다시 선택해 갱신
local function on_settings_show()
    if dodoOptionsCreated then return end
    dodoCreateOptions()

    if not (SettingsPanel.GetCurrentCategory and SettingsPanel.SelectCategory) then return end
    local cur = SettingsPanel:GetCurrentCategory()
    if cur == mainCategory then
        SettingsPanel:SelectCategory(cur)
        return
    end
    for _, sub in pairs(subCats) do
        if cur == sub then
            SettingsPanel:SelectCategory(cur)
            return
        end
    end
end

local initOptionFrame = CreateFrame("Frame")
initOptionFrame:RegisterEvent("ADDON_LOADED")
initOptionFrame:RegisterEvent("PLAYER_LOGIN")
initOptionFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        dodoDB = dodoDB or {}
        dodo.DB = dodoDB
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- 모든 애드온 로드 완료 후 서브카테고리 등록 (분리된 모듈의 RegisterOption 보장)
        register_subcategories()
        SettingsPanel:HookScript("OnShow", on_settings_show)
        self:UnregisterEvent("PLAYER_LOGIN")
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

_G.dodo = dodo
