-- ==============================
-- 설정 및 테이블
-- ==============================
---@diagnostic disable: lowercase-global, param-type-mismatch, redundant-parameter, undefined-field, undefined-global
local addonName, dodo = ...
dodoDB = dodoDB or {}
dodo.DB = dodo.DB or dodoDB

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

local channel_cache = {}

-- ==============================
-- 캐싱
-- ==============================
local CreateFrame = CreateFrame
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local _G = _G
local issecretvalue = issecretvalue or function() return false end
local pairs = pairs
local type = type

-- ==============================
-- 채널명 축약 로직
-- ==============================
local function shorten_channel_match(chan, name)
    if channel_cache[name] then 
        return "|Hchannel:" .. chan .. "|h[" .. channel_cache[name] .. "]|h" 
    end

    for full, short in pairs(Config.channelAbbreviations) do
        if name:find(full) then
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
    if not text or not dodo.DB.enableChatModule or not dodo.DB.useShortenChannels or type(text) ~= "string" or issecretvalue(text) then 
        return text 
    end
    return text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", shorten_channel_match)
end

local function hook_chat_frames()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame"..i]
        if frame and not frame.dodoShortenHooked then
            frame.dodoShortenHooked = true
            frame.OldAddMessage = frame.AddMessage
            frame.AddMessage = function(self, text, ...)
                return self:OldAddMessage(shorten_channels(text), ...)
            end
        end
    end
end

-- ==============================
-- 상태 업데이트 및 초기화
-- ==============================
local function update_state()
    hook_chat_frames()
end

dodo.UpdateChatShortState = update_state

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if dodo.DB.useShortenChannels == nil then dodo.DB.useShortenChannels = true end
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
