-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
local module = {}
dodo:RegisterModule("Slash", module)

local DoReadyCheck = DoReadyCheck
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local UnitIsGroupLeader = UnitIsGroupLeader
local _G = _G
local C_ChatInfo = C_ChatInfo
local C_PartyInfo = C_PartyInfo
local ChatEdit_SendText = ChatEdit_SendText
local ReloadUI = ReloadUI
local ShowMacroFrame = ShowMacroFrame
local SlashCmdList = SlashCmdList

-- ==============================
-- 동작 (동적 객체들은 런타임 시점에 _G에서 안전하게 참조)
-- ==============================

-- 1. 편집 모드
local function editMode()
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

-- 2. 쿨다운매니저
local function cdm()
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

-- 3. MDT
local function mdt(x)
    local editBox = _G.ChatFrame1EditBox
    if editBox then
        editBox:SetText("/MDT")
        ChatEdit_SendText(editBox)
    end
end

-- 4. 플레이터
local function pp(x)
    local editBox = _G.ChatFrame1EditBox
    if editBox then
        editBox:SetText("/plater")
        ChatEdit_SendText(editBox)
    end
end

-- 7. 위크오라
local function wa(x)
    local editBox = _G.ChatFrame1EditBox
    if editBox then
        editBox:SetText("/wa")
        ChatEdit_SendText(editBox)
    end
end

function module:OnEnable()
    -- 1. 편집 모드
    SLASH_DODO_EDITMODE1 = "/ed"
    SLASH_DODO_EDITMODE2 = "/ㄷㅇ"
    SlashCmdList["DODO_EDITMODE"] = function()
        editMode()
    end

    -- 2. 쿨다운매니저
    SLASH_DODO_CDM1 = "/cd"
    SLASH_DODO_CDM2 = "/ㅊㅇ"
    SlashCmdList["DODO_CDM"] = function()
        cdm()
    end

    -- 3. MDT (충돌 및 무한루프 방지 접두사 적용)
    SLASH_DODO_MDT1 = "/ㅡㅇㅅ"
    SlashCmdList["DODO_MDT"] = function(x)
        mdt(x)
    end

    -- 4. 플레이터 (충돌 및 무한루프 방지 접두사 적용)
    SLASH_DODO_PLATER1 = "/pp"
    SLASH_DODO_PLATER2 = "/ㅔㅔ"
    SlashCmdList["DODO_PLATER"] = function(x)
        pp(x)
    end

    -- 5. 리로드
    SLASH_DODO_RELOAD1 = "/re"
    SLASH_DODO_RELOAD2 = "/ㄱㄷ"
    SlashCmdList["DODO_RELOAD"] = ReloadUI

    -- 6. 매크로
    SLASH_DODO_MACRO1 = "/ㅡ"
    SlashCmdList["DODO_MACRO"] = function()
        ShowMacroFrame()
    end

    -- 7. 위크오라
    SLASH_DODO_WEAK_AURA1 = "/ㅈㅁ"
    SLASH_DODO_WEAK_AURA2 = "/ㅁㅈ"
    SLASH_DODO_WEAK_AURA3 = "/aw"
    SlashCmdList["DODO_WEAK_AURA"] = function(x)
        wa(x)
    end

    -- 8. 전투준비
    SLASH_DODO_RC1 = "/11"
    SlashCmdList["DODO_RC"] = function()
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

    -- 9. 파탈
    SLASH_DODO_LEAVEPARTY1 = "/ㅍㅌ"
    SLASH_DODO_LEAVEPARTY2 = "/vx"
    SlashCmdList["DODO_LEAVEPARTY"] = function()
        C_PartyInfo.LeaveParty()
    end

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