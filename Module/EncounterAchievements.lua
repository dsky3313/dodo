-- ==============================
-- Inspired by RefineUI
-- ==============================
-- EncounterAchievements.lua

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("EncounterAchievements", module)

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local type = type
local ipairs = ipairs
local _G = _G

-- ==============================
-- 상수
-- ==============================
local CUSTOM_TAB_ID = 5001
local BLIZZARD_ENCOUNTER_ADDON = "Blizzard_EncounterJournal"

-- 블리자드 순정 대소문자(LootTab 등)와 구버전 호환용 소문자(lootTab 등) 혼용 대응을 위해 대소문자 구분 키 설정
local NATIVE_TAB_KEYS = {
    "OverviewTab", "overviewTab",
    "LootTab", "lootTab",
    "BossTab", "bossTab",
    "ModelTab", "modelTab",
}

-- ==============================
-- 헬퍼 함수
-- ==============================
local function GetEncounterFrames()
    local journal = _G.EncounterJournal
    local encounter = journal and journal.encounter
    local info = encounter and encounter.info
    return journal, encounter, info
end

-- ==============================
-- 탭 및 패널 상태 제어
-- ==============================
function module:SetCustomTabSelected(selected)
    local tab = self.tabButton
    if not tab then return end

    if selected then
        if tab.selectedTexture then tab.selectedTexture:Show() end
        if tab.unselectedTexture then tab.unselectedTexture:Hide() end
        tab:LockHighlight()
    else
        if tab.selectedTexture then tab.selectedTexture:Hide() end
        if tab.unselectedTexture then tab.unselectedTexture:Show() end
        tab:UnlockHighlight()
    end
end

function module:ClearNativeTabSelection()
    local _, _, infoFrame = GetEncounterFrames()
    if not infoFrame then return end

    for _, tabKey in ipairs(NATIVE_TAB_KEYS) do
        local tab = infoFrame[tabKey]
        if tab then
            if tab.selected then tab.selected:Hide() end
            if tab.unselected then tab.unselected:Show() end
            if tab.UnlockHighlight then tab:UnlockHighlight() end
        end
    end
end

function module:HideNativeEncounterContent()
    local _, encounterFrame, infoFrame = GetEncounterFrames()
    if not infoFrame then return end

    -- 타 탭(LootTab, BossTab)처럼 블리자드 고유의 종이 배경(infoFrame.BG) 및 좌우 그림자(leftShadow, rightShadow)는 노출시킴
    if infoFrame.model and infoFrame.model.dungeonBG then infoFrame.model.dungeonBG:Hide() end

    if infoFrame.overviewScroll then infoFrame.overviewScroll:Hide() end
    if infoFrame.LootContainer then
        infoFrame.LootContainer:Hide()
        if infoFrame.LootContainer.classClearFilter then infoFrame.LootContainer.classClearFilter:Hide() end
    end
    if infoFrame.detailsScroll then infoFrame.detailsScroll:Hide() end
    if infoFrame.model then infoFrame.model:Hide() end
    if infoFrame.overviewScroll and infoFrame.overviewScroll.child then infoFrame.overviewScroll.child:Hide() end
    if infoFrame.detailsScroll and infoFrame.detailsScroll.child then infoFrame.detailsScroll.child:Hide() end

    if encounterFrame and encounterFrame.overviewFrame then encounterFrame.overviewFrame:Hide() end
    if encounterFrame and encounterFrame.infoFrame then encounterFrame.infoFrame:Hide() end

    -- 던전 대문(instance) 숨김으로 던전 설명글/일러스트 레이아웃 일괄 제거
    if encounterFrame and encounterFrame.instance then
        encounterFrame.instance:Hide()
    end

    -- 던전 대문 고유 이미지(InstanceFrameBG) 숨김
    if _G.InstanceFrameBG then
        _G.InstanceFrameBG:Hide()
    end

    if _G.EncounterJournal_HideCreatures then _G.EncounterJournal_HideCreatures() end
    if infoFrame.encounterTitle then infoFrame.encounterTitle:Hide() end

    -- 던전 난이도 드롭다운 숨김
    if infoFrame.difficulty then
        infoFrame.difficulty:Hide()
    end
    if _G.EncounterJournalEncounterFrameInfoDifficulty then
        _G.EncounterJournalEncounterFrameInfoDifficulty:Hide()
    end
end

