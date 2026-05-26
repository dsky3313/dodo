-- ==============================
-- Inspired
-- ==============================

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Slash", module)

-- ==============================
-- 캐싱
-- ==============================
local C_ChatInfo = C_ChatInfo
local C_PartyInfo = C_PartyInfo
local ChatEdit_SendText = ChatEdit_SendText
local DoReadyCheck = DoReadyCheck
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local ReloadUI = ReloadUI
local ShowMacroFrame = ShowMacroFrame
local SlashCmdList = SlashCmdList
local UnitIsGroupLeader = UnitIsGroupLeader
local _G = _G

-- ==============================
-- 동작 (동적 객체들은 런타임 시점에 _G에서 안전하게 참조)
-- ==============================

-- 1. 편집 모드
local function actual_editMode()
    if InCombatLockdown() then
        print("전투 중에는 열 수 없습니다.")
        return
    end

    local editModeManager = _G.EditModeManagerFrame
    local editBox = _G.ChatFrame1EditBox
    if editModeManager and editBox then
        editBox:SetText("/run ShowUIPanel(EditModeManagerFrame)")
        ChatEdit_SendText(editBox)
    end
end

local function editMode()
    dodo.Profile("Slash_editMode", actual_editMode)
end

-- 2. 쿨다운매니저
local function actual_cdm()
    if InCombatLockdown() then
        print("전투 중에는 열 수 없습니다.")
        return
    end

    local cooldownViewer = _G.CooldownViewerSettings
    local editBox = _G.ChatFrame1EditBox
    if cooldownViewer and editBox then
        editBox:SetText("/run ShowUIPanel(CooldownViewerSettings)")
        ChatEdit_SendText(editBox)
    end
end

local function cdm()
    dodo.Profile("Slash_cdm", actual_cdm)
end

-- 3. MDT
local function actual_mdt()
    local editBox = _G.ChatFrame1EditBox
    if editBox then
        editBox:SetText("/MDT")
        ChatEdit_SendText(editBox)
    end
end

local function mdt()
    dodo.Profile("Slash_mdt", actual_mdt)
end

-- 4. 플레이터
local function actual_pp()
    local editBox = _G.ChatFrame1EditBox
    if editBox then
        editBox:SetText("/plater")
        ChatEdit_SendText(editBox)
    end
end

local function pp()
    dodo.Profile("Slash_pp", actual_pp)
end

-- 7. 위크오라
local function actual_wa()
    local editBox = _G.ChatFrame1EditBox
    if editBox then
        editBox:SetText("/wa")
        ChatEdit_SendText(editBox)
    end
end

local function wa()
    dodo.Profile("Slash_wa", actual_wa)
end

-- 8. 전투준비 (파일 레벨 정적 함수로 분리)
local function actual_RC()
    local isLeader = UnitIsGroupLeader("player")
    local inRaid = IsInRaid()
    local inParty = IsInGroup()
    local channel = inRaid and "RAID" or "PARTY"

    if isLeader then
        DoReadyCheck()
        C_ChatInfo.SendChatMessage("특성 / 도핑 / 버프리필 / 펫 확인", channel)
    elseif inParty then
        C_ChatInfo.SendChatMessage("파티장 주세요", channel)
    end
end

local function rc()
    dodo.Profile("Slash_DODO_RC", actual_RC)
end

-- ==============================
-- 모듈 생명주기
-- ==============================
local isInitialized = false
function module:OnEnable()
    if isInitialized then return end
    isInitialized = true

    -- 1. 편집 모드
    SLASH_DODO_EDITMODE1 = "/ed"
    SLASH_DODO_EDITMODE2 = "/ㄷㅇ"
    SlashCmdList["DODO_EDITMODE"] = editMode

    -- 2. 쿨다운매니저
    SLASH_DODO_CDM1 = "/cd"
    SLASH_DODO_CDM2 = "/ㅊㅇ"
    SlashCmdList["DODO_CDM"] = cdm

    -- 3. MDT (충돌 및 무한루프 방지 접두사 적용)
    SLASH_DODO_MDT1 = "/ㅡㅇㅅ"
    SlashCmdList["DODO_MDT"] = mdt

    -- 4. 플레이터 (충돌 및 무한루프 방지 접두사 적용)
    SLASH_DODO_PLATER1 = "/pp"
    SLASH_DODO_PLATER2 = "/ㅔㅔ"
    SlashCmdList["DODO_PLATER"] = pp

    -- 5. 리로드
    SLASH_DODO_RELOAD1 = "/re"
    SLASH_DODO_RELOAD2 = "/ㄱㄷ"
    SlashCmdList["DODO_RELOAD"] = ReloadUI

    -- 6. 매크로
    SLASH_DODO_MACRO1 = "/ㅡ"
    SlashCmdList["DODO_MACRO"] = ShowMacroFrame

    -- 7. 위크오라
    SLASH_DODO_WEAK_AURA1 = "/ㅈㅁ"
    SLASH_DODO_WEAK_AURA2 = "/ㅁㅈ"
    SLASH_DODO_WEAK_AURA3 = "/aw"
    SlashCmdList["DODO_WEAK_AURA"] = wa

    -- 8. 전투준비
    SLASH_DODO_RC1 = "/11"
    SlashCmdList["DODO_RC"] = rc

    -- 9. 파탈
    SLASH_DODO_LEAVEPARTY1 = "/ㅍㅌ"
    SLASH_DODO_LEAVEPARTY2 = "/vx"
    SlashCmdList["DODO_LEAVEPARTY"] = C_PartyInfo.LeaveParty

    -- 10. 프레임스택
    SLASH_DODO_FSTACK1 = "/fs"
    SLASH_DODO_FSTACK2 = "/ㄹㄴ"
    SlashCmdList["DODO_FSTACK"] = function()
        if SlashCmdList.FRAMESTACK then
            SlashCmdList.FRAMESTACK(0)
        end
    end
end

-- ==============================
-- 설정
-- ==============================
function module:CreateOptions()
    -- 설정 UI 없음
end