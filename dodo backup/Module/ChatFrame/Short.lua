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
local pairs = pairs
local type = type

-- ==============================
-- 기능 구현
-- ==============================
local channel_cache = {}

local function abbreviate_channel_name(name)
    if not name or type(name) ~= "string" then return name end
    if channel_cache[name] then return channel_cache[name] end

    for full, short in pairs(Config.channelAbbreviations) do
        if name:find(full, 1, true) then
            channel_cache[name] = short
            return short
        end
    end

    channel_cache[name] = name
    return name
end

-- ChatFrameUtil.ResolvePrefixedChannelName 교체 방식 사용.
-- ChatFrame_AddMessageEventFilter로 arg4(channelString = "1. 공개")를 직접 수정하면
-- Blizzard 코드의 channelLength > strlen(channelListValue) 체크 실패 → 메시지 드롭.
-- 대신 표시 전용 함수를 교체해서 arg4는 보존하고 렌더 단계에서만 축약.
local function hook_resolve_prefixed()
    if not ChatFrameUtil or not ChatFrameUtil.ResolvePrefixedChannelName then return end

    local orig = ChatFrameUtil.ResolvePrefixedChannelName
    ChatFrameUtil.ResolvePrefixedChannelName = function(channelArg)
        if not (dodo.DB and dodo.DB.enableChatModule and dodo.DB.useShortenChannels) then
            return orig(channelArg)
        end
        -- "N. 채널명" 파싱. Communities 채널("N. clubId:streamId")은 orig로 위임.
        local name = channelArg:match("^%d+%. (.*)")
        if name and not name:find(":", 1, true) then
            return abbreviate_channel_name(name)
        end
        return orig(channelArg)
    end
end

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
    hook_resolve_prefixed()
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
