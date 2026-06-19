-- ==============================
-- Inspired
-- ==============================
-- Chattynator (https://www.curseforge.com/wow/addons/chattynator)

-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

-- 축약어 고정 정의
local Config = {
    channelAbbreviations = {
        ["공개"] = "공개",
        ["거래"] = "거래",
        ["수비"] = "수비",
        ["파티"] = "파티",
        ["공격대"] = "공",
        ["인스턴스"] = "인스",
        ["길드"] = "길",
        ["공지"] = "공",
    }
}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local _G = _G
local issecretvalue = issecretvalue
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
local pairs = pairs
local type = type

-- ==============================
-- 기능 구현
-- ==============================
-- 가벼운 메모리용 해시 캐시
local channel_cache = {}

-- 1. 채널 축약 변환 헬퍼 함수
local function shorten_channel_match(chan, name)
    if channel_cache[name] then
        return "|Hchannel:" .. chan .. "|h[" .. channel_cache[name] .. "]|h"
    end

    for full, short in pairs(Config.channelAbbreviations) do
        if name:find(full, 1, true) then
            channel_cache[name] = short
            return "|Hchannel:" .. chan .. "|h[" .. short .. "]|h"
        end
    end

    local index = name:match("^(%d+)%.")
    if index then
        channel_cache[name] = index
        return "|Hchannel:" .. chan .. "|h[" .. index .. "]|h"
    end

    channel_cache[name] = name
    return "|Hchannel:" .. chan .. "|h[" .. name .. "]|h"
end

local function shorten_channels(text)
    if not text or not dodo.DB.enableChatModule or not dodo.DB.useShortenChannels or type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
        return text
    end
    return text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", shorten_channel_match)
end

dodo.ShortenChannels = shorten_channels

-- 2. AddMessage 래핑: 필터 이후 완성된 포맷 텍스트에서 |Hchannel:| 치환
-- ChatFrame_AddMessageEventFilter는 raw 이벤트 arg(메시지 본문)를 받으므로
-- 채널명 하이퍼링크가 없음. AddMessage를 직접 감싸야 완성된 텍스트를 받을 수 있음.
local function wrap_addmessage(frame)
    if not frame or frame._dodoShortHooked then return end
    frame._dodoShortHooked = true
    local orig = frame.AddMessage
    frame.AddMessage = function(self, msg, ...)
        return orig(self, shorten_channels(msg), ...)
    end
end

-- 3. 업데이트 및 상태 제어
local function update_state()
    if dodo.UpdateChatFontState then
        dodo.UpdateChatFontState()
    end
end

dodo.UpdateChatShortState = update_state

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if dodo.DB.useShortenChannels == nil then dodo.DB.useShortenChannels = true end
    for i = 1, NUM_CHAT_WINDOWS do
        wrap_addmessage(_G["ChatFrame"..i])
    end
    update_state()
    self:UnregisterAllEvents()
end)

-- ==============================
-- 설정 등록
-- ==============================
if dodo.RegisterEditModeSystemSetting then
    dodo.RegisterEditModeSystemSetting(Enum.EditModeSystem.ChatFrame, {
        {
            name = "채널명 축약",
            get = function() return dodo.DB and dodo.DB.useShortenChannels ~= false end,
            set = function(checked)
                if dodo.DB then dodo.DB.useShortenChannels = checked end
                update_state()
            end,
            disabled = function() return dodo.DB and dodo.DB.enableChatModule == false end,
        }
    })
end