function module:ShowNativeEncounterContent()
    local journal, encounterFrame, infoFrame = GetEncounterFrames()
    if not journal or not encounterFrame or not infoFrame then return end
    if not journal:IsShown() or not encounterFrame:IsShown() then return end

    if infoFrame.BG then infoFrame.BG:Show() end
    if infoFrame.leftShadow then infoFrame.leftShadow:Show() end
    if infoFrame.model and infoFrame.model.dungeonBG then infoFrame.model.dungeonBG:Show() end

    if infoFrame.overviewScroll and infoFrame.overviewScroll.child then infoFrame.overviewScroll.child:Show() end
    if infoFrame.detailsScroll and infoFrame.detailsScroll.child then infoFrame.detailsScroll.child:Show() end
    if encounterFrame and encounterFrame.overviewFrame then encounterFrame.overviewFrame:Show() end
    if encounterFrame and encounterFrame.infoFrame then encounterFrame.infoFrame:Show() end

    -- 던전 대문(instance) 및 던전 이미지 복구
    if encounterFrame and encounterFrame.instance then
        encounterFrame.instance:Show()
    end
    if _G.InstanceFrameBG then
        _G.InstanceFrameBG:Show()
    end

    -- 던전 난이도 드롭다운 복구
    if infoFrame.difficulty then
        infoFrame.difficulty:Show()
    end
    if _G.EncounterJournalEncounterFrameInfoDifficulty then
        _G.EncounterJournalEncounterFrameInfoDifficulty:Show()
    end

    -- 원래 활성화되어 있던 탭 상태로 원복
    local hasVisibleNativeFrame = (infoFrame.overviewScroll and infoFrame.overviewScroll:IsShown())
        or (infoFrame.detailsScroll and infoFrame.detailsScroll:IsShown())
        or (infoFrame.LootContainer and infoFrame.LootContainer:IsShown())
        or (infoFrame.model and infoFrame.model:IsShown())

    if hasVisibleNativeFrame then return end

    if type(_G.EncounterJournal_SetTab) == "function" then
        local selectedNativeTab = type(infoFrame.tab) == "number" and infoFrame.tab
        if not selectedNativeTab then
            local overviewTab = infoFrame.OverviewTab or infoFrame.overviewTab
            if overviewTab then
                selectedNativeTab = overviewTab:GetID()
            end
        end
        if type(selectedNativeTab) == "number" then
            _G.EncounterJournal_SetTab(selectedNativeTab)
        end
    end
end

-- ==============================
-- 탭 활성화 / 비활성화
-- ==============================
function module:ActivateCustomTab()
    if not self.tabButton then return end

    self.customTabActive = true

    -- 블리자드 내부 탭 값(encounter.info.tab)을 우리 커스텀 탭 ID로 업데이트하여
    -- 블리자드 내부의 OnShow/OnUpdate 재갱신 루프가 던전 개요(Tab 1)를 강제로 표시하려던 오작동 원천 차단!
    local _, _, infoFrame = GetEncounterFrames()
    if infoFrame then
        infoFrame.tab = CUSTOM_TAB_ID
    end

    self:SetCustomTabSelected(true)
    self:ClearNativeTabSelection()
    self:HideNativeEncounterContent()

    if self.customPanel then
        self.customPanel:Show()
    end
end

function module:DeactivateCustomTab()
    if not self.customTabActive then return end

    self.customTabActive = false
    self:SetCustomTabSelected(false)

    if self.customPanel then
        self.customPanel:Hide()
    end

    -- 블리자드 순정 탭 값 복구 (기본적으로 개요 탭 등으로 원복)
    local _, _, infoFrame = GetEncounterFrames()
    if infoFrame then
        local selectedNativeTab = 1
        if infoFrame.OverviewTab then
            selectedNativeTab = infoFrame.OverviewTab:GetID()
        elseif infoFrame.overviewTab then
            selectedNativeTab = infoFrame.overviewTab:GetID()
        end
        infoFrame.tab = selectedNativeTab
    end

    self:ShowNativeEncounterContent()
end

