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
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter
local ChatFrame_RemoveMessageEventFilter = ChatFrame_RemoveMessageEventFilter
local CreateFrame = CreateFrame
local IsInInstance = IsInInstance
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
local _G = _G
local issecretvalue = issecretvalue
local pairs = pairs
local type = type

-- 가벼운 메모리용 해시 캐시
local channel_cache = {}

-- 1. 채널 축약 변환 필터 함수 (CHAT_MSG_CHANNEL용)
local function filter_channel_message(self, event, msg, author, lang, channelString, target, flags, zoneChannelID, channelIndex, channelBaseName, ...)
    if not dodo.DB.enableChatModule or not dodo.DB.useShortenChannels then
        return false, msg, author, lang, channelString, target, flags, zoneChannelID, channelIndex, channelBaseName, ...
    end

    -- KString 비밀값 체크
    if issecretvalue and (issecretvalue(msg) or issecretvalue(channelString) or (channelBaseName and issecretvalue(channelBaseName))) then
        return false, msg, author, lang, channelString, target, flags, zoneChannelID, channelIndex, channelBaseName, ...
    end

    local new_channel_string = channelString

    -- 캐시 검사
    if channel_cache[channelString] then
        new_channel_string = channel_cache[channelString]
    else
        local matched = false
        -- 1. 고정 축약 매칭
        for full, short in pairs(Config.channelAbbreviations) do
            if channelString:find(full) then
                channel_cache[channelString] = short
                new_channel_string = short
                matched = true
                break
            end
        end

        -- 2. 사설 채널 인덱스 보존 처리 ("1. 공개" -> "1")
        if not matched then
            local index = channelString:match("^(%d+)%.")
            if index then
                channel_cache[channelString] = index
                new_channel_string = index
            else
                channel_cache[channelString] = channelString
            end
        end
    end

    return false, msg, author, lang, new_channel_string, target, flags, zoneChannelID, channelIndex, channelBaseName, ...
end

-- 2. 전역 채널 포맷 재정의 (길드/파티/공대 단축용)
local function apply_global_channel_formats()
    local enabled = (dodo.DB.enableChatModule ~= false and dodo.DB.useShortenChannels ~= false)
    if enabled then
        _G.CHAT_PARTY_GET = "|Hchannel:Party|h[파티]|h %s: "
        _G.CHAT_PARTY_LEADER_GET = "|Hchannel:Party|h[파티]|h %s: "
        _G.CHAT_RAID_GET = "|Hchannel:Raid|h[공]|h %s: "
        _G.CHAT_RAID_LEADER_GET = "|Hchannel:Raid|h[공]|h %s: "
        _G.CHAT_INSTANCE_CHAT_GET = "|Hchannel:INSTANCE_CHAT|h[인스]|h %s: "
        _G.CHAT_INSTANCE_CHAT_LEADER_GET = "|Hchannel:INSTANCE_CHAT|h[인스]|h %s: "
        _G.CHAT_GUILD_GET = "|Hchannel:Guild|h[길]|h %s: "
        _G.CHAT_OFFICER_GET = "|Hchannel:Officer|h[관]|h %s: "
    else
        -- 기본값 복원
        _G.CHAT_PARTY_GET = "|Hchannel:Party|h[파티]|h %s: "
        _G.CHAT_PARTY_LEADER_GET = "|Hchannel:Party|h[파티]|h %s: "
        _G.CHAT_RAID_GET = "|Hchannel:Raid|h[공격대]|h %s: "
        _G.CHAT_RAID_LEADER_GET = "|Hchannel:Raid|h[공격대]|h %s: "
        _G.CHAT_INSTANCE_CHAT_GET = "|Hchannel:INSTANCE_CHAT|h[인스턴스]|h %s: "
        _G.CHAT_INSTANCE_CHAT_LEADER_GET = "|Hchannel:INSTANCE_CHAT|h[인스턴스]|h %s: "
        _G.CHAT_GUILD_GET = "|Hchannel:Guild|h[길드]|h %s: "
        _G.CHAT_OFFICER_GET = "|Hchannel:Officer|h[관리자]|h %s: "
    end
end

-- 3. 업데이트 분기 연동 및 필터 등록
local is_filter_registered = false

local function update_state()
    apply_global_channel_formats()

    local in_instance = IsInInstance()
    local should_register = (dodo.DB.enableChatModule ~= false and dodo.DB.useShortenChannels ~= false and not in_instance)

    if should_register then
        if not is_filter_registered then
            ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filter_channel_message)
            is_filter_registered = true
        end
    else
        if is_filter_registered then
            ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", filter_channel_message)
            is_filter_registered = false
        end
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

-- 4. 게임 내 설정 연결
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
