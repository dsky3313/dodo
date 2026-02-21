-- ==============================
-- 테이블
-- ==============================
---@diagnostic disable: lowercase-global
local addonName, dodo = ...
dodoDB = dodoDB or {}

local SendChat = C_ChatInfo and C_ChatInfo.SendChatMessage

-- ==============================
-- 동작
-- ==============================
local function chatKeyRoll()
    if not dodoDB then return end

    local isEnabled = (dodoDB.useKeyRoll ~= false)
    if not isEnabled then return end

    if IsInGroup() then
        local msg = "돌 굴리세요!"
        local chatType = "YELL"

        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage(msg, chatType)
        else
            SendChatMessage(msg, chatType)
        end
    end
end


-- ==============================
-- 이벤트
-- ==============================
local initKeyRoll = CreateFrame("Frame")
initKeyRoll:RegisterEvent("ADDON_LOADED")
initKeyRoll:SetScript("OnEvent", function(self, event, arg1)
    local isEnabled = (dodoDB.useKeyRoll ~= false)

    if event == "PLAYER_ENTERING_WORLD" then
        if isEnabled then
            self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        else
            self:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
        end
    elseif isEnabled and event == "CHALLENGE_MODE_COMPLETED" then
        C_Timer.After(10, chatKeyRoll)
    end
end)

function KeyRoll()
    initKeyRoll:RegisterEvent("PLAYER_ENTERING_WORLD")
    if IsLoggedIn() then
        initKeyRoll:GetScript("OnEvent")(initKeyRoll, "PLAYER_ENTERING_WORLD")
    end
end

dodo.KeyRoll = KeyRoll