-- ==============================
-- UI 구성 및 등록
-- ==============================
function module:CreateCustomPanel(infoFrame)
    if self.customPanel or not infoFrame then return end

    local panelAnchorFrame = infoFrame.model or infoFrame.detailsScroll
    if not panelAnchorFrame then return end

    -- 커스텀 패널 프레임 생성
    local panel = CreateFrame("Frame", "dodoEncounterAchievementsPanel", infoFrame)
    panel:SetPoint("TOPLEFT", panelAnchorFrame, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", panelAnchorFrame, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel((infoFrame:GetFrameLevel() or 1) + 40)
    panel:Hide()

    -- 투명 오버레이로 변경 (블리자드 기본 종이 배경이 보이도록 함)
    panel.Bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.Bg:SetAllPoints()
    panel.Bg:SetColorTexture(0, 0, 0, 0)

    -- 임시 텍스트
    panel.TempText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.TempText:SetPoint("CENTER", panel, "CENTER", 0, 0)
    panel.TempText:SetText("dodo 업적 패널 (배경 개선 완료!)")
    panel.TempText:SetTextColor(0.25, 0.15, 0.05, 0.8) -- 갈색톤 가죽 종이 배경에 맞춘 짙은 다크 브라운 텍스트

    self.customPanel = panel
end

function module:CreateCustomSideTab(infoFrame)
    if self.tabButton then return end

    -- 대소문자 둘 다 안전 지원
    local anchorTab = infoFrame.ModelTab or infoFrame.modelTab
    if not anchorTab then return end

    -- 블리자드 순정 모험안내서 탭 템플릿 사용
    local tab = CreateFrame("Button", "dodoEncounterAchievementsTab", infoFrame, "EncounterTabTemplate")
    tab:SetID(CUSTOM_TAB_ID)
    tab.tooltip = _G.ACHIEVEMENTS or "업적"
    tab:SetPoint("TOP", anchorTab, "BOTTOM", 0, 2)

    -- 요청된 업적 마이크로메뉴 아틀라스 지정
    local atlasName = "UI-HUD-MicroMenu-Achievements-Mouseover"
    
    -- 선택 비활성화 상태의 아이콘 텍스처
    local unselected = tab:CreateTexture(nil, "OVERLAY")
    unselected:SetSize(42, 42)
    unselected:SetPoint("CENTER", tab, "CENTER", 0, 0)
    unselected:SetAtlas(atlasName)
    unselected:SetVertexColor(0.83, 0.73, 0.58, 0.9)

    -- 선택 활성화 상태의 아이콘 텍스처
    local selected = tab:CreateTexture(nil, "OVERLAY")
    selected:SetAllPoints(unselected)
    selected:SetAtlas(atlasName)
    selected:SetVertexColor(1, 0.93, 0.66, 1)
    selected:Hide()

    tab.unselectedTexture = unselected
    tab.selectedTexture = selected

    tab:SetScript("OnClick", function(self)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN then
            PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        end
        module:ActivateCustomTab()
    end)

    tab:Show()
    self.tabButton = tab
end

-- ==============================
-- 블리자드 시각 제어 가드 (OnShow 가드)
-- ==============================
function module:InstallNativeVisibilityGuards(infoFrame)
    if self.nativeVisibilityGuardsInstalled or not infoFrame then return end

    local function GuardFrame(nativeFrame)
        if not nativeFrame or not nativeFrame.HookScript then return end

        nativeFrame:HookScript("OnShow", function(frame)
            if module.customTabActive then
                frame:Hide()
            end
        end)
    end

    GuardFrame(infoFrame.overviewScroll)
    GuardFrame(infoFrame.LootContainer)
    GuardFrame(infoFrame.detailsScroll)
    GuardFrame(infoFrame.model)
    
    local _, encounterFrame = GetEncounterFrames()
    GuardFrame(encounterFrame and encounterFrame.overviewFrame)
    GuardFrame(encounterFrame and encounterFrame.infoFrame)

    -- 던전 대문 및 던전 이미지 가드
    GuardFrame(encounterFrame and encounterFrame.instance)
    GuardFrame(_G.InstanceFrameBG)

    -- 던전 난이도 드롭다운 가드
    GuardFrame(infoFrame.difficulty)
    GuardFrame(_G.EncounterJournalEncounterFrameInfoDifficulty)

    self.nativeVisibilityGuardsInstalled = true
end

-- ==============================
-- 블리자드 안전 훅 등록
-- ==============================
function module:InstallEncounterHooks()
    -- 순정 탭 클릭 시 우리 커스텀 탭 꺼주기
    dodo.HookOnce("EncounterJournal_SetTab", function()
        if module.customTabActive then
            module:DeactivateCustomTab()
        end
    end)

    -- 모험안내서 닫힐 때 비활성화
    local journal = _G.EncounterJournal
    if journal and journal.HookScript then
        journal:HookScript("OnHide", function()
            module:DeactivateCustomTab()
        end)
    end

    -- 인스턴스 페이지가 닫힐 때(예: 목록으로 돌아갈 때) 비활성화
    local encounterFrame = journal and journal.encounter
    if encounterFrame and encounterFrame.HookScript then
        encounterFrame:HookScript("OnHide", function()
            module:DeactivateCustomTab()
        end)
    end
end

function module:InitializeJournalIntegration()
    local journal = _G.EncounterJournal
    local infoFrame = journal and journal.encounter and journal.encounter.info
    if not infoFrame then return end

    self:CreateCustomSideTab(infoFrame)
    self:CreateCustomPanel(infoFrame)
    self:InstallNativeVisibilityGuards(infoFrame)
    self:InstallEncounterHooks()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false

function module:OnEnable()
    -- 마스터 토글 기본값 설정
    if dodo.DB and dodo.DB.enableEncounterAchievementsModule == nil then
        dodo.DB.enableEncounterAchievementsModule = true
    end

    local enabled = dodo.DB and dodo.DB.enableEncounterAchievementsModule
    if not enabled then
        if self.tabButton then self.tabButton:Hide() end
        if self.customPanel then self.customPanel:Hide() end
        return
    end

    if isInitialized then return end
    isInitialized = true

    -- 지연 로드 이벤트 등록 (EncounterJournal 대기)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(sf, event, loadedAddon)
        if loadedAddon == BLIZZARD_ENCOUNTER_ADDON then
            module:InitializeJournalIntegration()
            sf:UnregisterEvent("ADDON_LOADED")
        end
    end)

    -- 이미 로드된 상태인 경우 즉시 초기화
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(BLIZZARD_ENCOUNTER_ADDON) then
        self:InitializeJournalIntegration()
    end
end
