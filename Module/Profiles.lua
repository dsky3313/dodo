-- ==============================
-- Inspired
-- ==============================
-- dodo Profiles (Game Settings & Profile Export)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Profiles", module)

local LibEditMode = LibStub and LibStub("LibEditMode", true)

-- ==============================
-- 캐싱 및 상수
-- ==============================
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetCVar = GetCVar
local IsControlKeyDown = IsControlKeyDown
local SetCVar = SetCVar
local UIParent = UIParent
local _G = _G

local NAMEPLATE_CLASS_COLOR = "nameplateUseClassColorForFriendlyPlayerUnitNames"
local NAMEPLATE_ONLY_NAME = "nameplateShowOnlyNameForFriendlyPlayerUnits"

-- 프로필 데이터 캐시
local HUD_PROFILE_CODE = "테스트문구"
local PLATER_PROFILE_CODE = "플레이터코드"

-- ==============================
-- CVar 최적화 설정 리스트
-- ==============================
local OPTIMIZED_CVARS = {
    -- 일반 설정
    { "countdownForCooldowns", 1 },      -- 재사용 대기시간 숫자 표시
    { "screenshotQuality", 10 },         -- 스크린샷 품질 (10)
    { "showTutorials", 0 },              -- 튜토리얼 숨기기
    { "damageMeterEnabled", 1 },
    { "damageMeterResetOnNewInstance", 1 },
    { "encounterWarningsEnabled", 1 },

    -- 이름표 최적화
    { "nameplateMaxDistance", 60 },      -- 이름표 표시 거리 (60)
    { "nameplateMinScale", 1 },          -- 이름표 최소 크기
    { "nameplateMaxScale", 1 },          -- 이름표 최대 크기
    { "nameplateMinAlpha", 0.9 },        -- 비대상 이름표 투명도
    { "nameplateOccludedAlphaMult", 0.4 }, -- 벽 뒤 유닛 이름표 투명도
    { NAMEPLATE_CLASS_COLOR, 1 },
    { NAMEPLATE_ONLY_NAME, 1 },

    -- 카메라 최적화
    { "cameraDistanceMaxZoomFactor", 2.6 }, -- 최대 시야 거리 확장
    { "cameraIndirectVisibility", 1 },      -- 장애물 뒤 캐릭터 실루엣 표시
    { "cameraIndirectOffset", 10 },

    -- 기타 시스템 최적화
    { "advancedCombatLogging", 1 },
    { "autoDismountFlying", 1 },
    { "autoLootDefault", 1 },
    { "Contrast", 70 },
    { "deselectOnClick", 1 },
    { "enableMultiActionBars", 127 },
    { "findYourselfAnywhere", 1 },
    { "findYourselfModeCircle", 1 },
    { "findYourselfModeOutline", 1 },
    { "ResampleAlwaysSharpen", 1 },
    { "showDungeonEntrancesOnMap", 1 },
    { "SoftTargetInteract", 3 },
    { "spellActivationOverlayOpacity", 0.25 },
    { "volumeFogLevel", 0 },
    { "vsync", 0 },
    { "weatherDensity", 0 },
    { "worldPreloadNonCritical", 0 },
    { "xpBarText", 1 },
}

-- ==============================
-- 기능: CVar 및 이름표 설정
-- ==============================
function dodo:SetupCVars()
    for _, info in ipairs(OPTIMIZED_CVARS) do
        local cvar, value = info[1], info[2]
        local current = GetCVar(cvar)
        if current ~= tostring(value) then
            SetCVar(cvar, value)
        end
    end
    print("|cffffd200[dodo]|r 게임 설정 최적화가 완료되었습니다.")
end

local function update_friendly_nameplates()
    if not dodo.DB then return end
    local isEnabled = (dodo.DB.useNameplateFriendly ~= false)

    if isEnabled then
        SetCVar(NAMEPLATE_CLASS_COLOR, 1)
        SetCVar(NAMEPLATE_ONLY_NAME, 1)
    else
        SetCVar(NAMEPLATE_CLASS_COLOR, 0)
        SetCVar(NAMEPLATE_ONLY_NAME, 0)
    end
end

local function hide_copy_popup()
    local popup = _G["dodo_LayoutCopyPopup"]
    if popup then
        popup:Hide()
    end
end

-- ==============================
-- 기능: 팝업 관리
-- ==============================
local function show_copy_popup(text, title)
    local popup = _G["dodo_LayoutCopyPopup"]
    if not popup then
        popup = CreateFrame("Frame", "dodo_LayoutCopyPopup", UIParent, "PortraitFrameTemplate")
        _G.ButtonFrameTemplate_HidePortrait(popup)
        popup:SetSize(300, 80)
        popup:SetPoint("CENTER")
        popup:SetFrameStrata("DIALOG")

        local eb = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        eb:SetPoint("BOTTOMLEFT", 25, 15)
        eb:SetPoint("BOTTOMRIGHT", -15, 15)
        eb:SetHeight(24)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() popup:Hide() end)
        eb:SetScript("OnEnterPressed", function() popup:Hide() end)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

        eb:SetScript("OnKeyDown", function(self, key)
            if IsControlKeyDown() and key == "C" then
                C_Timer.After(0.1, hide_copy_popup)
            end
        end)
        popup.editBox = eb
    end

    popup.TitleContainer.TitleText:SetText(title or "텍스트 복사 (Ctrl+C)")
    popup.editBox:SetText(text)
    popup:Show()
    popup.editBox:SetFocus()
    popup.editBox:HighlightText()
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    update_friendly_nameplates()

    if isInitialized then return end
    isInitialized = true

    -- dodoEditModePanel 내부에 설정 주입
    if dodo.RegisterEditModeModuleSetting then
        -- 인터페이스 카테고리
        dodo.RegisterEditModeModuleSetting("인터페이스", {
            {
                name = "아군 이름표 자동 설정",
                get = function() return dodo.DB and dodo.DB.useNameplateFriendly ~= false end,
                set = function(checked)
                    if dodo.DB then dodo.DB.useNameplateFriendly = checked end
                    update_friendly_nameplates()
                end
            }
        })

        -- 설정 & 프로필 카테고리
        dodo.RegisterEditModeModuleSetting("설정 & 프로필", {
            {
                type = "button",
                name = "HUD 레이아웃",
                text = "복사",
                onClick = function()
                    show_copy_popup(HUD_PROFILE_CODE, "HUD 레이아웃 복사 (Ctrl+C)")
                end
            },
            {
                type = "button",
                name = "플레이터",
                text = "복사",
                onClick = function()
                    show_copy_popup(PLATER_PROFILE_CODE, "플레이터 복사 (Ctrl+C)")
                end
            },
            {
                type = "button",
                name = "CVar 최적화",
                text = "실행",
                onClick = function()
                    dodo:SetupCVars()
                end
            }
        })
    end
end
