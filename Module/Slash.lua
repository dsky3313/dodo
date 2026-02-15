-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

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


-- 쿨다운 매니저
local _G = _G
local CooldownViewerSettings = _G.CooldownViewerSettings

local function cdm()
    if InCombatLockdown() then
        print("전투 중에는 열 수 없습니다.")
        return
    end

    if CooldownViewerSettings then
        ChatFrame1EditBox:SetText("/run ShowUIPanel(CooldownViewerSettings)")
        ChatEdit_SendText(ChatFrame1EditBox)
    end
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
SLASH_MDT = "/ㅡㅇㅅ"
SlashCmdList["MDT"] = function(x)
  mdt(x)
end


-- 플레이터
local function pp(x)
  ChatFrame1EditBox:SetText("/plater")
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
      C_ChatInfo.SendChatMessage("특성 / 도핑 확인", channel)
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