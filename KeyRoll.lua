------------------------------
-- 테이블
------------------------------
local addonName, dodo = ...

local function GetLib()
    return LibStub and LibStub:GetLibrary("LibOpenRaid-1.0", true)
end

local SendChat = C_ChatInfo and C_ChatInfo.SendChatMessage

------------------------------
-- 디스플레이
------------------------------
local KeyRollFrame = CreateFrame("Frame", "KeyRollFrame", UIParent)
KeyRollFrame:SetSize(500, 300)
KeyRollFrame:SetPoint("TOP", 0, -100)
KeyRollFrame:Hide()

KeyRollFrame.textTitle = KeyRollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHugeOutline")
KeyRollFrame.textTitle:SetPoint("TOPLEFT", KeyRollFrame, "TOPLEFT", 0, 0)
KeyRollFrame.textTitle:SetText("[ 파티 쐐기돌 ]")
KeyRollFrame.textTitle:SetTextColor(0.41, 0.8, 0.94)

KeyRollFrame.textMember = KeyRollFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLargeOutline")
KeyRollFrame.textMember:SetPoint("TOPLEFT", KeyRollFrame.textTitle, "BOTTOMLEFT", 0, -15) -- 제목 아래 15픽셀 지점
KeyRollFrame.textMember:SetJustifyH("LEFT")
KeyRollFrame.textMember:SetTextColor(1, 1, 1)
KeyRollFrame.textMember:SetSpacing(6)

------------------------------
-- 동작
------------------------------
local function GetDungeonName(mapID)
    if not mapID or mapID == 0 then return "알 수 없음" end
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    return (name and name ~= "") and name or "던전"
end

local function GetKeyLink(keystone)
    if not keystone or not keystone.level or keystone.level <= 0 then
        return "|cff808080쐐기돌 없음|r"
    end
    local mapID = keystone.challengeMapID or keystone.mythicPlusMapID
    return string.format("+%d %s", keystone.level, GetDungeonName(mapID))
end

local function UpdateDisplay()
    local isEnabled = dodoDB.useKeyRoll ~= false
    if not isEnabled then return end

    local LibOpenRaid = GetLib()
    if not LibOpenRaid then return end

    local partyMembers = {"player"}
    local num = GetNumGroupMembers()
    if num > 1 then
        for i = 1, num - 1 do table.insert(partyMembers, "party" .. i) end
    end

    local displayText = ""
    for _, unit in ipairs(partyMembers) do
        local info = LibOpenRaid.GetKeystoneInfo(unit)
        local uName = UnitName(unit)
        local _, class = UnitClass(unit)
        local color = (RAID_CLASS_COLORS[class] and RAID_CLASS_COLORS[class].colorStr) or "ffffffff"

        if info then
            displayText = displayText .. string.format("|c%s%s|r: %s\n", color, uName, GetKeyLink(info))
        end
    end

    if displayText ~= "" then
        KeyRollFrame.textMember:SetText(displayText)
        KeyRollFrame:Show()
    end
end

------------------------------
-- 이벤트
------------------------------
local initKeyRoll = CreateFrame("Frame")
initKeyRoll:RegisterEvent("PLAYER_ENTERING_WORLD")
initKeyRoll:RegisterEvent("CHALLENGE_MODE_COMPLETED")
initKeyRoll:RegisterEvent("CHAT_MSG_LOOT")
initKeyRoll:SetScript("OnEvent", function(self, event, arg1)
    local isEnabled = dodoDB.useKeyRoll ~= false
    if event == "PLAYER_ENTERING_WORLD" then
        if isEnabled then
            self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
            self:RegisterEvent("CHAT_MSG_LOOT")
        else
            self:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
            self:UnregisterEvent("CHAT_MSG_LOOT")
        end

    elseif event == "CHALLENGE_MODE_COMPLETED" and isEnabled then
        C_Timer.After(5, function()
            UpdateDisplay()
            C_Timer.After(5, function()
                if IsInGroup() then SendChat("돌 굴리세요!", "YELL") end
                C_Timer.After(45, function() KeyRollFrame:Hide() end)
            end)
        end)

    elseif event == "CHAT_MSG_LOOT" and isEnabled then
        local text = arg1
        if text and (text:find("item:158923") or text:find("쐐기돌")) then
            C_Timer.After(1, UpdateDisplay)
        end
    end
end)

------------------------------
-- 3. 초기화 함수 (스위치 역할)
------------------------------
function dodo.KeyRoll()
    -- 초기 실행 시 필요한 이벤트만 등록
    initKeyRoll:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- 명령어 등록
    SLASH_KEYROLL1 = "/돌"
    SlashCmdList["KEYROLL"] = function(msg)
        if msg == "닫기" then KeyRollFrame:Hide() else UpdateDisplay() end
    end

    -- (선택 사항) 초기화 시점에 이미 게임에 들어와 있다면 이벤트를 즉시 체크
    if IsLoggedIn() then
        initKeyRoll:GetScript("OnEvent")(initKeyRoll, "PLAYER_ENTERING_WORLD")
    end
end