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
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local CreateFrame = CreateFrame
local issecretvalue = issecretvalue
local pairs = pairs
local type = type

-- ==============================
-- 기능 구현
-- ==============================
-- 가벼운 메모리용 해시 캐시
local channel_cache = {}

-- 1. 채널명 문자열(arg4) 축약 — 하이퍼링크 구성 전 raw 채널 설명자(예: "1. 일반")를 받음
local function abbreviate_channel_name(name)
    if not name or type(name) ~= "string" then return name end
    if channel_cache[name] then return channel_cache[name] end

    for full, short in pairs(Config.channelAbbreviations) do
        if name:find(full, 1, true) then
            channel_cache[name] = short
            return short
        end
    end

    local index = name:match("^(%d+)%.")
    if index then
        channel_cache[name] = index
        return index
    end

    channel_cache[name] = name
    return name
end

-- 2. CHAT_MSG_CHANNEL 필터: arg4(channelString)만 축약, 나머지 그대로 통과
-- AddMessage 직접 교체 방식은 MessageEventHandler 실행 컨텍스트를 오염시켜
-- SetLastTellTarget의 secret string 변환 실패를 유발하므로 필터 방식으로 대체.
-- sender(arg2)는 secret value이므로 절대 연산하지 않고 그대로 통과.
local function channel_filter(self, event, message, sender, language, channelString, ...)
    if not dodo.DB.enableChatModule or not dodo.DB.useShortenChannels then
        return false, message, sender, language, channelString, ...
    end
    return false, message, sender, language, abbreviate_channel_name(channelString), ...
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
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", channel_filter)
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
