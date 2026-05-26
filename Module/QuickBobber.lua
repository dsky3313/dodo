-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("QuickBobber", module)
module.NonCombat = true

local LibIcon = dodo.LibIcon

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
-- 캐싱
-- ==============================
-- abc 오름차순 정렬 완료
-- [주의] ProfessionsBookFrame은 지연 로드(LoD) 되므로 절대 파일 로드 시점에 로컬 캐싱(Upvalue) 하면 안 됩니다!
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local _G = _G

-- ==============================
-- 디스플레이
-- ==============================
local BobberButton = LibIcon:Create("quickBobber", UIParent, BobberConfig)
BobberButton:Hide()

-- ==============================
-- 동작 (낚시찌 편의 기능)
-- ==============================
local function quick_bobber()
    if InCombatLockdown() then
        BobberButton:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local isEnabled = (dodo.DB and dodo.DB.enableQuickBobberModule ~= false)
    
    -- 전역 _G 테이블에서 동적으로 안전하게 실시간 확인
    local profFrame = _G.ProfessionsBookFrame
    local isUIOpen = (profFrame and profFrame:IsShown())

    -- 낚시찌 기능이 켜져 있고 전문기술 창이 열려 있을 때 작동
    if isEnabled and isUIOpen then
        BobberButton:RegisterEvent("BAG_UPDATE_DELAYED")
        BobberButton:RegisterEvent("BAG_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        BobberButton:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        
        BobberButton:ApplyConfig(BobberConfig)
        BobberButton:Show()
    else
        BobberButton:UnregisterAllEvents()
        BobberButton:Hide()
    end
end

-- 이벤트 핸들러
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

BobberButton:SetScript("OnEvent", on_bobber_event)

-- ==============================
-- 초기화
-- ==============================
local function initialize()
    if dodo.DB and dodo.DB.enableQuickBobberModule == nil then
        dodo.DB.enableQuickBobberModule = false
    end
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local bookHooked = false
local isInitialized = false
function module:OnEnable()
    initialize()
    quick_bobber()

    if isInitialized then return end
    isInitialized = true

    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    local function on_init_event(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            quick_bobber()
            self:UnregisterAllEvents()
        end
    end
    initFrame:SetScript("OnEvent", on_init_event)
    
    local function on_professions_book_loaded()
        local profFrame = _G.ProfessionsBookFrame
        if profFrame and not bookHooked then
            profFrame:HookScript("OnShow", quick_bobber)
            profFrame:HookScript("OnHide", quick_bobber)
            bookHooked = true
            quick_bobber()
        end
    end

    -- 지연 로드(LoD)되는 블리자드 전문기술 책 애드온 로드 완료 감시
    EventUtil.ContinueOnAddOnLoaded("Blizzard_ProfessionsBook", on_professions_book_loaded)

    -- 이미 로드되어 있는 상황을 대비한 즉시 훅 처리 (리로드 시)
    local profFrame = _G.ProfessionsBookFrame
    if profFrame and not bookHooked then
        profFrame:HookScript("OnShow", quick_bobber)
        profFrame:HookScript("OnHide", quick_bobber)
        bookHooked = true
    end

    -- dodoEditModePanel 내부에 세부 설정 주입
    if dodo.RegisterEditModeSetting then
        dodo.RegisterEditModeSetting("편의기능", {
            {
                name = "낚시찌 장난감 버튼",
                get = function() return dodo.DB and dodo.DB.enableQuickBobberModule or false end,
                set = function(checked)
                    if dodo.DB then 
                        dodo.DB.enableQuickBobberModule = checked 
                    end
                    quick_bobber()
                end
            }
        })
    end
end

-- ==============================
-- 전투 중 휴면 라이프사이클
-- ==============================
function module:OnCombatStart()
    BobberButton:UnregisterAllEvents()
    BobberButton:Hide()
end

function module:OnCombatEnd()
    quick_bobber()
end