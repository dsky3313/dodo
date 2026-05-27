-- ==============================
-- Inspired
-- ==============================
-- RefineUI (EncounterAchievements)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("EncounterAchievements", module)

-- ==============================
-- 캐싱 및 상수
-- ==============================
local C_AddOns = C_AddOns
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local ipairs, pairs = ipairs, pairs
local format = string.format
local EJ_GetInstanceInfo = EJ_GetInstanceInfo
local GetAchievementInfo = GetAchievementInfo
local GetAchievementLink = GetAchievementLink
local GetCategoryInfo = GetCategoryInfo
local GetCategoryList = GetCategoryList
local GetCategoryNumAchievements = GetCategoryNumAchievements
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local LoadAddOn = C_AddOns.LoadAddOn
local _G = _G

local CUSTOM_TAB_ID = 5001

-- ==============================
-- 헬퍼: 텍스트 정규화
-- ==============================
local function normalize_token(text)
    if type(text) ~= "string" then return "" end
    local token = text:lower()
    token = token:gsub("|c%x%x%x%x%x%x%x%x", "")
    token = token:gsub("|r", "")
    token = token:gsub("[%s%p%c]+", "") -- 공백, 문장부호, 제어문자 모두 제거
    return token
end

-- ==============================
-- 기능: 업적 검색 로직 (강화됨)
-- ==============================
local function get_instance_achievements(instanceID)
    if not instanceID then return nil end
    local instanceName = EJ_GetInstanceInfo(instanceID)
    if not instanceName then return nil end

    -- 검색용 핵심 키워드 (2글자 이상만 유효)
    local searchName = instanceName:gsub("공격대", ""):gsub("영웅", ""):gsub("전투", ""):gsub("던전", "")
    local instanceToken = normalize_token(searchName)
    if #instanceToken < 2 then instanceToken = normalize_token(instanceName) end
    
    local rawCategoryIDs = GetCategoryList()
    local categoryIDs = type(rawCategoryIDs) == "table" and rawCategoryIDs or { GetCategoryList() }
    
    local foundCategories = {}
    
    -- 모든 카테고리를 돌면서 이름이 포함되는지 확인
    for _, catID in ipairs(categoryIDs) do
        if type(catID) == "number" then
            local name, parentID = GetCategoryInfo(catID)
            local catToken = normalize_token(name)
            
            -- 인스턴스 이름이 카테고리에 포함되거나, 카테고리 이름이 인스턴스에 포함되는 경우
            if catToken ~= "" and (catToken:find(instanceToken, 1, true) or instanceToken:find(catToken, 1, true)) then
                table.insert(foundCategories, catID)
            end
        end
    end

    if #foundCategories == 0 then return nil end

    -- 수집된 모든 카테고리에서 업적 추출 (중복 제거)
    local achievements = {}
    local seen = {}
    for _, catID in ipairs(foundCategories) do
        local numAchievements = GetCategoryNumAchievements(catID)
        for i = 1, numAchievements do
            local id, name, _, completed, _, _, _, _, _, icon = GetAchievementInfo(catID, i)
            if id and not seen[id] then
                table.insert(achievements, { id = id, name = name, icon = icon, completed = completed })
                seen[id] = true
            end
        end
    end

    return achievements, instanceName
end

-- ==============================
-- 기능: 업적창 이동
-- ==============================
function module:OpenAchievement(achievementID)
    if not IsAddOnLoaded("Blizzard_AchievementUI") then
        LoadAddOn("Blizzard_AchievementUI")
    end

    if not _G.AchievementFrame:IsShown() then
        _G.AchievementFrame_ToggleAchievementFrame()
    end

    _G.AchievementFrame_SelectAchievement(achievementID)
end

