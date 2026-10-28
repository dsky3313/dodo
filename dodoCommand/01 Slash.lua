-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local DoReadyCheck = DoReadyCheck
local InCombatLockdown = InCombatLockdown
local IsInGroup = IsInGroup
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local UnitIsGroupLeader = UnitIsGroupLeader
local _G = _G
-- local C_AddOnProfiler = C_AddOnProfiler -- 프로파일러 비활성
local C_AddOns = C_AddOns
local C_ChatInfo = C_ChatInfo
local C_PartyInfo = C_PartyInfo
local ChatEdit_SendText = ChatEdit_SendText
local ChatFrame1EditBox = ChatFrame1EditBox
local CooldownViewerSettings = CooldownViewerSettings
local EditModeManagerFrame = EditModeManagerFrame
local ReloadUI = ReloadUI
-- local string_format = string.format -- 프로파일러 비활성
local ShowMacroFrame = ShowMacroFrame
local SlashCmdList = SlashCmdList

-- ==============================
-- 동작
-- ==============================
-- 편집 모드
local function editMode()
    if InCombatLockdown() then
        print("전투 중에는 열 수 없습니다.")
        return
    end

    if EditModeManagerFrame then
        ChatFrame1EditBox:SetText("/run ShowUIPanel(EditModeManagerFrame)")
        ChatEdit_SendText(ChatFrame1EditBox)
    end
end

SLASH_EDITMODE1 = "/ed"
SLASH_EDITMODE2 = "/ㄷㅇ"
SlashCmdList["EDITMODE"] = function()
    editMode()
end


-- 쿨다운매니저
local function cdm()
    if InCombatLockdown() then
        print("전투 중에는 열 수 없습니다.")
        return
    end
    local inInstance = IsInInstance()
    if inInstance then
        print("인스턴스 안에서는 /cd 를 사용할 수 없습니다. Blizzard 설정창에서 직접 여세요.")
        return
    end
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsPanel:Close(true)
    end
    ShowUIPanel(CooldownViewerSettings)
end

SLASH_CDM1 = "/cd"
SLASH_CDM2 = "/ㅊㅇ"
SlashCmdList["CDM"] = function()
    cdm()
end


-- MDT
local function mdt(x)
    ChatFrame1EditBox:SetText("/MDT")
    ChatEdit_SendText(ChatFrame1EditBox)
end
SLASH_MDT1 = "/ㅡㅇㅅ"
SlashCmdList["MDT"] = function(x)
    mdt(x)
end


-- 플레이터 / 플레이티
local function pp(x)
    local cmd
    if C_AddOns.IsAddOnLoaded("Plater") then
    cmd = "/plater"
    elseif C_AddOns.IsAddOnLoaded("Platynator") then
    cmd = "/platy"
    end
    if not cmd then return end
    ChatFrame1EditBox:SetText(cmd)
    ChatEdit_SendText(ChatFrame1EditBox)
end
SLASH_plater1 = "/pp"
SLASH_plater2 = "/ㅔㅔ"
SlashCmdList["plater"] = function(x)
    pp(x)
end

-- 리로드
SlashCmdList.RELOAD = ReloadUI
SLASH_RELOAD1 = "/re"
SLASH_RELOAD2 = "/ㄱㄷ"


-- dodo DB 초기화
SLASH_DODO_RESET1 = "/ddr"
SlashCmdList["DODO_RESET"] = function()
    dodoDB = nil
    ReloadUI()
end

-- 파티 추적 DB 초기화 (엔진 설정 + /dd 파티 추적 항목)
SLASH_DODO_PT_RESET1 = "/ptr"
SlashCmdList["DODO_PT_RESET"] = function()
    if dodoDB then
        dodoDB.partyTracker = nil
        local defaults = _G.dodo and _G.dodo.PT_DEFAULTS
        if defaults then
            for key in pairs(defaults) do dodoDB[key] = nil end
        end
    end
    ReloadUI()
end


-- 매크로
SlashCmdList.MACRO = function()
    ShowMacroFrame()	end
SLASH_MACRO1 = "/ㅡ"


-- 위크오라
local function wa(x)
    ChatFrame1EditBox:SetText("/wa")
    ChatEdit_SendText(ChatFrame1EditBox)
end
SLASH_WEAK_AURA1 = "/ㅈㅁ"
SLASH_WEAK_AURA2 = "/ㅁㅈ"
SLASH_WEAK_AURA3 = "/aw"
SlashCmdList["WEAK_AURA"] = function(x)
    wa(x)
end


-- 전투준비
SlashCmdList.RCSLASH = function()
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
SLASH_RCSLASH1 = "/11"


-- 파탈
SLASH_LEAVEPARTY1 = "/ㅍㅌ"
SLASH_LEAVEPARTY2 = "/vx"
SlashCmdList["LEAVEPARTY"] = function() C_PartyInfo.LeaveParty() end


-- 프레임스택
SlashCmdList.FSTACK = function()
SlashCmdList.FRAMESTACK(0)	end
SLASH_FSTACK1 = "/fs"
SLASH_FSTACK2 = "/ㄹㄴ"


-- [비활성] 프로파일러 (/pf) — 다시 쓰려면 아래 --[==[ 와 ]==] 줄 삭제 + 위 주석 2줄 해제
--[==[
-- 프로파일러 (dodo* 애드온별 호출 시간 지표)
-- 리로드/로그아웃으로는 초기화 안 됨 (게임 클라이언트 재시작 시 초기화)
local function profile()
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric) then return end
    local E = Enum.AddOnProfilerMetric
    print("|cff00ff00[dodo 프로파일]|r 애드온 | 최대(ms) | 1ms초과 | 5ms초과 | 평균(ms)")
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name:find("^dodo") and C_AddOns.IsAddOnLoaded(name) then
            local over1 = C_AddOnProfiler.GetAddOnMetric(name, E.CountTimeOver1Ms)
            print(string_format("%s%s|r | %.2f | %d | %d | %.4f",
                over1 > 0 and "|cffff5555" or "|cffffffff", name,
                C_AddOnProfiler.GetAddOnMetric(name, E.PeakTime), over1,
                C_AddOnProfiler.GetAddOnMetric(name, E.CountTimeOver5Ms),
                C_AddOnProfiler.GetAddOnMetric(name, E.SessionAverageTime)))
        end
    end
end

SLASH_DODO_PROFILE1 = "/pf"
SLASH_DODO_PROFILE2 = "/ㅔㄹ"
SlashCmdList["DODO_PROFILE"] = profile
]==]