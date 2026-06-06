-- ============================================================================
-- dodo: ChatFrame Short (채널 단축 표시 설정)
-- License: GPLv3 (배포 가능 자유 라이선스)
-- ============================================================================
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

-- 캐싱 및 와우 API 단축
local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local issecretvalue = issecretvalue
local pairs = pairs
local type = type

-- 가벼운 메모리용 해시 캐시
local channel_cache = {}

-- 1. 채널 축약 변환 헬퍼 함수
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
    if not text or not dodo.DB.enableChatModule or not dodo.DB.useShortenChannels or type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then 
        return text 
    end
    return text:gsub("|Hchannel:(.-)|h%[(.-)%]|h", shorten_channel_match)
end

dodo.ShortenChannels = shorten_channels

-- 2. 업데이트 및 상태 제어
local function update_state()
    if dodo.UpdateChatFontState then
        dodo.UpdateChatFontState()
    end
end

dodo.UpdateChatShortState = update_state

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if dodo.DB.useShortenChannels == nil then dodo.DB.useShortenChannels = true end
        update_state()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        update_state()
    end
end)

-- 3. 게임 내 설정 연결
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