-- ==============================
-- UI: 업적 탭 및 패널
-- ==============================
local function create_ui()
    if module.tab then return end

    local journal = _G.EncounterJournal
    if not journal then return end

    local encounter = journal.encounter
    local infoFrame = encounter.info

    -- 탭 생성
    local tab = CreateFrame("Button", nil, infoFrame, "EncounterTabTemplate")
    tab:SetID(CUSTOM_TAB_ID)
    tab.tooltip = ACHIEVEMENTS
    tab:SetPoint("TOP", infoFrame.modelTab, "BOTTOM", 0, 2)
    
    local icon = tab:CreateTexture(nil, "OVERLAY")
    icon:SetSize(42, 42)
    icon:SetPoint("CENTER")
    icon:SetAtlas("ShipMissionIcon-Bonus-Map")
    icon:SetVertexColor(0.83, 0.73, 0.58, 0.9)
    tab.icon = icon

    tab:SetScript("OnClick", function()
        module:ActivateTab()
    end)

    module.tab = tab

    -- 패널 생성
    local panel = CreateFrame("Frame", nil, infoFrame)
    panel:SetAllPoints(infoFrame.detailsScroll or infoFrame.model)
    panel:SetFrameLevel(infoFrame:GetFrameLevel() + 10)
    panel:Hide()

    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    panel.bg:SetColorTexture(0.03, 0.03, 0.03, 0.95)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 15, -15)

    -- 스크롤 프레임
    local scrollFrame = CreateFrame("ScrollFrame", "dodoEncounterAchievementScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(310, 1)
    scrollFrame:SetScrollChild(content)
    panel.content = content

    module.panel = panel

    -- 다른 탭 클릭 시 우리 패널 숨기기
    hooksecurefunc("EncounterJournal_SetTab", function(tabID)
        if tabID ~= CUSTOM_TAB_ID then
            module:DeactivateTab()
        end
    end)
end

function module:ActivateTab()
    local journal = _G.EncounterJournal
    if not journal then return end

    module.active = true
    module.panel:Show()
    module.tab.icon:SetVertexColor(1, 0.93, 0.66, 1)

    -- 다른 컨텐츠 숨기기
    local infoFrame = journal.encounter.info
    if infoFrame.detailsScroll then infoFrame.detailsScroll:Hide() end
    if infoFrame.model then infoFrame.model:Hide() end
    if infoFrame.overviewScroll then infoFrame.overviewScroll:Hide() end
    if infoFrame.LootContainer then infoFrame.LootContainer:Hide() end

    self:Refresh()
end

function module:DeactivateTab()
    module.active = false
    if module.panel then module.panel:Hide() end
    if module.tab then module.tab.icon:SetVertexColor(0.83, 0.73, 0.58, 0.9) end
end

function module:Refresh()
    if not module.active then return end

    local journal = _G.EncounterJournal
    local instanceID = journal.instanceID
    local achievements, instanceName = get_instance_achievements(instanceID)

    module.panel.title:SetText(instanceName or ACHIEVEMENTS)

    -- 기존 로우 숨기기
    if module.rows then
        for _, row in ipairs(module.rows) do row:Hide() end
    end
    module.rows = module.rows or {}

    if not achievements or #achievements == 0 then
        module.panel.title:SetText((instanceName or "") .. " - 관련 업적 없음")
        return
    end

    -- 정렬: 완료되지 않은 업적 우선
    table.sort(achievements, function(a, b)
        if a.completed ~= b.completed then
            return not a.completed
        end
        return a.name < b.name
    end)

    for i, data in ipairs(achievements) do
        local row = module.rows[i]
        if not row then
            row = CreateFrame("Button", nil, module.panel.content, "BackdropTemplate")
            row:SetSize(310, 42)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            row:SetBackdropColor(1, 1, 1, 0.03)
            row:SetBackdropBorderColor(0, 0, 0, 0.5)
            
            row.icon = row:CreateTexture(nil, "OVERLAY")
            row.icon:SetSize(34, 34)
            row.icon:SetPoint("LEFT", 5, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
            row.name:SetWidth(250)
            row.name:SetJustifyH("LEFT")
            
            row:SetScript("OnEnter", function(self)
                self:SetBackdropColor(1, 1, 1, 0.1)
                _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                _G.GameTooltip:SetAchievementByID(self.id)
                _G.GameTooltip:Show()
            end)
            
            row:SetScript("OnLeave", function(self)
                self:SetBackdropColor(1, 1, 1, 0.03)
                _G.GameTooltip:Hide()
            end)
            
            row:SetScript("OnClick", function(self)
                if IsShiftKeyDown() then
                    local link = GetAchievementLink(self.id)
                    if link then ChatEdit_InsertLink(link) end
                else
                    module:OpenAchievement(self.id)
                end
            end)
            
            table.insert(module.rows, row)
        end

        row.id = data.id
        row.icon:SetTexture(data.icon)
        row.name:SetText(data.name)
        if data.completed then
            row.name:SetTextColor(0.6, 1, 0.6)
            row.icon:SetDesaturated(false)
        else
            row.name:SetTextColor(1, 1, 1)
            row.icon:SetDesaturated(true)
        end
        
        row:SetPoint("TOPLEFT", 0, -(i-1)*44)
        row:Show()
    end
    
    module.panel.content:SetHeight(#achievements * 44 + 20)
end

-- ==============================
-- 모듈 On/Off 제어
-- ==============================
local function update_module_state()
    local enabled = (dodo.DB and dodo.DB.enableEncounterAchievementsModule ~= false)
    if not enabled then
        if module.tab then module.tab:Hide() end
        module:DeactivateTab()
    else
        if module.tab then module.tab:Show() end
    end
end

dodo.UpdateEncounterAchievementsModuleState = update_module_state

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    if not IsAddOnLoaded("Blizzard_EncounterJournal") then
        dodo.HookOnce("EncounterJournal_LoadUI", function()
            module:OnEnable()
        end)
        return
    end

    create_ui()
    update_module_state()

    if isInitialized then return end
    isInitialized = true

    -- 인스턴스 변경 시 리프레시
    hooksecurefunc("EncounterJournal_DisplayInstance", function()
        if module.active then module:Refresh() end
    end)
end
